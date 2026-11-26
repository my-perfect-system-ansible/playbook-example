#!/usr/bin/env bash
# Run a role's molecule/default scenario — finds the role across every
# odem-* collection. (Moved from manage/Justfile 2026-11-26.)
#
#   scripts/molecule.bash <role>     role name (`packages`) or FQN (`odem.os.packages`)
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/git.bash"
cd "$REPO_ROOT" || exit 1

role=${1:?usage: just molecule <role>}
target_role="$role"
if [[ "$target_role" == *.*.* ]]; then
    target_role="${target_role##*.}"
fi

found=0
for repo in "${COLLECTIONS[@]}"; do
    scenario_dir="$repo/roles/$target_role/molecule/default"
    if [ -d "$scenario_dir" ]; then
        echo "==> $repo/roles/$target_role"
        cd "$repo/roles/$target_role" || exit 1
        molecule test
        cd "$REPO_ROOT" || exit 1
        found=$((found + 1))
    fi
done
if [ "$found" -eq 0 ]; then
    echo "No molecule scenario found for role '$target_role'"
    exit 1
fi