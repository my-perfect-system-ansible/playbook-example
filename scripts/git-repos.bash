# Shared sibling-repo list + clone-URL derivation for the git-* and
# publish scripts. Sourced by them; run directly to print the list.
#
# Repo root = the directory above this scripts/ folder; the REPOS paths are
# relative to it. odem-*/manage/playbook-example are siblings in the
# my-perfect-system-ansible org, the mps-* repos sit two levels up in
# my-perfect-system.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

REPOS=(
    ../manage
    ../../my-perfect-system/mps-container-docker
    ../../my-perfect-system/mps-desktop-kanata
    ../../my-perfect-system/mps-desktop-qtile
    ../../my-perfect-system/mps-desktop-rofi
    ../../my-perfect-system/mps-desktop-thunar
    ../../my-perfect-system/mps-desktop-trayhub
    ../../my-perfect-system/mps-services-monitoring
    ../../my-perfect-system/mps-services-openvpn
    ../../my-perfect-system/mps-terminal-bash
    ../../my-perfect-system/mps-terminal-bash-aliases
    ../../my-perfect-system/mps-terminal-fonts
    ../../my-perfect-system/mps-terminal-kitty
    ../../my-perfect-system/mps-terminal-nvim
    ../../my-perfect-system/mps-terminal-scripts
    ../../my-perfect-system/mps-terminal-skeletons
    ../../my-perfect-system/mps-terminal-tmux
    ../../my-perfect-system/mps-terminal-vim
    ../odem-os
    ../odem-terminal
    ../odem-development
    ../odem-desktop
    ../odem-hardening
    ../odem-backup
    ../odem-services
    ../odem-alloy
    ../playbook-example
)

# GitHub clone URL for a repo basename: mps-* lives in the
# my-perfect-system org, everything else in my-perfect-system-ansible.
repo_url() {
    case "$1" in
        mps-*) echo "https://github.com/my-perfect-system/$1.git" ;;
        *)    echo "https://github.com/my-perfect-system-ansible/$1.git" ;;
    esac
}

# Standalone: print the list + derived URLs.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    for repo in "${REPOS[@]}"; do
        name=$(basename "$repo")
        printf '%-28s %s\n' "$name" "$(repo_url "$name")"
    done
fi