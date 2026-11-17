// Control center header tile with gradient user avatar, system uptime, and action buttons
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

BentoTile {
    id: header_root
    tile_index: 0
    implicitHeight: 68

    readonly property string user_name: {
        const env_user = Quickshell.env("USER") ?? "";
        if (env_user !== "") {
            return env_user;
        }
        const env_logname = Quickshell.env("LOGNAME") ?? "";
        return env_logname !== "" ? env_logname : "user";
    }

    readonly property string user_initial: header_root.user_name.length > 0
        ? header_root.user_name.charAt(0).toUpperCase()
        : "U"

    property string uptime_label: "работает 0 ч 0 мин"

    readonly property var action_buttons: [
        { icon: "󰸉", kind: "wallpaper" },
        { icon: "󰐥", kind: "power" },
        { icon: "󰅖", kind: "close" }
    ]

    // Здесь я разбираю первую колонку /proc/uptime (секунды с момента загрузки) в часы и минуты
    function parse_uptime(raw_text) {
        if (!raw_text || raw_text.trim() === "") {
            return;
        }
        const parts = raw_text.trim().split(/\s+/);
        const total_sec = parseFloat(parts[0]); // sec = seconds
        if (isNaN(total_sec) || total_sec < 0) {
            return;
        }
        const hours = Math.floor(total_sec / 3600);
        const minutes = Math.floor((total_sec % 3600) / 60);
        header_root.uptime_label = "работает " + hours + " ч " + minutes + " мин";
    }

    // Здесь я закрываю центр управления перед открытием оверлея обоев или питания, чтобы слои не конфликтовали
    function trigger_button(kind) {
        if (kind === "wallpaper") {
            Panels.control_open = false;
            wallpaper_ipc_proc.running = false;
            wallpaper_ipc_proc.running = true;
        } else if (kind === "power") {
            Panels.control_open = false;
            power_ipc_proc.running = false;
            power_ipc_proc.running = true;
        } else if (kind === "close") {
            Panels.control_open = false;
        }
    }

    FileView {
        id: uptime_file
        path: "/proc/uptime"
        onLoaded: header_root.parse_uptime(uptime_file.text())
    }

    Timer {
        id: uptime_timer
        interval: 30000
        running: Panels.control_open
        repeat: true
        triggeredOnStart: true
        onTriggered: uptime_file.reload()
    }

    Process {
        id: wallpaper_ipc_proc // proc = process
        command: ["qs", "ipc", "call", "wallpaper", "toggle"]
    }

    Process {
        id: power_ipc_proc
        command: ["qs", "ipc", "call", "power", "toggle"]
    }

    Row {
        id: user_row
        anchors {
            left: parent.left
            leftMargin: Style.space_md
            right: actions_row.left
            rightMargin: Style.space_sm
            verticalCenter: parent.verticalCenter
        }
        spacing: Style.space_md

        Rectangle {
            id: avatar_badge
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: Style.radius_pill

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Colors.primary }
                GradientStop { position: 1.0; color: Colors.tertiary }
            }

            Text {
                id: avatar_initial_text
                anchors.centerIn: parent
                text: header_root.user_initial
                font.family: Style.font_ui
                font.pixelSize: Style.text_lg
                font.weight: Font.Bold
                color: Colors.on_primary
            }
        }

        Column {
            id: user_info_column
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - avatar_badge.width - parent.spacing)
            spacing: 2

            Text {
                id: username_text
                width: parent.width
                text: header_root.user_name
                font.family: Style.font_ui
                font.pixelSize: Style.text_md
                font.weight: Font.DemiBold
                color: Colors.on_surface
                elide: Text.ElideRight
            }

            Text {
                id: uptime_text
                width: parent.width
                text: header_root.uptime_label
                font.family: Style.font_ui
                font.pixelSize: Style.text_xs
                color: Colors.on_surface_variant
                elide: Text.ElideRight
            }
        }
    }

    Row {
        id: actions_row
        anchors {
            right: parent.right
            rightMargin: Style.space_md
            verticalCenter: parent.verticalCenter
        }
        spacing: Style.space_xs

        Repeater {
            model: header_root.action_buttons

            delegate: Rectangle {
                id: action_btn // btn = button
                required property var modelData

                readonly property bool is_power: action_btn.modelData.kind === "power"

                width: 34
                height: 34
                radius: Style.radius_pill
                color: btn_mouse.pressed
                    ? Style.alpha(action_btn.is_power ? Colors.error : Colors.primary, Style.press_opacity)
                    : (btn_mouse.containsMouse
                        ? Style.alpha(action_btn.is_power ? Colors.error : Colors.on_surface, Style.hover_opacity)
                        : Style.alpha(Colors.surface_container_high, 0.65))
                border.width: 1
                border.color: btn_mouse.containsMouse
                    ? Style.alpha(action_btn.is_power ? Colors.error : Colors.primary, 0.5)
                    : Style.alpha(Colors.outline_variant, Style.glass_border_opacity)

                Behavior on color {
                    ColorAnimation {
                        duration: Style.motion_fast
                        easing.type: Style.easing
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Style.motion_fast
                        easing.type: Style.easing
                    }
                }

                Text {
                    id: btn_icon
                    anchors.centerIn: parent
                    text: action_btn.modelData.icon
                    font.family: Style.font_mono
                    font.pixelSize: Style.text_md
                    color: btn_mouse.containsMouse && action_btn.is_power
                        ? Colors.error
                        : Colors.on_surface
                }

                MouseArea {
                    id: btn_mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: header_root.trigger_button(action_btn.modelData.kind)
                }
            }
        }
    }
}
