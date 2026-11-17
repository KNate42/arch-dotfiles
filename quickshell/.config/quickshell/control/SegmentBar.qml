// Neon segment meter shared by audio and system status displays
// This work made by Anfinogentov Nikita

import QtQuick
import "../theme"

Item {
    id: segments_root

    property real value: 0
    property int count: 20
    property color accent: Colors.cyan
    property bool muted: false
    implicitHeight: 10

    // Здесь я зажигаю только целые сегменты и оставляю пустую шкалу при нулевом уровне.
    readonly property int lit_count: Math.ceil(Math.max(0, Math.min(1, value)) * count)
    Row {
        anchors.fill: parent
        spacing: 3
        Repeater {
            model: segments_root.count
            delegate: Rectangle {
                required property int index
                width: Math.max(0, (segments_root.width - (segments_root.count - 1) * 3) / segments_root.count)
                height: segments_root.height
                color: index < segments_root.lit_count && !segments_root.muted
                    ? segments_root.accent : Style.alpha(segments_root.accent, 0.12)
                border.width: 1
                border.color: Style.alpha(segments_root.accent, index < segments_root.lit_count ? 0.8 : 0.25)
                // Здесь я меняю яркость коротким импульсом без движения самой шкалы.
                Behavior on color { ColorAnimation { duration: Style.motion_fast } }
            }
        }
    }
}
