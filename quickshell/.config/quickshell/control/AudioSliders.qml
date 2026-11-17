// PipeWire audio controls with neon segment meters and persistent drag targets
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell.Services.Pipewire
import "../theme"

BentoTile {
    id: sliders_root
    tile_index: 2
    implicitHeight: sliders_column.implicitHeight + Style.space_md * 2

    readonly property var sink_node: Pipewire.defaultAudioSink
    readonly property var sink_audio: sliders_root.sink_node ? sliders_root.sink_node.audio : null
    readonly property bool has_sink: sliders_root.sink_audio !== null && sliders_root.sink_audio !== undefined
    readonly property bool sink_muted: sliders_root.has_sink ? Boolean(sliders_root.sink_audio.muted) : false
    readonly property real sink_level: sliders_root.has_sink && !isNaN(sliders_root.sink_audio.volume)
        ? Math.max(0.0, Math.min(1.0, sliders_root.sink_audio.volume))
        : 0.0
    readonly property int sink_percent: Math.round(sliders_root.sink_level * 100)

    readonly property var source_node: Pipewire.defaultAudioSource
    readonly property var source_audio: sliders_root.source_node ? sliders_root.source_node.audio : null
    readonly property bool has_source: sliders_root.source_audio !== null && sliders_root.source_audio !== undefined
    readonly property bool source_muted: sliders_root.has_source ? Boolean(sliders_root.source_audio.muted) : false
    readonly property real source_level: sliders_root.has_source && !isNaN(sliders_root.source_audio.volume)
        ? Math.max(0.0, Math.min(1.0, sliders_root.source_audio.volume))
        : 0.0
    readonly property int source_percent: Math.round(sliders_root.source_level * 100)

    readonly property string sink_icon: {
        if (!sliders_root.has_sink || sliders_root.sink_muted || sliders_root.sink_percent === 0) {
            return "󰝟";
        }
        if (sliders_root.sink_percent < 34) {
            return "󰕿";
        }
        if (sliders_root.sink_percent < 67) {
            return "󰖀";
        }
        return "󰕾";
    }

    readonly property string source_icon: {
        if (!sliders_root.has_source || sliders_root.source_muted || sliders_root.source_percent === 0) {
            return "󰍭";
        }
        return "󰍬";
    }

    PwObjectTracker {
        objects: {
            const list = [];
            if (Pipewire.defaultAudioSink) {
                list.push(Pipewire.defaultAudioSink);
            }
            if (Pipewire.defaultAudioSource) {
                list.push(Pipewire.defaultAudioSource);
            }
            return list;
        }
    }

    // Здесь я обновляю громкость выхода или входа PipeWire с ограничением диапазона 0..1
    function set_audio_level(is_mic, ratio) { // ratio = normalized level 0..1
        const clamped = Math.max(0.0, Math.min(1.0, ratio));
        if (is_mic) {
            if (sliders_root.has_source) {
                sliders_root.source_audio.volume = clamped;
                if (clamped > 0.01 && sliders_root.source_audio.muted) {
                    sliders_root.source_audio.muted = false;
                }
            }
        } else {
            if (sliders_root.has_sink) {
                sliders_root.sink_audio.volume = clamped;
                if (clamped > 0.01 && sliders_root.sink_audio.muted) {
                    sliders_root.sink_audio.muted = false;
                }
            }
        }
    }

    function toggle_audio_mute(is_mic) {
        if (is_mic) {
            if (sliders_root.has_source) {
                sliders_root.source_audio.muted = !sliders_root.source_audio.muted;
            }
        } else {
            if (sliders_root.has_sink) {
                sliders_root.sink_audio.muted = !sliders_root.sink_audio.muted;
            }
        }
    }

    Column {
        id: sliders_column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Style.space_md
        }
        spacing: Style.space_sm

        Repeater {
            id: parent_slider_model
            // Здесь я сохраняю делегаты при изменении уровня, чтобы не терять захват мыши.
            model: 2
            readonly property var slider_values: [
                {
                    is_mic: false,
                    title: "OUTPUT",
                    icon: sliders_root.sink_icon,
                    level: sliders_root.sink_level,
                    percent: sliders_root.sink_percent,
                    muted: sliders_root.sink_muted,
                    available: sliders_root.has_sink
                },
                {
                    is_mic: true,
                    title: "MIC",
                    icon: sliders_root.source_icon,
                    level: sliders_root.source_level,
                    percent: sliders_root.source_percent,
                    muted: sliders_root.source_muted,
                    available: sliders_root.has_source
                }
            ]

            delegate: HudPanel {
                id: thick_slider
                required property int index
                readonly property var slider_data: parent_slider_model.slider_values[index]
                width: sliders_column.width
                height: 54
                cut: 6
                brackets: false
                scanlines: false
                accent: slider_data.is_mic ? Colors.magenta : Colors.mint
                active: slider_mouse.containsMouse
                Row {
                    x: 12; y: 7; spacing: 8
                    NeonText { text: thick_slider.slider_data.icon; color: thick_slider.accent; pixel_size: Style.text_md }
                    Text {
                        text: thick_slider.slider_data.title
                        font.family: Style.font_hud
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: Style.hud_letter_spacing
                        font.pixelSize: Style.text_xs
                        color: Colors.on_surface
                    }
                }
                Text {
                    anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 7 }
                    text: !thick_slider.slider_data.available ? "--" :
                        (thick_slider.slider_data.muted ? "MUTE / " : "") + thick_slider.slider_data.percent + "%"
                    font.family: Style.font_hud
                    font.pixelSize: Style.text_xs
                    color: thick_slider.accent
                }
                SegmentBar {
                    id: slider_segments
                    x: 44; y: 32
                    width: Math.max(0, thick_slider.width - x - 12)
                    height: 10
                    value: thick_slider.slider_data.level
                    muted: thick_slider.slider_data.muted
                    accent: thick_slider.accent
                }
                // Здесь я сохраняю захват мыши и вычисляю уровень по видимой сегментной шкале.
                MouseArea {
                    id: slider_mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    property real press_start_x: 0
                    property bool dragged: false
                    function set_from_x(point_x) {
                        if (slider_segments.width > 0)
                            sliders_root.set_audio_level(thick_slider.slider_data.is_mic,
                                (point_x - slider_segments.x) / slider_segments.width);
                    }
                    onPressed: mouse => {
                        press_start_x = mouse.x;
                        dragged = false;
                        if (mouse.x > 40) set_from_x(mouse.x);
                    }
                    onPositionChanged: mouse => {
                        if (pressed && (Math.abs(mouse.x - press_start_x) > 4 || press_start_x > 40)) {
                            dragged = true;
                            set_from_x(mouse.x);
                        }
                    }
                    onReleased: {
                        if (!dragged && press_start_x <= 40)
                            sliders_root.toggle_audio_mute(thick_slider.slider_data.is_mic);
                    }
                    onWheel: wheel => {
                        sliders_root.set_audio_level(thick_slider.slider_data.is_mic,
                            thick_slider.slider_data.level + (wheel.angleDelta.y > 0 ? 0.05 : -0.05));
                    }
                }
            }
        }
    }
}
