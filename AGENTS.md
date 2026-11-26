# AGENTS.md — playbook-example

Common playbooks + per-inventory configurations for the `odem.*` Ansible
collections. Consolidates the former per-repo playbook trees of `examples/`
(home) and `examples-server/` (srv) into one repo where playbooks are
inventory-agnostic and every environment detail lives in
`inventories/<name>/`.

## Layout

```
playbook-example/
├── Justfile                    # list/run/check/graph + per-playbook targets
├── playbooks/                  # COMMON playbooks — hosts: all
│   ├── bootstrap.yml           #   odem.os.user + settings + packages + tools
│   ├── terminal_minimal.yml   #   bootstrap + bash/vim/tmux
│   ├── terminal_full.yml      #   bootstrap + 10 terminal roles
│   ├── desktop_minimal.yml    #   qtile/rofi/thunar/essentials/lightdm/browser
│   ├── desktop_full.yml       #   terminal_full + qtile..spotify
│   ├── workstation_minimal.yml
│   ├── workstation_full.yml
│   ├── services.yml           #   odem.services.docker + openwebui
│   ├── alloy.yml              #   odem.alloy stack
│   ├── hardening.yml          #   odem.hardening.firewall (+ commented rest)
│   ├── wazuh.yml              #   wazuh agent (ad-hoc)
│   ├── all.yml                #   bootstrap → terminal_full → services → alloy → hardening
│   └── testing.yml            #   ad-hoc role testing (mostly commented)
└── inventories/
    ├── home/                  # testvm (ssh) + inventory_local.ini (in-place)
    └── srv/                   # dsktest ([local] group) + srvtest ([srv] group)
```

## Conventions

- **Playbooks are common.** No inventory-specific playbooks; environment
  differences live in `group_vars`/`host_vars`, never in `playbooks/`.
- **Every play targets `all`** hosts of the selected inventory. Narrow by
  passing `--limit <hosts,groups>` through the justfile's extra args
  (e.g. `just bootstrap srv --limit local`).
- **One `inventory.ini` per inventory** (`ansible.cfg` sets
  `inventory = ./inventory.ini`). Where one host has multiple connection
  modes under the SAME name (home: testvm local vs ssh), a secondary
  `inventory_local.ini` is kept and selected via `-i`; where modes map to
  distinct hosts (srv: dsktest/srvtest), both are groups in `inventory.ini`
  (`local`, `srv`); `--limit` picks.
- **`group_vars/all/odem_<collection>.yml`** are commented-out dumps of every
  collection's role defaults — the override surface. **`odem_all.yml`** holds
  the active cross-collection vars (`ansible_user`). Refresh the dumps with
  `merge-ansible-configs.bash` (mps-terminal-scripts).
- **`host_vars/<host>.yml`** holds per-host values.
- **ansible.cfg**: `collections_path = ./../../../.ansible:~/.ansible/collections`
  → picks up the `just install-forced` output from `manage/`.
- No `galaxy.yml` — an overlay consuming the collections, not a collection.

## Justfile

- `just <playbook> [inventory] [args…]` — one target per playbook,
  `inventory` defaults to `home`.
- `just run <inventory> <playbook> [args…]` — generic form; extra args pass
  through to ansible-playbook (`--limit <subset>` narrows to groups/hosts).
- `just check <inventory>` — syntax-check every playbook.
- `just graph <inventory>` — inventory tree; `just list` — inventories +
  playbooks.

## Merge provenance (2026-11)

- `bootstrap.yml` = home's full role list (srv's variant had
  settings/packages/tools commented out — the server host_vars carry
  `settings_*` values, so the roles are wanted there too).
- `services.yml` = union of both variants (home: docker active; srv: openwebui
  active → both active).
- srv `terminal.yml` dropped — a subset of `terminal_full.yml`.
- srv `dsktest.yml` → `wazuh.yml` (deploys the wazuh agent to `all` hosts).
- srv `ansible.cfg` default inventory fixed to `./inventory.ini` (was a
  stale `./inventory_vm.ini`).

## See also

- `manage/AGENTS.md` — cross-collection conventions
- `manage/Justfile` — `install-forced`, `lint`, `git-clone`, …