// Desktop background clock widget with Russian date and time-of-day greeting on all monitors
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

Scope {
    id: desktop_root

    readonly property var ru_weekdays: [
        "воскресенье",
        "понедельник",
        "вторник",
        "среда",
        "четверг",
        "пятница",
        "суббота"
    ]

    readonly property var ru_months_genitive: [
        "января",
        "февраля",
        "марта",
        "апреля",
        "мая",
        "июня",
        "июля",
        "августа",
        "сентября",
        "октября",
        "ноября",
        "декабря"
    ]

    // Здесь я собираю дату вручную по таблицам склонений, чтобы формат «вторник, 17 ноября» не зависел от системной локали
    function format_ru_date(dt) { // dt = current Date instance
        if (!dt) {
            return "";
        }
        const day_name = desktop_root.ru_weekdays[dt.getDay()] ?? "";
        const month_name = desktop_root.ru_months_genitive[dt.getMonth()] ?? "";
        return day_name + ", " + dt.getDate() + " " + month_name;
    }

    // Здесь я выбираю приветствие по текущему часу суток
    function greeting_for_hour(hr) { // hr = hour in 0..23
        if (hr >= 5 && hr < 12) {
            return "Доброе утро";
        }
        if (hr >= 12 && hr < 18) {
            return "Добрый день";
        }
        if (hr >= 18 && hr < 23) {
            return "Добрый вечер";
        }
        return "Доброй ночи";
    }

    SystemClock {
        id: sys_clock // sys = system
        precision: SystemClock.Seconds
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: desktop_window
            required property var modelData

            screen: desktop_window.modelData
            focusable: false
            exclusiveZone: 0
            color: "transparent"

            WlrLayershell.namespace: "dots-desktop"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Здесь я задаю пустую область ввода, чтобы клики мыши проходили сквозь виджет к рабочему столу
            mask: Region {}

            anchors {
                left: true
                bottom: true
            }

            margins {
                left: 56
                bottom: 56
            }

            implicitWidth: clock_column.implicitWidth + Style.space_xl
            implicitHeight: clock_column.implicitHeight + Style.space_lg

            Column {
                id: clock_column
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                }
                spacing: Style.space_xs

                Item {
                    id: greeting_box
                    implicitWidth: greeting_main.implicitWidth
                    implicitHeight: greeting_main.implicitHeight

                    Text {
                        id: greeting_shadow
                        x: 1
                        y: 2
                        text: greeting_main.text
                        font.family: Style.font_ui
                        font.pixelSize: Style.text_md
                        font.weight: Font.Medium
                        font.letterSpacing: 0.6
                        color: Style.alpha(Colors.shadow, 0.18)
                    }

                    Text {
                        id: greeting_main
                        text: desktop_root.greeting_for_hour(sys_clock.date.getHours())
                        font.family: Style.font_ui
                        font.pixelSize: Style.text_md
                        font.weight: Font.Medium
                        font.letterSpacing: 0.6
                        color: Colors.on_surface_variant
                    }
                }

                Item {
                    id: time_box
                    implicitWidth: time_main.implicitWidth + Style.space_md
                    implicitHeight: time_main.implicitHeight - Style.space_md

                    Text {
                        id: time_shadow_outer
                        anchors.verticalCenter: parent.verticalCenter
                        x: 2
                        anchors.verticalCenterOffset: 6
                        text: time_main.text
                        font.family: Style.font_ui
                        font.pixelSize: 132
                        font.weight: Font.ExtraLight
                        font.letterSpacing: -3
                        color: Style.alpha(Colors.shadow, 0.16)
                    }

                    Text {
                        id: time_shadow_inner
                        anchors.verticalCenter: parent.verticalCenter
                        x: 1
                        anchors.verticalCenterOffset: 3
                        text: time_main.text
                        font.family: Style.font_ui
                        font.pixelSize: 132
                        font.weight: Font.ExtraLight
                        font.letterSpacing: -3
                        color: Style.alpha(Colors.shadow, 0.19)
                    }

                    Text {
                        id: time_glow_tertiary
                        anchors.verticalCenter: parent.verticalCenter
                        x: 2
                        anchors.verticalCenterOffset: -2
                        text: time_main.text
                        font.family: Style.font_ui
                        font.pixelSize: 132
                        font.weight: Font.ExtraLight
                        font.letterSpacing: -3
                        color: Style.alpha(Colors.tertiary, 0.36)
                        style: Text.Outline
                        styleColor: Style.alpha(Colors.tertiary, 0.18)
                    }

                    Text {
                        id: time_main
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatTime(sys_clock.date, "HH:mm")
                        font.family: Style.font_ui
                        font.pixelSize: 132
                        font.weight: Font.ExtraLight
                        font.letterSpacing: -3
                        color: Colors.primary
                    }
                }

                Item {
                    id: date_box
                    implicitWidth: date_main.implicitWidth
                    implicitHeight: date_main.implicitHeight

                    Text {
                        id: date_shadow
                        x: 1
                        y: 2
                        text: date_main.text
                        font.family: Style.font_ui
                        font.pixelSize: Style.text_xl
                        font.weight: Font.Medium
                        color: Style.alpha(Colors.shadow, 0.18)
                    }

                    Text {
                        id: date_main
                        text: desktop_root.format_ru_date(sys_clock.date)
                        font.family: Style.font_ui
                        font.pixelSize: Style.text_xl
                        font.weight: Font.Medium
                        color: Colors.on_surface
                    }
                }
            }
        }
    }
}
