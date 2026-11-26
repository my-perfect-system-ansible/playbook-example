# playbook-example

Common playbooks + per-inventory configurations for the `odem.*` Ansible
collections. Playbooks are inventory-agnostic — every play targets `all`
hosts — and live together in `playbooks/`; everything environment-specific
(hosts, groups, vars) lives in `inventories/<name>/`.

## Usage

```bash
just list                          # inventories + playbooks
just bootstrap home                # playbooks/bootstrap.yml → inventories/home
just bootstrap srv --limit srv     # … limited to the `srv` group
just run srv all --limit local     # generic form: run <inv> <playbook> [args…]
just run home bootstrap -K         # extra args pass through to ansible-playbook
just check srv                     # syntax-check every playbook
just graph home                    # inventory tree (hosts + groups)
```

In-place apply (run on the machine itself):

```bash
just run srv bootstrap --limit local               # srv: dsktest only
just run home bootstrap -i inventory_local.ini     # home: secondary ini
```

## Layout

| Path | Content |
|---|---|
| `playbooks/` | common playbooks — tier chains, `services`, `alloy`, `hardening`, `wazuh`, `all`, `testing` — all `hosts: all` |
| `inventories/<name>/ansible.cfg` | `collections_path` + connection settings (`inventory = ./inventory.ini`) |
| `inventories/<name>/inventory.ini` | hosts + groups of that inventory |
| `inventories/home/inventory_local.ini` | in-place apply variant (same host as the ssh entry, kept separate to avoid var conflicts) |
| `inventories/<name>/group_vars/all/` | `odem_<collection>.yml` — commented-out dumps of the role defaults; the override surface. `odem_all.yml` holds the active cross-collection vars |
| `inventories/<name>/host_vars/` | per-host values (`ansible_host`, role tunables) |

## Add an inventory

```bash
cd inventories
cp -r home <name>                # or start from scratch
$EDITOR <name>/inventory.ini    # your hosts + groups
$EDITOR <name>/host_vars/*.yml   # per-host values
```

`just <playbook> <name>` picks it up — no Justfile change needed.

## Conventions

- **Playbooks are common** — no inventory-specific playbooks. Environment
  differences live in `group_vars`/`host_vars`, never in `playbooks/`.
- **Every play targets `all`** hosts of the selected inventory; narrow by
  passing `--limit <hosts,groups>` through the extra args (e.g. `just bootstrap srv --limit local`).
- **Tier model**: `bootstrap` → `terminal_{minimal,full}` →
  `desktop_{minimal,full}` → `workstation_{minimal,full}` (import chains);
  `all` chains the full server stack
  (`bootstrap → terminal_full → services → alloy → hardening`).
- Collections are built + installed locally via `just install-forced` in
  `manage/` (`../.ansible/ansible_collections`); each `ansible.cfg` picks
  that up via `collections_path`.
- No `galaxy.yml` — this is an overlay consuming the `odem.*` collections.

## Documentation

- [`AGENTS.md`](AGENTS.md) — layout + conventions (incl. merge provenance)
- `manage/AGENTS.md` — cross-collection conventions

## License

GPL-3.0-or-later