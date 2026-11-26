# Justfile — playbook-example
#
# Common playbooks (playbooks/) applied to any inventory (inventories/<name>/).
# Every playbook targets `all` hosts of the selected inventory; narrow to
# groups/hosts by passing `--limit <subset>` (or any other ansible-playbook
# argument) through the extra args.
#
# `just install-forced` builds + force-installs the sibling odem-* collections
# into ../.ansible/ansible_collections — the path each ansible.cfg reads.
#
# Secrets live encrypted in inventories/<name>/group_vars/all/vault.yml
# (auto-loaded for every host of that inventory). The vault password file is
# expected OUTSIDE the repo at ~/.ansible/vault-pass-<inventory> (created by
# `vault-pass-create`); without it — or with VAULT_ASK=1 — the password is
# prompted instead. ansible.cfg deliberately sets NO vault_password_file:
# a missing file there fails every ansible run eagerly.

# List inventories and playbooks
list:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Inventories:"
    find inventories -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' | sort
    echo "Playbooks:"
    ls -1 playbooks | sed -e 's/\.yml$//' -e 's/^/  /'

# Show the inventory tree (hosts + groups)
graph inventory='home':
    #!/usr/bin/env bash
    set -euo pipefail
    cd "inventories/{{inventory}}"
    exec ansible-inventory -i inventory.ini --graph

# Run any playbook against any inventory.
#
#   just run <inventory> <playbook> [ansible-playbook args…]
#
#   inventory  subfolder of inventories/ (see `just list`)
#   playbook   basename in playbooks/     (see `just list`)
#   extra args passed through to ansible-playbook, e.g.:
#              --limit srv          only the `srv` group / given hosts
#              --limit dsktest,srvtest   comma-separated hosts/groups
#              -K                    ask become password
#              --check               dry-run
#              -i inventory_local.ini    in-place apply (home inventory)
run inventory playbook *args:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "inventories/{{inventory}}"
    # vault password file (when present) decrypts encrypted vars automatically
    pw="$HOME/.ansible/vault-pass-{{inventory}}"
    va=()
    if [ "${VAULT_ASK:-0}" = 1 ]; then va=(--ask-vault-pass)
    elif [ -f "$pw" ]; then va=(--vault-password-file "$pw"); fi
    exec ansible-playbook "${va[@]}" "../../playbooks/{{playbook}}.yml" {{args}}

# Syntax-check every playbook against an inventory
check inventory='home':
    #!/usr/bin/env bash
    set -euo pipefail
    cd "inventories/{{inventory}}"
    pw="$HOME/.ansible/vault-pass-{{inventory}}"
    va=()
    if [ "${VAULT_ASK:-0}" = 1 ]; then va=(--ask-vault-pass)
    elif [ -f "$pw" ]; then va=(--vault-password-file "$pw"); fi
    for pb in ../../playbooks/*.yml; do
        ansible-playbook "${va[@]}" --syntax-check "$pb"
        echo "OK  $(basename "$pb")"
    done

# Force build every sibling odem-* collection tarball and force-install it
# into the local collections path — the path every inventories/<name>/
# ansible.cfg picks up via collections_path. Playbook runs (`run`, `check`,
# per-playbook targets) resolve the odem.* collections from there.
# Moved here from manage/ (2026-11): the playbook repo owns the install step.
install-forced collections_path="../.ansible/ansible_collections":
    #!/usr/bin/env bash
    set -uo pipefail
    mkdir -p "{{collections_path}}"
    built=0
    installed=0
    failed=0
    for repo in ../odem-*/; do
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
        if ansible-galaxy collection install "$tarball" --force -p "{{collections_path}}" 2>&1 | tail -2; then
            installed=$((installed + 1))
        else
            echo "  ERROR: install failed"
            failed=$((failed + 1))
        fi
        echo
    done
    echo "Summary: $built built, $installed installed, $failed failed"

# --- Vault --------------------------------------------------------------------
# Secrets are stored encrypted at inventories/<name>/group_vars/all/vault.yml
# (auto-loaded for every host of that inventory — the encrypted file is
# committed). The vault password file lives OUTSIDE the repo at
# ~/.ansible/vault-pass-<inventory> (mode 0600; `vault-pass-create` writes it).
# Password source resolution for every vault target:
#   - password file present at the known location → used automatically
#   - VAULT_ASK=1                                → prompt (--ask-vault-pass)
#   - neither                                    → ansible-vault prompts itself
# Playbook runs (`run`, `check`, per-playbook targets) add the password file
# the same way. Extra args pass through to ansible-vault.

# Create the vault password file at the known location (prompts twice)
vault-pass-create inventory='home':
    #!/usr/bin/env bash
    set -euo pipefail
    pw="$HOME/.ansible/vault-pass-{{inventory}}"
    mkdir -p "$(dirname "$pw")"
    if [ -f "$pw" ]; then
        echo "ERROR: $pw exists — rotate it with: just vault-rekey {{inventory}}"
        exit 1
    fi
    read -rsp "New vault password for '{{inventory}}': " n1; echo
    read -rsp "Confirm password: " n2; echo
    [ "$n1" = "$n2" ] || { echo "ERROR: passwords differ"; exit 1; }
    [ -n "$n1" ] || { echo "ERROR: empty password"; exit 1; }
    umask 077
    printf '%s\n' "$n1" > "$pw"
    echo "==> wrote $pw"

# Create the per-inventory vault file (fails if it exists — use vault-edit)
vault-create inventory='home' *args:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "inventories/{{inventory}}"
    if [ -f group_vars/all/vault.yml ]; then
        echo "ERROR: group_vars/all/vault.yml exists (just vault-edit {{inventory}})"
        exit 1
    fi
    mkdir -p group_vars/all
    pw="$HOME/.ansible/vault-pass-{{inventory}}"
    va=()
    if [ "${VAULT_ASK:-0}" = 1 ]; then va=(--ask-vault-pass)
    elif [ -f "$pw" ]; then va=(--vault-password-file "$pw"); fi
    ansible-vault create "${va[@]}" {{args}} group_vars/all/vault.yml
    if [ ! -f "$pw" ] && [ "${VAULT_ASK:-0}" != 1 ]; then
        echo "NOTE: no password file at $pw — playbook runs will need --ask-vault-pass (or: just vault-pass-create {{inventory}})" >&2
    fi

# Edit the vault file in $EDITOR
vault-edit inventory='home' *args:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "inventories/{{inventory}}"
    pw="$HOME/.ansible/vault-pass-{{inventory}}"
    va=()
    if [ "${VAULT_ASK:-0}" = 1 ]; then va=(--ask-vault-pass)
    elif [ -f "$pw" ]; then va=(--vault-password-file "$pw"); fi
    exec ansible-vault edit "${va[@]}" {{args}} group_vars/all/vault.yml

# Print the decrypted vault file (read-only)
vault-view inventory='home' *args:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "inventories/{{inventory}}"
    pw="$HOME/.ansible/vault-pass-{{inventory}}"
    va=()
    if [ "${VAULT_ASK:-0}" = 1 ]; then va=(--ask-vault-pass)
    elif [ -f "$pw" ]; then va=(--vault-password-file "$pw"); fi
    exec ansible-vault view "${va[@]}" {{args}} group_vars/all/vault.yml

# Change the vault password (rekeys vault.yml and rewrites the password file)
vault-rekey inventory='home' *args:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "inventories/{{inventory}}"
    if [ ! -f group_vars/all/vault.yml ]; then
        echo "ERROR: group_vars/all/vault.yml missing (just vault-create {{inventory}})"
        exit 1
    fi
    pw="$HOME/.ansible/vault-pass-{{inventory}}"
    va=()
    if [ "${VAULT_ASK:-0}" = 1 ]; then va=(--ask-vault-pass)
    elif [ -f "$pw" ]; then va=(--vault-password-file "$pw"); fi
    read -rsp "New vault password for '{{inventory}}': " n1; echo
    read -rsp "Confirm password: " n2; echo
    [ "$n1" = "$n2" ] || { echo "ERROR: passwords differ"; exit 1; }
    [ -n "$n1" ] || { echo "ERROR: empty password"; exit 1; }
    # old password: password file (untouched) or prompt; the new password goes
    # to a private temp file (ansible-vault cannot read /proc/fd paths) — the
    # real password file is rewritten only after a successful rekey
    new_tmp=$(mktemp)
    printf '%s\n' "$n1" > "$new_tmp"
    ansible-vault rekey "${va[@]}" {{args}} --new-vault-password-file "$new_tmp" group_vars/all/vault.yml
    rm -f "$new_tmp"
    umask 077
    printf '%s\n' "$n1" > "$pw"
    echo "==> updated $pw"

# Encrypt a file of an inventory (path relative to inventories/<name>/)
vault-encrypt inventory file *args:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "inventories/{{inventory}}"
    pw="$HOME/.ansible/vault-pass-{{inventory}}"
    va=()
    if [ "${VAULT_ASK:-0}" = 1 ]; then va=(--ask-vault-pass)
    elif [ -f "$pw" ]; then va=(--vault-password-file "$pw"); fi
    exec ansible-vault encrypt "${va[@]}" {{args}} "{{file}}"

# Decrypt an encrypted file of an inventory (path relative to inventories/<name>/)
vault-decrypt inventory file *args:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "inventories/{{inventory}}"
    pw="$HOME/.ansible/vault-pass-{{inventory}}"
    va=()
    if [ "${VAULT_ASK:-0}" = 1 ]; then va=(--ask-vault-pass)
    elif [ -f "$pw" ]; then va=(--vault-password-file "$pw"); fi
    exec ansible-vault decrypt "${va[@]}" {{args}} "{{file}}"

# Show vault state: vault file + password file presence, decrypt check
vault-status inventory='home':
    #!/usr/bin/env bash
    set -euo pipefail
    cd "inventories/{{inventory}}"
    pw="$HOME/.ansible/vault-pass-{{inventory}}"
    va=()
    if [ "${VAULT_ASK:-0}" = 1 ]; then va=(--ask-vault-pass)
    elif [ -f "$pw" ]; then va=(--vault-password-file "$pw"); fi
    if [ -f group_vars/all/vault.yml ]; then
        echo "vault file    : present (group_vars/all/vault.yml)"
        if [ ${#va[@]} -gt 0 ]; then
            if ansible-vault view "${va[@]}" group_vars/all/vault.yml >/dev/null 2>&1; then
                echo "decrypt check : OK"
            else
                echo "decrypt check : FAILED (wrong password source?)"
            fi
        else
            echo "decrypt check : skipped (no password source)"
        fi
    else
        echo "vault file    : missing (just vault-create {{inventory}})"
    fi
    if [ -f "$pw" ]; then
        echo "password file : $pw"
    else
        echo "password file : missing (just vault-pass-create {{inventory}} or VAULT_ASK=1)"
    fi

# --- Per-playbook targets -----------------------------------------------------
# Each takes the inventory as first parameter (default `home`, see `just
# list`) and passes extra args through to ansible-playbook. Examples:
#   just bootstrap home                 # playbooks/bootstrap.yml → inventories/home
#   just bootstrap srv --limit srv     # … only the `srv` group
#   just terminal_full home --limit testvm -K   # … only testvm, ask become pw

bootstrap inventory='home' *args:
    {{just_executable()}} run {{inventory}} bootstrap {{args}}

all inventory='home' *args:
    {{just_executable()}} run {{inventory}} all {{args}}

alloy inventory='home' *args:
    {{just_executable()}} run {{inventory}} alloy {{args}}

desktop_minimal inventory='home' *args:
    {{just_executable()}} run {{inventory}} desktop_minimal {{args}}

desktop_full inventory='home' *args:
    {{just_executable()}} run {{inventory}} desktop_full {{args}}

hardening inventory='home' *args:
    {{just_executable()}} run {{inventory}} hardening {{args}}

services inventory='home' *args:
    {{just_executable()}} run {{inventory}} services {{args}}

terminal_minimal inventory='home' *args:
    {{just_executable()}} run {{inventory}} terminal_minimal {{args}}

terminal_full inventory='home' *args:
    {{just_executable()}} run {{inventory}} terminal_full {{args}}

testing inventory='home' *args:
    {{just_executable()}} run {{inventory}} testing {{args}}

wazuh inventory='home' *args:
    {{just_executable()}} run {{inventory}} wazuh {{args}}

workstation_minimal inventory='home' *args:
    {{just_executable()}} run {{inventory}} workstation_minimal {{args}}

workstation_full inventory='home' *args:
    {{just_executable()}} run {{inventory}} workstation_full {{args}}