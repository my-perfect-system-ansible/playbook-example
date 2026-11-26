#!/usr/bin/env python3
"""Check every odem-* role for clone-relative copy sources missing remote_src.

Bug class (2026-11-26): roles clone mps-* repos to
``user_default_repo_dir(_mps)`` ON THE TARGET and then ``copy`` from the
clone. Without ``remote_src: true`` the copy resolves ``src`` on the
Ansible controller and fails at runtime. ``--syntax-check``,
``--list-tasks`` and the argument-spec validation sweep (``--tags
always``) cannot catch it — only a per-task static walk can.

Exemptions (controller-side src by design):
  * src vars allowlisted in CONTROLLER_SIDE_VARS (controller-side backup
    sources)
  * src vars whose role-default value embeds ``role_path`` (the file ships
    inside the collection — odem.os.tweaks kmscon)
  * loop/fact references (dotted names like ``item.entity.home``) — not
    statically resolvable, and those tasks move existing user files

Not scanned: ``slurp`` (remote by definition), ``synchronize`` (rsync
controller->remote by design), ``template``/``unarchive`` (no role uses a
clone-relative src there — re-check by hand when adding one).

Usage: scripts/check-remote-src.py [collection-glob ...]
Exits non-zero (1) on findings, 2 on unparseable task files.
"""
import glob
import os
import re
import sys

import yaml

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANSIBLE_ROOT = os.path.dirname(REPO_ROOT)

COPY_KEYS = ("ansible.builtin.copy", "copy")
CONTROLLER_SIDE_VARS = {"backup_source", "backup_ssh_source"}
VAR_RE = re.compile(r"\{\{\s*([a-zA-Z_][a-zA-Z0-9_]*)")
LOOP_REF_RE = re.compile(r"\{\{\s*[a-zA-Z_][a-zA-Z0-9_]*\.")


def load_defaults(role_dir):
    path = os.path.join(role_dir, "defaults", "main.yml")
    if not os.path.isfile(path):
        return {}
    try:
        data = yaml.safe_load(open(path)) or {}
    except yaml.YAMLError:
        return {}
    return data if isinstance(data, dict) else {}


def iter_tasks(node):
    if isinstance(node, list):
        for item in node:
            yield from iter_tasks(item)
    elif isinstance(node, dict):
        if any(k in node for k in COPY_KEYS):
            yield node
        for value in node.values():
            yield from iter_tasks(value)


def check_role(role_dir):
    findings, broken = [], []
    defaults = load_defaults(role_dir)
    tasks_files = sorted(
        glob.glob(os.path.join(role_dir, "tasks", "**", "*.yml"), recursive=True))
    for tf in tasks_files:
        try:
            docs = list(yaml.safe_load_all(open(tf)))
        except yaml.YAMLError as exc:
            broken.append((tf, str(exc).splitlines()[0]))
            continue
        for doc in docs:
            for task in iter_tasks(doc):
                for key in COPY_KEYS:
                    block = task.get(key)
                    if not isinstance(block, dict):
                        continue
                    src = block.get("src")
                    if not isinstance(src, str) or "{{" not in src:
                        continue
                    if "role_path" in src or block.get("remote_src"):
                        continue
                    if LOOP_REF_RE.search(src):
                        continue  # loop/fact reference — existing user file
                    match = VAR_RE.search(src)
                    if not match:
                        continue
                    var = match.group(1)
                    if var in CONTROLLER_SIDE_VARS:
                        continue
                    default = defaults.get(var)
                    if isinstance(default, str) and "role_path" in default:
                        continue  # collection-embedded file
                    findings.append(
                        (os.path.relpath(tf, ANSIBLE_ROOT),
                         str(task.get("name", "(unnamed)")),
                         src.strip()))
    return findings, broken


def main():
    patterns = sys.argv[1:] or ["odem-*"]
    roles = []
    for pattern in patterns:
        for col in sorted(glob.glob(os.path.join(ANSIBLE_ROOT, pattern))):
            roles += sorted(glob.glob(os.path.join(col, "roles", "*")))
    roles = [r for r in roles if os.path.isdir(r)]
    if not roles:
        print(f"no roles matched: {patterns}")
        return 1

    findings, broken = [], []
    for role in roles:
        f, b = check_role(role)
        findings += f
        broken += b

    for path, err in broken:
        print(f"UNPARSEABLE {path}: {err}")
    for path, name, src in findings:
        print(f"MISSING remote_src: {path} :: {name} :: src={src}")

    checked = len(roles)
    if findings or broken:
        print(f"\n{checked} roles checked — {len(findings)} finding(s), "
              f"{len(broken)} unparseable file(s)")
        return 1 if findings else 2
    print(f"clean — {checked} roles checked, every clone-relative copy "
          "carries remote_src")
    return 0


if __name__ == "__main__":
    sys.exit(main())
