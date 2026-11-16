// Active keyboard layout indicator listening to Hyprland activelayout events
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"

Rectangle {
    id: layout_root

    property string current_layout: "EN"

    implicitWidth: layout_text.implicitWidth + 14
    implicitHeight: 22
    radius: 6
    color: Colors.surface_container_high

    // Здесь я разбираю строку события activelayout вида "клавиатура,раскладка" с учётом возможных запятых в имени
    function update_layout_from_event(raw_payload) {
        if (!raw_payload) {
            return;
        }
        const comma_idx = raw_payload.indexOf(","); // idx = index
        const layout_part = (comma_idx >= 0 ? raw_payload.substring(comma_idx + 1) : raw_payload).trim().toLowerCase();
        if (layout_part.includes("ru") || layout_part.includes("рус")) {
            layout_root.current_layout = "RU";
        } else if (layout_part.includes("en") || layout_part.includes("us") || layout_part.includes("англ")) {
            layout_root.current_layout = "EN";
        } else if (layout_part.length >= 2) {
            layout_root.current_layout = layout_part.substring(0, 2).toUpperCase();
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event && event.name === "activelayout") {
                layout_root.update_layout_from_event(event.data);
            }
        }
    }

    Text {
        id: layout_text
        anchors.centerIn: parent
        text: "󰌌 " + layout_root.current_layout
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        font.bold: true
        color: Colors.on_surface
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: layout_switch.running = true
    }

    Process {
        id: layout_switch
        command: ["hyprctl", "switchxkblayout", "all", "next"]
    }
}
