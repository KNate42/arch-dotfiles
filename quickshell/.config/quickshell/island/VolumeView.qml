// Expanded island volume OSD view with mute icon, gradient level bar and percentage readout
// This work made by Anfinogentov Nikita

import QtQuick
import "../theme"

Item {
    id: volume_view_root

    property string volume_icon: "󰕾"
    property bool is_muted: false
    property real clamped_level: 0.0
    property int volume_percent: 0

    signal mute_toggled()
    signal level_selected(real ratio)

    // Здесь я выравниваю иконку, ползунок и процент внутри капсулы 320x44 с фиксированной шириной подписи
    Text {
        id: vol_glyph // vol = volume
        anchors {
            left: parent.left
            leftMargin: Style.space_lg
            verticalCenter: parent.verticalCenter
        }
        text: volume_view_root.volume_icon
        font.family: Style.font_mono
        font.pixelSize: Style.text_lg
        color: volume_view_root.is_muted ? Colors.on_surface_variant : Colors.primary

        MouseArea {
            id: icon_mouse
            anchors {
                fill: parent
                margins: -4
            }
            cursorShape: Qt.PointingHandCursor
            onClicked: volume_view_root.mute_toggled()
        }
    }

    Text {
        id: percent_label
        anchors {
            right: parent.right
            rightMargin: Style.space_lg
            verticalCenter: parent.verticalCenter
        }
        width: 42
        horizontalAlignment: Text.AlignRight
        text: volume_view_root.is_muted ? "MUTE" : (volume_view_root.volume_percent + "%")
        font.family: Style.font_ui
        font.pixelSize: Style.text_sm
        font.weight: Font.DemiBold
        color: volume_view_root.is_muted ? Colors.on_surface_variant : Colors.on_surface
    }

    Rectangle {
        id: slider_track
        anchors {
            left: vol_glyph.right
            leftMargin: Style.space_md
            right: percent_label.left
            rightMargin: Style.space_sm
            verticalCenter: parent.verticalCenter
        }
        height: 6
        radius: Style.radius_pill
        color: Style.alpha(Colors.surface_variant, 0.80)

        // Здесь я заливаю ползунок градиентом primary → tertiary, а в режиме mute приглушаю цвет до outline
        Rectangle {
            id: slider_fill
            width: parent.width * Math.max(0.0, Math.min(1.0, volume_view_root.clamped_level))
            height: parent.height
            radius: Style.radius_pill

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0.0
                    color: volume_view_root.is_muted ? Colors.outline : Colors.primary
                }

                GradientStop {
                    position: 1.0
                    color: volume_view_root.is_muted ? Colors.outline_variant : Colors.tertiary
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: Style.motion_fast
                    easing.type: Style.easing
                }
            }
        }

        MouseArea {
            id: track_mouse
            anchors {
                fill: parent
                topMargin: -8
                bottomMargin: -8
            }
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (slider_track.width > 0) {
                    const ratio = Math.max(0.0, Math.min(1.0, mouse.x / slider_track.width));
                    volume_view_root.level_selected(ratio);
                }
            }
        }
    }
}
