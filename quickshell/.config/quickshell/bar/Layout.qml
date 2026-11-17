// Active keyboard layout indicator listening to Hyprland activelayout events
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"

BarChip {
    id: layout_root

    property string current_layout: "EN"

    icon: "󰌌"
    label: layout_root.current_layout
    icon_color: Colors.on_surface
    text_color: Colors.on_surface

    // Здесь я разбираю строку события activelayout вида "клавиатура,раскладка" с учётом возможных запятых в имени
    function update_layout_from_event(raw_payload) {
        if (!raw_payload) {
            return;
        }
        const comma_idx = raw_payload.indexOf(","); // idx = index
        const layout_part = (comma_idx >= 0 ? raw_payload.substring(comma_idx + 1) : raw_payload).trim().toLowerCase();
        if (layout_part.includes("ru") || layout_part.includes("рус")) {
            layout_root.current_layout = "RU";
        } else if (layout_part.includes("en") || layout_part.includes("us") || layout_part.includes("англ")) {
            layout_root.current_layout = "EN";
        } else if (layout_part.length >= 2) {
            layout_root.current_layout = layout_part.substring(0, 2).toUpperCase();
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event && event.name === "activelayout") {
                layout_root.update_layout_from_event(event.data);
            }
        }
    }

    // Здесь я один раз спрашиваю текущую раскладку при создании: панель нового экрана (ТВ) иначе показывала бы EN до первого переключения
    Process {
        id: layout_query
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(this.text).keyboards || [];
                    const main_kb = keyboards.find(kb => kb.main) || keyboards[0]; // kb = keyboard
                    if (main_kb && main_kb.active_keymap) {
                        layout_root.update_layout_from_event("," + main_kb.active_keymap);
                    }
                } catch (err) {
                    return;
                }
            }
        }
    }

    onClicked: {
        layout_switch.running = false;
        layout_switch.running = true;
    }

    Process {
        id: layout_switch
        command: ["hyprctl", "switchxkblayout", "all", "next"]
    }
}
