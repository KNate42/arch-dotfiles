// System tray items row with primary activation and context menu support
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../theme"

Row {
    id: tray_root
    spacing: 4

    Repeater {
        model: SystemTray.items

        delegate: Rectangle {
            id: tray_item
            required property var modelData

            width: 24
            height: 22
            radius: 6
            color: Colors.surface_container_high

            QsMenuAnchor {
                id: menu_anchor
                anchor.item: tray_item
                menu: tray_item.modelData ? tray_item.modelData.menu : null
            }

            Image {
                id: tray_icon
                anchors.centerIn: parent
                width: 16
                height: 16
                source: tray_item.modelData ? tray_item.modelData.icon : ""
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (!tray_item.modelData) {
                        return;
                    }
                    if (mouse.button === Qt.RightButton) {
                        if (tray_item.modelData.hasMenu) {
                            menu_anchor.open();
                        }
                    } else if (mouse.button === Qt.MiddleButton) {
                        tray_item.modelData.secondaryActivate();
                    } else {
                        if (tray_item.modelData.onlyMenu && tray_item.modelData.hasMenu) {
                            menu_anchor.open();
                        } else {
                            tray_item.modelData.activate();
                        }
                    }
                }
            }
        }
    }
}
