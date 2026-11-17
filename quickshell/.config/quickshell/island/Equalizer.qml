// Four-column neon segment equalizer driven by playback state
// This work made by Anfinogentov Nikita

import QtQuick
import "../theme"

Row {
    id: eq_root
    property bool is_playing: false
    property int phase_step: 0
    readonly property var patterns: [[1, 3, 2, 4], [4, 2, 4, 1], [2, 4, 1, 3], [3, 1, 3, 4]]
    height: 19
    spacing: 3
    // Здесь я двигаю сегменты только во время воспроизведения и при видимом острове.
    Timer {
        interval: 135
        repeat: true
        running: eq_root.is_playing && eq_root.visible
        onTriggered: eq_root.phase_step = (eq_root.phase_step + 1) % eq_root.patterns.length
    }
    Repeater {
        model: 4
        delegate: Column {
            id: eq_column
            required property int index
            readonly property int lit: eq_root.is_playing ? eq_root.patterns[eq_root.phase_step][index] : 1
            spacing: 1
            // Здесь я зажигаю столбцы снизу вверх отдельными неоновыми прямоугольниками.
            Repeater {
                model: 4
                delegate: Rectangle {
                    required property int index
                    width: 3; height: 4
                    color: index >= 4 - eq_column.lit
                        ? (index < 2 ? Colors.magenta : Colors.cyan) : Style.alpha(Colors.cyan, 0.12)
                }
            }
        }
    }
}
