#!/usr/bin/env bash
# Vault lifecycle management for playbook-example.
#
# Secrets live encrypted at inventories/<inventory>/group_vars/all/vault.yml
# (auto-loaded for every host of that inventory — the encrypted file is
# committed). The vault password file lives INSIDE its inventory at
# inventories/<inventory>/vault-pass (mode 0600; `pass-create` writes it;
# gitignored — see .gitignore).
#
# Password source resolution (the VA array; shared with run-playbook.bash
# and check-playbooks.bash, which source this file):
#   - password file present at the known location → --vault-password-file
#   - VAULT_ASK=1                                → --ask-vault-pass (prompt)
#   - neither                                    → no arg (ansible-vault prompts itself)
#
# Usage:
#   scripts/vault.bash <command> <inventory> [file] [ansible-vault args…]
# Commands: pass-create create edit view rekey encrypt decrypt status
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

vault_password_file() {
    printf '%s\n' "$REPO_ROOT/inventories/$1/vault-pass"
}

# Sets the global VA array to the ansible vault-password arguments.
resolve_vault_password() {
    local pw
    pw="$(vault_password_file "$1")"
    VA=()
    if [ "${VAULT_ASK:-0}" = 1 ]; then
        VA=(--ask-vault-pass)
    elif [ -f "$pw" ]; then
        VA=(--vault-password-file "$pw")
    fi
}

# Prompts for a new password (twice) and sets NEW_PW.
read_new_password() {
    local n1 n2
    read -rsp "New vault password for '$1': " n1; echo
    read -rsp "Confirm password: " n2; echo
    [ "$n1" = "$n2" ] || { echo "ERROR: passwords differ"; exit 1; }
    [ -n "$n1" ] || { echo "ERROR: empty password"; exit 1; }
    NEW_PW="$n1"
}

vault_main() {
    local cmd inv file pw new_tmp
    if [ $# -gt 0 ]; then cmd="$1"; shift; else cmd=""; fi
    case "$cmd" in
        pass-create)
            inv="${1:?usage: vault.bash pass-create <inventory>}"
            pw="$(vault_password_file "$inv")"
            if [ -f "$pw" ]; then
                echo "ERROR: $pw exists — rotate it with: just vault-rekey $inv"
                exit 1
            fi
            mkdir -p "$(dirname "$pw")"
            read_new_password "$inv"
            umask 077
            printf '%s\n' "$NEW_PW" > "$pw"
            echo "==> wrote $pw"
            ;;
        create)
            inv="${1:?usage: vault.bash create <inventory> [ansible-vault args…]}"; shift
            cd "$REPO_ROOT/inventories/$inv"
            if [ -f group_vars/all/vault.yml ]; then
                echo "ERROR: group_vars/all/vault.yml exists (just vault-edit $inv)"
                exit 1
            fi
            mkdir -p group_vars/all
            resolve_vault_password "$inv"
            ansible-vault create "${VA[@]}" "$@" group_vars/all/vault.yml
            pw="$(vault_password_file "$inv")"
            if [ ! -f "$pw" ] && [ "${VAULT_ASK:-0}" != 1 ]; then
                echo "NOTE: no password file at $pw — playbook runs will need --ask-vault-pass (or: just vault-pass-create $inv)" >&2
            fi
            ;;
        edit|view)
            inv="${1:?usage: vault.bash $cmd <inventory> [ansible-vault args…]}"; shift
            cd "$REPO_ROOT/inventories/$inv"
            resolve_vault_password "$inv"
            exec ansible-vault "$cmd" "${VA[@]}" "$@" group_vars/all/vault.yml
            ;;
        rekey)
            inv="${1:?usage: vault.bash rekey <inventory> [ansible-vault args…]}"; shift
            cd "$REPO_ROOT/inventories/$inv"
            if [ ! -f group_vars/all/vault.yml ]; then
                echo "ERROR: group_vars/all/vault.yml missing (just vault-create $inv)"
                exit 1
            fi
            resolve_vault_password "$inv"
            read_new_password "$inv"
            # the new password goes to a private temp file — ansible-vault
            # cannot read /proc/<pid>/fd process-substitution paths
            new_tmp="$(mktemp)"
            printf '%s\n' "$NEW_PW" > "$new_tmp"
            ansible-vault rekey "${VA[@]}" "$@" \
                --new-vault-password-file "$new_tmp" group_vars/all/vault.yml
            rm -f "$new_tmp"
            pw="$(vault_password_file "$inv")"
            umask 077
            printf '%s\n' "$NEW_PW" > "$pw"
            echo "==> updated $pw"
            ;;
        encrypt|decrypt)
            inv="${1:?usage: vault.bash $cmd <inventory> <file> [ansible-vault args…]}"
            file="${2:?file path (relative to inventories/$inv/)}"; shift 2
            cd "$REPO_ROOT/inventories/$inv"
            resolve_vault_password "$inv"
            exec ansible-vault "$cmd" "${VA[@]}" "$@" "$file"
            ;;
        status)
            inv="${1:?usage: vault.bash status <inventory>}"
            cd "$REPO_ROOT/inventories/$inv"
            resolve_vault_password "$inv"
            pw="$(vault_password_file "$inv")"
            if [ -f group_vars/all/vault.yml ]; then
                echo "vault file    : present (group_vars/all/vault.yml)"
                if [ "${#VA[@]}" -gt 0 ]; then
                    if ansible-vault view "${VA[@]}" group_vars/all/vault.yml >/dev/null 2>&1; then
                        echo "decrypt check : OK"
                    else
                        echo "decrypt check : FAILED (wrong password source?)"
                    fi
                else
                    echo "decrypt check : skipped (no password source)"
                fi
            else
                echo "vault file    : missing (just vault-create $inv)"
            fi
            if [ -f "$pw" ]; then
                echo "password file : $pw"
            else
                echo "password file : missing (just vault-pass-create $inv or VAULT_ASK=1)"
            fi
            ;;
        *)
            echo "usage: scripts/vault.bash <pass-create|create|edit|view|rekey|encrypt|decrypt|status> <inventory> [file] [args…]" >&2
            [ -n "$cmd" ] && echo "unknown command: $cmd" >&2
            exit 1
            ;;
    esac
}

# Only dispatch when executed directly (run-playbook.bash sources this file).
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    vault_main "$@"
fi