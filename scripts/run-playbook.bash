#!/usr/bin/env bash
# Run a common playbook against an inventory (called from the Justfile).
#
#   scripts/run-playbook.bash <inventory> <playbook> [ansible-playbook args…]
#
# cd into inventories/<inventory>/ (its ansible.cfg applies), resolve the
# vault password source (password file at ~/.ansible/vault-pass-<inventory>,
# or VAULT_ASK=1, or none) and exec ansible-playbook.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/vault.bash"

inv="${1:?usage: run-playbook.bash <inventory> <playbook> [ansible-playbook args…]}"
playbook="${2:?playbook name (basename in playbooks/, without .yml)}"
shift 2

resolve_vault_password "$inv"
cd "$REPO_ROOT/inventories/$inv"
exec ansible-playbook "${VA[@]}" "$REPO_ROOT/playbooks/$playbook.yml" "$@"