#!/usr/bin/env bash
#
# Hyprland + Quickshell rice — installer for Arch Linux.
#
#   ./install.sh                      packages + AUR + configs + services
#   ./install.sh --dry-run            print every command, change nothing
#   ./install.sh --copy               copy configs instead of symlinking
#   ./install.sh --no-packages        only place the configs
#   ./install.sh --with-wallpapers    also sparse-clone the wallpaper collection
#   ./install.sh --force-distro       proceed on a non-Arch system (for testing)
#
# Safe to re-run: package installs are --needed and existing configs are backed
# up with a timestamp rather than overwritten.

set -euo pipefail

# ───────────────────────────────────────────────────────────────── flags
DRY_RUN=0 COPY=0 DO_PKG=1 WITH_WALLPAPERS=0 FORCE_DISTRO=0
for arg in "$@"; do
    case "$arg" in
        --dry-run)         DRY_RUN=1 ;;
        --copy)            COPY=1 ;;
        --no-packages)     DO_PKG=0 ;;
        --with-wallpapers) WITH_WALLPAPERS=1 ;;
        --force-distro)    FORCE_DISTRO=1 ;;
        -h|--help)         awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;;
        *) echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
    esac
done

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S)"

say()  { printf '\n\033[1;32m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m warn:\033[0m %s\n' "$*"; }
# act: report a step; under --dry-run it says so instead of claiming it happened
act() {
    if [[ $DRY_RUN -eq 1 ]]; then printf '  [dry-run] would %s\n' "$*"
    else printf '  %s\n' "$*"; fi
}
# run: execute, or print under --dry-run
run() {
    if [[ $DRY_RUN -eq 1 ]]; then printf '  [dry-run] %s\n' "$*"; else "$@"; fi
}

# ─────────────────────────────────────────────────────────────── distro check
if [[ ! -f /etc/os-release ]]; then
    warn "/etc/os-release missing — cannot identify this system"
elif ! grep -qiE '^(ID|ID_LIKE)=.*arch' /etc/os-release && [[ $FORCE_DISTRO -eq 0 ]]; then
    say "This is not an Arch system"
    grep -E '^(NAME|ID|ID_LIKE)=' /etc/os-release | sed 's/^/  /'
    cat <<'EOF'

  install.sh drives pacman, makepkg and systemctl for an Arch session. On
  anything else, run it with --dry-run to see the plan without touching the
  system, or --force-distro if you know what you are doing.
EOF
    exit 1
fi

say "Installing the rice from $REPO"
[[ $DRY_RUN -eq 1 ]] && warn "DRY RUN — nothing will actually change"

# ───────────────────────────────────────────────────────────── 1. packages
# All names verified to exist in core/extra; AUR packages are handled later.
PACMAN_PKGS=(
    # compositor + shell
    hyprland quickshell
    # session plumbing
    networkmanager network-manager-applet nm-connection-editor
    pipewire wireplumber
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    hyprpolkitagent plasma-integration
    # display manager
    ly
    # everything the configs launch or shell out to
    dunst kitty nautilus obsidian
    playerctl brightnessctl
    hyprshot grim slurp wl-clipboard
    ttf-jetbrains-mono
    # build tooling (needed if we have to bootstrap the AUR helper)
    base-devel git
)
# AUR: zen-browser-bin installs /usr/bin/zen-browser, which SUPER+SHIFT+RETURN calls.
AUR_PKGS=(zen-browser-bin spotify spicetify-cli)

if [[ $DO_PKG -eq 1 ]]; then
    say "1/5  Repo packages"
    run sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

    say "2/5  AUR helper"
    if command -v paru >/dev/null 2>&1; then
        AUR_HELPER=paru
        echo "  paru already installed"
    elif command -v yay >/dev/null 2>&1; then
        AUR_HELPER=yay
        echo "  yay already installed"
    else
        echo "  building paru-bin from the AUR (makepkg refuses to run as root)"
        AUR_HELPER=paru
        build_dir="$(mktemp -d)"
        run git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$build_dir/paru-bin"
        if [[ $DRY_RUN -eq 1 ]]; then
            printf '  [dry-run] (cd %s/paru-bin && makepkg -si --noconfirm)\n' "$build_dir"
        else
            ( cd "$build_dir/paru-bin" && makepkg -si --noconfirm )
        fi
        run rm -rf "$build_dir"
    fi

    say "3/5  AUR packages"
    run "$AUR_HELPER" -S --needed --noconfirm "${AUR_PKGS[@]}"
else
    say "1-3/5  packages skipped (--no-packages)"
fi

# ───────────────────────────────────────────────────────────── 2. services
say "4/5  Services"
# NetworkManager owns the WiFi that the bar's panel drives over nmcli.
run sudo systemctl enable --now NetworkManager
run sudo systemctl enable ly.service
echo  "        if another login manager is active, disable it:"
echo  "        sudo systemctl disable gdm.service sddm.service lightdm.service 2>/dev/null"

# ──────────────────────────────────────────────────────────── 3. wallpaper
say "5/5  Configs"
if [[ $WITH_WALLPAPERS -eq 1 ]]; then
    # The rice ships its own wallpaper, so this is optional. --filter=blob:none
    # plus sparse-checkout avoids pulling the whole ~3 GB collection.
    if [[ -d "$HOME/gruvbox-wallpapers/.git" ]]; then
        echo "  ~/gruvbox-wallpapers already cloned"
    else
        echo "  sparse-cloning the wallpaper collection (only wallpapers/mix)"
        run git clone --depth 1 --filter=blob:none --sparse \
            https://github.com/AngelJumbo/gruvbox-wallpapers "$HOME/gruvbox-wallpapers"
        run git -C "$HOME/gruvbox-wallpapers" sparse-checkout set wallpapers/mix
    fi
fi

for dir in hypr quickshell; do
    src="$REPO/$dir"
    dst="$CFG/$dir"
    [[ -d "$src" ]] || { warn "$src is missing — skipped"; continue; }

    if [[ -L "$dst" ]]; then
        act "replace the symlink $dst"
        run rm "$dst"
    elif [[ -e "$dst" ]]; then
        act "back up $dst -> $dst.bak-$STAMP"
        run mv "$dst" "$dst.bak-$STAMP"
    fi

    if [[ $COPY -eq 1 ]]; then
        run cp -r "$src" "$dst"
        act "copy $src -> $dst"
    else
        run ln -s "$src" "$dst"
        act "link $dst -> $src"
    fi
done

# ─────────────────────────────────────────────────────────────── 4. checks
say "Post-install checks"
check() { # check <label> <command>
    local label="$1" cmd="$2"
    if command -v "$cmd" >/dev/null 2>&1; then printf '  \033[1;32mok\033[0m      %s\n' "$label"
    else printf '  \033[1;33mMISSING\033[0m %s\n' "$label"; fi
}
check "compositor (Hyprland)"        Hyprland
check "shell (quickshell)"           quickshell
check "terminal (kitty)"             kitty
check "browser (zen-browser)"        zen-browser
check "notifications (dunst)"        dunst
check "wifi (nmcli)"                 nmcli
check "audio (wpctl)"                wpctl
check "screenshots (hyprshot)"       hyprshot
check "portal for Hyprland"          xdg-desktop-portal-hyprland
check "polkit agent"                 hyprpolkitagent
check "Hermes desktop (SUPER + A)"   hermes-desktop

if [[ $DRY_RUN -eq 0 && -f "$CFG/hypr/hyprland.lua" ]]; then
    printf '\n  validating the compositor config...\n'
    Hyprland --verify-config -c "$CFG/hypr/hyprland.lua" 2>&1 | tail -3 | sed 's/^/    /' || true
fi

cat <<'EOF'

Next:
  1. Log out, pick "Hyprland" at the ly prompt.
  2. SUPER + RETURN opens kitty; SUPER + SPACE is the launcher.
  3. The bar only exists while quickshell runs — check `pgrep quickshell` and
     restart it detached with `quickshell -d` if the session looks bare.
  4. SUPER + A needs hermes-desktop somewhere on PATH (it is not a package).
  5. Keyboard media/brightness keys use playerctl, wpctl and brightnessctl.

Not covered by this script:
  - a firewall, Bluetooth, printing, or a swap file
  - spicetify theming: run `spicetify apply` once after Spotify's first launch
  - the ~/gruvbox-wallpapers collection, unless you pass --with-wallpapers
EOF
