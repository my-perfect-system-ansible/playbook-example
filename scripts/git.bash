#!/usr/bin/env bash
# Cross-repo git operations over every sibling repo (moved from manage/).
#
#   scripts/git.bash clone           clone every missing sibling repo
#   scripts/git.bash status           git status + last commit per repo
#   scripts/git.bash pull            fast-forward pull; skip dirty trees
#   scripts/git.bash commit "msg"    add, commit (with MSG), push per dirty repo
#
# Doubles as the shared library for scripts/publish.bash, which sources
# this file for the REPOS list + repo_url(). Repo root = the directory
# above this scripts/ folder; the REPOS paths are relative to it:
# odem-*/manage/playbook-example are siblings in the my-perfect-system-ansible
# org, the mps-* repos sit two levels up in my-perfect-system.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

REPOS=(
    ../manage
    ../../my-perfect-system/mps-container-docker
    ../../my-perfect-system/mps-desktop-kanata
    ../../my-perfect-system/mps-desktop-qtile
    ../../my-perfect-system/mps-desktop-rofi
    ../../my-perfect-system/mps-desktop-thunar
    ../../my-perfect-system/mps-desktop-trayhub
    ../../my-perfect-system/mps-services-monitoring
    ../../my-perfect-system/mps-services-openvpn
    ../../my-perfect-system/mps-terminal-bash
    ../../my-perfect-system/mps-terminal-bash-aliases
    ../../my-perfect-system/mps-terminal-fonts
    ../../my-perfect-system/mps-terminal-kitty
    ../../my-perfect-system/mps-terminal-nvim
    ../../my-perfect-system/mps-terminal-scripts
    ../../my-perfect-system/mps-terminal-skeletons
    ../../my-perfect-system/mps-terminal-tmux
    ../../my-perfect-system/mps-terminal-vim
    ../odem-os
    ../odem-terminal
    ../odem-development
    ../odem-desktop
    ../odem-hardening
    ../odem-backup
    ../odem-services
    ../odem-alloy
    ../playbook-example
)

# GitHub clone URL for a repo basename: mps-* lives in the
# my-perfect-system org, everything else in my-perfect-system-ansible.
repo_url() {
    case "$1" in
        mps-*) echo "https://github.com/my-perfect-system/$1.git" ;;
        *)     echo "https://github.com/my-perfect-system-ansible/$1.git" ;;
    esac
}

usage() {
    cat <<'EOF'
Usage: scripts/git.bash <action> [args]

Actions:
  clone            clone every missing sibling repo from GitHub
  status           git status + last commit of every sibling repo
  pull             fast-forward pull every repo; skip dirty working trees
  commit <msg>     add, commit (with MSG), and push every dirty repo

publish.bash sources this file for the REPOS list + repo_url().
EOF
}

git_clone() {
    local repo name cloned=0 present=0 failed=0
    for repo in "${REPOS[@]}"; do
        name=$(basename "$repo")
        echo "==> $name"
        if [ -d "$repo/.git" ]; then
            echo "  present"
            present=$((present + 1))
        elif [ -e "$repo" ]; then
            echo "  ERROR: path exists but is not a git repo"
            failed=$((failed + 1))
        elif GIT_TERMINAL_PROMPT=0 git clone "$(repo_url "$name")" "$repo"; then
            cloned=$((cloned + 1))
        else
            echo "  ERROR: clone failed"
            failed=$((failed + 1))
        fi
        echo
    done
    echo "Summary: $cloned cloned, $present present, $failed failed"
    [ "$failed" -eq 0 ]
}

git_status() {
    local repo
    for repo in "${REPOS[@]}"; do
        echo "==> $repo"
        if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            echo "  SKIP: not a git repo"
        else
            git -C "$repo" status -sb
            git -C "$repo" log --pretty=oneline \
                | head -n 1 \
                | awk '{$1=""; sub(/^ /,""); print}'
        fi
        echo
    done
}

git_pull() {
    local repo
    for repo in "${REPOS[@]}"; do
        echo "==> $repo"
        if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            echo "  SKIP: not a git repo"
            echo
            continue
        fi
        if ! git -C "$repo" diff --quiet HEAD 2>/dev/null; then
            echo "  SKIP: working tree dirty — commit or stash first"
            echo
            continue
        fi
        git -C "$repo" pull --ff-only || echo "  ERROR: pull failed"
        echo
    done
}

git_commit() {
    local msg repo committed=0 skipped=0 failed=0
    msg=${1:?usage: scripts/git.bash commit "<commit message>"}
    for repo in "${REPOS[@]}"; do
        echo "==> $repo"
        if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            echo "  SKIP: not a git repo"
            skipped=$((skipped + 1))
            echo
            continue
        fi
        if [ -z "$(git -C "$repo" status --porcelain)" ]; then
            echo "  SKIP: clean"
            skipped=$((skipped + 1))
            echo
            continue
        fi
        if git -C "$repo" add -A \
        && git -C "$repo" commit -m "$msg" \
        && git -C "$repo" push; then
            echo " COMMIT: add/commit/push successful"
            committed=$((committed + 1))
        else
            echo "  ERROR: add/commit/push failed"
            failed=$((failed + 1))
        fi
        echo
    done
    echo "Summary: $committed committed+pushed, $skipped clean, $failed failed"
    [ "$failed" -eq 0 ]
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -uo pipefail
    cd "$REPO_ROOT" || exit 1
    action=${1:-}
    if [ $# -gt 0 ]; then shift; fi
    case "$action" in
        clone)  git_clone ;;
        status) git_status ;;
        pull)   git_pull ;;
        commit) git_commit "$@" ;;
        "")     usage ;;
        *)      usage >&2; exit 2 ;;
    esac
fi