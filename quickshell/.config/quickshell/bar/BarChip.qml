// Reusable pill-shaped status bar chip with Nerd Font glyph and optional text
// This work made by Anfinogentov Nikita

import QtQuick
import "../theme"

Rectangle {
    id: chip_root

    property string icon: ""
    property string label: ""
    property color icon_color: Colors.on_surface
    property color text_color: Colors.on_surface
    property int max_label_width: 0

    signal clicked(var mouse)
    signal wheel(var wheel)

    implicitHeight: Style.bar_item_height
    implicitWidth: Math.max(
        Style.bar_item_height,
        chip_row.implicitWidth + (chip_root.label !== "" ? Style.space_sm * 2 : Style.space_xs * 2)
    )
    radius: Style.radius_pill

    // Здесь я использую прозрачную базу с тем же RGB, чтобы анимация hover и press не уходила в тёмный оттенок
    color: chip_mouse.pressed
        ? Style.alpha(Colors.on_surface, Style.press_opacity)
        : (chip_mouse.containsMouse
            ? Style.alpha(Colors.on_surface, Style.hover_opacity)
            : Style.alpha(Colors.on_surface, 0.0))

    Behavior on color {
        ColorAnimation {
            duration: Style.motion_fast
            easing.type: Style.easing
        }
    }

    Row {
        id: chip_row
        anchors.centerIn: parent
        spacing: Style.space_xs

        Text {
            id: icon_label
            visible: chip_root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: chip_root.icon
            font.family: Style.font_mono
            font.pixelSize: Style.text_md
            color: chip_root.icon_color
        }

        Text {
            id: text_label
            visible: chip_root.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: chip_root.max_label_width > 0
                ? Math.min(text_label.implicitWidth, chip_root.max_label_width)
                : text_label.implicitWidth
            text: chip_root.label
            font.family: Style.font_ui
            font.pixelSize: Style.text_sm
            font.weight: Font.Medium
            color: chip_root.text_color
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    MouseArea {
        id: chip_mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => chip_root.clicked(mouse)
        onWheel: wheel => chip_root.wheel(wheel)
    }
}
