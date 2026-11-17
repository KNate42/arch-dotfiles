// Status terminal header with session address, uptime and overlay actions
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

BentoTile {
    id: header_root
    tile_index: 0
    implicitHeight: 104

    readonly property string user_name: {
        const env_user = Quickshell.env("USER") ?? "";
        if (env_user !== "") {
            return env_user;
        }
        const env_logname = Quickshell.env("LOGNAME") ?? "";
        return env_logname !== "" ? env_logname : "user";
    }

    property string host_name: Quickshell.env("HOSTNAME") || "host"
    property string uptime_label: "UPTIME 0H 0M"

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
        header_root.uptime_label = "UPTIME " + hours + "H " + minutes + "M";
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
        path: "/proc/sys/kernel/hostname"
        onLoaded: {
            const name = text().trim();
            if (name !== "") header_root.host_name = name;
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

    // Здесь я вывожу адрес сеанса отдельно от команд, чтобы заголовок помещался на узком экране.
    Column {
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.space_md }
        spacing: 5
        NeonText {
            id: terminal_title
            text: ">> SYS.CONTROL"
            color: Colors.cyan
            pixel_size: Style.text_lg
        }
        Text {
            text: "// " + header_root.user_name + "@" + header_root.host_name + "  ::  " + header_root.uptime_label
            width: parent.width
            elide: Text.ElideRight
            font.family: Style.font_hud
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Style.hud_letter_spacing
            font.pixelSize: Style.text_xs
            color: Colors.mint
        }
        Row {
            spacing: Style.space_sm
            Repeater {
                model: header_root.action_buttons
                delegate: HudPanel {
                    id: action_btn
                    required property var modelData
                    width: 44; height: 28; cut: 5; brackets: false; scanlines: false
                    accent: modelData.kind === "power" ? Colors.magenta : Colors.cyan
                    active: btn_mouse.containsMouse
                    NeonText {
                        anchors.centerIn: parent
                        text: action_btn.modelData.icon
                        color: action_btn.accent
                        pixel_size: Style.text_md
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
    onIs_revealedChanged: { if (is_revealed) terminal_title.glitch(); }
}
