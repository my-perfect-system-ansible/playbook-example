#!/usr/bin/env bash
# Add, commit (with MSG), and push every dirty sibling repo.
#
#   scripts/git-commit.bash "<commit message>"    (via: just git-commit 'msg')
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/git-repos.bash"
cd "$REPO_ROOT" || exit 1

msg=${1:?usage: just git-commit "<commit message>"}

committed=0
skipped=0
failed=0
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