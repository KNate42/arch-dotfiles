// CPU and memory telemetry with neon segment meters polled every two seconds
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

    // Здесь я показываю оба датчика строками, чтобы проценты читались без круглых приборов.
    Column {
        id: sys_column
        x: Style.space_md; y: Style.space_md
        width: parent.width - Style.space_md * 2
        spacing: 12
        NeonText { text: ">> STATUS"; pixel_size: Style.text_xs; color: Colors.mint; spacing: 0.5 }
        Repeater {
            model: 2
            delegate: Column {
                id: gauge_column
                required property int index
                readonly property int percent: index === 0 ? system_root.cpu_percent : system_root.mem_percent
                readonly property color meter_color: index === 0 ? Colors.cyan : Colors.magenta
                width: sys_column.width
                spacing: 5
                Text {
                    text: (gauge_column.index === 0 ? "CPU" : "RAM") + " :: " + gauge_column.percent + "%"
                    font.family: Style.font_hud
                    font.pixelSize: Style.text_xs
                    font.letterSpacing: 0.5
                    color: gauge_column.meter_color
                }
                SegmentBar {
                    width: parent.width
                    count: 10
                    value: gauge_column.percent / 100
                    accent: gauge_column.meter_color
                }
            }
        }
        Text {
            width: parent.width
            text: system_root.mem_detail
            elide: Text.ElideRight
            font.family: Style.font_hud
            font.pixelSize: 10
            color: Colors.on_surface_variant
        }
    }
}
