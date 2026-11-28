# Justfile — playbook-example
#
# Common playbooks (playbooks/) applied to any inventory (inventories/<name>/).
# Every playbook targets `all` hosts of the selected inventory; narrow to
# groups/hosts by passing `--limit <subset>` (or any other ansible-playbook
# argument) through the extra args.
#
# Recipes are thin wrappers — the logic lives in scripts/:
#   run-playbook.bash / check-playbooks.bash    playbook runs + syntax checks
#   install-collections.bash                   odem-* build + force-install
#   vault.bash                                  vault lifecycle + password resolution
#   git.bash                                    cross-repo git ops (clone|status|pull|commit)
#   bootstrap-machine.bash                      fresh-machine bootstrap: prereqs + fetch every repo
#   publish.bash                                Galaxy publish per odem-* collection

#   lint.bash / list-roles.bash / molecule.bash   collection lint, role listing, molecule

default: usage

usage:
    #!/usr/bin/env bash
    set -euo pipefail
    just --list

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

# Run any playbook against any inventory (scripts/run-playbook.bash).
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
    scripts/run-playbook.bash "{{inventory}}" "{{playbook}}" {{args}}

# Syntax-check every playbook against an inventory (scripts/check-playbooks.bash)
check inventory='home':
    scripts/check-playbooks.bash "{{inventory}}"

# Force build + force-install every sibling odem-* collection into the local
# collections path — the path every inventories/<name>/ansible.cfg picks up
# via collections_path (scripts/install-collections.bash).
install-forced collections_path="../.ansible/ansible_collections":
    scripts/install-collections.bash "{{collections_path}}"

# --- Collection tooling (scripts/{lint,list-roles,molecule}.bash) ---
# The scripts iterate the seven odem-* sibling collections — the
# COLLECTIONS subset of REPOS derived in scripts/git.bash.

# List every role in every odem-* collection with its description
list-roles:
    scripts/list-roles.bash

# Run ansible-lint + yamllint on every odem.* collection (skips repos
# without lint configs; exits non-zero if any collection fails)
lint:
    scripts/lint.bash

# Check every odem-* role for clone-relative copy srcs missing remote_src —
# the class that broke tmux/kitty/rofi/qtile (scripts/check-remote-src.py;
# invisible to --syntax-check, --list-tasks and the validation sweep)
check-remote-src:
    scripts/check-remote-src.py

# Run a Molecule scenario for a single role (name or odem.<col>.<role> FQN)
molecule role:
    scripts/molecule.bash "{{role}}"

# List every installed collection of an inventory
list-collections inventory='home':
    #!/usr/bin/env bash
    set -euo pipefail
    cd "inventories/{{inventory}}"
    ansible-galaxy collection list

# --- Cross-repo git + Galaxy publish (scripts/git.bash, publish.bash) ---
# git.bash iterates every sibling repo (its REPOS list + clone URLs);
# publish.bash sources it for the same list:
# odem-*/manage/playbook-example in the my-perfect-system-ansible org,
# mps-* two levels up in my-perfect-system.

# Clone every missing sibling repo from GitHub (in-tree resync; fresh machines: bootstrap-machine)
git-clone:
    scripts/git.bash clone

# Bootstrap a fresh machine: prerequisites (git; python3.13 interpreter pin on
# Fedora 45+), clone playbook-example when missing, then fetch every sibling
# repo. Also curl-able standalone — see AGENTS.md → Machine bootstrap
bootstrap-machine:
    scripts/bootstrap-machine.bash

# Show git status + last commit of every sibling repo
git-status:
    scripts/git.bash status

# Fast-forward pull every sibling repo; skip dirty working trees
git-pull:
    scripts/git.bash pull

# Add, commit (with MSG), and push every dirty sibling repo
git-commit msg:
    scripts/git.bash commit "{{msg}}"

# Publish every odem-* collection to Ansible Galaxy — GALAXY_API_TOKEN
# from the environment or .env at the repo root
publish server='':
    scripts/publish.bash "{{server}}"

# --- Vault (scripts/vault.bash) ------------------------------------------------
# Secrets live encrypted at inventories/<name>/group_vars/all/vault.yml
# (auto-loaded for every host; the encrypted file is committed). Password
# source: file at inventories/<name>/vault-pass (mode 0600, gitignored,
# written by vault-pass-create) → used automatically; VAULT_ASK=1 → prompt;
# neither → ansible-vault prompts itself. Extra args pass through to
# ansible-vault; encrypt/decrypt take the file path relative to
# inventories/<name>/.

# Create the vault password file at the known location (prompts twice)
vault-pass-create inventory='home':
    scripts/vault.bash pass-create "{{inventory}}"

# Create the encrypted vault file (fails if it exists — use vault-edit)
vault-create inventory='home' *args:
    scripts/vault.bash create "{{inventory}}" {{args}}

# Edit the vault file in $EDITOR
vault-edit inventory='home' *args:
    scripts/vault.bash edit "{{inventory}}" {{args}}

# Print the decrypted vault file (read-only)
vault-view inventory='home' *args:
    scripts/vault.bash view "{{inventory}}" {{args}}

# Change the vault password (rekeys vault.yml + rewrites the password file)
vault-rekey inventory='home' *args:
    scripts/vault.bash rekey "{{inventory}}" {{args}}

# Encrypt a file of an inventory (path relative to inventories/<name>/)
vault-encrypt inventory file *args:
    scripts/vault.bash encrypt "{{inventory}}" "{{file}}" {{args}}

# Decrypt an encrypted file of an inventory (path relative to inventories/<name>/)
vault-decrypt inventory file *args:
    scripts/vault.bash decrypt "{{inventory}}" "{{file}}" {{args}}

# Show vault state: vault + password file presence, decrypt check
vault-status inventory='home':
    scripts/vault.bash status "{{inventory}}"

# --- Per-playbook targets -------------------------------------------------------
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