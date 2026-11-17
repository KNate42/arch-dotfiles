// PipeWire audio sink volume indicator and controller for the status bar
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell.Services.Pipewire
import "../theme"

BarChip {
    id: volume_root

    readonly property var sink_node: Pipewire.defaultAudioSink
    readonly property var sink_audio: volume_root.sink_node ? volume_root.sink_node.audio : null
    readonly property bool has_audio: volume_root.sink_audio !== null && volume_root.sink_audio !== undefined
    readonly property bool is_muted: volume_root.has_audio ? Boolean(volume_root.sink_audio.muted) : false
    readonly property real volume_level: volume_root.has_audio && !isNaN(volume_root.sink_audio.volume) ? volume_root.sink_audio.volume : 0.0
    readonly property int volume_percent: Math.round(volume_root.volume_level * 100)

    readonly property string volume_icon: {
        if (!volume_root.has_audio || volume_root.is_muted) {
            return "󰝟";
        }
        if (volume_root.volume_percent < 33) {
            return "󰕿";
        }
        if (volume_root.volume_percent < 66) {
            return "󰖀";
        }
        return "󰕾";
    }

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    icon: volume_root.volume_icon
    label: volume_root.has_audio ? (volume_root.is_muted ? "MUTE" : (volume_root.volume_percent + "%")) : "--"
    icon_color: volume_root.is_muted ? Colors.on_surface_variant : Colors.on_surface
    text_color: volume_root.is_muted ? Colors.on_surface_variant : Colors.on_surface

    onClicked: {
        if (volume_root.has_audio) {
            volume_root.sink_audio.muted = !volume_root.sink_audio.muted;
        }
    }

    onWheel: wheel => {
        if (!volume_root.has_audio) {
            return;
        }
        const delta_step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
        const next_val = Math.max(0.0, Math.min(1.0, volume_root.volume_level + delta_step)); // val = value
        volume_root.sink_audio.volume = next_val;
    }
}
