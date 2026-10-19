#!/usr/bin/env bash
# Install this rice: link (or copy) hypr/ and quickshell/ into ~/.config.
# Default is symlink, so edits to the repo are live. Use --copy to place real files.
set -euo pipefail

MODE=link
[[ "${1:-}" == "--copy" ]] && MODE=copy

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S)"

for dir in hypr quickshell; do
    src="$REPO/$dir"
    dst="$CFG/$dir"

    if [[ -e "$dst" && ! -L "$dst" ]]; then
        backup="$dst.bak-$STAMP"
        echo "backing up existing $dst -> $backup"
        mv "$dst" "$backup"
    elif [[ -L "$dst" ]]; then
        echo "replacing existing symlink $dst"
        rm "$dst"
    fi

    if [[ "$MODE" == link ]]; then
        ln -s "$src" "$dst"
        echo "linked $dst -> $src"
    else
        cp -r "$src" "$dst"
        echo "copied $src -> $dst"
    fi
done

cat <<'EOF'

Done. Before logging into Hyprland, check that:
  - a polkit agent runs (polkit-kde-agent or hyprpolkitagent)
  - the gruvbox-wallpapers repo is cloned to ~/gruvbox-wallpapers
  - hermes-desktop is on PATH if you want SUPER + A
Validate the compositor config with:
  Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
EOF
