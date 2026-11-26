#!/usr/bin/env bash
# Clone every missing sibling repo from GitHub (fresh-install helper).
# Existing git repos are skipped; a non-git directory at a target path is an error.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/git-repos.bash"
cd "$REPO_ROOT" || exit 1

cloned=0
present=0
failed=0
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