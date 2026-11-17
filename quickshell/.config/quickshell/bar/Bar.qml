// Floating glass status bar spawned across all screens via Variants
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme"

Scope {
    id: bar_scope

    signal power_requested()

    Process {
        id: launcher_proc // proc = process
        command: ["rofi", "-show", "drun"]
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: bar_window
            required property var modelData

            screen: bar_window.modelData
            WlrLayershell.namespace: "dots-bar"
            anchors {
                top: true
                left: true
                right: true
            }
            margins {
                top: Style.bar_margin_top
                left: Style.bar_margin_side
                right: Style.bar_margin_side
            }
            implicitHeight: Style.bar_height
            // Здесь я включаю верхний отступ в exclusiveZone, чтобы окна Hyprland не залезали под плавающий остров
            exclusiveZone: Style.bar_height + Style.bar_margin_top
            color: "transparent"

            Rectangle {
                id: bar_island
                anchors.fill: parent
                radius: Style.radius_lg
                color: Style.alpha(Colors.surface, Style.glass_opacity)
                border.width: 1
                border.color: Style.alpha(Colors.outline_variant, Style.glass_border_opacity)

                Row {
                    id: left_modules
                    anchors {
                        left: parent.left
                        leftMargin: Style.space_sm
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Style.space_sm

                    BarChip {
                        id: launcher_chip
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "󰣇"
                        icon_color: Colors.primary
                        onClicked: {
                            launcher_proc.running = false;
                            launcher_proc.running = true;
                        }
                    }

                    Workspaces {
                        id: workspaces_widget
                        anchors.verticalCenter: parent.verticalCenter
                        bar_screen: bar_window.modelData
                    }
                }

                Clock {
                    id: clock_widget
                    anchors.centerIn: parent
                }

                Row {
                    id: right_modules
                    anchors {
                        right: parent.right
                        rightMargin: Style.space_sm
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Style.space_xs

                    Media {
                        id: media_widget
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Layout {
                        id: layout_widget
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Volume {
                        id: volume_widget
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Network {
                        id: network_widget
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Tray {
                        id: tray_widget
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    BarChip {
                        id: power_chip
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "󰐥"
                        icon_color: Colors.on_surface
                        onClicked: bar_scope.power_requested()
                    }
                }
            }
        }
    }
}
