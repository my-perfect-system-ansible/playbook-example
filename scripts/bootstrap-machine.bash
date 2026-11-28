#!/usr/bin/env bash
# Machine bootstrap: fetch every repo of the ecosystem onto a fresh host.
#
# Standalone (fresh machine, nothing cloned yet):
#   curl -fsSL https://raw.githubusercontent.com/my-perfect-system-ansible/playbook-example/main/scripts/bootstrap-machine.bash | bash
#
# From a clone (idempotent re-run, or `just bootstrap-machine`):
#   scripts/bootstrap-machine.bash
#
# Two phases, one file:
#   1. standalone (piped from curl, no sibling git.bash): install
#      prerequisites — git, plus the python3.13 interpreter pin on Fedora 45+
#      (the manual bootstrap prerequisite from AGENTS.md: ansible-core 2.19
#      breaks on the system Python 3.15) — clone the anchor repo
#      playbook-example (the only hardcoded URL; this repo owns the
#      cross-repo tooling), then re-exec the cloned copy of this script.
#   2. from clone (sibling git.bash present): source scripts/git.bash and
#      clone every missing sibling repo — the REPOS list stays single-sourced
#      there (odem-* + playbook-example in my-perfect-system-ansible/,
#      mps-* in my-perfect-system/).
#
# Layout created — root overridable with MPS_REPO_BASE (default
# /srv/repo/github, the canonical repo root per user_default_repo_dir; pass a
# custom path for dedicated data disks):
#
#   ${MPS_REPO_BASE}/my-perfect-system-ansible/{odem-*,playbook-example}
#   ${MPS_REPO_BASE}/my-perfect-system/mps-*
#
# Requires sudo rights (package installs; root-owned base creation).
# Idempotent: present repos are skipped, safe to re-run. Provisioning is NOT
# done here — accounts/config stay with the playbooks (just bootstrap <inv>);
# the script prints the next steps.
set -euo pipefail

ANCHOR_NAME="playbook-example"
ANCHOR_URL="https://github.com/my-perfect-system-ansible/${ANCHOR_NAME}.git"
REPO_BASE_DEFAULT="/srv/repo/github"

log() { echo "==> $*"; }

# Run a command via sudo when not root (empty-prefix ${SUDO} is avoided on
# purpose — no word-splitting surprises, no shellcheck 2086).
SUDO=""
[ "$(id -u)" -eq 0 ] || SUDO="sudo"
run_sudo() {
    if [ -n "$SUDO" ]; then "$SUDO" "$@"; else "$@"; fi
}

#--- Distro detection ------------------------------------------------------------
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
fi
OS_ID="${ID:-unknown}"
OS_VERSION_ID="${VERSION_ID:-0}"

pkg_install() {
    case "$OS_ID" in
        debian)
            run_sudo apt-get update -qq || true
            run_sudo apt-get install -y "$@"
            ;;
        fedora | rhel | rocky | almalinux | centos)
            run_sudo dnf install -y "$@"
            ;;
        *)
            echo "ERROR: unsupported distro '${OS_ID}' — install manually: $*" >&2
            return 1
            ;;
    esac
}

# Prerequisites every machine needs: git to fetch, and on Fedora 45+ the
# python3.13 interpreter pin ansible targets require (AGENTS.md → Fedora 45
# interpreter pinning).
install_prereqs() {
    if ! command -v git >/dev/null 2>&1; then
        log "Installing git (${OS_ID})"
        pkg_install git || { echo "ERROR: git is required" >&2; exit 1; }
    fi
    case "$OS_ID" in
        fedora)
            if [[ "$OS_VERSION_ID" =~ ^[0-9]+$ ]] && ((OS_VERSION_ID >= 45)) \
                && [ ! -x /usr/bin/python3.13 ]; then
                log "Installing python3.13 (Fedora 45+ interpreter pin)"
                pkg_install python3.13
            fi
            ;;
    esac
}

# Create a directory the invoking user can write to — plain mkdir when the
# parent is writable (MPS_REPO_BASE inside $HOME, or an admin-group-writable
# /srv/repo/github), elevated install when the base is root-owned.
ensure_dir() {
    mkdir -p "$1" 2>/dev/null && return 0
    run_sudo install -d -m 0755 -o "$(id -un)" -g "$(id -gn)" "$1"
}

print_next_steps() {
    local repo_root="$1" base mps_dir
    base=$(cd "${repo_root}/../.." && pwd)
    if [ -d "${base}/my-perfect-system" ]; then
        mps_dir="${base}/my-perfect-system"
    else
        mps_dir="${base}/my-perfect-system (clones failed — check summary above)"
    fi
    cat <<EOF

All repos fetched under ${base}. Next steps:

  cd ${repo_root}
  just install-forced              # build + install every odem.* collection
  just vault-pass-create <inv>     # per inventory (inventories/<inv>/vault-pass)
  just bootstrap <inv> -K          # provision — add the host to the inventory first

Notes:
  - 'just' + ansible-core are not installed by this script.
    Fedora: dnf install just ansible-core. Debian: apt install ansible-core;
    'just' via cargo or a release binary (github.com/casey/just).
  - Fedora 45+ as an ansible TARGET: this script installed python3.13 — set
    ansible_python_interpreter: /usr/bin/python3.13 in the host's host_vars
    when adding it to an inventory.
  - Per-user roles clone their own mps repos under user_default_repo_dir_mps
    (/srv/repo/github/my-perfect-system/mps), independent of this development
    tree (${mps_dir}).
  - A failed clone usually means a private repo — configure git
    credentials for github.com (gh auth login, credential helper, or SSH
    remotes) and re-run; present repos are skipped.
  - Keep the tree current: just git-pull
EOF
}

#--- Phase dispatch --------------------------------------------------------------
# Piped from curl, BASH_SOURCE[0] is empty → standalone; run from a clone,
# the sibling git.bash (this script's only library) marks phase 2.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "${SCRIPT_DIR}/git.bash" ]; then
    # Phase 2 — running from the playbook-example clone: fetch every repo.
    install_prereqs
    # shellcheck source=scripts/git.bash
    source "${SCRIPT_DIR}/git.bash"
    cd "$REPO_ROOT"
    log "Fetching every sibling repo (scripts/git.bash clone)"
    clone_failed=0
    git_clone || clone_failed=1
    print_next_steps "$REPO_ROOT"
    exit "$clone_failed"
fi

# Phase 1 — standalone: prerequisites + anchor clone, then re-exec from it.
REPO_BASE="${MPS_REPO_BASE:-${REPO_BASE_DEFAULT}}"
REPO_BASE="${REPO_BASE%/}"
ORG_DIR="${REPO_BASE}/my-perfect-system-ansible"
DEST="${ORG_DIR}/${ANCHOR_NAME}"

install_prereqs

if [ -d "${DEST}/.git" ]; then
    log "${ANCHOR_NAME} already present at ${DEST}"
elif [ -e "$DEST" ]; then
    echo "ERROR: ${DEST} exists but is not a git repository" >&2
    exit 1
else
    log "Creating ${ORG_DIR}"
    ensure_dir "$ORG_DIR"
    log "Cloning ${ANCHOR_URL} (anchor repo)"
    GIT_TERMINAL_PROMPT=0 git clone "$ANCHOR_URL" "$DEST"
fi

if [ -f "${DEST}/scripts/bootstrap-machine.bash" ]; then
    log "Continuing from the clone"
    exec bash "${DEST}/scripts/bootstrap-machine.bash"
fi

# Older clone without this script — fall back to the plain repo fetch.
log "Clone has no bootstrap-machine.bash — falling back to git.bash clone"
exec bash "${DEST}/scripts/git.bash" clone
