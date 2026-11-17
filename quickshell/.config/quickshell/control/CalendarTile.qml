// Russian current-month calendar bento tile with Monday-first layout and primary circle for today
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import "../theme"

BentoTile {
    id: calendar_root
    tile_index: 4
    implicitHeight: 204

    readonly property var ru_months: [
        "Январь",
        "Февраль",
        "Март",
        "Апрель",
        "Май",
        "Июнь",
        "Июль",
        "Август",
        "Сентябрь",
        "Октябрь",
        "Ноябрь",
        "Декабрь"
    ]

    readonly property var weekday_headers: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    SystemClock {
        id: cal_clock // cal = calendar
        precision: SystemClock.Minutes
    }

    readonly property int cur_year: cal_clock.date ? cal_clock.date.getFullYear() : 2026 // cur = current
    readonly property int cur_month: cal_clock.date ? cal_clock.date.getMonth() : 0
    readonly property int today_day: cal_clock.date ? cal_clock.date.getDate() : 1

    readonly property string month_title: (calendar_root.ru_months[calendar_root.cur_month] ?? "")
        + " " + calendar_root.cur_year

    // Здесь я перевожу день недели из формата JS (0 = воскресенье) в сетку, где 0 = понедельник
    readonly property int first_weekday_offset: {
        const first_dt = new Date(calendar_root.cur_year, calendar_root.cur_month, 1); // dt = date
        return (first_dt.getDay() + 6) % 7;
    }

    readonly property int days_in_month: {
        const last_dt = new Date(calendar_root.cur_year, calendar_root.cur_month + 1, 0);
        return last_dt.getDate();
    }

    Column {
        id: cal_column
        anchors {
            fill: parent
            margins: Style.space_md
        }
        spacing: 6

        Row {
            id: cal_header_row
            width: parent.width
            spacing: Style.space_xs

            Text {
                id: cal_icon
                anchors.verticalCenter: parent.verticalCenter
                text: "󰃭"
                font.family: Style.font_mono
                font.pixelSize: Style.text_md
                color: Colors.primary
            }

            Text {
                id: cal_title
                anchors.verticalCenter: parent.verticalCenter
                text: calendar_root.month_title
                font.family: Style.font_ui
                font.pixelSize: Style.text_sm
                font.weight: Font.DemiBold
                color: Colors.on_surface
                elide: Text.ElideRight
            }
        }

        Row {
            id: weekdays_row
            width: parent.width

            Repeater {
                model: calendar_root.weekday_headers

                delegate: Text {
                    id: weekday_label
                    required property string modelData
                    required property int index

                    width: weekdays_row.width / 7
                    text: weekday_label.modelData
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Style.font_ui
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: weekday_label.index >= 5 ? Colors.secondary : Colors.on_surface_variant
                }
            }
        }

        // Здесь я строю 42 ячейки (6 недель по 7 дней) и выделяю сегодняшнее число кружком цвета primary
        Grid {
            id: days_grid
            width: parent.width
            columns: 7
            rowSpacing: 2

            Repeater {
                model: 42

                delegate: Item {
                    id: day_cell
                    required property int index

                    readonly property int day_num: day_cell.index - calendar_root.first_weekday_offset + 1 // num = number
                    readonly property bool in_month: day_cell.day_num >= 1 && day_cell.day_num <= calendar_root.days_in_month
                    readonly property bool is_today: day_cell.in_month && day_cell.day_num === calendar_root.today_day
                    readonly property bool is_weekend: (day_cell.index % 7) >= 5

                    width: days_grid.width / 7
                    height: 21

                    Rectangle {
                        id: today_circle
                        anchors.centerIn: parent
                        width: 21
                        height: 21
                        radius: Style.radius_pill
                        visible: day_cell.is_today
                        color: Colors.primary
                    }

                    Text {
                        id: day_text
                        anchors.centerIn: parent
                        visible: day_cell.in_month
                        text: day_cell.in_month ? String(day_cell.day_num) : ""
                        font.family: Style.font_mono
                        font.pixelSize: 10
                        font.weight: day_cell.is_today ? Font.Bold : Font.Medium
                        color: day_cell.is_today
                            ? Colors.on_primary
                            : (day_cell.is_weekend ? Colors.on_surface_variant : Colors.on_surface)
                    }
                }
            }
        }
    }
}
