// Neon system tray with application activation and anchored context menus
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../theme"

BentoTile {
    id: tray_root
    tile_index: 5
    readonly property var tray_items: SystemTray.items.values
    visible: tray_root.tray_items.length > 0
    implicitHeight: visible ? tray_column.implicitHeight + Style.space_md * 2 : 0

    Column {
        id: tray_column
        x: Style.space_md
        y: Style.space_md
        width: parent.width - Style.space_md * 2
        spacing: Style.space_sm

        Text {
            text: "// APPLICATIONS"
            font.family: Style.font_hud
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Style.hud_letter_spacing
            font.pixelSize: Style.text_sm
            font.weight: Font.DemiBold
            color: Colors.on_surface_variant
        }

        // Здесь я переношу лишние иконки на следующую строку, сохраняя размер области клика.
        Flow {
            id: tray_flow
            width: parent.width
            spacing: Style.space_xs

            Repeater {
                model: tray_root.tray_items

                delegate: Rectangle {
                    id: tray_item
                    required property var modelData
                    width: 36
                    height: 36
                    radius: 0
                    border.width: 1
                    border.color: tray_mouse.containsMouse ? Colors.cyan : Colors.outline_variant
                    color: tray_mouse.pressed
                        ? Style.alpha(Colors.primary, Style.press_opacity)
                        : Style.alpha(Colors.on_surface, tray_mouse.containsMouse ? Style.hover_opacity : 0)

                    Behavior on color {
                        ColorAnimation { duration: Style.motion_fast }
                    }

                    QsMenuAnchor {
                        id: menu_anchor
                        anchor.item: tray_item
                        menu: tray_item.modelData ? tray_item.modelData.menu : null
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        source: tray_item.modelData ? tray_item.modelData.icon : ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    // Здесь я повторяю рабочие способы активации и меню из старого трея.
                    MouseArea {
                        id: tray_mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            const item = tray_item.modelData;
                            if (!item) {
                                return;
                            }
                            if (mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && item.onlyMenu)) {
                                if (item.hasMenu) {
                                    menu_anchor.open();
                                }
                            } else if (mouse.button === Qt.MiddleButton) {
                                item.secondaryActivate();
                            } else {
                                item.activate();
                            }
                        }
                    }
                }
            }
        }
    }
}
