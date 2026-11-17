// On-screen display overlay for default audio sink volume and mute changes
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "../theme"

Scope {
    id: osd_root // osd = on-screen display

    property bool osd_visible: false

    readonly property var sink_node: Pipewire.defaultAudioSink
    readonly property var sink_audio: osd_root.sink_node ? osd_root.sink_node.audio : null
    readonly property bool has_audio: osd_root.sink_audio !== null && osd_root.sink_audio !== undefined
    readonly property bool is_muted: osd_root.has_audio ? Boolean(osd_root.sink_audio.muted) : false
    readonly property real volume_level: osd_root.has_audio && !isNaN(osd_root.sink_audio.volume) ? osd_root.sink_audio.volume : 0.0
    readonly property real clamped_level: Math.max(0.0, Math.min(1.0, osd_root.volume_level))
    readonly property int volume_percent: Math.round(osd_root.volume_level * 100)

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    function show_osd() {
        osd_root.osd_visible = true;
        hide_timer.restart();
    }

    onVolume_levelChanged: {
        if (osd_root.has_audio) {
            osd_root.show_osd();
        }
    }

    onIs_mutedChanged: {
        if (osd_root.has_audio) {
            osd_root.show_osd();
        }
    }

    Timer {
        id: hide_timer
        interval: 1500
        repeat: false
        onTriggered: osd_root.osd_visible = false
    }

    PanelWindow {
        id: osd_window
        visible: osd_root.osd_visible
        WlrLayershell.namespace: "dots-osd"
        anchors {
            bottom: true
        }
        margins {
            bottom: Style.space_xl * 2
        }
        exclusiveZone: 0
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        implicitWidth: Style.space_xl * 11
        implicitHeight: Style.space_xl * 2 + Style.space_xs
        color: "transparent"

        Rectangle {
            id: osd_card
            anchors.fill: parent
            radius: Style.radius_lg
            color: Style.alpha(Colors.surface, Style.glass_opacity)
            border.width: 1
            border.color: Style.alpha(Colors.outline_variant, Style.glass_border_opacity)

            Row {
                id: osd_row
                anchors {
                    fill: parent
                    leftMargin: Style.space_lg
                    rightMargin: Style.space_lg
                }
                spacing: Style.space_md

                Text {
                    id: osd_icon
                    anchors.verticalCenter: parent.verticalCenter
                    text: osd_root.is_muted ? "󰝟" : "󰕾"
                    font.family: Style.font_mono
                    font.pixelSize: Style.text_lg
                    color: osd_root.is_muted ? Colors.on_surface_variant : Colors.primary
                }

                Rectangle {
                    id: level_track
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space_xl * 6
                    height: Style.space_sm
                    radius: Style.radius_pill
                    color: Style.alpha(Colors.surface_variant, Style.glass_opacity)

                    Rectangle {
                        id: level_fill
                        width: parent.width * osd_root.clamped_level
                        height: parent.height
                        radius: Style.radius_pill
                        color: osd_root.is_muted ? Colors.outline : Colors.primary

                        Behavior on width {
                            NumberAnimation {
                                duration: Style.motion_fast
                                easing.type: Style.easing
                            }
                        }
                    }
                }

                Text {
                    id: osd_text
                    anchors.verticalCenter: parent.verticalCenter
                    text: osd_root.is_muted ? "MUTE" : (osd_root.volume_percent + "%")
                    font.family: Style.font_ui
                    font.pixelSize: Style.text_sm
                    font.weight: Font.DemiBold
                    color: Colors.on_surface
                }
            }
        }
    }
}
