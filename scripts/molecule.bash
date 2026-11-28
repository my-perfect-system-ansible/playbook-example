#!/usr/bin/env bash
# Run a role's molecule/default scenario — finds the role across every
# odem-* collection. (Moved from manage/Justfile 2026-11-26.)
#
#   scripts/molecule.bash <role>     role name (`packages`) or FQN (`odem.os.packages`)
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/git.bash"
cd "$REPO_ROOT" || exit 1

# Molecule venv (2026-11-26): molecule + molecule-docker, ansible-core pinned
# to 2.19.11 (matching the system) and passlib (controller-side
# password_hash in odem.os.user). Create with:
#   python3 -m venv ~/.venvs/molecule
#   ~/.venvs/molecule/bin/pip install molecule molecule-docker \
#     'ansible-core==2.19.11' passlib
if [ -x "$HOME/.venvs/molecule/bin/molecule" ]; then
    export PATH="$HOME/.venvs/molecule/bin:$PATH"
fi

# molecule-docker 2.1.0 bundles playbooks that predate core 2.19's strict
# conditional typing (str-derived `when:`) — allow them.
export ANSIBLE_ALLOW_BROKEN_CONDITIONALS=1

# Resolve odem.* (built by `just install-forced`) AND ansible.posix
# (molecule-docker create.yml uses ansible.posix.synchronize).
export ANSIBLE_COLLECTIONS_PATH="$REPO_ROOT/../.ansible/ansible_collections:$HOME/.ansible/collections"
unset ANSIBLE_COLLECTIONS_PATHS

role=${1:?usage: just molecule <role>}
target_role="$role"
if [[ "$target_role" == *.*.* ]]; then
    target_role="${target_role##*.}"
fi

found=0
failed=0
for repo in "${COLLECTIONS[@]}"; do
    scenario_dir="$repo/roles/$target_role/molecule/default"
    if [ -d "$scenario_dir" ]; then
        echo "==> $repo/roles/$target_role"
        cd "$repo/roles/$target_role" || exit 1
        molecule test
        rc=$?
        cd "$REPO_ROOT" || exit 1
        if [ "$rc" -ne 0 ]; then
            echo "ERROR: molecule test failed for $repo/roles/$target_role (exit $rc)" >&2
            failed=1
        fi
        found=$((found + 1))
    fi
done
if [ "$found" -eq 0 ]; then
    echo "No molecule scenario found for role '$target_role'"
    exit 1
fi
exit "$failed"