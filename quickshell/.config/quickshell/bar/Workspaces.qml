// Hyprland workspaces indicator and switcher for a single monitor
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../theme"

Row {
    id: workspaces_root
    spacing: 4

    property var bar_screen: null
    readonly property var hypr_monitor: workspaces_root.bar_screen ? Hyprland.monitorFor(workspaces_root.bar_screen) : null

    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            id: ws_item // ws = workspace
            required property var modelData

            readonly property bool is_special: ws_item.modelData && ws_item.modelData.name ? ws_item.modelData.name.startsWith("special:") : false
            readonly property bool is_active: ws_item.modelData ? Boolean(ws_item.modelData.active) : false

            // Здесь я фильтрую воркспейсы по монитору панели, чтобы каждый экран показывал только свои
            readonly property bool on_this_monitor: {
                if (!ws_item.modelData || !ws_item.modelData.monitor) {
                    return false;
                }
                if (workspaces_root.hypr_monitor) {
                    return ws_item.modelData.monitor.id === workspaces_root.hypr_monitor.id;
                }
                if (workspaces_root.bar_screen && workspaces_root.bar_screen.name) {
                    return ws_item.modelData.monitor.name === workspaces_root.bar_screen.name;
                }
                return true;
            }

            visible: ws_item.on_this_monitor && !ws_item.is_special
            width: Math.max(24, ws_label.implicitWidth + 12)
            height: 22
            radius: 6
            color: ws_item.is_active ? Colors.primary : Colors.surface_container_high

            Text {
                id: ws_label
                anchors.centerIn: parent
                text: ws_item.modelData ? ws_item.modelData.name : ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.bold: ws_item.is_active
                color: ws_item.is_active ? Colors.on_primary : Colors.on_surface
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (ws_item.modelData) {
                        // Здесь я передаю диспетчер в Lua-синтаксисе: с hyprland.lua старые строки вида "workspace 3" не работают
                        Hyprland.dispatch("hl.dsp.focus({ workspace = " + ws_item.modelData.id + " })");
                    }
                }
            }
        }
    }
}
