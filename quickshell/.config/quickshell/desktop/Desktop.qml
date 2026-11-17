// Desktop neon clock with chromatic split, Russian greeting and periodic signal glitch
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

            // Здесь я оставляю часы прямо на обоях без подложки и скруглений.
            Column {
                id: clock_column
                anchors { left: parent.left; leftMargin: 6; bottom: parent.bottom; bottomMargin: 6 }
                spacing: Style.space_xs
                NeonText {
                    text: "// " + desktop_root.greeting_for_hour(sys_clock.date.getHours()) + ", NIK"
                    color: Colors.mint
                    glow_color: Colors.mint
                    pixel_size: Style.text_md
                }
                NeonText {
                    id: time_main
                    text: Qt.formatTime(sys_clock.date, "HH:mm")
                    pixel_size: 132
                    weight: Font.Medium
                    split: true
                    color: "#ffffff"
                    glow_color: Colors.cyan
                    spacing: 3
                }
                NeonText {
                    text: desktop_root.format_ru_date(sys_clock.date)
                    color: Colors.magenta
                    glow_color: Colors.magenta
                    pixel_size: Style.text_lg
                    spacing: 3
                }
            }
            // Здесь я даю редкий случайный сбой сигнала примерно раз в двадцать секунд.
            Timer {
                interval: 18000 + Math.round(Math.random() * 4000)
                running: desktop_window.visible
                repeat: true
                onTriggered: {
                    time_main.glitch();
                    interval = 18000 + Math.round(Math.random() * 4000);
                }
            }
        }
    }
}
