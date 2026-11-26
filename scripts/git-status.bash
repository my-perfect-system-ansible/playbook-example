#!/usr/bin/env bash
# Show git status + last commit of every sibling repo.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/git-repos.bash"
cd "$REPO_ROOT" || exit 1

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