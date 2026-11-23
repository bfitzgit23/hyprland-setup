//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

ShellRoot {
    // Monochrome bar icon. Adwaita ships these as black-on-transparent symbolic
    // SVGs and Quickshell 0.3.2's IconImage cannot recolour, so the black is
    // lifted to white (brightness) and then tinted (colorization); without that
    // the icons are invisible against the dark bar.
    component BarIcon: Item {
        id: barIcon
        property string iconName: ""
        property string iconSource: ""
        property color tint: "#ffffff"
        property int iconSize: 16
        implicitWidth: iconSize
        implicitHeight: iconSize
        Image {
            id: iconSource
            anchors.fill: parent
            source: barIcon.iconSource !== ""
                    ? barIcon.iconSource
                    : (bar.iconFiles[barIcon.iconName] !== undefined
                       ? bar.iconFiles[barIcon.iconName]
                       : Quickshell.iconPath(barIcon.iconName))
            sourceSize.width: barIcon.iconSize
            sourceSize.height: barIcon.iconSize
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        MultiEffect {
            anchors.fill: parent
            source: iconSource
            visible: iconSource.status === Image.Ready
            brightness: 1.0
            colorization: 1.0
            colorizationColor: barIcon.tint
        }
    }

    PanelWindow {
        id: bar
        anchors { top: true; left: true; right: true }
        implicitHeight: 36
        color: "#1e1e1e"

        property string batText: "BAT --%"
        property string wifiText: "Wi-Fi: --"
        property string volText: "Vol: --%"
        property string briText: "Bri: --%"
        property string profText: "BAL"
        property string batIcon: "battery-good-symbolic"
        property bool micMuted: false
        // Now playing: MPRIS when VLC/Spotify/Chromium (or cmus built with
        // elogind) publishes it, otherwise now-playing.sh polls cmus-remote.
        property string npText: ""
        property bool npPlaying: false
        property var npPlayer: null
        // Attached devices: one "kind|a|b|c|d" record each, see devices.sh.
        property var devLines: []
        property int devCount: 0
        property string wxText: "--°F"
        property string wxIcon: "weather-clear-symbolic"
        property string wxDesc: ""

        // wttr.in reports a WWO weather code; fold it onto the Adwaita symbolic
        // set the bar already uses, so the chip stays monochrome-tinted.
        function wxIconFor(code) {
            if (code === 113) return "weather-clear-symbolic"
            if (code === 116) return "weather-few-clouds-symbolic"
            if (code === 119 || code === 122) return "weather-overcast-symbolic"
            if (code === 143 || code === 248 || code === 260) return "weather-fog-symbolic"
            if ([200, 386, 389, 392, 395].indexOf(code) >= 0) return "weather-storm-symbolic"
            if ([179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320, 323, 326, 329,
                 332, 335, 338, 350, 362, 365, 368, 371, 374, 377].indexOf(code) >= 0)
                return "weather-snow-symbolic"
            return "weather-showers-symbolic"
        }

        function refreshNowPlaying() {
            let players = Mpris.players.values
            let active = null
            for (let i = 0; i < players.length; i++)
                if (players[i].isPlaying) { active = players[i]; break }
            if (active === null)
                for (let i = 0; i < players.length; i++)
                    if (players[i].trackTitle !== "") { active = players[i]; break }

            if (active !== null) {
                bar.npPlayer = active
                bar.npPlaying = active.isPlaying
                let artist = active.trackArtist ? active.trackArtist + " — " : ""
                bar.npText = artist + active.trackTitle
            } else {
                bar.npPlayer = null
                cmusProc.running = true   // sets or clears npText itself
            }
        }

        function togglePlayback() {
            if (bar.npPlayer !== null) bar.npPlayer.togglePlaying()
            else Quickshell.execDetached(["cmus-remote", "-u"])
        }

        function skipPlayback(step) {
            if (bar.npPlayer !== null) {
                if (step > 0) bar.npPlayer.next(); else bar.npPlayer.previous()
            } else {
                Quickshell.execDetached(["cmus-remote", step > 0 ? "-n" : "-r"])
            }
        }

        // Quickshell's icon provider returns a broken-image placeholder for a
        // handful of Adwaita symbolic icons (network-wireless, view-refresh,
        // view-app-grid, ...), while Qt renders those same SVGs correctly from
        // an absolute path. So the files are resolved once at startup in the
        // current icon theme and the provider is kept only as a fallback.
        property var iconFiles: ({})
        readonly property var iconNames: [
            "view-app-grid-symbolic",
            "network-wireless-symbolic",
            "display-brightness-symbolic",
            "audio-volume-high-symbolic",
            "audio-input-microphone-symbolic",
            "microphone-sensitivity-muted-symbolic",
            "video-display-symbolic",
            "view-refresh-symbolic",
            "battery-full-symbolic",
            "battery-good-symbolic",
            "battery-low-symbolic",
            "battery-caution-symbolic",
            "weather-clear-symbolic",
            "weather-few-clouds-symbolic",
            "weather-overcast-symbolic",
            "weather-showers-symbolic",
            "weather-snow-symbolic",
            "weather-storm-symbolic",
            "weather-fog-symbolic",
            "media-playback-start-symbolic",
            "media-playback-pause-symbolic",
            "phone-symbolic",
            "drive-harddisk-usb-symbolic",
            "system-shutdown-symbolic"
        ]

        Process {
            id: iconResolver
            command: ["bash", "-c",
                "T=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d \"'\"); " +
                "T=${T:-Adwaita}; " +
                "for n in " + bar.iconNames.join(" ") + "; do " +
                "p=$(find -L /usr/share/icons/$T /usr/share/icons/hicolor -name \"$n.svg\" -print -quit 2>/dev/null); " +
                "printf '%s\\t%s\\n' \"$n\" \"$p\"; done"]
            stdout: SplitParser {
                onRead: data => {
                    let parts = data.trim().split("\t");
                    if (parts.length === 2 && parts[1] !== "") {
                        let map = Object.assign({}, bar.iconFiles);
                        map[parts[0]] = "file://" + parts[1];
                        bar.iconFiles = map;
                    }
                }
            }
        }

        Process {
            id: statusProc
            command: ["bash", "-c",
                "BAT=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1); " +
                "STAT=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1); " +
                "SSID=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; exit}'); " +
                "VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{printf \"%d%%\", $2*100}'); " +
                "BRI=$(brightnessctl -m 2>/dev/null | awk -F, '{print $4}'); " +
                "PROF=$(powerprofilesctl get 2>/dev/null | cut -c1-4); " +
                "MIC=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED && echo muted || echo live); " +
                "echo \"${BAT:-AC}% (${STAT:-N/A})|${SSID:-Offline}|${VOL:-0%}|${BRI:-100%}|${PROF:-bal}|${MIC:-live}\""
            ]
            stdout: SplitParser {
                onRead: data => {
                    let parts = data.trim().split("|");
                    if (parts.length === 6) {
                        bar.batText = "BAT " + parts[0];
                        let pct = parseInt(parts[0], 10);
                        bar.batIcon = isNaN(pct) ? "battery-good-symbolic"
                                    : pct >= 90 ? "battery-full-symbolic"
                                    : pct >= 40 ? "battery-good-symbolic"
                                    : pct >= 15 ? "battery-low-symbolic"
                                    : "battery-caution-symbolic";
                        bar.wifiText = "Wi-Fi: " + parts[1];
                        bar.volText = "Vol: " + parts[2];
                        bar.briText = "Bri: " + parts[3];
                        bar.profText = parts[4].toUpperCase();
                        bar.micMuted = parts[5] === "muted";
                    }
                }
            }
        }

        Process {
            id: weatherProc
            // Run through bash so a missing exec bit cannot turn the chip into
            // a permanent placeholder: the timer only retries every 15 minutes.
            command: ["bash", "-c", "bash \"$HOME/.local/bin/weather.sh\""]
            stdout: SplitParser {
                onRead: data => {
                    let parts = data.trim().split("|");
                    if (parts.length < 2) return;
                    bar.wxText = parts[1] + "°F";
                    bar.wxIcon = bar.wxIconFor(parseInt(parts[0], 10));
                    bar.wxDesc = parts.length > 2 ? parts[2] : "";
                }
            }
        }

        // wttr.in is polled every 15 minutes: conditions do not change faster
        // than that, and each call is a real HTTP request.
        Timer {
            interval: 900000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: weatherProc.running = true
        }

        Process {
            id: cmusProc
            command: ["bash", Quickshell.env("HOME") + "/.local/bin/now-playing.sh"]
            stdout: SplitParser {
                onRead: data => {
                    if (bar.npPlayer !== null) return
                    let parts = data.trim().split("|");
                    if (parts.length < 3 || parts[0] === "" || parts[0] === "stopped") {
                        bar.npText = "";
                        return;
                    }
                    bar.npText = (parts[1] !== "" ? parts[1] + " — " : "") + parts[2];
                    bar.npPlaying = (parts[0] === "playing");
                }
            }
        }

        Process {
            id: devicesProc
            command: ["bash", Quickshell.env("HOME") + "/.local/bin/devices.sh"]
            stdout: SplitParser {
                onRead: data => {
                    let line = data.trim();
                    if (line === "") return;
                    let next = bar.devLines.slice();
                    next.push(line);
                    bar.devLines = next;
                    bar.devCount = next.length;
                }
            }
        }

        Timer {
            interval: 3000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: bar.refreshNowPlaying()
        }

        Timer {
            interval: 6000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: { bar.devLines = []; bar.devCount = 0; devicesProc.running = true }
        }

        Timer {
            interval: 2000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: statusProc.running = true
        }

        Timer { id: micRefresh; interval: 300; repeat: false; onTriggered: statusProc.running = true }

        Component.onCompleted: iconResolver.running = true


        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            y: bar.implicitHeight - 1
            height: 1
            color: "#383838"
        }

        RowLayout {
            id: barRow
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 4

            // App Launcher (Rofi)
            Rectangle {
                Layout.preferredWidth: appsRow.implicitWidth + 12
                Layout.fillWidth: false; Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter
                height: 26; radius: 6
                color: "#303030"; border.width: 1; border.color: "#454545"
                Row {
                    id: appsRow
                    anchors.centerIn: parent
                    spacing: 6
                    // Gentoo signet instead of the generic app grid. Tinted like
                    // the other bar glyphs, so only its shape survives.
                    BarIcon {
                        iconSource: "file://" + Quickshell.env("HOME") + "/.local/share/icons/gentoo-symbolic.svg"
                        tint: "#c58af9"
                    }
                    Text { id: appsLabel; text: "Apps"; color: "#c58af9"; font.pixelSize: 15; font.bold: true }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["rofi", "-show", "drun", "-show-icons"])
                }
            }

            // Hyprland Workspaces
            Row {
                Layout.preferredWidth: implicitWidth
                Layout.fillWidth: false; Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter
                spacing: 5
                Repeater {
                    model: Hyprland.workspaces
                    Rectangle {
                        width: 24; height: 26; radius: 6
                        color: modelData.focused ? "#3584e4" : "#303030"
                        border.width: 1
                        border.color: modelData.focused ? "#62a0ea" : "#454545"
                        Text {
                            anchors.centerIn: parent
                            text: modelData.id
                            color: "#ffffff"
                            font.pixelSize: 15; font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: modelData.activate()
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }

            // Now playing (click play/pause, scroll for next/previous)
            Rectangle {
                visible: bar.npText !== ""
                Layout.preferredWidth: npRow.implicitWidth + 12
                Layout.fillWidth: false; Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter
                height: 26; radius: 6
                color: "#303030"; border.width: 1; border.color: "#454545"
                Row {
                    id: npRow
                    anchors.centerIn: parent
                    spacing: 6
                    BarIcon {
                        iconName: bar.npPlaying ? "media-playback-start-symbolic"
                                                : "media-playback-pause-symbolic"
                        tint: "#c061cb"
                    }
                    Text {
                        text: bar.npText
                        width: Math.min(implicitWidth, 210)
                        elide: Text.ElideRight
                        color: "#c061cb"; font.pixelSize: 15; font.bold: true
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: bar.togglePlayback()
                    onWheel: wheel => bar.skipPlayback(wheel.angleDelta.y < 0 ? 1 : -1)
                }
            }

            // Wi-Fi Status
            Rectangle {
                Layout.preferredWidth: wifiRow.implicitWidth + 12
                Layout.fillWidth: false; Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter
                height: 26; radius: 6
                color: "#303030"; border.width: 1; border.color: "#454545"
                Row {
                    id: wifiRow
                    anchors.centerIn: parent
                    spacing: 6
                    BarIcon { iconName: "network-wireless-symbolic"; tint: "#57e389" }
                    Text {
                        id: wifiLabel
                        text: bar.wifiText
                        // Capped and elided: the bar has no slack left, so a long
                        // SSID must clip itself instead of squeezing the clock.
                        width: Math.min(implicitWidth, 190)
                        elide: Text.ElideRight
                        color: "#57e389"; font.pixelSize: 15; font.bold: true
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["kitty", "-e", "nmtui"])
                }
            }

            // Weather (Click opens the full forecast in a terminal)
            Rectangle {
                Layout.preferredWidth: wxRow.implicitWidth + 12
                Layout.fillWidth: false; Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter
                height: 26; radius: 6
                color: "#303030"; border.width: 1; border.color: "#454545"
                Row {
                    id: wxRow
                    anchors.centerIn: parent
                    spacing: 6
                    BarIcon { iconName: bar.wxIcon; tint: "#dc8add" }
                    Text { id: wxLabel; text: bar.wxText; color: "#dc8add"; font.pixelSize: 15; font.bold: true }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onClicked: Quickshell.execDetached(["kitty", "-e", "bash", "-c",
                        "curl -s 'wttr.in/?m' | less -R"])
                }
            }

            // Screen Brightness (Click cycles +15%, wraps at 100%)
            Rectangle {
                Layout.preferredWidth: briRow.implicitWidth + 12
                Layout.fillWidth: false; Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter
                height: 26; radius: 6
                color: "#303030"; border.width: 1; border.color: "#454545"
                Row {
                    id: briRow
                    anchors.centerIn: parent
                    spacing: 6
                    BarIcon { iconName: "display-brightness-symbolic"; tint: "#99c1f1" }
                    Text { id: briLabel; text: bar.briText; color: "#99c1f1"; font.pixelSize: 15; font.bold: true }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Quickshell.execDetached(["bash", "-c", "CUR=$(brightnessctl -m | awk -F, '{gsub(\"%\",\"\",$4); print $4}'); [ \"$CUR\" -ge 95 ] && brightnessctl set 20% || brightnessctl set 15%+"]);
                        statusProc.running = true;
                    }
                }
            }

            // Audio Volume (Click toggles mute)
            Rectangle {
                Layout.preferredWidth: volRow.implicitWidth + 12
                Layout.fillWidth: false; Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter
                height: 26; radius: 6
                color: "#303030"; border.width: 1; border.color: "#454545"
                Row {
                    id: volRow
                    anchors.centerIn: parent
                    spacing: 6
                    BarIcon { iconName: "audio-volume-high-symbolic"; tint: "#deddda" }
                    Text { id: volLabel; text: bar.volText; color: "#deddda"; font.pixelSize: 15; font.bold: true }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
                        statusProc.running = true;
                    }
                }
            }

            // Microphone (Click runs the same toggle as Super+M)
            Rectangle {
                Layout.preferredWidth: micRow.implicitWidth + 12
                Layout.fillWidth: false; Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter
                height: 26; radius: 6
                color: "#303030"; border.width: 1; border.color: bar.micMuted ? "#a51d2d" : "#454545"
                Row {
                    id: micRow
                    anchors.centerIn: parent
                    spacing: 6
                    BarIcon {
                        iconName: bar.micMuted ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic"
                        tint: bar.micMuted ? "#ff7b72" : "#57e389"
                    }
                    Text {
                        id: micLabel
                        text: bar.micMuted ? "Muted" : "Mic"
                        color: bar.micMuted ? "#ff7b72" : "#57e389"
                        font.pixelSize: 15; font.bold: true
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/mic-toggle.sh"]);
                        micRefresh.start();
                    }
                }
            }

            // Battery & Power Profile
            Rectangle {
                Layout.preferredWidth: batRow.implicitWidth + 12
                Layout.fillWidth: false; Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter
                height: 26; radius: 6
                color: "#303030"; border.width: 1; border.color: "#454545"
                Row {
                    id: batRow
                    anchors.centerIn: parent
                    spacing: 6
                    BarIcon { iconName: bar.batIcon; tint: "#ffa348" }
                    Text {
                        id: batLabel
                        text: bar.batText + " [" + bar.profText + "]"
                        // Same guard as the Wi-Fi label: the charge string grows with
                        // the state word, so cap it before it can push the clock.
                        width: Math.min(implicitWidth, 240)
                        elide: Text.ElideRight
                        color: "#ffa348"; font.pixelSize: 15; font.bold: true
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/power-menu.sh"])
                }
            }

            // GPU Switcher
            Rectangle {
                Layout.preferredWidth: gpuRow.implicitWidth + 12
                Layout.fillWidth: false; Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter
                height: 26; radius: 6
                color: "#303030"; border.width: 1; border.color: "#454545"
                Row {
                    id: gpuRow
                    anchors.centerIn: parent
                    spacing: 6
                    BarIcon { iconName: "video-display-symbolic"; tint: "#f8e45c" }
                    Text { id: gpuLabel; text: "GPU"; color: "#f8e45c"; font.pixelSize: 15; font.bold: true }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/gpu-switch.sh"])
                }
            }

            // Portage Updater
            Rectangle {
                Layout.preferredWidth: updateRow.implicitWidth + 12
                Layout.fillWidth: false; Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter
                height: 26; radius: 6
                color: "#303030"; border.width: 1; border.color: "#454545"
                Row {
                    id: updateRow
                    anchors.centerIn: parent
                    spacing: 6
                    BarIcon { iconName: "view-refresh-symbolic"; tint: "#8ff0a4" }
                    Text { id: updateLabel; text: "Update"; color: "#8ff0a4"; font.pixelSize: 15; font.bold: true }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["kitty", "-e", Quickshell.env("HOME") + "/.local/bin/portage-update.sh"])
                }
            }

            // Attached devices: phones and removable drives. Only present while
            // something is actually plugged in.
            Rectangle {
                id: devChip
                visible: bar.devCount > 0
                Layout.preferredWidth: devRow.implicitWidth + 12
                Layout.fillWidth: false; Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter
                height: 26; radius: 6
                color: devMenu.visible ? "#3a3a3a" : "#303030"
                border.width: 1; border.color: "#454545"
                Row {
                    id: devRow
                    anchors.centerIn: parent
                    spacing: 6
                    BarIcon { iconName: "drive-harddisk-usb-symbolic"; tint: "#f9c440" }
                    Text { text: bar.devCount; color: "#f9c440"; font.pixelSize: 15; font.bold: true }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: devMenu.visible = !devMenu.visible
                }
                PopupWindow {
                    id: devMenu
                    anchor.window: bar
                    anchor.item: devChip
                    anchor.edges: Edges.Bottom
                    anchor.gravity: Edges.Bottom
                    color: "transparent"
                    visible: false
                    implicitWidth: 330
                    implicitHeight: devCol.implicitHeight + 12
                    Rectangle {
                        anchors.fill: parent
                        radius: 6; color: "#303030"; border.width: 1; border.color: "#454545"
                        Column {
                            id: devCol
                            anchors.centerIn: parent
                            spacing: 2
                            Repeater {
                                model: bar.devLines
                                Rectangle {
                                    id: devRowItem
                                    required property string modelData
                                    property var fields: modelData.split("|")
                                    width: devMenu.implicitWidth - 20
                                    height: 28; radius: 4
                                    color: devHover.containsMouse ? "#3a3a3a" : "transparent"
                                    BarIcon {
                                        id: devKindIcon
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        iconName: devRowItem.fields[0] === "phone"
                                                  ? "phone-symbolic" : "drive-harddisk-usb-symbolic"
                                        tint: devRowItem.fields[0] === "phone" ? "#57e389" : "#f9c440"
                                    }
                                    Text {
                                        anchors.left: devKindIcon.right
                                        anchors.leftMargin: 8
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                        color: "#deddda"; font.pixelSize: 14; font.bold: true
                                        text: devRowItem.fields[0] === "phone"
                                              ? devRowItem.fields[3]
                                              : devRowItem.fields[2] + "  " + devRowItem.fields[3]
                                                + (devRowItem.fields[4] !== "" ? "  (mounted)" : "")
                                    }
                                    MouseArea {
                                        id: devHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: devRowItem.fields[0] === "usb"
                                        onClicked: {
                                            devMenu.visible = false
                                            let cmd = devRowItem.fields[4] === ""
                                                ? ["udisksctl", "mount", "-b", devRowItem.fields[1]]
                                                : ["udisksctl", "unmount", "-b", devRowItem.fields[1]]
                                            Quickshell.execDetached(cmd)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Session menu: lock, suspend, log out, reboot, shut down
            Rectangle {
                id: sessionChip
                Layout.preferredWidth: 30
                Layout.fillWidth: false; Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter
                height: 26; radius: 6
                color: sessionMenu.visible ? "#3a3a3a" : "#303030"
                border.width: 1; border.color: "#454545"
                BarIcon { anchors.centerIn: parent; iconName: "system-shutdown-symbolic"; tint: "#f66151" }
                MouseArea {
                    anchors.fill: parent
                    onClicked: sessionMenu.visible = !sessionMenu.visible
                }
                PopupWindow {
                    id: sessionMenu
                    anchor.window: bar
                    anchor.item: sessionChip
                    anchor.edges: Edges.Bottom
                    anchor.gravity: Edges.Bottom
                    color: "transparent"
                    visible: false
                    implicitWidth: 190
                    implicitHeight: sessionCol.implicitHeight + 12
                    Rectangle {
                        anchors.fill: parent
                        radius: 6; color: "#303030"; border.width: 1; border.color: "#454545"
                        Column {
                            id: sessionCol
                            anchors.centerIn: parent
                            spacing: 2
                            Repeater {
                                model: [
                                    { label: "Lock screen", cmd: "loginctl lock-session" },
                                    { label: "Suspend", cmd: "loginctl lock-session; sleep 1; loginctl suspend" },
                                    { label: "Update Hyprland + dots", cmd: "exec kitty -e $HOME/.local/bin/hypr-update.sh" },
                                    { label: "Log out", cmd: "loginctl terminate-user bennji" },
                                    { label: "Reboot", cmd: "loginctl reboot" },
                                    { label: "Shut down", cmd: "loginctl poweroff" }
                                ]
                                Rectangle {
                                    id: sessionRow
                                    required property var modelData
                                    width: sessionMenu.implicitWidth - 20
                                    height: 28; radius: 4
                                    color: sessionHover.containsMouse ? "#3a3a3a" : "transparent"
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: sessionRow.modelData.label
                                        color: "#deddda"; font.pixelSize: 15; font.bold: true
                                    }
                                    MouseArea {
                                        id: sessionHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            sessionMenu.visible = false
                                            Quickshell.execDetached(["bash", "-c", sessionRow.modelData.cmd])
                                        }
                                    }
                                }
                            }

                            // Updater toggle: the marker file makes the autostart
                            // hook in hyprland.lua pull the dotfiles at login.
                            Process {
                                id: autoMarkerCheck
                                command: ["bash", "-c",
                                    "test -e \"$HOME/.config/hypr/autoupdate\" && echo on || echo off"]
                                stdout: SplitParser {
                                    onRead: data => { autoUpdateRow.on = data.trim() === "on"; }
                                }
                            }
                            Rectangle {
                                id: autoUpdateRow
                                property bool on: false
                                width: sessionMenu.implicitWidth - 20
                                height: 28; radius: 4
                                color: autoUpdateHover.containsMouse ? "#3a3a3a" : "transparent"
                                Component.onCompleted: autoMarkerCheck.running = true
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Auto-update on login"
                                    color: "#deddda"; font.pixelSize: 15; font.bold: true
                                }
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30; height: 16; radius: 8
                                    color: autoUpdateRow.on ? "#3584e4" : "#4a4a4a"
                                    Rectangle {
                                        width: 12; height: 12; radius: 6
                                        color: "#deddda"
                                        y: 2; x: autoUpdateRow.on ? 16 : 2
                                        Behavior on x { NumberAnimation { duration: 90 } }
                                    }
                                }
                                MouseArea {
                                    id: autoUpdateHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        let next = !autoUpdateRow.on;
                                        autoUpdateRow.on = next;
                                        Quickshell.execDetached(["bash", "-c",
                                            "M=$HOME/.config/hypr/autoupdate; " +
                                            (next ? "mkdir -p $(dirname $M); : > $M" : "rm -f $M")]);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // StatusNotifier (app) indicators: blueman, RustDesk, nm-applet, ...
            Row {
                Layout.preferredWidth: implicitWidth
                Layout.fillWidth: false; Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter
                spacing: 4
                Repeater {
                    model: SystemTray.items
                    Rectangle {
                        id: trayEntry
                        required property var modelData
                        // Whether this tray icon should be tinted like the bar's own
                        // indicators. A helper checks the resolved theme artwork for
                        // hue: greyscale glyphs (nm-applet's signal bars) get tinted,
                        // colour artwork (blueman's blue icon, RustDesk's PNG) is left
                        // alone. Until it answers, render as colour.
                        property bool monoIcon: false
                        property string iconPath: ""
                        Component.onCompleted: iconProbe.running = true
                        Process {
                            id: iconProbe
                            command: [Quickshell.env("HOME") + "/.local/bin/tray-icon-resolve.sh",
                                      String(trayEntry.modelData.icon),
                                      String(trayEntry.modelData.id)]
                            stdout: SplitParser {
                                onRead: data => {
                                    let parts = data.trim().split(" ");
                                    if (!parts.length || parts[0] === "") return;
                                    trayEntry.monoIcon = (parts[0] === "mono");
                                    trayEntry.iconPath = parts.length > 1 ? "file://" + parts[1] : "";
                                }
                            }
                        }
                        width: 24; height: 24; radius: 6
                        color: trayHover.containsMouse ? "#303030" : "transparent"
                        BarIcon {
                            anchors.centerIn: parent
                            iconSize: 18
                            iconSource: trayEntry.iconPath !== "" ? trayEntry.iconPath : trayEntry.modelData.icon
                            tint: "#deddda"
                            visible: trayEntry.monoIcon
                        }
                        Image {
                            anchors.centerIn: parent
                            // Artwork sits at its native 22px in the 24px slot; a
                            // 20px draw thinned the blueman glyph to a single hairline.
                            width: 22; height: 22
                            source: trayEntry.iconPath !== "" ? trayEntry.iconPath : trayEntry.modelData.icon
                            sourceSize.width: 22; sourceSize.height: 22
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: !trayEntry.monoIcon
                        }
                        MouseArea {
                            id: trayHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            // Left = the item's own action, unless it only offers a menu.
                            // Right = its context menu, drawn by the anchor below.
                            // Middle = secondary activate; wheel = its scroll action.
                            onClicked: mouse => {
                                trayTip.visible = false;
                                trayTipDelay.stop();
                                if (mouse.button === Qt.MiddleButton) {
                                    trayEntry.modelData.secondaryActivate();
                                } else if (mouse.button === Qt.LeftButton && !trayEntry.modelData.onlyMenu) {
                                    trayEntry.modelData.activate();
                                } else if (trayEntry.modelData.hasMenu) {
                                    trayMenu.open();
                                }
                            }
                            onWheel: wheel => trayEntry.modelData.scroll(
                                Math.round(wheel.angleDelta.y / 120), wheel.angleDelta.x !== 0)
                            onEntered: trayTipDelay.restart()
                            onExited: {
                                trayTipDelay.stop();
                                trayTip.visible = false;
                            }
                        }
                        // Hover tooltip, styled like the bar's chips (#303030 fill,
                        // #454545 border, radius 6, 15px bold). The bar is the top
                        // layer, so it drops out of the icon's bottom edge.
                        Timer {
                            id: trayTipDelay
                            interval: 400; repeat: false
                            onTriggered: {
                                if (!trayHover.containsMouse) return;
                                if (String(trayEntry.modelData.tooltipTitle) !== "" ||
                                    String(trayEntry.modelData.tooltipDescription) !== "")
                                    trayTip.visible = true;
                            }
                        }
                        PopupWindow {
                            id: trayTip
                            anchor.window: bar
                            anchor.item: trayEntry
                            anchor.edges: Edges.Bottom
                            anchor.gravity: Edges.Bottom
                            color: "transparent"
                            visible: false
                            implicitWidth: tipRow.implicitWidth + 12
                            implicitHeight: 26
                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: "#303030"
                                border.width: 1
                                border.color: "#454545"
                                Row {
                                    id: tipRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: String(trayEntry.modelData.tooltipTitle)
                                        visible: text !== ""
                                        color: "#ffffff"
                                        font.pixelSize: 15; font.bold: true
                                    }
                                    Text {
                                        // Description is capped and elided like the
                                        // bar's own Wi-Fi and battery labels.
                                        text: String(trayEntry.modelData.tooltipDescription)
                                        visible: text !== ""
                                        width: Math.min(implicitWidth, 260)
                                        elide: Text.ElideRight
                                        color: "#b8b8b8"
                                        font.pixelSize: 15
                                    }
                                }
                            }
                        }

                        // Platform menu for this item. The anchor needs the bar's
                        // window and rectangle in window coordinates; display() with
                        // item-local coordinates is what silently did nothing before.
                        QsMenuAnchor {
                            id: trayMenu
                            menu: trayEntry.modelData.menu
                            anchor.window: bar
                            anchor.item: trayEntry
                            anchor.edges: Edges.Bottom
                            anchor.gravity: Edges.Bottom
                        }
                    }
                }
            }

            // Clock
            Text {
                id: clockText
                Layout.fillWidth: false; Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter
                color: "#ffffff"
                font.pixelSize: 15; font.bold: true
                Timer {
                    interval: 1000; running: true; repeat: true; triggeredOnStart: true
                    onTriggered: clockText.text = Qt.formatDateTime(new Date(), "ddd MMM d  hh:mm AP")
                }
            }
        }
    }
}
