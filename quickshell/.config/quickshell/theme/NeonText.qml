// Neon text: soft blurred glow, optional chromatic split for large text and a short glitch jitter
// This work made by Anfinogentov Nikita

import QtQuick
import QtQuick.Effects

Item {
    id: neon_root

    property string text: ""
    property color color: Colors.on_surface
    property color glow_color: Colors.cyan
    property int pixel_size: Style.text_md
    property int weight: Font.Medium
    property bool caps: true
    property bool split: false
    property bool glow: true
    property real spacing: Style.hud_letter_spacing
    property string family: Style.font_hud

    implicitWidth: main_text.implicitWidth
    implicitHeight: main_text.implicitHeight

    // Здесь я запускаю «глитч»: текст на миг дёргается и мерцает, как сбой сигнала
    function glitch() {
        glitch_anim.restart();
    }

    // Расслоение цвета имеет смысл только на крупном тексте: на мелком оно выглядит как плохо отрисованный шрифт
    readonly property bool split_on: neon_root.split && neon_root.pixel_size >= 40
    readonly property real split_shift: Math.max(1, Math.round(neon_root.pixel_size / 60))

    Text {
        id: split_cyan
        visible: neon_root.split_on
        x: -neon_root.split_shift
        color: Style.alpha(Colors.cyan, 0.55)
        text: neon_root.text
        font: main_text.font
        renderType: Text.QtRendering
    }

    Text {
        id: split_magenta
        visible: neon_root.split_on
        x: neon_root.split_shift
        color: Style.alpha(Colors.magenta, 0.55)
        text: neon_root.text
        font: main_text.font
        renderType: Text.QtRendering
    }

    Text {
        id: main_text
        color: neon_root.color
        text: neon_root.text
        font.family: neon_root.family
        font.pixelSize: neon_root.pixel_size
        font.weight: neon_root.weight
        font.capitalization: neon_root.caps ? Font.AllUppercase : Font.MixedCase
        font.letterSpacing: neon_root.spacing
        font.features: { "tnum": 1 }
        // Здесь я оставляю обычную отрисовку шрифта: копии со сдвигом делали контуры мутными
        renderType: Text.NativeRendering
        layer.enabled: neon_root.glow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Style.alpha(neon_root.glow_color, 0.85)
            shadowBlur: neon_root.pixel_size >= 40 ? 0.9 : 0.55
            shadowScale: 1.0
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: neon_root.pixel_size >= 40 ? 32 : 12
        }
    }

    SequentialAnimation {
        id: glitch_anim
        PropertyAction { target: main_text; property: "x"; value: 3 }
        PropertyAction { target: neon_root; property: "opacity"; value: 0.55 }
        PauseAnimation { duration: Style.glitch_duration / 4 }
        PropertyAction { target: main_text; property: "x"; value: -2 }
        PropertyAction { target: neon_root; property: "opacity"; value: 1.0 }
        PauseAnimation { duration: Style.glitch_duration / 4 }
        PropertyAction { target: main_text; property: "x"; value: 1 }
        PropertyAction { target: neon_root; property: "opacity"; value: 0.75 }
        PauseAnimation { duration: Style.glitch_duration / 2 }
        PropertyAction { target: main_text; property: "x"; value: 0 }
        PropertyAction { target: neon_root; property: "opacity"; value: 1.0 }
    }
}
