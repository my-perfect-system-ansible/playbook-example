#!/usr/bin/env bash
# Fast-forward pull every sibling repo; skip dirty working trees.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/git-repos.bash"
cd "$REPO_ROOT" || exit 1

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