// Monitor-filtered Hyprland workspace dots with gradient active pill and wheel switching
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
        onWheel: wheel => {
            workspaces_root.step_workspace(wheel.angleDelta.y);
            wheel.accepted = true;
        }
    }

    Row {
        id: dots_row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: Hyprland.workspaces

            delegate: Rectangle {
                id: ws_dot
                required property var modelData

                readonly property bool is_special: ws_dot.modelData && ws_dot.modelData.name
                    ? ws_dot.modelData.name.startsWith("special:")
                    : false
                readonly property bool is_active: ws_dot.modelData ? Boolean(ws_dot.modelData.active) : false
                // Здесь я оставляю на острове только воркспейсы его собственного монитора
                readonly property bool on_this_monitor: workspaces_root.is_ws_on_monitor(ws_dot.modelData)

                visible: ws_dot.on_this_monitor && !ws_dot.is_special
                anchors.verticalCenter: parent.verticalCenter
                width: ws_dot.is_active ? 22 : 7
                height: 7
                radius: Style.radius_pill

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0.0
                        color: ws_dot.is_active
                            ? Colors.primary
                            : (dot_mouse.containsMouse
                                ? Colors.on_surface
                                : Style.alpha(Colors.on_surface_variant, 0.50))

                        Behavior on color {
                            ColorAnimation {
                                duration: Style.motion_normal
                                easing.type: Style.easing
                            }
                        }
                    }

                    GradientStop {
                        position: 1.0
                        color: ws_dot.is_active
                            ? Colors.tertiary
                            : (dot_mouse.containsMouse
                                ? Colors.on_surface
                                : Style.alpha(Colors.on_surface_variant, 0.50))

                        Behavior on color {
                            ColorAnimation {
                                duration: Style.motion_normal
                                easing.type: Style.easing
                            }
                        }
                    }
                }

                Behavior on width {
                    SpringAnimation {
                        spring: Style.spring
                        damping: Style.spring_damping
                        epsilon: 0.2
                    }
                }

                MouseArea {
                    id: dot_mouse
                    anchors {
                        fill: parent
                        margins: -3
                    }
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (ws_dot.modelData) {
                            // Здесь я передаю фокус воркспейса в Lua-синтаксисе Hyprland 0.57
                            Hyprland.dispatch("hl.dsp.focus({ workspace = " + ws_dot.modelData.id + " })");
                        }
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
