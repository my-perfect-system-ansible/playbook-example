# Justfile — playbook-example
#
# Common playbooks (playbooks/) applied to any inventory (inventories/<name>/).
# Every playbook targets `all` hosts of the selected inventory; narrow to
# groups/hosts by passing `--limit <subset>` (or any other ansible-playbook
# argument) through the extra args.

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
    exec ansible-playbook "../../playbooks/{{playbook}}.yml" {{args}}

# Syntax-check every playbook against an inventory
check inventory='home':
    #!/usr/bin/env bash
    set -euo pipefail
    cd "inventories/{{inventory}}"
    for pb in ../../playbooks/*.yml; do
        ansible-playbook --syntax-check "$pb"
        echo "OK  $(basename "$pb")"
    done

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