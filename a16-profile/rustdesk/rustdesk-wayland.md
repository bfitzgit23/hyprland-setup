# RustDesk on Hyprland: what actually breaks, and the fix

Verified on the Dell box, RustDesk 1.5.3, Hyprland 0.57.2,
`xdg-desktop-portal` 1.20.4.

## First: decide which code path you are on

RustDesk branches on `is_server_running()` (`src/server/wayland.rs`):

| How RustDesk runs | Portal interface | Input |
| --- | --- | --- |
| user GUI, no root service | `RemoteDesktop.CreateSession` | RemoteDesktop portal |
| **root service running** (`rustdesk --service`) | `ScreenCast.CreateSession` | **uinput** (kernel) |

An OpenRC host with `rc-service rustdesk start` is on the second row, so it
needs **ScreenCast** — which `xdg-desktop-portal-hyprland` implements — and
`/dev/uinput`, which the root service can open. `RemoteDesktop` is **not** on
that path, and installing a backend for it changes nothing.

That distinction is what the "RustDesk requires RemoteDesktop" advice online
(sensible for a user-mode GUI, e.g. Omarchy's) gets wrong for a service setup.

## The real fault: the user server starts with no session environment

`rustdesk --service` runs as root and spawns the per-user server itself:

```
sudo -E XDG_RUNTIME_DIR=/run/user/1001 -u bennji /usr/share/rustdesk/rustdesk --server
```

`XDG_RUNTIME_DIR` is the only variable it sets, so without more the child falls
back to the X11 clipboard (Hyprland forwards nothing) and stalls looking for the
display. `sudo -E` preserves the daemon's own environment, so the fix is to give
the daemon those variables. OpenRC sources `/etc/conf.d/rustdesk` before starting
it:

```sh
# /etc/conf.d/rustdesk
export WAYLAND_DISPLAY=wayland-1
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus
```

Check that it reached the child:

```sh
ps eww -eo pid,args | grep '[r]ustdesk --server' | tr ' ' '\n' \
  | grep -E '^(WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS)='
```

Both lines present means capture, clipboard and input all have a session to
attach to.

## Input injection needs a machine-readable uinput

Remote input goes through `/dev/uinput`, opened by the root service. There is a
known upstream bug (rustdesk#16580) where the *virtual keyboard* fails with
EACCES on `/dev/input/event*` while the mouse device is created fine. If the
mouse moves but typing does nothing:

```
# /etc/udev/rules.d/70-uinput-rustdesk.rules
KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
SUBSYSTEM=="input", KERNEL=="event*", GROUP="input", MODE="0660"
```

then `udevadm control --reload-rules && udevadm trigger`.

## If you deliberately want the user-mode path

Only then is `xdg-desktop-portal-luminous` relevant: build it with cargo
(`cargo build --release`, ~3.5 min, 488 crates), install the binary to
`/usr/libexec/`, add
`/usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.luminous.service`,
and route **both** interfaces to it — a RemoteDesktop session dispatches
`SelectSources` to the global ScreenCast implementation, so ScreenCast has to
follow:

```ini
# ~/.config/xdg-desktop-portal/hyprland-portals.conf
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.RemoteDesktop=luminous;hyprland;gtk
org.freedesktop.impl.portal.ScreenCast=luminous;hyprland;gtk
```

The frontend exports nothing for a bare `RemoteDesktop=` line while ScreenCast
still points elsewhere — that combination silently yields no interface at all.

## Verify

1. `rustdesk --version` → 1.5.3
2. `rc-service rustdesk status` → started
3. Child env carries `WAYLAND_DISPLAY` and `DBUS_SESSION_BUS_ADDRESS`
4. ScreenCast present:
   `gdbus introspect --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop | grep -c portal.ScreenCast`
5. Connect from another machine: picture, mouse, typing, then copy/paste
6. `~/.local/share/logs/RustDesk/*.log` should contain no
   `No such interface "org.freedesktop.portal.RemoteDesktop"`

Steps 1–4 are checked; 5–6 need a real remote session.
