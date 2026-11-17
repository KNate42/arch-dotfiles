// HUD command switches for Wi-Fi, Do Not Disturb, Audio Mute and Microphone
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../theme"

Item {
    id: toggles_root

    property int tile_index: 1
    property bool wifi_enabled: true
    property string pending_wifi_arg: "on" // arg = command argument

    readonly property var sink_node: Pipewire.defaultAudioSink
    readonly property var sink_audio: toggles_root.sink_node ? toggles_root.sink_node.audio : null
    readonly property bool has_sink: toggles_root.sink_audio !== null && toggles_root.sink_audio !== undefined
    readonly property bool sink_muted: toggles_root.has_sink ? Boolean(toggles_root.sink_audio.muted) : false

    readonly property var source_node: Pipewire.defaultAudioSource
    readonly property var source_audio: toggles_root.source_node ? toggles_root.source_node.audio : null
    readonly property bool has_source: toggles_root.source_audio !== null && toggles_root.source_audio !== undefined
    readonly property bool source_muted: toggles_root.has_source ? Boolean(toggles_root.source_audio.muted) : false

    implicitHeight: toggles_grid.implicitHeight

    PwObjectTracker {
        objects: {
            const tracked = [];
            if (Pipewire.defaultAudioSink) {
                tracked.push(Pipewire.defaultAudioSink);
            }
            if (Pipewire.defaultAudioSource) {
                tracked.push(Pipewire.defaultAudioSource);
            }
            return tracked;
        }
    }

    // Здесь я опрашиваю состояние Wi-Fi через nmcli при открытии панели и периодически по таймеру
    Process {
        id: wifi_status_proc // proc = process
        command: ["env", "LC_ALL=C", "nmcli", "radio", "wifi"]

        stdout: SplitParser {
            onRead: line => {
                const state_str = line.trim().toLowerCase();
                if (state_str === "enabled") {
                    toggles_root.wifi_enabled = true;
                } else if (state_str === "disabled") {
                    toggles_root.wifi_enabled = false;
                }
            }
        }
    }

    Process {
        id: wifi_toggle_proc
        command: ["nmcli", "radio", "wifi", toggles_root.pending_wifi_arg]
        onExited: {
            wifi_status_proc.running = false;
            wifi_status_proc.running = true;
        }
    }

    Timer {
        id: wifi_poll_timer
        interval: 4000
        running: Panels.control_open
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!wifi_toggle_proc.running) {
                wifi_status_proc.running = false;
                wifi_status_proc.running = true;
            }
        }
    }

    // Здесь я переключаю выбранную плитку: сеть через nmcli, DND через синглтон Panels, звук через Pipewire
    function trigger_tile(kind) {
        if (kind === "wifi") {
            const next_state = !toggles_root.wifi_enabled;
            toggles_root.wifi_enabled = next_state;
            toggles_root.pending_wifi_arg = next_state ? "on" : "off";
            wifi_toggle_proc.running = false;
            wifi_toggle_proc.running = true;
        } else if (kind === "dnd") {
            Panels.dnd = !Panels.dnd;
        } else if (kind === "mute") {
            if (toggles_root.has_sink) {
                toggles_root.sink_audio.muted = !toggles_root.sink_audio.muted;
            }
        } else if (kind === "mic") {
            if (toggles_root.has_source) {
                toggles_root.source_audio.muted = !toggles_root.source_audio.muted;
            }
        }
    }

    readonly property var tiles_data: [
        {
            kind: "wifi",
            title: "WIFI",
            icon: toggles_root.wifi_enabled ? "󰖩" : "󰖪",
            active: toggles_root.wifi_enabled
        },
        {
            kind: "dnd",
            title: "DND",
            icon: Panels.dnd ? "󰂛" : "󰂚",
            active: Panels.dnd
        },
        {
            kind: "mute",
            title: "MUTE",
            icon: toggles_root.sink_muted ? "󰝟" : "󰕾",
            active: toggles_root.sink_muted
        },
        {
            kind: "mic",
            title: "MIC",
            icon: toggles_root.source_muted ? "󰍭" : "󰍬",
            active: !toggles_root.source_muted && toggles_root.has_source
        }
    ]

    Grid {
        id: toggles_grid
        width: parent.width
        columns: 2
        rowSpacing: Style.tile_gap
        columnSpacing: Style.tile_gap
        Repeater {
            model: 4
            delegate: BentoTile {
                id: toggle_card
                required property int index
                readonly property var tile_data: toggles_root.tiles_data[index]
                readonly property bool is_active: Boolean(tile_data.active)
                tile_index: toggles_root.tile_index
                reveal_delay: index * 25
                width: (toggles_grid.width - Style.tile_gap) / 2
                height: 52
                accent: card_mouse.containsMouse ? Colors.mint : Colors.cyan
                active: is_active || card_mouse.containsMouse
                onIs_activeChanged: Qt.callLater(() => toggle_card.glitch())
                // Здесь я кладу заливку внутрь скоса, чтобы включённая команда читалась тёмным текстом.
                Rectangle {
                    anchors { fill: parent; margins: 8 }
                    color: toggle_card.is_active ? Colors.cyan : "transparent"
                }
                Text {
                    anchors.centerIn: parent
                    text: "[ " + toggle_card.tile_data.title + " :: " + (toggle_card.is_active ? "ON" : "OFF") + " ]"
                    font.family: Style.font_hud
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.5
                    font.pixelSize: Style.text_xs
                    font.weight: Font.Bold
                    color: toggle_card.is_active ? Colors.on_primary : Colors.cyan
                }
                MouseArea {
                    id: card_mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: toggles_root.trigger_tile(toggle_card.tile_data.kind)
                }
            }
        }
    }
}
