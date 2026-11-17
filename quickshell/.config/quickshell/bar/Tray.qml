// System tray items row with primary activation and context menu support
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../theme"

Row {
    id: tray_root
    spacing: Style.space_xs

    Repeater {
        model: SystemTray.items

        delegate: Rectangle {
            id: tray_item
            required property var modelData

            width: Style.bar_item_height
            height: Style.bar_item_height
            radius: Style.radius_pill
            color: tray_mouse.pressed
                ? Style.alpha(Colors.on_surface, Style.press_opacity)
                : (tray_mouse.containsMouse
                    ? Style.alpha(Colors.on_surface, Style.hover_opacity)
                    : Style.alpha(Colors.on_surface, 0.0))

            Behavior on color {
                ColorAnimation {
                    duration: Style.motion_fast
                    easing.type: Style.easing
                }
            }

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
                id: tray_mouse
                anchors.fill: parent
                hoverEnabled: true
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
