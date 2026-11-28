# AGENTS.md — my-perfect-system ecosystem

This file documents the `odem.*` Ansible-collection ecosystem plus the
`mps.*` config/tool repos, and serves as the repo doc of **playbook-example**
— the common-playbooks + tooling repo. It is the canonical home of the
cross-collection conventions: both folder roots symlink their `AGENTS.md`
here (`my-perfect-system-ansible/AGENTS.md` → `playbook-example/AGENTS.md`,
`my-perfect-system/AGENTS.md` → the same file). The former `manage/` repo —
which held the cross-repo `Justfile` and this documentation — was retired
2026-11-26; every one of its targets moved into this repo (see
[Justfile](#justfile)).

## Repos

Each `odem-*` subdirectory is its own Git repository, published on GitHub
under `github.com/my-perfect-system-ansible`, and intended to be published
to Ansible Galaxy as the long-term distribution path.

| Repo | Galaxy name | Version | Depends on | Purpose |
|---|---|---|---|---|
| `odem-os/` | `odem.os` | 0.6.0 | ansible.posix | Operating system init **plus the shared per-user identity model, system tweaks, and per-user backup restore** — package sources, unattended-upgrades, locale/keyboard/timezone, core CLI tooling, the merged `odem.os.user` role (users, groups, SSH keys, sudoers, group folders, `user_*` model, `odem_*` filter plugins), the merged `odem.os.tweaks` role (zram, tmpfs ramdisks, kmscon), and the merged `odem.os.backup` role (SSH keys/config/authorized_keys, Brave bookmarks, home directory). Debian 13 + Fedora 45. |
| `odem-terminal/` | `odem.terminal` | 0.3.2 | odem.os, ansible.posix | Shell and editor environment — bash, vim, nvim, tmux, kitty, fonts, python, rust, scripts, skeletons. Mostly per-user. Debian 13 + Fedora 45. |
| `odem-development/` | `odem.development` | 0.3.2 | odem.os, ansible.posix | Per-user development tooling — opencode, java, dotnet, espidf, latex, lmstudio, unity, pi. |
| `odem-desktop/` | `odem.desktop` | 0.5.0 | odem.os, ansible.posix | Desktop GUI / window manager environment — grubmenu and browser (firefox + brave), plus per-user qtile/rofi/thunar/trayhub/essentials (incl. gnome tools)/kanata/lightdm (greeter + x11 + wm) and system-level thunderbird/spotify. |
| `odem-hardening/` | `odem.hardening` | 0.4.0 | odem.os, ansible.posix, community.crypto | System-level hardening — firewall (iptables), apparmor, auditd, AIDE, fail2ban, Wazuh agent, CIS lockdown (clones `ansible-lockdown/DEBIAN13-CIS`). |
| `odem-services/` | `odem.services` | 0.4.3 | odem.os, ansible.posix, community.docker | Service deployment and configuration — docker (via the `mps-services-docker` repo), openvpn (from the `mps-services-openvpn` repo), monitoring (mps-services-monitoring stack), openwebui. |
| `odem-alloy/` | `odem.alloy` | 0.2.0 | odem.os, ansible.posix | Observability collection — Alloy agent install plus host, docker, monitoring, and fail2ban log collection, blackbox, proxy, and sms exporters. |

The `odem-base`, `odem-users`, `odem-optimize`, and `odem-backup` collections were deleted (2026-11): their content merged into `odem.os` — `odem.base.identity` + `odem.users.*` into the `user` role + `plugins/filter/`, `odem.optimize.{zram,ramdisks,kmscon}` into the `tweaks` role, `odem.backup.backup` into the `backup` role. The conventions documentation lives in this file. Old GitHub URLs 301-redirect.

Collections `odem-os`, `odem-terminal`, `odem-desktop`, `odem-development`, and `odem-hardening` are Fedora-ready — see [Platform support conventions](#platform-support-conventions). The remaining collections are still Debian 13 only.

`playbook-example/` (this repo) consolidates the **common playbooks** (inventory-agnostic, every play `hosts: all`) beside `inventories/<name>/` — one subfolder per inventory, each with its own `inventory.ini` + `ansible.cfg` — plus ALL cross-repo tooling: playbook runs, collection build/install, git ops, Galaxy publish, lint/molecule/list-roles/list-collections. `mps-container-docker/` (in the my-perfect-system org) builds the self-contained mps container image — public repo links only, local ansible provider.

## Standalone `mps-container-*` / `mps-terminal-*` / `mps-desktop-*` / `mps-services-*` repos

Non-collection Git repositories versioned in the sibling
`../../my-perfect-system/` folder (GitHub org `my-perfect-system`) — plain
configuration and tool repos, each self-contained: standalone `install.sh`
works without Ansible, and the odem roles can rely on the repo installers
(`odem.terminal.bash`/`nvim`/`vim` for the respective repos).

Each repo ships: `bootstrap.sh` — the `curl | bash` entry point shown atop each
README; `install.sh` — idempotent deploy: distro detection, then the matching
`install-<distro>.sh` for OS-specific packages (best-effort, config deploys
even without sudo), then the per-user config deploy; `install-debian.sh` /
`install-fedora.sh` — the apt/dnf package lists and system tools, gated by
`MPS_<NAME>_ENABLE_*` env toggles mirroring the role toggles. The bootstrap
clones the repo via https to
`${MPS_REPO_DIR:-${REPO_DIR_DEFAULT}}/<repo>` — `REPO_DIR_DEFAULT` is the
per-repo variable at the top of each `bootstrap.sh` (default
`/srv/repo/github/my-perfect-system/mps`, matching `odem.os.user`'s
`user_default_repo_dir_mps`), overridable per invocation with the
`MPS_REPO_DIR` env var — one clone per host, shared by all users, so the
ansible role and standalone installs converge on the same clone. Clone/pull
run through `sudo` (the dir is root-owned); a failed pull falls back to the
existing clone, so non-admin users install from whatever an admin cloned.
`install.sh` then runs as the invoking user (per-user `$HOME`, or `/etc` and
system tools with `sudo`).

| Repo | Purpose |
|---|---|
| `mps-terminal-bash/` | Bash shell configuration — `~/.bashrc` loader plus `~/.config/bashrc/` (main config, prompt, colors, distro detection, logout). |
| `mps-terminal-bash-aliases/` | System-wide bash alias files `.bashrc_alias_*`, deployed to `/etc/bash_aliases.d/` and sourced alphabetically by the bash config. Supersedes the former `mps-bash-aliases` repo. |
| `mps-terminal-nvim/` | Neovim configuration (lazy.nvim, native `vim.lsp`, blink.cmp) in `config/nvim/`, deployed to `~/.config/nvim/`. Authoring rules in its `AGENTS.md`. Supersedes the former `mps-nvim` repo. |
| `mps-terminal-vim/` | Lean Vim config — `config/vim/.vimrc` deployed to `~/.vimrc`, plus a `~/.NERDTreeBookmarks` seed (only-if-absent). Supersedes the former `mps-vim` repo. |
| `mps-terminal-fonts/` | System-wide font installer — Nerd Fonts (JetBrainsMono) and icon fonts (codicon) downloaded to `/usr/share/fonts`, `fc-cache` rebuild. Installed by the `odem.terminal.fonts` role via its `install.sh`. |
| `mps-terminal-kitty/` | Kitty terminal config — `config/kitty/kitty.conf` deployed to `~/.config/kitty/`. Supersedes the role's embedded copy. |
| `mps-terminal-scripts/` | CLI helper scripts — `scripts/` deployed per-user to `~/.local/bin` (mode 0700). Supersedes the former `mps-scripts` repo; hosts `merge-ansible-configs.bash`. |
| `mps-terminal-skeletons/` | Project skeleton templates — `skeletons/` deployed system-wide to `/etc/mps/skeletons/`. Supersedes the role's embedded copy. |
| `mps-terminal-tmux/` | tmux + tmuxinator config — `config/tmux/` and `config/tmuxinator/` deployed to `~/.config/`. Supersedes the role's embedded copy. |

| Repo | Purpose |
|---|---|
| `mps-desktop-kanata/` | kanata keyboard remapper config — `config/kanata/` deployed to `~/.config/kanata/`; install.sh also sets up the uinput group + udev rule and (optionally) installs kanata via rustup/cargo. |
| `mps-desktop-qtile/` | qtile window manager config — plain `config/qtile/` Python modules (single config spot `config/qtile/settings.py`) copied per user by the `odem.desktop.qtile` role, plus `home/` dotfiles, `etc/qtile.desktop` (xsession) and `scripts/` (autostart + startup/reload/restart helpers). |
| `mps-desktop-rofi/` | Rofi launcher config — `config/rofi/` (config.rasi + themes) deployed to `~/.config/rofi/`, themes also to `/usr/share/rofi/themes`, `scripts/rofi-boot-*.bash` to `~/.local/bin`. |
| `mps-desktop-thunar/` | Thunar file manager config — `config/{Thunar,xfce4}` deployed to `~/.config/`. |
| `mps-desktop-trayhub/` | mps-trayhub — modular pluggable system-tray application (PyQt6): `tray_hub/` package + `main.py`, `user_plugins/` seeds → `~/.config/mps-trayhub/plugins/`; `install.sh` deploys per user (app to `~/.local/share/mps-trayhub`, launcher, rofi wiring, desktop entries) — run per user by the `odem.desktop.trayhub` role; PyQt6 runtime via `install-{debian,fedora}.sh` (`python3-pyqt6`) or the role's `trayhub_packages`. |
| `mps-container-docker/` | self-contained mps container image — Debian base, odem.* collections via public git links (`requirements.yml`), playbook-example clone, build-time apply via the local provider; `install.sh` = `docker compose build`; its own Justfile (build/run/shell/config/up/down) took over the former manage `docker-*` targets. |

| Repo | Purpose |
|---|---|
| `mps-services-docker/` | Docker Engine installer — Debian: official Docker apt repo (`docker-ce` suite); Fedora: packaged `moby-engine` + `docker-compose` (version-checked, official dnf repo as fallback). The engine is never started by the installer (the `odem.services.docker` role owns service management + daemon.json). |
| `mps-services-openvpn/` | OpenVPN docker-compose stack (server/client/networks/PKI generation) — cloned and driven by `odem.services.openvpn`. |
| `mps-services-monitoring/` | Prometheus + Loki + Grafana (+ optional Wazuh) docker-compose stack — cloned and driven by `odem.services.monitoring`. |

The sibling-repo list these tables describe lives in `scripts/git.bash`
(`REPOS`) — `just git-{clone,status,pull}` / `just git-commit 'msg'` iterate
it; the `odem-*` subset (`COLLECTIONS`, derived in the same script) drives
`just lint` / `list-roles` / `molecule`, and `publish.bash` sources the same
library. All of these targets moved here from the retired `manage/` repo
(2026-11-26).

## Per-repo layout

```
odem-<col>/
├── galaxy.yml                  # collection metadata + dependencies
├── changelogs/                 # changelog fragments + compiled changelog.yaml
├── meta/                       # collection-level runtime.yml
└── roles/                      # the actual roles
    └── <role>/
        ├── defaults/main.yml   # role-specific defaults + per-role toggle vars
        ├── files/              # static files deployed to hosts (optional)
        ├── meta/
        │   ├── main.yml        # galaxy_info + role dependencies
        │   └── argument_specs.yml
        └── tasks/
            ├── main.yml        # orchestrator: include install.yml / facts.yml / configure.yml etc.
            ├── install.yml     # system package installation
            ├── configure.yml   # per-user config deployment
            └── facts.yml       # role-internal set_fact computations (see below)
```

## Role structure conventions

Every role follows the same flow inside `tasks/main.yml`:

```yaml
- include_tasks: install.yml      # system-level installation
- include_tasks: facts.yml        # role-internal set_fact computations
- include_tasks: configure.yml    # per-user config deployment
```

Some roles also include:

- Inline conversion blocks inside a subpart file (e.g. the tmpfs conversion block in `odem.os.tweaks` `tasks/ramdisks.yml`) — multi-step operations too large for a single task block, gated by a task-level `when:`.

## Task naming convention

Every `name:` field in `tasks/*.yml` and `handlers/*.yml` is a **bare action phrase** describing what the task does — no role-name prefix, no quoted string wrappers.

Examples:

```yaml
- name: Install bash-completion when enabled
- name: Deploy per-user .bashrc
- name: Configure net.ipv4.ip_forward for NAT
- name: Rebuild font cache
```

Rules:
- No `<ROLE>_MAIN - …`, no `<ROLE> - …`, no `DESK_BRAVE_INSTALL - …`. The role context is already implied by the file path.
- Names are unquoted (no `"..."`).
- They correspond 1:1 to the action — quick to scan in ansible-playbook output.
- `notify:` references match the bare name of the handler task. Handler files (`handlers/main.yml`) follow the same convention.

Do **not** reintroduce the historical `<ROLE_NAME> - <message>` prefix. The first thing a future reader of a play log needs is the action, not the file path.

## Platform support conventions

`odem.*` roles support the **Debian** and **RedHat** platform families. The platform gate lives exactly once, in `odem.os.user` (`tasks/identity.yml`):

```yaml
- name: Assert supported target platform
  ansible.builtin.assert:
    that:
      - ansible_facts['os_family'] in ['Debian', 'RedHat']
    fail_msg: "This role supports Debian and RedHat family distributions only"
    quiet: true
```

The assert lives in `identity.yml`, so it fires wherever identity is resolved — in `odem.os.user` itself and in every consuming role's lazy guard (see [Identity resolution protocol](#identity-resolution-protocol)) — not only where the role is applied explicitly. Leaf roles do **not** re-assert the platform — they branch per family with `when: ansible_facts['os_family'] == 'Debian'` / `== 'RedHat'` conditions. Debian-only features (debconf, `/etc/default/*`, tasksel, `update-alternatives`, apt sources templates) are gated to `== 'Debian'` and skipped on Fedora.

### Package installation — dnf CLI pattern on RedHat

All RedHat-family package installs go through the **`dnf` CLI** (`ansible.builtin.command: dnf install -y ...`), never `ansible.builtin.package`. Reason:

- Fedora 45 ships Python 3.15, which breaks ansible-core 2.19 module execution (`dataclasses._is_type` removed) — the interpreter must be pinned (`ansible_python_interpreter: /usr/bin/python3.13`).
- A pinned 3.13 interpreter lacks the `libdnf5` Python bindings the ansible `dnf` backend needs — `ansible.builtin.package` fails regardless of which interpreter is used.
- The `dnf` CLI runs under the system Python (3.15) and is immune to both problems.

Idempotency is approximated with `changed_when: "'Nothing to do' not in <register>.stdout"` — `dnf install -y` is a no-op when everything is already present. Do not switch RedHat paths back to `ansible.builtin.package`.

### Per-family differences already encoded

| Topic | Debian | RedHat (Fedora) |
|---|---|---|
| auto-upgrades | `unattended-upgrades` + apt-daily timers | `dnf-automatic.timer` |
| locale | `/etc/locale.gen` + `/etc/default/locale` + debconf | `glibc-langpack-<lang>` + `/etc/locale.conf` |
| keyboard | `keyboard-configuration` + `/etc/default/keyboard` | `/etc/vconsole.conf` + `/etc/X11/xorg.conf.d/00-keyboard.conf` |
| console font | `console-setup` (Debian only) | — (skipped) |
| admin group for sudo | `sudo` | `wheel` |
| root shell/gecos | `chsh` / `chfn` (usermod refuses root) | `usermod -s` / `usermod -c` (Fedora 45 removed `chfn`/`chsh` from shadow-utils) |
| vim | `vim-nox` + addon packages | `vim-enhanced` |
| tmuxinator | apt package | `gem install tmuxinator` |
| npm global root | `/usr/lib/node_modules` | `/usr/local/lib/node_modules` (`nvim_npm_global_root` default) |

### Fedora 45 interpreter pinning

Fedora 45 hosts need `dnf install -y python3.13` as a manual bootstrap prerequisite, then in host vars:

```yaml
ansible_python_interpreter: /usr/bin/python3.13
```

Until ansible-core supports Python 3.15, this pin is required on Fedora 45+.

## `odem.os.user` — merged per-user role

`odem.os.user` (in `odem-os/roles/user/`) is the **single source of truth** for the per-user identity data model and resolve protocol, and the merged home of the former `odem.base.identity`, `odem.users.users`, `groups`, `ssh`, and `sudo` roles. No per-user role meta-depends on it — every consuming role resolves identity lazily via a first-task guard (see [Identity resolution protocol](#identity-resolution-protocol)); there is neither a per-role `resolve.yml` nor a meta dependency. The role's account management (groups, users, SSH, sudo, folders) only runs where the role is applied explicitly, e.g. `playbooks/bootstrap.yml`.

Orchestrator `tasks/main.yml`: platform assert → `identity.yml` → `folders.yml` (gated) → `groups.yml` → `users.yml` → `ssh.yml` → `sudo.yml`.

It produces four facts:

| Fact | Description |
|---|---|
| `user_resolved` | List of dicts, one per `user_list` entry: `id`, `name`, `state`, `user_roles`, plus every other field from the matching `user_catalog` entry. |
| `user_present` | `user_resolved` filtered to `state == 'present'`. |
| `user_absent` | `user_resolved` filtered to `state == 'absent'`. |
| `user_group_names` | Flat, deduplicated list of all group names referenced by present users (sourced from each user's `group` and `groups` fields). |

Each consuming role filters `user_resolved` by its own `user_roles.<key>` flag inline in its task loops:

```yaml
loop: "{{ user_resolved | odem.os.odem_filter_users('terminal_bash') }}"
loop_control:
  loop_var: entity
```

or with plain `when: entity.user_roles.<key> | default(false)` conditions.

### `user_catalog` and `user_list` — single source of truth

Both inputs to the identity model are declared and defaulted **exactly once** in `odem-os/roles/user/`:

- `odem-os/roles/user/meta/argument_specs.yml` — canonical spec, including the **full single-entity schema** for a `user_catalog` entry (every supported field: `name`, `uid`, `group`, `groups`, `append_groups`, `comment`, `shell`, `home`, `create_home`, `system`, `expires`, `password`, `ssh_keys`, `authorized_keys`, `sudo`, `user_roles`).
- `odem-os/roles/user/defaults/main.yml` — canonical defaults, including the ecosystem-wide `user_default_*` globals, per-user field defaults (`user_shell`, `user_create_home`, `user_system`, `user_expires`, `user_groups`, `user_admin_groups`, `user_append_groups`, `user_password`), two role-set profiles (`user_roles_default`, `user_roles_minimal`), group management (`user_groups_list`, `user_enable_group_extraction`), sudo macros (`user_sudo_macros`, `user_sudo_macros_files`), and empty `user_catalog: {}` / `user_list: []` ready to be overridden per host.

Per-user roles **do not** declare `user_catalog` or `user_list` in their own `argument_specs.yml` or `defaults/main.yml` — they flow through the play scope into the lazy identity guard. Re-declaring them would duplicate the schema and risk drift.

### Filter plugins

Data-shaping lives in `odem-os/plugins/filter/` (one filter per file), referenced fully-qualified because Ansible does not resolve bare filter names via a play's `collections:` list: `odem.os.odem_resolve_users`, `odem.os.odem_user_groups`, and `odem.os.odem_filter_users` (the per-user-role opt-in filter used by leaf collections).

### Identity resolution protocol

The historical per-role `resolve.yml` was removed from every role. The steps now live exclusively in `odem.os.user` (`tasks/identity.yml`):

1. **Validate** — assert `item.name in user_catalog` for each present user
2. **Resolve** — combine catalog entry with id/name/state/user_roles into `user_resolved`
3. **Split** — filter into present/absent lists
4. **Extract** — flatten each present user's `group` and `groups` fields into `user_group_names`

Consumer roles invoke the protocol via the **lazy identity guard** — the first task of every identity-consuming role (`tasks/main.yml`):

```yaml
- name: Resolve identity facts when missing
  ansible.builtin.include_role:
    name: odem.os.user
    tasks_from: identity.yml
    public: true
  when: user_resolved is not defined or user_default_repo_dir_mps is not defined
```

- `tasks_from: identity.yml` — resolve facts only; no account management.
- `public: true` — exposes `odem.os.user`'s `user_default_*` ecosystem globals to the play.
- The `when` clause needs BOTH conditions: `user_resolved` facts persist across the plays of one run, role defaults do not — the second clause forces a re-include in every play.
- Roles that consume no identity data (`odem.os.{settings,packages,tools}`, most `odem.development` roles) carry neither guard nor meta dependency.
- **Argument-spec validation renders role defaults and spec defaults BEFORE any role task** — it cannot rely on the guard. Two rules follow: `argument_specs.yml` `default:` fields are literals (never `{{ user_* }}` templates), and every consuming role whose `defaults/main.yml` templates a `user_default_*` global mirrors the canonical value in its own defaults file (inventory overrides still beat role defaults). Verify spec health with one `ansible-playbook --check --tags always` sweep over all roles — it runs only the `always`-tagged validation tasks.

### Shared group folders

The role also creates collaborative group folders. Configurable via `user_group_folders` (list of dicts: `path` + `group` + optional `mode`), gated by `user_enable_group_folders` (default `true`, empty list = no-op). Each folder is root-owned with the entry's group and the setgid bit (`user_group_folders_mode`, default `2770`) so new subfolders inherit the group; referenced groups are ensured present.

## Toggle variable pattern

Every yes/no subcomponent toggle is named `<role>_enable_<component>: bool`. Lists and config values keep their existing names; their execution is gated by the corresponding `enable_*` toggle.

Examples:

```yaml
bash_enable_bash_completion: true      # was: bash_install_bash_completion
bash_enable_aliases: true              # was: bash_install_aliases
bash_enable_fun_packages: true         # new gate for the bash_fun_packages list
firewall_enable_icmp: true             # was: firewall_allow_icmp
firewall_enable_nat_ip_forwarding: false # was: firewall_nat_enable_ip_forwarding
lockdown_enable_execute: false         # was: lockdown_execute
packages_enable_repos_main: true
tools_enable_archives: true
```

Role `defaults/main.yml` lists the toggles. Tasks apply them via `when:` clauses. `meta/argument_specs.yml` documents them for runtime validation.

## Identity user roles (denylist model)

Per-user roles are **disabled by default**. Users opt in via `user_roles.<key>: true` in their catalog entry. Keys are prefixed with the collection name:

```yaml
user_catalog:
  user01:
    user_roles:
      terminal_bash: true
      terminal_vim: true
      desktop_qtile: true
      desktop_rofi: true
      development_opencode: true
      os_backup: true
```

The convention is: `user_roles_default` defines the global default per-user role set in `odem-os/roles/user/defaults/main.yml`, and per-user catalog entries reference it via `"{{ user_roles_default }}"`. A second preset `user_roles_minimal` is provided for restricted users.

## This repo — layout

```
playbook-example/
├── Justfile                    # thin wrappers — logic in scripts/
├── scripts/                   # run-playbook / check-playbooks / install-collections / vault / git / machine bootstrap / publish / lint / list-roles / molecule
│   ├── run-playbook.bash      # cd inventory + vault pw resolution + ansible-playbook
│   ├── check-playbooks.bash   # --syntax-check every playbook
│   ├── install-collections.bash # odem-* build + force-install (install-forced)
│   ├── git.bash               # cross-repo git ops clone|status|pull|commit + shared REPOS/COLLECTIONS list (moved from manage/)
│   ├── bootstrap-machine.bash # fresh-machine bootstrap: prereqs + anchor clone + fetch every repo (sources git.bash)
│   ├── publish.bash           # ansible-galaxy collection publish per odem-* (moved from manage/; sources git.bash)
│   ├── lint.bash              # yamllint + ansible-lint per collection (moved from manage/)
│   ├── list-roles.bash        # role listing per collection (moved from manage/)
│   ├── molecule.bash          # molecule/default scenario per role (moved from manage/)
│   └── vault.bash             # vault lifecycle; also the shared pw-resolution lib (sourced by run-playbook.bash)
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

## This repo — conventions

- **Playbooks are common.** No inventory-specific playbooks; environment differences live in `group_vars`/`host_vars`, never in `playbooks/`.
- **Every play targets `all`** hosts of the selected inventory. Narrow by passing `--limit <hosts,groups>` through the justfile's extra args (e.g. `just bootstrap srv --limit local`).
- **One `inventory.ini` per inventory** (`ansible.cfg` sets `inventory = ./inventory.ini`). Where one host has multiple connection modes under the SAME name (home: testvm local vs ssh), a secondary `inventory_local.ini` is kept and selected via `-i`; where modes map to distinct hosts (srv: dsktest/srvtest), both are groups in `inventory.ini` (`local`, `srv`); `--limit` picks.
- **`group_vars/all/odem_<collection>.yml`** are commented-out dumps of every collection's role defaults — the override surface. **`odem_all.yml`** holds the active cross-collection vars (`ansible_user`). Refresh the dumps with `merge-ansible-configs.bash` (mps-terminal-scripts).
- **`host_vars/<host>.yml`** holds per-host values.
- **ansible.cfg**: `collections_path = ./../../../.ansible:~/.ansible/collections` → picks up the `just install-forced` output from this repo.
- No `galaxy.yml` — an overlay consuming the collections, not a collection.
- **Vault**: secrets live encrypted at `inventories/<name>/group_vars/all/vault.yml` (auto-loaded for every host; the encrypted file is committed — nothing sensitive is in the repo). The password file lives INSIDE its inventory at `inventories/<name>/vault-pass` (mode 0600, **gitignored** via `.gitignore` — never commit it; written by `just vault-pass-create <inv>`); `VAULT_ASK=1` prompts instead. `ansible.cfg` deliberately sets NO `vault_password_file` — a missing file there fails EVERY ansible run eagerly (verified ansible-core 2.16: startup error even with no encrypted content, `--syntax-check` included). The Justfile passes `--vault-password-file` conditionally instead.

## Machine bootstrap

`scripts/bootstrap-machine.bash` is the single entry point for a fresh
machine — one command fetches every repo of the ecosystem (26: the 7
`odem-*` collections + `playbook-example` + 18 `mps-*` repos):

```bash
curl -fsSL https://raw.githubusercontent.com/my-perfect-system-ansible/playbook-example/main/scripts/bootstrap-machine.bash | bash
```

Two phases, one file:

1. **standalone** (piped from curl, no sibling `git.bash`): installs
   prerequisites — `git`, plus the `python3.13` interpreter pin on Fedora 45+
   (the manual bootstrap prerequisite from
   [Platform support conventions](#platform-support-conventions), now encoded
   here) — clones the anchor repo `playbook-example` (the only hardcoded URL;
   this repo owns the cross-repo tooling), then re-execs the cloned copy. A
   clone predating the script falls back to plain `git.bash clone`.
2. **from clone** (sibling `git.bash` present): sources `scripts/git.bash`
   and clones every missing sibling — the REPOS list stays single-sourced
   there.

Layout created — the root is overridable with `MPS_REPO_BASE` (default
`/srv/repo/github`, the canonical repo root per `user_default_repo_dir`; pass
a custom path for dedicated data disks):

```
${MPS_REPO_BASE}/my-perfect-system-ansible/{odem-*,playbook-example}
${MPS_REPO_BASE}/my-perfect-system/mps-*
```

Requires sudo rights (package installs; root-owned base creation).
Idempotent — present repos are skipped, safe to re-run; `just git-clone`
remains the in-tree resync, `just git-pull` the update. Provisioning is NOT
part of the bootstrap — accounts/config stay with the playbooks
(`just bootstrap <inv>`); the script prints the next steps. The roles' own mps
clones under `user_default_repo_dir_mps` are independent of this development
tree — they clone/update themselves during playbook runs.

## Justfile

Recipes are thin wrappers — the logic lives in `scripts/`:
`run-playbook.bash` (run), `check-playbooks.bash` (check),
`install-collections.bash` (install-forced), `vault.bash` (the
`vault-*` targets), `git.bash` (the `git-*` targets, subcommands
`clone|status|pull|commit`), `bootstrap-machine.bash` (the fresh-machine
bootstrap; sources `git.bash`), `publish.bash` (Galaxy publish), and — moved
from `manage/` 2026-11-26 — `lint.bash` / `list-roles.bash` /
`molecule.bash` (collection tooling). Shared libraries sourced under their
`BASH_SOURCE` main guards: `vault.bash` (`resolve_vault_password`) and
`git.bash` (`REPOS` + `repo_url` + derived `COLLECTIONS` — sourced by
`publish.bash`, `lint.bash`, `list-roles.bash`, `molecule.bash`).

- `just <playbook> [inventory] [args…]` — one target per playbook,
  `inventory` defaults to `home`.
- `just run <inventory> <playbook> [args…]` — generic form; extra args pass
  through to ansible-playbook (`--limit <subset>` narrows to groups/hosts).
- `just check <inventory>` — syntax-check every playbook;
  `just graph <inventory>` — inventory tree; `just list` — inventories +
  playbooks.
- `just install-forced [collections_path]` — force build + force-install
  every sibling `odem-*` collection into `../.ansible/ansible_collections`.
- `just list-collections [inventory]` — installed collections of that
  inventory.
- `just list-roles` — every role in every `odem-*` collection with its
  description.
- `just lint` — yamllint + ansible-lint per collection (skips repos without
  lint configs; exits non-zero if any collection fails).
- `just molecule <role>` — run a role's molecule/default scenario (role name
  or `odem.<col>.<role>` FQN).
- `just bootstrap-machine` — fresh-machine bootstrap: prerequisites + clone
  playbook-example (when missing) + fetch every sibling repo. Curl-able
  standalone entry (`scripts/bootstrap-machine.bash`; see
  [Machine bootstrap](#machine-bootstrap)).

- `just git-{clone,status,pull}` / `just git-commit 'msg'` — cross-repo git
  ops over every sibling repo, and `just publish [server]` —
  `ansible-galaxy collection publish` per `odem-*` collection (token from
  `GALAXY_API_TOKEN` or `.env`). All moved from `manage/` (2026-11-26).
- `just vault-{pass-create,create,edit,view,rekey,encrypt,decrypt,status}` —
  manage `inventories/<inv>/group_vars/all/vault.yml`; password file at
  `inventories/<inv>/vault-pass` (gitignored), `VAULT_ASK=1` to prompt;
  `encrypt`/`decrypt` take a path relative to `inventories/<inv>/`.

## Build, install, run

All targets run from this repo; paths are relative to the sibling collections:

```bash
just                            # default → usage (just --list)
just <playbook> [inv] [args…]   # playbooks/<playbook>.yml → inventories/<inv> (default: home)
just run <inv> <playbook> …     # generic form; args pass through (--limit, -K, --check, -i)
just check <inv>                # --syntax-check every playbook
just install-forced             # build + install every ../odem-* into ../.ansible/ansible_collections
just list-collections [inv]     # installed collections of inventories/<inv>
just list-roles                 # every role in every odem-* collection with its description
just lint                       # yamllint + ansible-lint per collection
just molecule <role>            # a role's molecule/default scenario
just git-clone                  # clone every missing sibling repo from GitHub (fresh install)
just git-status / git-pull      # status -sb + last commit / ff-only pull per repo
just git-commit 'msg'           # add + commit + push, every dirty repo
just publish [server]           # Galaxy publish per collection (GALAXY_API_TOKEN, or .env)
just vault-*                    # vault lifecycle (see Justfile section)
```

The default install path (`../.ansible/ansible_collections`) matches the first `collections_path` entry in `inventories/<name>/ansible.cfg`.

## Molecule

Every role of every collection carries a `molecule/default` scenario — a
**lightweight dual-platform smoke test** (`just molecule <role>` or
`just molecule odem.<col>.<role>`; docker daemon required):

- **Platforms**: `geerlingguy/docker-debian13-ansible` +
  `geerlingguy/docker-fedora44-ansible`, names `<col>-<role>-{debian,fedora}`.
  Both families run on every scenario — Fedora paths get real coverage.
- **Converge** applies the role once; molecule's idempotence phase asserts a
  second run changes nothing. Per-user roles opt a synthetic `molecule_user`
  into exactly their own role via `user_roles.<key>: true`.
- **Verify** = 2-3 basic assertions (stat / package_facts) — deliberately
  minimal; deeper tests come later.
- **Container-safety toggles** (defaults `true`, scenarios set `false`):
  `settings_enable_console` / `settings_enable_time` (systemd + timedatectl),
  `tweaks_enable_zram` / `tweaks_enable_ramdisks`,
  `kanata_enable_udev_reload` / `kanata_enable_kernel_module` /
  `kanata_enable_service`, `grubmenu_enable_regenerate` (no real `/boot`),
  `lightdm_enable_service` (containers have no systemd).
  The deploys (files, configs, packages) stay ungated.
- **kmscon** needs `trixie-backports` on Debian — the tweaks scenario
  self-configures that pocket in a `pre_tasks` step (Fedora 44 ships kmscon).
- Tooling: `~/.venvs/molecule` (molecule + molecule-docker, `ansible-core`
  pinned `2.19.11`, passlib for controller-side `password_hash`);
  `scripts/molecule.bash` prepends the venv, sets
  `ANSIBLE_ALLOW_BROKEN_CONDITIONALS=1` (molecule-docker 2.1.0 bundled
  playbooks predate core 2.19 strict conditional typing) and
  `ANSIBLE_COLLECTIONS_PATH` (our build dir + `~/.ansible` for ansible.posix).

State (2026-11-26): all 27 roles of os/terminal/desktop pass on both
platforms. Hardening + development scenarios are still the old single-platform
generated stubs.

## Publishing path to Galaxy

Every collection is built locally and installed into `../.ansible/ansible_collections/` via `just install-forced` in this repo. To publish:

1. Push each `odem-<col>/` repo to GitHub under `github.com/my-perfect-system-ansible/odem-<col>` (one repo per collection) — done.
2. Either configure a Galaxy import on each repo and tag a release (e.g. `0.3.0`) — Galaxy auto-builds the tarball and publishes — or run `just publish`, which builds each tarball and calls `ansible-galaxy collection publish` with `GALAXY_API_TOKEN` (loaded from `.env` at this repo's root when present; template in `.env.example`).
3. Consumers then run `ansible-galaxy collection install odem.os odem.terminal odem.alm ...`.

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
- `install-forced` moved here from `manage/` (2026-11-26) — this repo owns the
  collection build + install step.
- The cross-repo git targets (`git-clone` / `git-status` / `git-pull` /
  `git-commit`) and `publish` moved here from `manage/` (2026-11-26), the four
  git actions merged into the one `scripts/git.bash`.
- `run-example` retired from `manage/` — covered here by `run` + the
  per-playbook targets (`--limit` / `-i` passthrough).
- Vault infrastructure (2026-11-26): the `vault-*` targets + the
  password-file convention; no variables moved into the vault yet.
  `ansible.cfg` `vault_password_file` intentionally omitted (eager failure
  on a missing file — the Justfile resolves the password source instead).
- Justfile logic extracted into `scripts/*.bash` (2026-11-26) — recipes are
  one-line wrappers; vault password resolution lives once in `vault.bash`
  (was duplicated inline across `run`, `check` and every vault recipe).
- The **`manage` repo retired** (2026-11-26): its remaining Justfile targets
  (`lint` / `list-roles` / `molecule` / `list-collections` / `usage`) moved
  here as `scripts/{lint,list-roles,molecule}.bash` + recipes; the canonical
  conventions doc (`manage/AGENTS.md`) merged into this file; the GitHub repo
  + local directory were deleted; the folder-root `AGENTS.md` symlinks
  repointed here.

## Recent refactoring notes

The following cleanup passes have been committed to the local repos:

- **`odem.os.user` meta dependencies replaced by the lazy identity guard (2026-11-26)** — all 36 `role: odem.os.user` meta deps across the 7 collections were removed. The 25 identity-consuming roles (terminal ×10, desktop ×7, services ×4, alloy `base`+`install`, `development.pi`, `hardening.lockdown`, `os.backup`) now resolve `user_resolved`/`user_present`/`user_absent`/`user_group_names` plus the `user_default_*` globals lazily via a first-task `include_role { name: odem.os.user, tasks_from: identity.yml, public: true }` guard (see [Identity resolution protocol](#identity-resolution-protocol)). Account management (groups/users/ssh/sudo/folders) now runs ONLY where `odem.os.user` is an explicit role — `playbooks/bootstrap.yml`; identity-free roles (`os.{settings,packages,tools}`, most `development` roles) carry neither guard nor dep. Consequence: a fresh host MUST be bootstrapped before any per-user role play (the guard does not create accounts), and the platform assert likewise only runs where the user role applies.
- **Validation-render follow-up (same day)** — argument-spec validation renders role `defaults/main.yml` AND spec defaults BEFORE any role task, so it cannot rely on the guard: the first live `desktop_full` run died on qtile's spec default. Fixed by (a) literal `default:` values in all 8 `argument_specs.yml` files that templated `user_default_*` (alloy sms; desktop kanata/qtile/rofi/thunar/trayhub; terminal fonts/skeletons), and (b) mirroring the canonical `user_default_repo_dir(_mps)` value in the 18 consuming roles whose `defaults/main.yml` template it. Verified with the `--tags always` sweep: 55/55 roles validate.
- **Fedora (RedHat family) support added to `odem-base`, `odem-os`, `odem-users`, `odem-terminal`** — the Debian-13-only assert in `odem.base.identity` was replaced by a family-based gate (`os_family in ['Debian', 'RedHat']`). Every Debian-specific task is now gated per family; RedHat paths install via the `dnf` CLI (see [Platform support conventions](#platform-support-conventions)). Affected roles: `package_manager`, `system_settings`, `system_tools` (os); `users` root block, `sudo` wheel mapping (users); `bash`, `fonts`, `kitty`, `nvim`, `python`, `rust`, `tmux`, `vim` (terminal). Fedora 45 added to every `meta/main.yml` platform list.
- **`odem.users.sudo` — shared macros file** — the sudo macros are no longer expanded inline into each per-user sudoers file. A shared macros file (`sudo_macros_file`, default `/etc/sudoers.d/00_macros`) renders every `sudo_macros` entry as a `Cmnd_Alias`; each per-user file references the aliases by name (`alice ALL=(ALL) ADMIN_DEFAULT, ADMIN_DEBUG`). Both files are validated with `validate: visudo -cf %s` (visudo accepts cross-file alias references). `community.general` dependency dropped from `odem-users` (sudo was its only consumer) — rules are plain `ansible.builtin.copy` with mode `0440`.
- **`odem.users.users` root block per-family** — root's shell/gecos edits use `chsh`/`chfn` on Debian (where usermod refuses root) and `usermod -s`/`-c` on RedHat (Fedora 45 removed `chfn`/`chsh` from shadow-utils). `chpasswd -e` and `chage -E` work on both.
- **`odem.terminal.nvim` fixes** — `nvim_enable_apt_deps` renamed to `nvim_enable_deps` (per-family dependency lists now); `nvim_npm_global_root` default added (`/usr/local/lib/node_modules` on RedHat vs `/usr/lib/node_modules` on Debian — the `creates:` idempotency check needs it); per-user nvim config dir is pre-created at `0700` before the `remote_src` tree copy (with `remote_src` + directory src, `copy` applies `mode` to the destination dir itself — a `mode: "0600"` on the copy produced `drw-------` nvim dirs; `mode` dropped from the copy since it never reaches files under `remote_src`).
- **`odem.terminal.vim` toggle rename** — `vim_enable_vim_nox` → `vim_enable_packages` (Fedora has no vim-nox; RedHat path installs `vim-enhanced` via dnf).
- **`examples` inventory fix** — `admin_groups: [user_default_admin_group, user_default_config_group]` in `group_vars/all/odem_users.yml` was unquoted, so users' `groups` fields carried the literal strings instead of resolving to `admin`/`config` — the groups role created junk groups named `user_default_*` and the real `admin` group never existed (surfaced on a fresh Fedora VM as `chgrp failed: failed to look up group admin`). Fixed to `admin_groups: ["{{ user_default_admin_group }}", "{{ user_default_config_group }}"]`.
- **`manage/Justfile` `run-example` passthrough** — extra args after the playbook name are passed through to `ansible-playbook` (`just run-example home vm bootstrap -K`).
- **Task name prefix removed** — every `name:` field in `tasks/*.yml` and `handlers/*.yml` across all 9 collections had its `<ROLE> -` prefix stripped (140 files, 429 names). `notify:` references rewired to the new bare names.
- **Dead options removed** from `argument_specs.yml` + matching defaults:
  - `odem-desktop/qtile`: `qtile_keepass_bin`, `qtile_keepass_db_path`, `qtile_screenlayout_hive_cmd` (keepass integration dropped; screenlayout cmd unused).
  - `odem-hardening/aide`: `aide_conf_file` (never referenced).
  - `odem-hardening/lockdown`: `lockdown_ssh_port`, `lockdown_cis_vars` (ssh_port hardcoded in `hosts.j2`; cis_vars.yml wiring was missing).
- **`users_catalog` / `users_list` centralised** — removed from every per-user role's `argument_specs.yml`. The canonical home is now `odem-base/roles/identity/meta/argument_specs.yml` (with full single-entity schema) and `odem-base/roles/identity/defaults/main.yml` (with sensible defaults and example shapes).
- **`changelogs/` folders repopulated** — fragments + compiled `changelog.yaml` exist again in the 9 original collections; `odem-services` and `odem-alloy` still need theirs.
- **Per-user roles merged into `odem.users.user`** — `odem.base.identity` (platform assert, `identity_default_*` globals, resolve protocol, group folders) and `odem.users.users`/`groups`/`ssh`/`sudo` were merged into the single role `odem.users.user` (one tasks file per subpart — `identity.yml`, `folders.yml`, `groups.yml`, `users.yml`, `ssh.yml`, `sudo.yml` — behind one orchestrator; add/del/facts logic folded into task-level `when:` checks, no `_add`/`_del`/`_facts` splits). Variables renamed to the unified `user_*` prefix (`identity_default_*`→`user_default_*`, `users_catalog`/`users_list`→`user_catalog`/`user_list`, facts `identity_users_{resolved,present,absent}`→`user_{resolved,present,absent}`, `identity_user_groups`→`user_group_names`, `admin_groups`→`user_admin_groups`, `sudo_macros*`→`user_sudo_macros*`, `groups_*`→`user_groups_*`). Filter plugins moved `odem-base/plugins/filter`→`odem-users/plugins/filter` (refs `odem.base.odem_*`→`odem.users.odem_*`). `odem.base` is now a docs-only anchor: every leaf collection's Galaxy dependency swapped `odem.base`→`odem.users`, every per-user role's meta dependency is `odem.users.user`. odem-base 0.4.0, odem-users 0.4.0.
- **`odem-meta` collection added then removed** — `odem-meta` was initially introduced as composition-only meta roles (`bootstrap`, `terminal_full`/`terminal_minimal`, `desktop_full`/`desktop_minimal`, `workstation_full`/`workstation_minimal`) that bundled leaf roles from the other collections into host classes. Each meta role was `meta/main.yml` listing `dependencies:` plus a no-op `tasks/main.yml`. The whole collection was subsequently deleted and replaced with 7 tier playbooks under `examples/inventories/home/playbooks/` (`bootstrap.yml`, `terminal_minimal.yml`, `terminal_full.yml`, `desktop_minimal.yml`, `desktop_full.yml`, `workstation_minimal.yml`, `workstation_full.yml`) using `import_playbook` chains — one less collection, no `odem.meta.*` namespace pollution, every leaf role visible at the play site.
- **`manage/Justfile` added** — cross-repo git ops (`git-status`, `git-pull`, `git-commit`), example runner (`run-example`), and force build/install (`install-forced` → `ansible-galaxy collection build --force && install --force` into `../.ansible/ansible_collections/`). Replaces the prior `odem-examples/` Make for local development loops. (The `manage` repo itself was retired 2026-11-26 — all of this lives in this repo now.)
- **Feature toggles hoisted to top of `defaults/main.yml`** — every role defaults file with `<rolename>_enable_*` toggles was restructured to put the toggles in a top section under `# Feature toggles — naming pattern: <rolename>_enable_<feature>`, followed by a `# Regular configuration` section. 13 of 49 role defaults files were affected (the rest have no toggles yet). Toggle grouping is now visually consistent across roles.
- **`examples/inventories/home/` reorganised** — `host_vars/testvm.yml` holds the host-specific `ansible_host`; `group_vars/all.yml` holds `ansible_user: deploy` (shared by every host); `group_vars/all/odem_*.yml` are commented-out reference dumps of every collection's role defaults, so users can see what they have available to override.
- **`odem.os.user` sudoers — per-group macro files + NOPASSWD (2026-11-27)** — the single shared Cmnd_Alias macros file (`user_sudo_macros_file`, `/etc/sudoers.d/00_macros`) was split per macro group: `user_sudo_macros_files` (dict alias → path) now renders one file per alias (`/etc/sudoers.d/00_macros_admin_default|admin_debug|admin_minimal`) via a looped copy task, and the legacy merged `00_macros` is removed. The per-user rule line now always carries the `NOPASSWD` flag — `sudo.nopasswd: true` → `user ALL=(ALL) NOPASSWD: ALL`, otherwise `user ALL=(ALL) NOPASSWD: <aliases>`; the macro branch previously rendered the bare aliases, which prompts for a password instead of running the commands password-free.
- **`odem.desktop.qtile` — config dir mode clobber (2026-11-27)** — the per-user config copy (`remote_src: true` + directory src) carried `mode: "0644"`, which `copy` applies to the destination directory itself — `~/.config/qtile` deployed as `drw-r--r--`, unstat-able by its owner, so `import settings` (and every `qtile-{restart,reload,autostart}` helper reading `settings.QTILE_VENV_REL`) died with `ModuleNotFoundError` and an empty venv path. `mode` dropped from that copy (pre-created `0700` + `directory_mode: "0700"` remain), mirroring the earlier `odem.terminal.nvim` fix.
- **`odem.desktop.lightdm` — autologin + Fedora service enable (2026-11-27)** — the role now covers the install-time steps the testvm session debugging surfaced. (a) Fedora ships no systemd preset for lightdm — a new `lightdm_enable_service`-gated task enables + starts the unit (RedHat-only; Debian's package postinst already enables it; molecule sets the toggle false). (b) New `tasks/autologin.yml` + `lightdm_enable_autologin` toggle configure passwordless graphical autologin: system `autologin` group + membership for the first present user opted into `user_roles.desktop_lightdm` (or `lightdm_autologin_user`), a group-gated `/etc/pam.d/lightdm-autologin` template (RedHat-only — Fedora's lightdm package ships none, and without it the autologin session dies; Debian's package ships its own), and a dropin `/etc/lightdm/lightdm.conf.d/99-mps-autologin.conf` — the `autologin-*` options must sit in `[Seat:*]`, lightdm silently ignores them in `[LightDM]` (logs "contains unknown option"). A new handler restarts lightdm when the dropin/PAM change. All four pieces were proven live on testvm (Fedora 45) before being written into the role.

- **`odem.desktop.lightdm` — graphical boot target (2026-11-28)** — enabling the lightdm unit only wires the `display-manager.service` alias; `graphical.target` is what pulls that alias in at boot. testvm (Fedora Server/Everything preset) booted `multi-user.target`, so after a reboot only a manual `systemctl restart lightdm` brought up the greeter. New `lightdm_enable_service`-gated task (family-agnostic) links `/etc/systemd/system/default.target` → `/usr/lib/systemd/system/graphical.target` via `ansible.builtin.file` (`state: link`, `force: true` — idempotent, replaces the `systemctl set-default` command). Molecule stays safe: scenarios keep setting the toggle false.

- **Machine bootstrap (2026-11-28)** — new `scripts/bootstrap-machine.bash` + `just bootstrap-machine`: the fresh-machine entry point — prerequisites (git; `python3.13` on Fedora 45+, the documented manual prerequisite now encoded), clone of the anchor repo `playbook-example` (the only hardcoded URL), then delegation to `scripts/git.bash clone` so the REPOS list stays single-sourced. Curl-able standalone, `MPS_REPO_BASE` root override (default `/srv/repo/github`). See [Machine bootstrap](#machine-bootstrap).

## Deferred (regenerate in dedicated sessions)

- Per-role / per-collection **README.md** files
- **AGENTS.md** files inside individual collection subdirectories
- **Molecule** tests for every role — os/terminal/desktop (27 roles) carry lightweight dual-platform scenarios (see [Molecule](#molecule)); services/alloy scenarios remain TODO
- Cross-collection tier model (base / common / optional) — currently each leaf carries its own 3-tier playbook structure; future design may consolidate
- New changelog fragments (will be added once the refactor work is wrapped up)

## See also

- `mps-container-docker/` — self-contained mps container image (my-perfect-system org)
- Each leaf collection's own `AGENTS.md` and `README.md`