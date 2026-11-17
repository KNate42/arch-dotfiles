// Neon text: glow halo, optional chromatic split (cyan/magenta copies) and a short glitch jitter
// This work made by Anfinogentov Nikita

import QtQuick

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

    // Ореол из нескольких полупрозрачных копий со сдвигом во все стороны
    Repeater {
        model: neon_root.glow ? [[-1, 0], [1, 0], [0, -1], [0, 1], [-2, 0], [2, 0]] : []

        delegate: Text {
            required property var modelData
            x: modelData[0]
            y: modelData[1]
            text: neon_root.text
            color: Style.alpha(neon_root.glow_color, 0.22)
            font.family: neon_root.family
            font.pixelSize: neon_root.pixel_size
            font.weight: neon_root.weight
            font.capitalization: neon_root.caps ? Font.AllUppercase : Font.MixedCase
            font.letterSpacing: neon_root.spacing
            font.features: { "tnum": 1 }
        }
    }

    Text {
        id: split_cyan
        visible: neon_root.split
        x: -2
        color: Style.alpha(Colors.cyan, 0.75)
        text: neon_root.text
        font.family: neon_root.family
        font.pixelSize: neon_root.pixel_size
        font.weight: neon_root.weight
        font.capitalization: neon_root.caps ? Font.AllUppercase : Font.MixedCase
        font.letterSpacing: neon_root.spacing
        font.features: { "tnum": 1 }
    }

    Text {
        id: split_magenta
        visible: neon_root.split
        x: 2
        color: Style.alpha(Colors.magenta, 0.75)
        text: neon_root.text
        font.family: neon_root.family
        font.pixelSize: neon_root.pixel_size
        font.weight: neon_root.weight
        font.capitalization: neon_root.caps ? Font.AllUppercase : Font.MixedCase
        font.letterSpacing: neon_root.spacing
        font.features: { "tnum": 1 }
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
