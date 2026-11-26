#!/usr/bin/env bash
# Publish every odem-* collection to Ansible Galaxy.
#
# Repos without a galaxy.yml are skipped. The API token comes from
# GALAXY_API_TOKEN in the environment or from .env at this repo's root
# (gitignored). Optional argument: a Galaxy server URL.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/git-repos.bash"
cd "$REPO_ROOT" || exit 1

if [ -f ./.env ]; then
    source ./.env
fi
if [ -z "${GALAXY_API_TOKEN:-}" ]; then
    echo "ERROR: GALAXY_API_TOKEN is not set."
    echo "Get a token at https://galaxy.ansible.com/me/preferences, then:"
    echo "  GALAXY_API_TOKEN=<token> just publish"
    exit 1
fi

published=0
failed=0
skipped=0
server_args=()
if [ -n "${1:-}" ]; then
    server_args+=(--server "$1")
fi
for repo in "${REPOS[@]}"; do
    name=$(basename "$repo")
    if [ ! -f "$repo/galaxy.yml" ]; then
        echo "==> $name: SKIP (no galaxy.yml)"
        skipped=$((skipped + 1))
        continue
    fi
    echo "==> $name"
    if ! (cd "$repo" && ansible-galaxy collection build --force) >/tmp/odem-publish-build.log 2>&1; then
        echo "  ERROR: build failed"
        tail -5 /tmp/odem-publish-build.log | sed 's/^/    /'
        failed=$((failed + 1))
        continue
    fi
    tarball=$(ls -t "$repo"/odem-*.tar.gz 2>/dev/null | head -1)
    if [ -z "$tarball" ]; then
        echo "  ERROR: no tarball after build"
        failed=$((failed + 1))
        continue
    fi
    if ansible-galaxy collection publish "$tarball" \
            --token "$GALAXY_API_TOKEN" \
            "${server_args[@]}" 2>&1 | tail -6; then
        published=$((published + 1))
    else
        echo "  ERROR: publish failed"
        failed=$((failed + 1))
    fi
    echo
done
rm -f /tmp/odem-publish-build.log
echo "Summary: $published published, $failed failed, $skipped skipped"
[ "$failed" -eq 0 ]