// Status bar clock showing time and localized Russian short date
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import "../theme"

Rectangle {
    id: clock_root

    implicitWidth: clock_row.implicitWidth + Style.space_md * 2
    implicitHeight: Style.bar_item_height
    radius: Style.radius_pill
    color: clock_mouse.pressed
        ? Style.alpha(Colors.on_surface, Style.press_opacity)
        : (clock_mouse.containsMouse
            ? Style.alpha(Colors.on_surface, Style.hover_opacity)
            : Style.alpha(Colors.on_surface, 0.0))

    Behavior on color {
        ColorAnimation {
            duration: Style.motion_fast
            easing.type: Style.easing
        }
    }

    // Здесь я форматирую дату в русской локали и поднимаю первую букву дня недели («Вт, 17 нояб.»)
    function format_ru_date(dt) { // dt = current date value
        if (!dt) {
            return "";
        }
        const raw_str = dt.toLocaleString(Qt.locale("ru_RU"), "ddd, d MMM");
        if (raw_str.length === 0) {
            return "";
        }
        return raw_str.charAt(0).toUpperCase() + raw_str.slice(1);
    }

    SystemClock {
        id: sys_clock // sys = system
        precision: SystemClock.Minutes
    }

    Row {
        id: clock_row
        anchors.centerIn: parent
        spacing: Style.space_sm

        Text {
            id: time_label
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatTime(sys_clock.date, "HH:mm")
            font.family: Style.font_ui
            font.pixelSize: Style.text_md
            font.weight: Font.DemiBold
            color: Colors.on_surface
        }

        Text {
            id: date_label
            anchors.verticalCenter: parent.verticalCenter
            text: clock_root.format_ru_date(sys_clock.date)
            font.family: Style.font_ui
            font.pixelSize: Style.text_xs
            color: Colors.on_surface_variant
        }
    }

    MouseArea {
        id: clock_mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }
}
