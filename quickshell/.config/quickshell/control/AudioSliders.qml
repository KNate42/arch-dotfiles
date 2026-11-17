// Thick iOS-style draggable PipeWire volume and microphone sliders with percentages
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
                    title: "Громкость",
                    icon: sliders_root.sink_icon,
                    level: sliders_root.sink_level,
                    percent: sliders_root.sink_percent,
                    muted: sliders_root.sink_muted,
                    available: sliders_root.has_sink
                },
                {
                    is_mic: true,
                    title: "Микрофон",
                    icon: sliders_root.source_icon,
                    level: sliders_root.source_level,
                    percent: sliders_root.source_percent,
                    muted: sliders_root.source_muted,
                    available: sliders_root.has_source
                }
            ]

            delegate: Rectangle {
                id: thick_slider
                required property int index
                readonly property var slider_data: parent_slider_model.slider_values[thick_slider.index]

                width: sliders_column.width
                height: 44
                radius: 14
                color: Style.alpha(Colors.surface_container_high, 0.88)
                border.width: 1
                border.color: slider_mouse.pressed
                    ? Colors.primary
                    : Style.alpha(Colors.outline_variant, Style.glass_border_opacity)
                clip: true

                readonly property bool over_left_label: !thick_slider.slider_data.muted && thick_slider.slider_data.level > 0.32
                readonly property bool over_right_label: !thick_slider.slider_data.muted && thick_slider.slider_data.level > 0.86

                Rectangle {
                    id: slider_fill
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    width: Math.max(0, Math.min(1, thick_slider.slider_data.level)) * parent.width
                    radius: parent.radius
                    color: thick_slider.slider_data.muted
                        ? Style.alpha(Colors.on_surface_variant, 0.32)
                        : Colors.primary

                    Behavior on width {
                        enabled: !slider_mouse.pressed
                        NumberAnimation {
                            duration: Style.motion_fast
                            easing.type: Style.easing
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Style.motion_fast
                            easing.type: Style.easing
                        }
                    }
                }

                Row {
                    id: left_info
                    anchors {
                        left: parent.left
                        leftMargin: Style.space_md
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Style.space_sm

                    Text {
                        id: slider_icon_text
                        anchors.verticalCenter: parent.verticalCenter
                        text: thick_slider.slider_data.icon
                        font.family: Style.font_mono
                        font.pixelSize: 18
                        color: thick_slider.over_left_label ? Colors.on_primary : Colors.on_surface
                    }

                    Text {
                        id: slider_title_text
                        anchors.verticalCenter: parent.verticalCenter
                        text: thick_slider.slider_data.title
                        font.family: Style.font_ui
                        font.pixelSize: Style.text_sm
                        font.weight: Font.Medium
                        color: thick_slider.over_left_label ? Colors.on_primary : Colors.on_surface
                    }
                }

                Text {
                    id: percent_label
                    anchors {
                        right: parent.right
                        rightMargin: Style.space_md
                        verticalCenter: parent.verticalCenter
                    }
                    text: !thick_slider.slider_data.available
                        ? "--"
                        : (thick_slider.slider_data.muted
                            ? ("MUTE · " + thick_slider.slider_data.percent + "%")
                            : (thick_slider.slider_data.percent + "%"))
                    font.family: Style.font_mono
                    font.pixelSize: Style.text_sm
                    font.weight: Font.DemiBold
                    color: thick_slider.over_right_label
                        ? Colors.on_primary
                        : (thick_slider.slider_data.muted ? Colors.on_surface_variant : Colors.on_surface)
                }

                // Здесь я разделяю короткий клик по иконке слева (переключение mute) и перетаскивание ползунка мышью
                MouseArea {
                    id: slider_mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    property real press_start_x: 0
                    property bool dragged: false

                    onPressed: mouse => {
                        slider_mouse.press_start_x = mouse.x;
                        slider_mouse.dragged = false;
                        if (mouse.x > 40) {
                            sliders_root.set_audio_level(thick_slider.slider_data.is_mic, mouse.x / thick_slider.width);
                        }
                    }

                    onPositionChanged: mouse => {
                        if (!slider_mouse.pressed) {
                            return;
                        }
                        if (Math.abs(mouse.x - slider_mouse.press_start_x) > 4 || slider_mouse.press_start_x > 40) {
                            slider_mouse.dragged = true;
                            sliders_root.set_audio_level(thick_slider.slider_data.is_mic, mouse.x / thick_slider.width);
                        }
                    }

                    onReleased: mouse => {
                        if (!slider_mouse.dragged && slider_mouse.press_start_x <= 40) {
                            sliders_root.toggle_audio_mute(thick_slider.slider_data.is_mic);
                        }
                    }

                    onWheel: wheel => {
                        const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                        sliders_root.set_audio_level(
                            thick_slider.slider_data.is_mic,
                            thick_slider.slider_data.level + step
                        );
                    }
                }
            }
        }
    }
}
