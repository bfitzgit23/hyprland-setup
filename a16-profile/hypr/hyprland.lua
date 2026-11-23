-- Hyprland configuration (Lua API - Hyprland 0.57)
-- NOTE: this file is *executed*; settings only apply through hl.* calls.
-- Returning a Lua table does nothing.

-------------- ENVIRONMENT --------------
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "0")
-- Qt apps take their icons/colours from the GTK theme, which is where
-- Tela-dracula-dark is set. "kde" in /etc/environment has no plugin installed.
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("GTK_THEME", "adw-gtk3-dark")

-------------- MONITORS --------------
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-------------- LOOK AND FEEL --------------
hl.config({
    cursor = { sync_gsettings_theme = false, no_hardware_cursors = true, use_cpu_buffer = true, hide_on_touch = false, invisible = false },
    general = {
        gaps_in         = 5,
        gaps_out        = 10,
        border_size     = 2,
        layout          = "dwindle",
        resize_on_border = true,
        col = {
            active_border   = { colors = { "rgba(3584e4ee)", "rgba(62a0eaee)" }, angle = 45 },
            inactive_border = "rgba(383838aa)",
        },
    },
    decoration = {
        rounding         = 6,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = { enabled = true, range = 4, render_power = 3, color = 0xee1a1a1a },
        blur   = { enabled = true, size = 3, passes = 1 },
    },
    dwindle = { preserve_split = true },
    misc    = { disable_hyprland_logo = true, force_default_wallpaper = 0, focus_on_activate = true },
})

-------------- INPUT --------------
hl.config({
    input = {
        kb_layout    = "us",
        repeat_rate  = 35,
        repeat_delay = 250,
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll       = false,
            tap_to_click         = true,
            clickfinger_behavior = true,
            disable_while_typing = true,
            scroll_factor        = 1.0,
        },
    },
})

-- Dell Precision 7530 i2c-hid touchpad (name as normalised by Hyprland)
hl.device({ name = "dell0831:00-044e:1220-touchpad", sensitivity = 0.2 })

-- 3-finger horizontal swipe switches workspaces
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-------------- KEYBINDS --------------
local mainMod = "SUPER"

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())   -- was Super+M, handed to the mic toggle
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("rofi -show drun -show-icons"))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + N",         hl.dsp.window.move({ workspace = "special:min", follow = false }))  -- minimize
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.workspace.toggle_special("min"))                            -- show/restore minimized
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ action = "set", mode = 1 }))          -- maximize (keeps bar)
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("~/.local/bin/gpu-switch.sh"))
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd("kitty -e ~/.local/bin/portage-update.sh"))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("~/.local/bin/power-menu.sh"))
hl.bind(mainMod .. " + W",         hl.dsp.exec_cmd("~/.local/bin/wallpaper-picker.sh"))  -- choose wallpaper
hl.bind(mainMod .. " + K",         hl.dsp.exec_cmd("~/.local/bin/keybinds.py search"))     -- search keybinds
hl.bind(mainMod .. " + H",         hl.dsp.exec_cmd("~/.local/bin/keybinds.py sheet"))      -- full keybind list

-- Screenshots: grim captures on Wayland (flameshot cannot), swappy annotates.
hl.bind("PRINT",               hl.dsp.exec_cmd("~/.local/bin/screenshot.sh region annotate"))
hl.bind("SHIFT + PRINT",       hl.dsp.exec_cmd("~/.local/bin/screenshot.sh region clip"))
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("~/.local/bin/screenshot.sh output annotate"))
hl.bind(mainMod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("~/.local/bin/screenshot.sh full clip"))

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.swap({ direction = "down" }))

for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true, repeating = true })
hl.bind(mainMod .. " + M",           hl.dsp.exec_cmd("~/.local/bin/mic-toggle.sh"))             -- mic mute toggle

-------------- AUTOSTART --------------
hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell")
    hl.exec_cmd("mako")
    -- Nothing on Hyprland reads /etc/xdg/autostart, so the polkit agent has to be
    -- started by hand: enrolling a fingerprint (net.reactivated.fprint.device.enroll
    -- is auth_self_keep for active sessions) and most admin prompts need it.
    hl.exec_cmd("/usr/libexec/polkit-gnome-authentication-agent-1")
    -- The portal backend registers ScreenCast/RemoteDesktop only when it starts
    -- with the desktop identity; dbus activation from a bare environment left
    -- the bus without ScreenCast entirely. Start it in-session.
    hl.exec_cmd("/usr/libexec/xdg-desktop-portal-hyprland")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("pipewire")
    -- PulseAudio compatibility server. Bare PipeWire exposes the mic only to
    -- PW/ALSA/JACK clients; Firefox, Chromium, Electron and RustDesk speak the
    -- PA protocol, and without this daemon they see no input device at all.
    hl.exec_cmd("pipewire -c pipewire-pulse.conf")
    hl.exec_cmd("wireplumber")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("~/.local/bin/wallpaper-rotate.sh")
    -- Optional dotfiles pull at login, toggled from the bar's session menu
    -- (the toggle just creates or removes ~/.config/hypr/autoupdate).
    hl.exec_cmd("[ -e ~/.config/hypr/autoupdate ] && ~/.local/bin/hypr-update.sh --dots-only --quiet")
end)
