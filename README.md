# Hyprland + Quickshell rice (Arch-ready)

Narla's Hyprland session (`hyprland.lua`, Hyprland **0.56**) and the Quickshell bar/shell,
ported from NixOS to run on Arch Linux.

- **Compositor:** Hyprland 0.56, Lua config format (`hl.*` API, 0.55+)
- **Shell/chrome:** Quickshell 0.3.x — wallpaper layer, top bar, launcher, wifi/audio panels, system menu
- **Theme:** Omarchy Miasma (`bg #222222`, `fg #c2c2b0`, accent `#78824b`, cursor `#d7c483`)

Hyprland owns windows/tiling/binds and nothing visual; Quickshell draws *all* chrome as layer
surfaces. They talk through exactly one channel: `quickshell ipc call <target> <fn>` from a bind,
matching an `IpcHandler` target in `quickshell/shell.qml`.

## Install

```bash
./install.sh          # symlinks hypr/ and quickshell/ into ~/.config (backs up what's there)
./install.sh --copy   # copy instead of symlink
```

Packages (everything below is in `extra`/`core` — no AUR needed except the two browser/music ones):

```bash
# AUR helper first (Arch ships neither) — or build these two by hand
sudo pacman -S --needed base-devel git && git clone https://aur.archlinux.org/paru-bin.git && (cd paru-bin && makepkg -si)

sudo pacman -S --needed \
  hyprland quickshell dunst kitty nautilus obsidian \
  networkmanager network-manager-applet nm-connection-editor \
  pipewire wireplumber playerctl brightnessctl \
  hyprshot grim slurp wl-clipboard \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  polkit-kde-agent plasma-integration ttf-jetbrains-mono ly

paru -S zen-browser-bin spotify spicetify-cli
```

| Config needs | Package | Why |
|---|---|---|
| `hyprland` | `hyprland` | 0.56.2 in `extra`; Lua config works |
| `quickshell` | `quickshell` | 0.3.2 in `extra` (config was written against 0.3.1 — compatible) |
| autostarted `dunst` | `dunst` | owns `org.freedesktop.Notifications` |
| `zen-browser` bind | `zen-browser-bin` (**AUR**) | installs `/usr/bin/zen-browser` |
| `spotify` bind | `spotify` (**AUR**) | |
| `nautilus`, `obsidian`, `kitty` binds | `nautilus`, `obsidian`, `kitty` | |
| wifi panel + `nm-connection-editor` rule | `networkmanager`, `network-manager-applet` | `nmcli` |
| audio panel + media keys | `pipewire`, `wireplumber` | `wpctl` |
| `playerctl`, `brightnessctl` | same names | media / brightness keys |
| `PRINT` → `hyprshot -m region` | `hyprshot`, `grim`, `slurp`, `wl-clipboard` | hyprshot needs all three for region-to-clipboard |
| bar font | `ttf-jetbrains-mono` | `Miasma.qml` → `JetBrains Mono` |
| `QT_QPA_PLATFORMTHEME=kde` | `plasma-integration` | otherwise Qt silently drops the theme |
| `xdg-desktop-portal*` | both portal packages | file pickers, screen share |
| wallpaper | clone of [gruvbox-wallpapers](https://github.com/AngelJumbo/gruvbox-wallpapers) at `~/gruvbox-wallpapers` | `Wallpaper.qml` reads `~/gruvbox-wallpapers/wallpapers/mix/rockman.png` |
| `SUPER + A` | `hermes-desktop` on `PATH` | not a package; install Hermes desktop wherever you like |

Also: a **polkit agent** must be running for anything that asks for a password in a GUI, and the
session must be told it is Wayland — see the `dbus-update-activation-environment` line in
`hypr/hyprland.lua`.

## What was changed for Arch

The live NixOS configs were **not** touched; these edits exist only in this repo. Everything else is
byte-identical, so the theme, binds, animations and window rules are exactly as on the NixOS box.

| File | NixOS | Arch | Why |
|---|---|---|---|
| `hypr/hyprland.lua` | `hl.env("NIXOS_OZONE_WL", "1")` | `hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")` | `NIXOS_OZONE_WL` is a NixOS-only name; Electron/Chromium ignore it elsewhere |
| `hypr/hyprland.lua` | *(nothing set the session vars)* | `XDG_CURRENT_DESKTOP=Hyprland`, `XDG_SESSION_TYPE=wayland` | NixOS's desktop module exported these; on Arch nothing does |
| `hypr/hyprland.lua` | *(NixOS set up D-Bus activation)* | `dbus-update-activation-environment --systemd …` on start | portals/screen-share/file-pickers need the session env in the user manager |
| `hypr/hyprland.lua` | `exec_cmd("zen")` | `exec_cmd("zen-browser")` | AUR `zen-browser-bin` installs `/usr/bin/zen-browser` — `zen` does not exist |
| `hypr/hyprland.lua` | `$HOME/.nix-profile/bin/hermes-desktop` | `hermes-desktop` | no `~/.nix-profile` on Arch; resolves from `PATH` |
| `quickshell/Wallpaper.qml` | `file:///home/narla/gruvbox-wallpapers/…` | `"file://" + Quickshell.env("HOME") + "/gruvbox-wallpapers/…"` | hardcoded username; this survives a different $HOME |
| `hypr/legacy-hyprland.conf` | `$HOME/.nix-profile/bin/hermes-desktop`, `zen` | `hermes-desktop`, `zen-browser` | same two fixes in the hyprlang fallback |

`hypr/legacy-hyprland.conf` is the old hyprlang config, kept only as a fallback for Hyprland
**< 0.55**. On 0.56 it is ignored entirely — `hyprland.lua` wins. Arch ships 0.56.2, so the Lua file
is what runs. (Renamed from `hyprland.conf.bak` so nobody mistakes it for the active config.)

## Verified

- `Hyprland --verify-config -c hypr/hyprland.lua` → **`config ok`** (real Hyprland 0.56 binary)
- `qmllint` over all 8 QML files → **exit 0**, no syntax errors
- every package name above checked against the official repo and AUR APIs

Not verified: an actual Arch session. The config was validated against Hyprland 0.56 /
Quickshell 0.3.1 here, and Arch ships 0.56.2 / 0.3.2 — same 0.5x line, but the pixels on Arch
are untested.

## Keybinds

| Bind | Action |
|---|---|
| `SUPER + RETURN` | kitty |
| `SUPER + SHIFT + RETURN` | zen-browser |
| `SUPER + SHIFT + F` | nautilus |
| `SUPER + SHIFT + O` | obsidian |
| `SUPER + SHIFT + S` | spotify |
| `SUPER + A` | hermes-desktop |
| `SUPER + SPACE` | launcher (`quickshell ipc call launcher toggle`) |
| `SUPER + ESCAPE` | system menu |
| `SUPER + W` / `F` / `V` | kill / fullscreen / float |
| `SUPER + 1..5`, `+SHIFT` | switch workspace / move window there |
| `SUPER + arrows`, `+SHIFT + arrows` | focus / move + raise |
| `SUPER + LMB/RMB drag` | move / resize window |
| media + `XF86MonBrightness*` | playerctl / wpctl / brightnessctl |
| `PRINT` | `hyprshot -m region --clipboard-only` |

## Notes

- The monitor line is pinned to `HDMI-A-1` at `1920x1080@60`, scale 1 (Dell P2214H). If your
  connector or mode differs, `hyprctl monitors all` first — `hl.monitor({...})` with the wrong
  output silently does nothing.
- Only workspace changes and window *movement* animate; everything else is deliberately instant.
  Hyprland animation `speed` is inverse-intuitive here — lower is faster.
- The bar reserves its height with `exclusiveZone = barHeight`; `Miasma.qml` holds the palette and
  `barHeight` (30).
- QML edits reload the running shell instantly — stage a file outside `~/.config/quickshell`,
  validate, then move it in, or your desktop repaints mid-edit.
