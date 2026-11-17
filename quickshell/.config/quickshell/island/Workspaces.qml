// Monitor-filtered numbered HUD workspaces with magenta focus and Lua dispatch
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../theme"

Item {
    id: workspaces_root

    property var island_screen: null
    readonly property var hypr_monitor: workspaces_root.island_screen ? Hyprland.monitorFor(workspaces_root.island_screen) : null
    readonly property bool contains_mouse: wheel_catcher.containsMouse

    signal workspace_pulsed()

    implicitWidth: dots_row.implicitWidth
    implicitHeight: Style.island_height

    function is_ws_on_monitor(ws_obj) { // ws = workspace
        if (!ws_obj || !ws_obj.monitor) {
            return false;
        }
        if (workspaces_root.hypr_monitor) {
            return ws_obj.monitor.id === workspaces_root.hypr_monitor.id;
        }
        if (workspaces_root.island_screen && workspaces_root.island_screen.name) {
            return ws_obj.monitor.name === workspaces_root.island_screen.name;
        }
        return true;
    }

    readonly property int active_ws_id: {
        const list = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        if (list) {
            for (let i = 0; i < list.length; i++) {
                const item = list[i];
                const is_spec = item && item.name ? item.name.startsWith("special:") : false;
                if (item && !is_spec && item.active && workspaces_root.is_ws_on_monitor(item)) {
                    return item.id;
                }
            }
        }
        if (workspaces_root.hypr_monitor && workspaces_root.hypr_monitor.activeWorkspace) {
            return workspaces_root.hypr_monitor.activeWorkspace.id;
        }
        return -1;
    }

    property int prev_ws_id: -1

    onActive_ws_idChanged: {
        if (workspaces_root.prev_ws_id > 0 && workspaces_root.active_ws_id > 0 && workspaces_root.prev_ws_id !== workspaces_root.active_ws_id) {
            workspaces_root.workspace_pulsed();
        }
        if (workspaces_root.active_ws_id > 0) {
            workspaces_root.prev_ws_id = workspaces_root.active_ws_id;
        }
    }

    // Здесь я ищу соседний рабочий стол текущего монитора для прокрутки колесом и переключаю через Lua-диспетчер
    function step_workspace(delta_y) {
        if (delta_y === 0) {
            return;
        }
        const list = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        const mon_ids = []; // mon = monitor
        if (list) {
            for (let i = 0; i < list.length; i++) {
                const item = list[i];
                const is_spec = item && item.name ? item.name.startsWith("special:") : false;
                if (item && !is_spec && workspaces_root.is_ws_on_monitor(item) && item.id > 0) {
                    mon_ids.push(item.id);
                }
            }
        }
        mon_ids.sort((a, b) => a - b);
        const step = delta_y > 0 ? -1 : 1;
        if (mon_ids.length > 1) {
            const cur_idx = mon_ids.indexOf(workspaces_root.active_ws_id); // idx = index
            if (cur_idx >= 0) {
                const next_idx = Math.max(0, Math.min(mon_ids.length - 1, cur_idx + step));
                if (next_idx !== cur_idx) {
                    Hyprland.dispatch("hl.dsp.focus({ workspace = " + mon_ids[next_idx] + " })");
                    return;
                }
            }
        }
        const fallback_id = Math.max(1, Math.min(9, (workspaces_root.active_ws_id > 0 ? workspaces_root.active_ws_id : 1) + step));
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + fallback_id + " })");
    }

    MouseArea {
        id: wheel_catcher
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
        onWheel: wheel => {
            workspaces_root.step_workspace(wheel.angleDelta.y);
            wheel.accepted = true;
        }
    }

    Row {
        id: dots_row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Repeater {
            model: Hyprland.workspaces
            delegate: Item {
                id: ws_slot
                required property var modelData
                readonly property bool is_special: modelData && modelData.name ? modelData.name.startsWith("special:") : false
                readonly property bool is_active: modelData ? Boolean(modelData.active) : false
                visible: workspaces_root.is_ws_on_monitor(modelData) && !is_special
                width: ws_label.implicitWidth + 6
                height: 26
                NeonText {
                    id: ws_label
                    anchors.centerIn: parent
                    text: {
                        const number = String(ws_slot.modelData ? ws_slot.modelData.id : 0).padStart(2, "0");
                        return ws_slot.is_active ? "▸[" + number + "]" : number;
                    }
                    color: ws_slot.is_active ? Colors.magenta : (dot_mouse.containsMouse ? Colors.cyan : Colors.on_surface_variant)
                    glow_color: Colors.magenta
                    glow: ws_slot.is_active
                    pixel_size: Style.text_sm
                    spacing: 0.5
                }
                // Здесь я подсвечиваю смену фокуса, не меняя фильтрацию по монитору.
                onIs_activeChanged: Qt.callLater(() => { if (is_active) ws_label.glitch(); })
                MouseArea {
                    id: dot_mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (ws_slot.modelData)
                            Hyprland.dispatch("hl.dsp.focus({ workspace = " + ws_slot.modelData.id + " })");
                    }
                    onWheel: wheel => {
                        workspaces_root.step_workspace(wheel.angleDelta.y);
                        wheel.accepted = true;
                    }
                }
            }
        }
    }
}
