#!/usr/bin/env bash
# List every role of every odem-* collection with its description.
# (Moved from manage/Justfile 2026-11-26.)
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/git.bash"
cd "$REPO_ROOT" || exit 1

for repo in "${COLLECTIONS[@]}"; do
    col_name=$(basename "$repo")
    echo "==> $col_name"
    for role_dir in "$repo/roles"/*/; do
        [ -d "$role_dir" ] || continue
        role_name=$(basename "$role_dir")
        meta="$role_dir/meta/main.yml"
        if [ -f "$meta" ]; then
            desc=$(python3 -c "import yaml,sys; d=yaml.safe_load(open('$meta')) or {}; print(d.get('galaxy_info',{}).get('description',''))" 2>/dev/null || echo "")
            printf "  %-22s %s\n" "$role_name" "$desc"
        else
            printf "  %-22s (no meta)\n" "$role_name"
        fi
    done
    echo
done