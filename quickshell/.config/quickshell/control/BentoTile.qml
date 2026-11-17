// Chamfered HUD tile with staggered reveal and signal glitch
// This work made by Anfinogentov Nikita

import QtQuick
import "../theme"

HudPanel {
    id: bento_root

    property int tile_index: 0
    property int reveal_delay: 0
    property bool panel_open: Panels.control_open
    property bool is_revealed: false
    cut: 8
    brackets: false
    active: tile_hover.hovered
    opacity: is_revealed ? 1 : 0
    enabled: is_revealed && panel_open

    function glitch() { if (is_revealed) reveal_glitch.restart(); }

    // Здесь я запускаю плитки по очереди при каждом открытии терминала.
    onPanel_openChanged: {
        cascade_timer.stop();
        reveal_glitch.stop();
        tile_shift.x = 0;
        bento_root.is_revealed = false;
        if (bento_root.panel_open) cascade_timer.restart();
    }
    Component.onCompleted: {
        if (bento_root.panel_open) cascade_timer.restart();
    }
    HoverHandler { id: tile_hover }
    Timer {
        id: cascade_timer
        interval: Math.max(15, bento_root.tile_index * 55 + bento_root.reveal_delay)
        onTriggered: {
            if (bento_root.panel_open) {
                bento_root.is_revealed = true;
                bento_root.glitch();
            }
        }
    }
    Behavior on opacity { NumberAnimation { duration: Style.motion_fast } }

    // Здесь я даю короткий горизонтальный сбой сигнала, сохраняя геометрию сетки.
    transform: Translate { id: tile_shift }
    SequentialAnimation {
        id: reveal_glitch
        PropertyAction { target: tile_shift; property: "x"; value: 4 }
        PauseAnimation { duration: Style.glitch_duration / 3 }
        PropertyAction { target: tile_shift; property: "x"; value: -2 }
        PauseAnimation { duration: Style.glitch_duration / 3 }
        PropertyAction { target: tile_shift; property: "x"; value: 1 }
        PauseAnimation { duration: Style.glitch_duration / 3 }
        PropertyAction { target: tile_shift; property: "x"; value: 0 }
    }
}
