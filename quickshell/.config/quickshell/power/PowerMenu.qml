// Fullscreen glass power menu overlay with keyboard navigation and IPC toggle
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../theme"

Scope {
    id: power_root

    property bool is_open: false
    property int selected_index: 0
    property var target_screen: null

    readonly property var actions_model: [
        { label: "Блокировка", icon: "󰌾", kind: "lock" },
        { label: "Выход", icon: "󰍃", kind: "logout" },
        { label: "Перезагрузка", icon: "󰜉", kind: "reboot" },
        { label: "Выключение", icon: "󰐥", kind: "poweroff" }
    ]

    // Здесь я нахожу экран, на котором сейчас фокус Hyprland, чтобы открыть меню именно на нём
    function find_focused_screen() {
        const screens = Quickshell.screens;
        if (!screens || screens.length === 0) {
            return null;
        }
        const focused_mon = Hyprland.focusedMonitor; // mon = monitor
        if (focused_mon) {
            for (let i = 0; i < screens.length; i++) {
                const mon = Hyprland.monitorFor(screens[i]);
                if ((mon && mon.id === focused_mon.id) || screens[i].name === focused_mon.name) {
                    return screens[i];
                }
            }
        }
        return screens[0];
    }

    function open_menu() {
        close_timer.stop();
        power_root.selected_index = 0;
        power_root.target_screen = power_root.find_focused_screen();
        power_root.is_open = true;
        key_catcher.forceActiveFocus();
    }

    function close_menu() {
        if (!power_root.is_open) {
            return;
        }
        power_root.is_open = false;
        close_timer.restart();
    }

    function toggle_menu() {
        if (power_root.is_open) {
            power_root.close_menu();
        } else {
            power_root.open_menu();
        }
    }

    // Здесь я выполняю выбранное действие и сразу закрываю оверлей; для выхода использую Lua-диспетчер
    function trigger_action(idx) { // idx = action index
        if (idx < 0 || idx >= power_root.actions_model.length) {
            return;
        }
        const item = power_root.actions_model[idx];
        power_root.close_menu();
        if (item.kind === "lock") {
            lock_proc.running = false;
            lock_proc.running = true;
        } else if (item.kind === "logout") {
            Hyprland.dispatch("hl.dsp.exit()");
        } else if (item.kind === "reboot") {
            reboot_proc.running = false;
            reboot_proc.running = true;
        } else if (item.kind === "poweroff") {
            poweroff_proc.running = false;
            poweroff_proc.running = true;
        }
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            power_root.toggle_menu();
        }
    }

    Process {
        id: lock_proc // proc = process
        command: ["hyprlock"]
    }

    Process {
        id: reboot_proc
        command: ["systemctl", "reboot"]
    }

    Process {
        id: poweroff_proc
        command: ["systemctl", "poweroff"]
    }

    Timer {
        id: close_timer
        interval: Style.motion_normal
        repeat: false
    }

    PanelWindow {
        id: power_window
        screen: power_root.target_screen
        visible: power_root.is_open || close_timer.running
        focusable: true
        aboveWindows: true
        exclusiveZone: -1
        WlrLayershell.namespace: "dots-power"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"

        onVisibleChanged: {
            if (power_window.visible) {
                key_catcher.forceActiveFocus();
            }
        }

        FocusScope {
            id: key_catcher
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                const count = power_root.actions_model.length;
                if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                    power_root.selected_index = (power_root.selected_index + 1) % count;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                    power_root.selected_index = (power_root.selected_index + count - 1) % count;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    power_root.trigger_action(power_root.selected_index);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    power_root.close_menu();
                    event.accepted = true;
                }
            }

            Rectangle {
                id: backdrop_dim
                anchors.fill: parent
                color: Style.alpha(Colors.shadow, 0.35)
                opacity: power_root.is_open ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Style.motion_normal
                        easing.type: Style.easing
                    }
                }

                MouseArea {
                    id: backdrop_mouse
                    anchors.fill: parent
                    onClicked: power_root.close_menu()
                }
            }

            Rectangle {
                id: power_card
                anchors.centerIn: parent
                width: buttons_row.implicitWidth + Style.space_xl * 2
                height: buttons_row.implicitHeight + Style.space_xl * 2
                radius: Style.radius_lg
                color: Style.alpha(Colors.surface, Style.glass_opacity)
                border.width: 1
                border.color: Style.alpha(Colors.outline_variant, Style.glass_border_opacity)
                opacity: power_root.is_open ? 1.0 : 0.0
                scale: power_root.is_open ? 1.0 : 0.96

                Behavior on opacity {
                    NumberAnimation {
                        duration: Style.motion_normal
                        easing.type: Style.easing
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Style.motion_normal
                        easing.type: Style.easing
                    }
                }

                MouseArea {
                    id: card_blocker
                    anchors.fill: parent
                }

                Row {
                    id: buttons_row
                    anchors.centerIn: parent
                    spacing: Style.space_lg

                    Repeater {
                        model: power_root.actions_model

                        delegate: Rectangle {
                            id: action_button
                            required property var modelData
                            required property int index

                            readonly property bool is_selected: power_root.selected_index === action_button.index

                            width: Style.space_xl * 5
                            height: Style.space_xl * 5
                            radius: Style.radius_md
                            color: button_mouse.pressed
                                ? Style.alpha(Colors.primary, Style.press_opacity)
                                : (action_button.is_selected
                                    ? Style.alpha(Colors.primary, Style.hover_opacity)
                                    : (button_mouse.containsMouse
                                        ? Style.alpha(Colors.on_surface, Style.hover_opacity)
                                        : Style.alpha(Colors.on_surface, 0.0)))
                            border.width: 1
                            border.color: action_button.is_selected
                                ? Colors.primary
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

                            Column {
                                id: button_column
                                anchors.centerIn: parent
                                spacing: Style.space_sm

                                Text {
                                    id: button_icon
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: action_button.modelData.icon
                                    font.family: Style.font_mono
                                    font.pixelSize: 28
                                    color: action_button.is_selected ? Colors.primary : Colors.on_surface
                                }

                                Text {
                                    id: button_label
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: action_button.modelData.label
                                    font.family: Style.font_ui
                                    font.pixelSize: Style.text_md
                                    font.weight: action_button.is_selected ? Font.DemiBold : Font.Medium
                                    color: action_button.is_selected ? Colors.on_surface : Colors.on_surface_variant
                                }
                            }

                            MouseArea {
                                id: button_mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: power_root.selected_index = action_button.index
                                onClicked: power_root.trigger_action(action_button.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
