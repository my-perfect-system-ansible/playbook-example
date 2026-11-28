# playbook-example

Common playbooks + per-inventory configurations for the `odem.*` Ansible
collections. Playbooks are inventory-agnostic — every play targets `all`
hosts — and live together in `playbooks/`; everything environment-specific
(hosts, groups, vars) lives in `inventories/<name>/`.

## New machine

Bootstrap a fresh machine — prerequisites (git; the python3.13 interpreter
pin on Fedora 45+) plus every repo of the ecosystem (26: the 7 `odem-*`
collections + this repo + 18 `mps-*` repos):

```bash
curl -fsSL https://raw.githubusercontent.com/my-perfect-system-ansible/playbook-example/main/scripts/bootstrap-machine.bash | bash
```

`MPS_REPO_BASE` overrides the root (default `/srv/repo/github`). From an
existing clone the same steps are `just bootstrap-machine` (idempotent) —
details in [AGENTS.md](AGENTS.md) → *Machine bootstrap*.

## Usage

```bash
just list                          # inventories + playbooks
just bootstrap home                # playbooks/bootstrap.yml → inventories/home
just bootstrap srv --limit srv     # … limited to the `srv` group
just run srv all --limit local     # generic form: run <inv> <playbook> [args…]
just run home bootstrap -K         # extra args pass through to ansible-playbook
just install-forced                # build + install the sibling odem-* collections
just vault-pass-create home         # vault password file → inventories/home/vault-pass
just vault-create home              # encrypted inventories/home/group_vars/all/vault.yml
just vault-edit home                # edit it ($EDITOR); vault-view prints it
just check srv                     # syntax-check every playbook
just graph home                    # inventory tree (hosts + groups)

just list-roles                   # every role in every odem-* collection
just lint                         # yamllint + ansible-lint per collection
just molecule backup              # run a role's molecule scenario
just list-collections home        # installed collections of an inventory

just bootstrap-machine          # fresh machine: prereqs + fetch every repo
just git-clone                    # clone every missing sibling repo (fresh install)
just git-status                   # git status + last commit per sibling repo
just git-pull                     # fast-forward pull per repo; skip dirty
just git-commit 'msg'             # add + commit + push, every dirty repo
just publish                      # ansible-galaxy publish per odem-* (GALAXY_API_TOKEN or .env)
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
| `scripts/` | the Justfile's logic — `run-playbook.bash`, `check-playbooks.bash`, `install-collections.bash`, `git.bash` (`clone|status|pull|commit`), `bootstrap-machine.bash` (fresh-machine bootstrap), `publish.bash`, `vault.bash` (recipes are thin wrappers) |
| `inventories/<name>/ansible.cfg` | `collections_path` + connection settings (`inventory = ./inventory.ini`) |
| `inventories/<name>/inventory.ini` | hosts + groups of that inventory |
| `inventories/home/inventory_local.ini` | in-place apply variant (same host as the ssh entry, kept separate to avoid var conflicts) |
| `inventories/<name>/group_vars/all/` | `odem_<collection>.yml` — commented-out dumps of the role defaults; the override surface. `odem_all.yml` holds the active cross-collection vars |
| `inventories/<name>/host_vars/` | per-host values (`ansible_host`, role tunables) |
| `inventories/<name>/group_vars/all/vault.yml` | encrypted secrets — auto-loaded for every host (managed via the `vault-*` targets) |
| `inventories/<name>/vault-pass` | vault password file (mode 0600, **gitignored** — never commit it) |

## Add an inventory

```bash
cd inventories
cp -r home <name>                # or start from scratch
$EDITOR <name>/inventory.ini    # your hosts + groups
$EDITOR <name>/host_vars/*.yml   # per-host values
```

`just <playbook> <name>` picks it up — no Justfile change needed.

## Vault

Secrets live encrypted in `inventories/<name>/group_vars/all/vault.yml`
(auto-loaded for every host of that inventory; the encrypted file is
committed). The vault password file lives inside its inventory at
`inventories/<name>/vault-pass` (mode 0600, **gitignored** via `.gitignore`):

```bash
just vault-pass-create home     # password file (prompts twice)
just vault-create home          # vault file (fails if it exists)
just vault-view home            # print decrypted
just vault-edit home            # edit in $EDITOR
just vault-rekey home           # change the password (+ password file)
just vault-encrypt srv host_vars/srvtest.yml    # encrypt any inventory file
just vault-decrypt srv host_vars/srvtest.yml     # decrypt it back
just vault-status home          # vault + password file state, decrypt check
VAULT_ASK=1 just vault-view home                # prompt instead of the file
```

Playbook runs (`just run`, per-playbook targets, `check`) pass the password
file to ansible automatically when it exists; `VAULT_ASK=1` (or passing
`--ask-vault-pass`) prompts instead. No variables are in the vault yet —
it is pure infrastructure so far.

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
  this repo (`../.ansible/ansible_collections`); each `ansible.cfg` picks
  that up via `collections_path`.
- No `galaxy.yml` — this is an overlay consuming the `odem.*` collections.

## Documentation

- [`AGENTS.md`](AGENTS.md) — this repo's layout + conventions, merged with the
  ecosystem conventions from the retired `manage` repo (2026-11-26)

## License

GPL-3.0-or-later