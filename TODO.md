# TODO — next session

## 1. Confirm the lightdm molecule scenario

Fixes are already in source (`../odem-desktop/roles/lightdm/molecule/default/`), only the
verifying run is missing (last run was aborted mid-flight):

```bash
just molecule odem.desktop.lightdm
```

Expected: green on both platforms (debian + fedora containers). If it fails, check
`/tmp/molecule-lightdm*.log` (delete those afterwards).

Background — two scenario defects, both already fixed:

- `converge.yml`: the minimal catalog entry (`molecule_user: {user_roles: …}`) lacked
  `home:` — the identity resolve preserves catalog fields verbatim (no defaults), so the
  per-user picom/dunst deploys crashed on `entity.home` with
  `object of type 'dict' has no attribute 'home'`. Converge now carries a full catalog
  entry (`name`, `home`, `user_roles`).
- `converge.yml`: `xserver-xorg-video-nvidia` (default `lightdm_packages_wm` member)
  lives in Debian **non-free**; the geerlingguy container image ships main-only apt
  sources → `No package matching 'xserver-xorg-video-nvidia' is available`. Converge
  overrides `lightdm_packages_wm` without it (role default stays — real hosts have
  non-free enabled).

## 2. Commit + push — all work is verified, nothing is committed yet

One run covers every dirty repo:

```bash
just git-commit '<msg>'
```

Uncommitted, by repo:

- **odem-os** — sudoers: `user_sudo_macros_files` per-group split
  (`00_macros_admin_default|admin_debug|minimal`), legacy merged `00_macros` removal,
  per-user rule lines always carry `NOPASSWD:` (`sudo.nopasswd: true` → `NOPASSWD: ALL`,
  otherwise `NOPASSWD: <aliases>`).
- **odem-desktop** —
  - `qtile`: dropped `mode:` from the remote_src directory config copy (dest dir was
    deployed `0644` → unstat-able → `import settings` died); pre-create `0700` +
    `directory_mode: "0700"` remain.
  - `lightdm`: new `lightdm_enable_service` toggle (Fedora ships no systemd preset for
    lightdm — task enables + starts the unit) + `tasks/autologin.yml` behind
    `lightdm_enable_autologin` (autologin group, group-gated
    `/etc/pam.d/lightdm-autologin` template — RedHat only, Debian's package ships its
    own — and the `[Seat:*]` dropin `/etc/lightdm/lightdm.conf.d/99-mps-autologin.conf`;
    autologin options in `[LightDM]` are silently ignored by lightdm) + `handlers/main.yml`
    (Restart lightdm) + molecule scenario fixes (see item 1).
- **playbook-example** — AGENTS.md notes (sudoers, qtile, lightdm; container-toggle list
  gains `lightdm_enable_service`), `inventories/*/group_vars/all/odem_os.yml` +
  `odem_desktop.yml` dump updates, `host_vars/testvm.yml` interpreter pin
  (`ansible_python_interpreter: /usr/bin/python3.13`).

## 3. Optional: stale alloy label on testvm

`host_vars/testvm.yml` → `base_custom_labels` still says `mps_alloy_os_name=debian13` —
stale, testvm is Fedora 45. Only affects alloy labels, nothing else.

## Already done (verified live on testvm — no action needed)

- Bootstrap green (`ok=65 failed=0`); `python3.13` installed + interpreter pinned.
- Sudoers fix deployed via bootstrap.
- `desktop_minimal --limit testvm` green (`ok=103 changed=7 failed=0`).
- lightdm `enabled`/`active`; role-managed autologin boots the qtile session on
  `systemctl restart lightdm` — socket up, `cmd-obj status` → `OK`,
  `qtile-restart.bash` → rc 0.