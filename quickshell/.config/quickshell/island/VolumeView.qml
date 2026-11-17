// HUD volume readout with mute action and segmented click target
// This work made by Anfinogentov Nikita

import QtQuick
import "../theme"
import "../control"

Item {
    id: volume_view_root
    property string volume_icon: "󰕾"
    property bool is_muted: false
    property real clamped_level: 0
    property int volume_percent: 0
    signal mute_toggled()
    signal level_selected(real ratio)
    function glitch() { percent_label.glitch(); }
    onIs_mutedChanged: Qt.callLater(() => { if (visible) glitch(); })
    // Здесь я сохраняю независимую кнопку mute слева от шкалы.
    NeonText {
        id: vol_glyph
        anchors { left: parent.left; leftMargin: Style.space_lg; verticalCenter: parent.verticalCenter }
        text: volume_view_root.volume_icon
        color: Colors.mint
        pixel_size: Style.text_lg
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: volume_view_root.mute_toggled()
        }
    }
    NeonText {
        id: percent_label
        anchors { right: parent.right; rightMargin: Style.space_lg; verticalCenter: parent.verticalCenter }
        text: volume_view_root.is_muted ? "MUTE" : volume_view_root.volume_percent + "%"
        color: Colors.mint
        glow_color: Colors.mint
        pixel_size: Style.text_sm
    }
    SegmentBar {
        id: slider_track
        anchors {
            left: vol_glyph.right; leftMargin: Style.space_md
            right: percent_label.left; rightMargin: Style.space_md
            verticalCenter: parent.verticalCenter
        }
        count: 18
        accent: Colors.mint
        value: volume_view_root.clamped_level
        muted: volume_view_root.is_muted
        // Здесь я перевожу координату клика в прежний сигнал выбора громкости.
        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -8
            anchors.bottomMargin: -8
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (slider_track.width > 0)
                    volume_view_root.level_selected(Math.max(0, Math.min(1, mouse.x / slider_track.width)));
            }
        }
    }
}
