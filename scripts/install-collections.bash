#!/usr/bin/env bash
# Force build every sibling odem-* collection tarball and force-install it
# into the local collections path — the path every inventories/<name>/
# ansible.cfg picks up via collections_path. Called from the Justfile
# (`just install-forced`).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
collections_path="${1:-$REPO_ROOT/../.ansible/ansible_collections}"

mkdir -p "$collections_path"
built=0
installed=0
failed=0
for repo in "$REPO_ROOT"/../odem-*/; do
    if [ ! -f "${repo}galaxy.yml" ]; then
        continue
    fi
    echo "==> $repo"
    if (cd "$repo" && ansible-galaxy collection build --force 2>&1 | tail -2); then
        built=$((built + 1))
    else
        echo "  ERROR: build failed"
        failed=$((failed + 1))
        echo
        continue
    fi
    tarball=$(ls -t "${repo}"odem-*.tar.gz 2>/dev/null | head -1)
    if [ -z "$tarball" ]; then
        echo "  ERROR: no tarball after build"
        failed=$((failed + 1))
        echo
        continue
    fi
    if ansible-galaxy collection install "$tarball" --force -p "$collections_path" 2>&1 | tail -2; then
        installed=$((installed + 1))
    else
        echo "  ERROR: install failed"
        failed=$((failed + 1))
    fi
    echo
done
echo "Summary: $built built, $installed installed, $failed failed"