#!/usr/bin/env bash
# Run yamllint + ansible-lint on every odem-* collection repo.
#
# Skips repos without lint configs (.ansible-lint/.yamllint). Exits
# non-zero if any collection fails. (Moved from manage/Justfile 2026-11-26.)
#
# Run `just install-forced` first so cross-collection dependencies resolve
# for ansible-lint.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/git.bash"
cd "$REPO_ROOT" || exit 1
# Let ansible-lint resolve cross-collection role references (the molecule
# converge.yml syntax-check) against the locally installed collections —
# run `just install-forced` first.
export ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_COLLECTIONS_PATH:-$REPO_ROOT/../.ansible/ansible_collections}"

passed=0
failed=0
skipped=0
for repo in "${COLLECTIONS[@]}"; do
    name=$(basename "$repo")
    if [ ! -f "$repo/.ansible-lint" ] || [ ! -f "$repo/.yamllint" ]; then
        echo "==> $name: SKIP (no lint configs found)"
        skipped=$((skipped + 1))
        continue
    fi
    echo "==> $name"
    cd "$repo" || { echo "  ERROR: cannot enter $repo"; failed=$((failed + 1)); continue; }
    yamllint_out=$(yamllint -c .yamllint . 2>&1)
    yamllint_status=$?
    ansible_lint_out=$(ansible-lint --offline 2>&1)
    ansible_lint_status=$?
    if [ "$yamllint_status" -eq 0 ] && [ "$ansible_lint_status" -eq 0 ]; then
        echo "  PASS"
        passed=$((passed + 1))
    else
        echo "  FAIL (yamllint exit=$yamllint_status, ansible-lint exit=$ansible_lint_status)"
        if [ "$yamllint_status" -ne 0 ]; then
            echo "$yamllint_out" | sed 's/^/    yamllint:    /' | head -10
        fi
        if [ "$ansible_lint_status" -ne 0 ]; then
            echo "$ansible_lint_out" | sed 's/^/    ansible-lint: /' | head -10
        fi
        failed=$((failed + 1))
    fi
    cd "$REPO_ROOT" || exit 1
done
echo
echo "Summary: $passed passed, $failed failed, $skipped skipped"
[ "$failed" -eq 0 ]