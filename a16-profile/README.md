# A16 Hyprland profile

A self-contained Hyprland + Quickshell desktop for the **GIGABYTE A16 CVH**
(Raptor Lake H, RTX 5060 Laptop, 16" 16:10 WQXGA panel, Intel Wi-Fi), built from
the configuration running on the Gentoo desktop (`10.0.0.37`), with the
A16-specific parts changed.

## What is in here

| Path | Installs to | What it is |
|---|---|---|
| `hypr/hyprland.lua` | `~/.config/hypr/` | Hyprland 0.57 Lua config: monitors scaled for the 16" panel, hybrid-GPU environment, all keybinds |
| `hypr/hypridle.conf` | `~/.config/hypr/` | idle policy (dim, lock; suspend left disabled) |
| `quickshell/shell.qml` | `~/.config/quickshell/` | the bar: workspaces, now-playing, Wi-Fi, weather, brightness, volume, mic, battery, GPU, update, devices, session menu, tray, clock |
| `local-bin/*` | `~/.local/bin/` | `weather.sh`, `wallpaper-picker.sh`, `wallpaper-rotate.sh`, `keybinds.py`, `devices.sh`, `now-playing.sh`, `power-menu.sh`, `screenshot.sh`, `mic-toggle.sh`, `gpu-switch.sh`, `portage-update.sh`, `tray-icon-resolve.sh` |
| `icons/gentoo-symbolic.svg` | `~/.local/share/icons/` | Gentoo signet used as the app-menu icon (official artwork, Gentoo Name and Logo Usage Guidelines apply) |
| `portage/package.use.cmus` | `/etc/portage/package.use/` | cmus USE flags |
| `portal/hyprland-portals.conf` | `~/.config/xdg-desktop-portal/` | **optional**: routes RemoteDesktop + ScreenCast to luminous, only for RustDesk's user-mode GUI |
| `rustdesk/rustdesk-wayland.md` | — | the two RustDesk-on-Hyprland fixes, with commands |
| `fprint/fprint-enable.sh` | `~/.local/bin/` | wires `pam_fprintd` into PAM once a finger is enrolled |

Run `./install.sh` as your desktop user; it installs everything and skips files
that already exist.

## Prerequisites (Gentoo)

```sh
emerge --ask \
  gui-wm/hyprland gui-apps/quickshell gui-apps/hypridle gui-apps/swww \
  x11-misc/grim x11-misc/slurp x11-misc/swappy gui-apps/wl-clipboard \
  x11-misc/rofi x11-misc/brightnessctl media-sound/pipewire media-video/wireplumber \
  gui-apps/mako sys-fs/udisks media-sound/cmus

# optional, for the device widget
emerge --ask dev-util/android-tools app-pda/libimobiledevice

# for the fingerprint reader (see fprint/)
emerge --ask sys-auth/fprintd
```

`cmus` uses the flags in `portage/package.use.cmus` — copy that file to
`/etc/portage/package.use/cmus` first. Note `wma` and `zsh-completion` are not
cmus USE flags; WMA decoding comes from `ffmpeg`, and the zsh completion is a
contrib script upstream.

Fonts/icons used by the bar come from the icon theme already assumed by
`shell.qml` (Adwaita symbolic names, resolved by absolute path at startup).

## A16-specific changes vs the desktop config

- **Monitor**: `eDP-1` at `preferred` mode and **scale 1.25** (2560x1600 on a 16"
  panel). Change to 1.0 if you prefer the full pixel area.
- **Hybrid graphics**: `LIBVA_DRIVER_NAME=iHD` (Intel VA-API), `NVD_BACKEND=direct`
  and `__GLX_VENDOR_LIBRARY_NAME=nvidia` for the NVIDIA Wayland path. Hyprland
  itself renders on the iGPU. There is no mux switch, so `gpu-switch.sh`
  (bar GPU chip, `SUPER+G`) is a PRIME-offload launcher and status view rather
  than a switcher.
- **Touchpad**: the Precision-specific device block is gone; the A16's i2c-hid
  touchpad uses the generic `input.touchpad` settings. Pin its exact name
  (`hyprctl devices`) if you want a per-device sensitivity.
- **Idle**: `hypridle.conf` does not suspend by default — a low-battery suspend
  is what repeatedly knocked the reference desktop off the network mid-build.

## Desktop features carried over

- Keybinds: `SUPER+Q`/`Return` terminal, `R` launcher, `W` wallpaper picker,
  `K` keybind search, `SUPER+H` full keybind list, `X` power menu,
  `L` lock, `M` mic, `G` GPU, `U` portage update, screenshots on `PRINT`,
  `SUPER+arrows` focus/swap, `SUPER+1..9` workspaces, media/brightness keys.
- Bar chips: playback (MPRIS: VLC/Spotify/Chromium/cmus-with-elogind; cmus
  fallback via `now-playing.sh`), attached devices (phones + removable drives,
  USB rows mount/unmount with `udisksctl`), session menu (lock/suspend/log
  out/reboot/shut down), weather (Louisville, KY in °F, 15-minute refresh).
- Wallpaper: swww rotation over `/usr/share/backgrounds` every 15 minutes,
  overridden by a pinned pick from `SUPER+W`.

## Verification checklist

1. Log in: the bar appears, no QML errors on stderr.
2. `weather.sh` prints `code|tempF|desc`; the chip shows a °F value.
3. `SUPER+W` picks a wallpaper and `swww query` confirms it.
4. `SUPER+H` lists every bind grouped with descriptions; `SUPER+K` searches them.
5. Play something in VLC or cmus; the playback chip appears and toggles on click.
6. Plug in a USB stick; the device chip appears and mounts it on click.
7. `rustdesk --version` is 1.5.3, `rc-service rustdesk status` is started, and
   the spawned `rustdesk --server` carries `WAYLAND_DISPLAY` and
   `DBUS_SESSION_BUS_ADDRESS` (`rustdesk/rustdesk-wayland.md`).

## Known gaps

- The four bar widgets, the Gentoo icon and the keybind list are verified on the
  reference desktop running this same `shell.qml` (screenshots taken there), but
  have not yet been run on an A16. Expect at most a monitor-scale tweak.
- `tray-icon-resolve.sh` is a portable rewrite: the reference desktop's copy maps Discord's blank pixmap to a Tela artwork file that only exists on that machine, whereas this one resolves the app icon from the active theme.
- `xdg-desktop-portal-luminous` is not packaged in Gentoo and is **not needed**
  when RustDesk runs as a root service: that path uses ScreenCast + uinput.
  Building it only matters for RustDesk's user-mode GUI, and then it also takes
  over ScreenCast for Discord/OBS — see `portal/hyprland-portals.conf`.
- RustDesk 1.5.3 is a Wayland-preview-generation build: capture and control work
  once the portal and service env are fixed, but login-screen/unattended access
  is only supported in RustDesk's Debian/Ubuntu preview build.
