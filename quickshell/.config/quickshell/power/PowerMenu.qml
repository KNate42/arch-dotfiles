// Fullscreen HUD power console with keyboard navigation and IPC toggle
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
        { label: "LOCK", icon: "󰌾", kind: "lock" },
        { label: "LOGOUT", icon: "󰍃", kind: "logout" },
        { label: "REBOOT", icon: "󰜉", kind: "reboot" },
        { label: "SHUTDOWN", icon: "󰐥", kind: "poweroff" }
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
        Qt.callLater(() => power_title.glitch());
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
                color: Style.alpha(Colors.shadow, 0.60)
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

            HudPanel {
                id: power_card
                anchors.centerIn: parent
                width: Math.min(660, Math.max(0, parent.width - 32))
                height: power_content.implicitHeight + Style.space_xl * 2
                accent: Colors.cyan
                active: true
                opacity: power_root.is_open ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Style.motion_fast } }
                MouseArea { anchors.fill: parent }
                Column {
                    id: power_content
                    x: Style.space_xl; y: Style.space_xl
                    width: parent.width - Style.space_xl * 2
                    spacing: Style.space_lg
                    NeonText {
                        id: power_title
                        text: ">> POWER.MENU"
                        color: Colors.cyan
                        pixel_size: Style.text_lg
                        split: true
                    }
                    // Здесь я переношу кнопки на узком мониторе, сохраняя клавиатурный порядок.
                    Flow {
                        width: parent.width
                        spacing: Style.space_md
                        Repeater {
                            model: power_root.actions_model
                            delegate: HudPanel {
                                id: action_button
                                required property var modelData
                                required property int index
                                readonly property bool is_selected: power_root.selected_index === index
                                width: (power_content.width - Style.space_md * (power_content.width < 460 ? 1 : 3))
                                    / (power_content.width < 460 ? 2 : 4)
                                height: 116
                                accent: is_selected ? Colors.magenta : Colors.cyan
                                active: is_selected || button_mouse.containsMouse
                                Column {
                                    anchors.centerIn: parent
                                    spacing: Style.space_sm
                                    NeonText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: action_button.modelData.icon
                                        pixel_size: 28
                                        color: action_button.accent
                                        glow_color: action_button.accent
                                    }
                                    NeonText {
                                        id: button_label
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: action_button.modelData.label
                                        pixel_size: Style.text_xs
                                        spacing: 0.5
                                        color: action_button.is_selected ? Colors.magenta : Colors.on_surface
                                        glow_color: action_button.accent
                                    }
                                }
                                onIs_selectedChanged: Qt.callLater(() => { if (is_selected) button_label.glitch(); })
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
                    Text {
                        text: "[ ← → ] SELECT  //  [ ENTER ] EXEC  //  [ ESC ] ABORT"
                        width: parent.width
                        wrapMode: Text.Wrap
                        font.family: Style.font_hud
                        font.pixelSize: Style.text_xs
                        color: Colors.mint
                    }
                }
            }
        }
    }
}
