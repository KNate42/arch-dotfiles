// Status bar clock showing time and revealing date on hover or click
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import "../theme"

Rectangle {
    id: clock_root

    property bool date_pinned: false
    readonly property bool show_date: clock_root.date_pinned || clock_mouse.containsMouse

    implicitWidth: clock_text.implicitWidth + 16
    implicitHeight: 24
    radius: 6
    color: clock_root.show_date ? Colors.surface_container_high : "transparent"

    SystemClock {
        id: sys_clock // sys = system
        precision: SystemClock.Minutes
    }

    Text {
        id: clock_text
        anchors.centerIn: parent
        text: Qt.formatDateTime(sys_clock.date, clock_root.show_date ? "ddd, dd MMM yyyy  HH:mm" : "HH:mm")
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        font.bold: true
        color: Colors.on_surface
    }

    MouseArea {
        id: clock_mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: clock_root.date_pinned = !clock_root.date_pinned
    }
}
