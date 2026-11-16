// Top status bar spawned across all screens via Variants
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import "../theme"

Scope {
    id: bar_scope

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: bar_window
            required property var modelData

            screen: bar_window.modelData
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 32
            exclusiveZone: 32
            color: Colors.surface

            Item {
                id: bar_container
                anchors.fill: parent

                Workspaces {
                    id: workspaces_widget
                    anchors {
                        left: parent.left
                        leftMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    bar_screen: bar_window.modelData
                }

                Clock {
                    id: clock_widget
                    anchors.centerIn: parent
                }

                Row {
                    id: right_modules
                    anchors {
                        right: parent.right
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 6

                    Layout {
                        id: layout_widget
                    }

                    Volume {
                        id: volume_widget
                    }

                    Network {
                        id: network_widget
                    }

                    Tray {
                        id: tray_widget
                    }
                }
            }
        }
    }
}
