// System monitor bento tile with dual circular gauges for CPU and memory usage polled every 2 seconds
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell.Io
import "../theme"

BentoTile {
    id: system_root
    tile_index: 4
    implicitHeight: 204

    property int cpu_percent: 0
    property int mem_percent: 0 // mem = memory
    property string mem_detail: ""

    property real prev_cpu_total: 0 // prev = previous
    property real prev_cpu_idle: 0

    // Здесь я считаю загрузку процессора по разнице счётчиков /proc/stat между двумя замерами
    function parse_cpu_stat(raw_text) {
        if (!raw_text) {
            return;
        }
        const first_line = raw_text.split("\n")[0] ?? "";
        if (!first_line.startsWith("cpu")) {
            return;
        }
        const parts = first_line.trim().split(/\s+/);
        if (parts.length < 5) {
            return;
        }
        let total = 0;
        for (let i = 1; i < parts.length && i <= 8; i++) {
            const val = parseFloat(parts[i]); // val = counter value
            if (!isNaN(val)) {
                total += val;
            }
        }
        const idle = (parseFloat(parts[4]) || 0) + (parseFloat(parts[5]) || 0);
        if (system_root.prev_cpu_total > 0) {
            const diff_total = total - system_root.prev_cpu_total;
            const diff_idle = idle - system_root.prev_cpu_idle;
            if (diff_total > 0) {
                const busy_ratio = 1.0 - (diff_idle / diff_total);
                system_root.cpu_percent = Math.max(0, Math.min(100, Math.round(busy_ratio * 100)));
            }
        }
        system_root.prev_cpu_total = total;
        system_root.prev_cpu_idle = idle;
    }

    // Здесь я вычисляю занятую оперативную память из MemTotal и MemAvailable в /proc/meminfo
    function parse_mem_info(raw_text) {
        if (!raw_text) {
            return;
        }
        const lines = raw_text.split("\n");
        let mem_total_kb = 0; // kb = kilobytes
        let mem_avail_kb = 0; // avail = available
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line.startsWith("MemTotal:")) {
                mem_total_kb = parseFloat(line.replace(/[^0-9]/g, "")) || 0;
            } else if (line.startsWith("MemAvailable:")) {
                mem_avail_kb = parseFloat(line.replace(/[^0-9]/g, "")) || 0;
            }
            if (mem_total_kb > 0 && mem_avail_kb > 0) {
                break;
            }
        }
        if (mem_total_kb > 0) {
            const used_kb = Math.max(0, mem_total_kb - mem_avail_kb);
            system_root.mem_percent = Math.max(0, Math.min(100, Math.round((used_kb / mem_total_kb) * 100)));
            const used_gb = (used_kb / 1048576).toFixed(1); // gb = gigabytes
            const total_gb = (mem_total_kb / 1048576).toFixed(0);
            system_root.mem_detail = used_gb + " / " + total_gb + " ГБ";
        }
    }

    FileView {
        id: stat_file
        path: "/proc/stat"
        onLoaded: system_root.parse_cpu_stat(stat_file.text())
    }

    FileView {
        id: mem_file
        path: "/proc/meminfo"
        onLoaded: system_root.parse_mem_info(mem_file.text())
    }

    Timer {
        id: poll_timer
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat_file.reload();
            mem_file.reload();
        }
    }

    Column {
        id: sys_column // sys = system
        anchors {
            fill: parent
            margins: Style.space_md
        }
        spacing: Style.space_md

        Row {
            id: sys_header_row
            width: parent.width
            spacing: Style.space_xs

            Text {
                id: sys_icon
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍛"
                font.family: Style.font_mono
                font.pixelSize: Style.text_md
                color: Colors.primary
            }

            Text {
                id: sys_title
                anchors.verticalCenter: parent.verticalCenter
                text: "Система"
                font.family: Style.font_ui
                font.pixelSize: Style.text_sm
                font.weight: Font.DemiBold
                color: Colors.on_surface
            }
        }

        Row {
            id: rings_row
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space_md

            Repeater {
                id: gauge_model
                model: 2
                readonly property var gauge_values: [
                    {
                        label: "CPU",
                        sub: "Процессор",
                        percent: system_root.cpu_percent,
                        ring_color: Colors.primary
                    },
                    {
                        label: "ОЗУ",
                        sub: system_root.mem_detail !== "" ? system_root.mem_detail : "Память",
                        percent: system_root.mem_percent,
                        ring_color: Colors.tertiary
                    }
                ]

                delegate: Column {
                    id: gauge_col // col = column
                    required property int index
                    readonly property var gauge_data: gauge_model.gauge_values[gauge_col.index]

                    width: (sys_column.width - rings_row.spacing) / 2
                    spacing: Style.space_xs

                    property real animated_ratio: Math.max(0.0, Math.min(1.0, gauge_col.gauge_data.percent / 100.0))

                    Behavior on animated_ratio {
                        NumberAnimation {
                            duration: Style.motion_slow
                            easing.type: Style.easing
                        }
                    }

                    onAnimated_ratioChanged: ring_canvas.requestPaint()

                    Item {
                        id: ring_box
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(72, gauge_col.width)
                        height: width

                        Canvas {
                            id: ring_canvas
                            anchors.fill: parent

                            property color active_color: gauge_col.gauge_data.ring_color
                            property color track_color: Style.alpha(Colors.surface_container_high, 0.95)

                            onActive_colorChanged: ring_canvas.requestPaint()
                            onTrack_colorChanged: ring_canvas.requestPaint()

                            // Здесь я рисую фоновое и заполненное кольцо прогресса со скруглёнными краями
                            onPaint: {
                                const ctx = ring_canvas.getContext("2d"); // ctx = canvas 2d context
                                ctx.reset();
                                const cx = ring_canvas.width / 2;
                                const cy = ring_canvas.height / 2;
                                const radius = (Math.min(ring_canvas.width, ring_canvas.height) / 2) - 6;
                                const start_angle = -Math.PI / 2;
                                const end_angle = start_angle + (Math.PI * 2 * gauge_col.animated_ratio);

                                ctx.lineWidth = 7;
                                ctx.lineCap = "round";

                                ctx.beginPath();
                                ctx.arc(cx, cy, radius, 0, Math.PI * 2, false);
                                ctx.strokeStyle = ring_canvas.track_color;
                                ctx.stroke();

                                if (gauge_col.animated_ratio > 0.005) {
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, radius, start_angle, end_angle, false);
                                    ctx.strokeStyle = ring_canvas.active_color;
                                    ctx.stroke();
                                }
                            }
                        }

                        Text {
                            id: ring_percent_text
                            anchors.centerIn: parent
                            text: gauge_col.gauge_data.percent + "%"
                            font.family: Style.font_mono
                            font.pixelSize: Style.text_sm
                            font.weight: Font.Bold
                            color: Colors.on_surface
                        }
                    }

                    Text {
                        id: gauge_label
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: gauge_col.gauge_data.label
                        font.family: Style.font_ui
                        font.pixelSize: Style.text_xs
                        font.weight: Font.DemiBold
                        color: Colors.on_surface
                    }

                    Text {
                        id: gauge_sublabel
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: gauge_col.gauge_data.sub
                        font.family: Style.font_ui
                        font.pixelSize: 10
                        color: Colors.on_surface_variant
                    }
                }
            }
        }
    }
}
