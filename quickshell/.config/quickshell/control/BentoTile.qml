// Base bento grid tile with glass surface styling and staggered spring cascade entrance
// This work made by Anfinogentov Nikita

import QtQuick
import "../theme"

Rectangle {
    id: bento_root

    property int tile_index: 0
    property int reveal_delay: 0
    property bool panel_open: Panels.control_open
    property bool is_revealed: false
    property real surface_alpha: 0.78

    radius: Style.tile_radius
    color: Style.alpha(Colors.surface_container, bento_root.surface_alpha)
    border.width: 1
    border.color: Style.alpha(Colors.outline_variant, Style.glass_border_opacity)
    opacity: bento_root.is_revealed ? 1.0 : 0.0

    // Здесь я запускаю каскадную задержку по индексу плитки, чтобы элементы всплывали по очереди сверху вниз
    onPanel_openChanged: {
        if (bento_root.panel_open) {
            bento_root.is_revealed = false;
            cascade_timer.restart();
        } else {
            cascade_timer.stop();
            bento_root.is_revealed = false;
        }
    }

    Component.onCompleted: {
        if (bento_root.panel_open) {
            cascade_timer.restart();
        }
    }

    Timer {
        id: cascade_timer
        interval: Math.max(15, bento_root.tile_index * 45 + bento_root.reveal_delay)
        repeat: false
        onTriggered: {
            if (bento_root.panel_open) {
                bento_root.is_revealed = true;
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Style.motion_normal
            easing.type: Style.easing
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Style.motion_fast
            easing.type: Style.easing
        }
    }

    // Здесь я подтягиваю плитку снизу вверх на пружине синхронно с проявлением прозрачности
    transform: Translate {
        id: tile_shift
        y: bento_root.is_revealed ? 0 : 16

        Behavior on y {
            SpringAnimation {
                spring: Style.spring
                damping: Style.spring_damping
                epsilon: 0.25
            }
        }
    }
}
