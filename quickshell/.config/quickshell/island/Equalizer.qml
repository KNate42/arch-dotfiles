// Animated four-bar audio equalizer indicator with primary-to-tertiary gradient
// This work made by Anfinogentov Nikita

import QtQuick
import "../theme"

Row {
    id: eq_root // eq = equalizer

    property bool is_playing: false
    property int phase_step: 0

    readonly property var height_patterns: [
        [6, 14, 9, 12],
        [13, 7, 16, 6],
        [8, 16, 6, 14],
        [15, 9, 13, 7],
        [5, 12, 15, 10],
        [11, 15, 7, 15]
    ]
    readonly property var paused_heights: [5, 7, 6, 4]

    spacing: 2.5
    height: 18

    // Здесь я вычисляю высоту каждой из 4 полосок по фазе таймера, а на паузе возвращаю спокойный уровень
    function bar_height(bar_idx, step_val) { // idx = index, val = value
        if (!eq_root.is_playing) {
            return eq_root.paused_heights[bar_idx % 4];
        }
        const pattern = eq_root.height_patterns[step_val % eq_root.height_patterns.length];
        return pattern[bar_idx % 4];
    }

    // Здесь я двигаю фазу только пока трек реально играет, чтобы на паузе полоски замирали без лишних тиков
    Timer {
        id: bounce_timer
        interval: 135
        repeat: true
        running: eq_root.is_playing && eq_root.visible
        onTriggered: {
            eq_root.phase_step = (eq_root.phase_step + 1) % eq_root.height_patterns.length;
        }
    }

    Repeater {
        model: 4

        delegate: Rectangle {
            id: eq_bar
            required property int index

            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: eq_root.bar_height(eq_bar.index, eq_root.phase_step)
            radius: Style.radius_pill

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Colors.primary
                }
                GradientStop {
                    position: 1.0
                    color: Colors.tertiary
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: 135
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
