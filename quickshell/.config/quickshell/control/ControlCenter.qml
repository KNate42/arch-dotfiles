// Focused-monitor glass control center with spring motion, outside dismissal and bento settings
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"

Scope {
    id: control_root

    property var target_screen: null
    property bool entered: false

    // Здесь я фиксирую монитор при открытии, чтобы панель не переезжала вслед за фокусом.
    function find_focused_screen() {
        const screens = Quickshell.screens;
        const monitor = Hyprland.focusedMonitor;
        for (let i = 0; i < screens.length; i++) {
            if (monitor && screens[i].name === monitor.name) {
                return screens[i];
            }
        }
        return screens.length > 0 ? screens[0] : null;
    }

    function sync_open() {
        if (Panels.control_open) {
            control_root.target_screen = control_root.find_focused_screen();
            Qt.callLater(() => {
                control_root.entered = Panels.control_open;
                if (Panels.control_open) {
                    key_catcher.forceActiveFocus();
                    content_scroll.contentY = 0;
                }
            });
        } else {
            control_root.entered = false;
        }
    }

    Component.onCompleted: control_root.sync_open()

    Connections {
        target: Panels
        function onControl_openChanged() {
            control_root.sync_open();
        }
    }

    PanelWindow {
        id: control_window
        screen: control_root.target_screen
        visible: Panels.control_open || slide_motion.running || fade_motion.running
        color: "transparent"
        exclusiveZone: 0
        focusable: Panels.control_open
        WlrLayershell.namespace: "dots-control"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Panels.control_open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Здесь я сразу освобождаю ввод при закрытии, пока стекло ещё доигрывает анимацию.
        mask: Region { item: Panels.control_open ? key_catcher : null }

        FocusScope {
            id: key_catcher
            anchors.fill: parent
            focus: Panels.control_open
            enabled: Panels.control_open
            Keys.onEscapePressed: event => {
                Panels.control_open = false;
                event.accepted = true;
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: Panels.control_open = false
            }

            Rectangle {
                id: panel_card
                property real slide_progress: control_root.entered ? 1 : 0
                x: parent.width - width - 10 + (1 - slide_progress) * (width + 10)
                y: 10
                width: Math.min(Style.control_width, Math.max(0, parent.width - 20))
                height: Math.max(0, parent.height - 20)
                radius: Style.radius_lg
                color: Style.alpha(Colors.surface, Style.glass_opacity)
                border.width: 1
                border.color: Style.alpha(Colors.outline_variant, Style.glass_border_opacity)
                opacity: control_root.entered ? 1 : 0

                Behavior on slide_progress {
                    SpringAnimation {
                        id: slide_motion
                        spring: Style.spring
                        damping: Style.spring_damping
                        epsilon: 0.001
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        id: fade_motion
                        duration: Style.motion_normal
                        easing.type: Style.easing
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onWheel: wheel => wheel.accepted = true
                }

                // Здесь я оставляю прокрутку для небольших экранов и длинного ряда приложений в трее.
                Flickable {
                    id: content_scroll
                    anchors.fill: parent
                    anchors.margins: Style.space_md
                    contentWidth: width
                    contentHeight: tile_column.implicitHeight
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: tile_column
                        width: content_scroll.width
                        spacing: Style.tile_gap

                        HeaderTile { width: parent.width }
                        QuickToggles { width: parent.width }
                        AudioSliders { width: parent.width }
                        MediaTile { width: parent.width }

                        Row {
                            width: parent.width
                            spacing: Style.tile_gap
                            CalendarTile { width: (parent.width - parent.spacing) / 2 }
                            SystemTile { width: (parent.width - parent.spacing) / 2 }
                        }

                        TrayTile { width: parent.width }
                    }
                }
            }
        }
    }
}
