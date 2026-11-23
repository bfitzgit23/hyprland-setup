# hyprland-setup

My Hyprland desktop, kept in one place so either machine can be rebuilt from it:
a **Hyprland (hyprland.lua config) + Quickshell bar** session on Gentoo/OpenRC,
with the machine-specific bits split out.

Two machines, one kit:

| folder | what it is |
| --- | --- |
| `dell/` | a mirror snapshot pulled from the **Dell Precision 7530** (`wlp112s0`, BCM4352, RustDesk, fingerprint) — real filesystem layout, `home/`, `etc/`, `usr/`, `var/` |
| `a16-profile/` | the hand-written **GIGABYTE A16** profile — `hypr/`, `quickshell/`, `local-bin/`, `icons/`, `portage/`, optional portal config |

## Scripts

**`pull.sh` / `pull_dell.py`** — take a fresh snapshot of the Dell into `dell/`
(needs `python3` + `paramiko`, password taken from `DELL_PW` or prompted):

```sh
python pull_dell.py            # -> dell/ and dell-snapshot.tar.gz
```

**`restore.sh`** — install a profile onto a machine. Run as root; existing files are
kept as `<name>.bak-<timestamp>`, nothing is deleted:

```sh
./restore.sh dell --dry-run    # show the plan, change nothing
./restore.sh dell              # root tree + dotfiles + service list
./restore.sh a16 --user bennji --packages
```

`dell` maps `dell/home/<user>` onto the target home and `dell/{etc,usr,var}` onto `/`;
`a16` maps `hypr/`, `quickshell/`, `local-bin/`, `icons/` into `~/.config` and
`~/.local`. Package lists are only emerged with `--packages`.

**`hypr-update.sh`** — update the stack and the dotfiles, then reload:

```sh
hypr-update.sh                 # emerge the Hyprland atoms + pull dotfiles + reload
hypr-update.sh --check         # report what is behind, change nothing
hypr-update.sh --dots-only     # dotfiles only, no root
hypr-update.sh --system-only
hypr-update.sh --quiet         # log to ~/.local/state/hypr-update/last.log
```

It clones or fast-forwards this repo into `~/.local/share/hyprland-setup`, picks
the profile from `hostname` (`dell` or `a16`, override with `HYPR_PROFILE`), copies
only the files that differ into `~/.config/{hypr,quickshell}` and `~/.local/bin`,
then `hyprctl reload` + restarts quickshell. Emerge runs under `sudo`, so the
system part needs a terminal — the bar opens `kitty` for it.

**`protonvpn-enable.sh` / `protonvpn-toggle.sh`** — Proton VPN:

```sh
protonvpn-enable.sh            # prompt for email + password, store them (0600)
protonvpn-enable.sh --show     # report what is stored, never the secret
protonvpn-enable.sh --forget   # delete the stored account
protonvpn-toggle.sh            # connect if down, disconnect if up
protonvpn-toggle.sh status     # "on <iface>" or "off"
```

Packaging caveat on this machine: `guru`'s Proton set is internally inconsistent
(app 4.17.1 + api-core 4.19.1 — the app imports `proton.vpn.core.vpnconnector`,
which 4.19 dropped; app 4.19.1 + api-core 5.8.11 then need
`proton.vpn.platform`, which no installed package ships). Local overlay copies
of `net-vpn/proton-vpn-gtk-app-4.19.1` and `dev-python/proton-vpn-api-core-5.8.11`
are in `dell/var/db/repos/bennji-overlay/`; the GUI will start working once
`proton-vpn-network-manager` is bumped to the release that carries
`proton.vpn.platform`. Until then the tunnel is driven through NetworkManager:
import a Proton WireGuard/OpenVPN config (`nmcli connection import type openvpn
file x.ovpn`) and the chip + toggle pick it up.

Credentials live in `~/.config/protonvpn/credentials` and are **gitignored**
(`*credentials*`, `protonvpn/`) — the repo ships the scripts, never the account.
Client: `net-vpn/proton-vpn-gtk-app` from `guru` (`~amd64`, so a
`package.accept_keywords` line is needed), plus its Proton Python/Rust deps. The
app keeps the session in the keyring, so the first sign-in is done once in the
app; after that the toggle works headless. A NetworkManager VPN profile (an
imported `.ovpn`) also drives the same toggle.

## The bar toggle

The bar's session menu (power icon, far right) has:

- **Update Hyprland + dots** — opens kitty running `hypr-update.sh`
- **Auto-update on login** — a switch that creates/removes `~/.config/hypr/autoupdate`

`hyprland.lua` runs `hypr-update.sh --dots-only --quiet` at login only when that
marker exists, so the toggle is off by default and costs nothing when off.

## Installed packages the kit assumes

`gui-wm/hyprland`, `gui-libs/hyprutils`, `gui-apps/hypridle`, `gui-apps/hyprlock`,
`gui-libs/xdg-desktop-portal-hyprland`, `gui-apps/quickshell` (live ebuild),
plus `gui-apps/kitty`, `hyprlock`, `mako`, `matugen`-free wallpaper rotation and
`~/.local/bin/*` helpers (`weather.sh`, `keybinds.py`, `mic-toggle.sh`,
`power-menu.sh`, `hypr-update.sh`, …). `a16-profile/packages.list` is the full list.

## Things that needed a real fix (so they are not re-broken)

- **Suspend from the bar did nothing.** LightDM registers the session against
  `tty2` while the foreground VT is `tty8`, so elogind reports `Active=no` and
  polkit demands authentication for `org.freedesktop.login1.suspend`
  (`allow_active=yes`, `allow_inactive=auth_admin_keep`). A bar button cannot
  answer a prompt, so no suspend request ever reached the kernel.
  `etc/polkit-1/rules.d/49-desktop-power.rules` allows `wheel` to
  suspend/hibernate/reboot/power off without a prompt. Verified with
  `pkcheck --action-id org.freedesktop.login1.suspend --process <quickshell pid>`
  (rc 0 after the rule, "Authorization requires authentication" before) and
  `busctl call … CanSuspend` → `yes`.
- **BCM4352 Wi-Fi flapping.** `bcma-pci-bridge` binds before `wl`, so the first
  minutes of a session are unstable. `modprobe.d/20-broadcom-sta.conf` stubs
  `bcma ssb b43 brcmsmac` to `/bin/true` and `wl.conf` adds `options wl nompc=1`.
  The 5 GHz internal radio is the default; the USB dongle has `autoconnect no`.
- **RustDesk with no screen in service mode.** The service child needs the session
  environment (`WAYLAND_DISPLAY`, `DBUS_SESSION_BUS_ADDRESS`, `XDG_RUNTIME_DIR`)
  in `/etc/conf.d/rustdesk`; `RemoteDesktop`/luminous is not needed in that mode.
- **Hyprland "launched without start-hyprland" warning.**
  `/usr/local/bin/start-hyprland-wayland` (LightDM's `Xsession`) now `exec`s
  `/usr/bin/start-hyprland`.

## Still manual after a restore

- reboot once so the `modprobe.d` changes apply
- `fprintd-enroll` in an active session, then `fprint-enable.sh`
- `rc-service rustdesk start`
- log out and back in so LightDM picks up the session wrapper
