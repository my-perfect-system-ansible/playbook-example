#!/usr/bin/env bash
# Syntax-check every common playbook against an inventory (called from the
# Justfile). Vault password resolution as in run-playbook.bash — encrypted
# group_vars must decrypt for the vars loading to parse.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/vault.bash"

inv="${1:?usage: check-playbooks.bash <inventory>}"
resolve_vault_password "$inv"
cd "$REPO_ROOT/inventories/$inv"
for pb in "$REPO_ROOT"/playbooks/*.yml; do
    ansible-playbook "${VA[@]}" --syntax-check "$pb"
    echo "OK  $(basename "$pb")"
done