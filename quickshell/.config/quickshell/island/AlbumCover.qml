// Rounded album cover widget with fallback music glyph for compact and expanded island states
// This work made by Anfinogentov Nikita

import QtQuick
import "../theme"

Rectangle {
    id: cover_root

    property string art_url: ""
    property int cover_size: 22
    property int corner_radius: 6
    property color mask_color: Qt.darker(Colors.surface, 1.5)

    readonly property bool has_valid_art: cover_root.art_url !== "" && cover_image.status === Image.Ready
    readonly property int ring_thickness: Math.max(6, Math.ceil(cover_root.corner_radius * 0.6))

    width: cover_root.cover_size
    height: cover_root.cover_size
    radius: cover_root.corner_radius
    clip: true
    color: Style.alpha(Colors.surface_container_high, 0.85)

    // Здесь я подгружаю обложку асинхронно и обрезаю с сохранением пропорций
    Image {
        id: cover_image
        anchors.fill: parent
        source: cover_root.art_url
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        visible: cover_root.has_valid_art
    }

    // Здесь я скругляю углы квадратной картинки кольцевой рамкой в цвет фона капсулы без внешних шейдеров
    Rectangle {
        id: corner_mask
        anchors.centerIn: parent
        width: parent.width + cover_root.ring_thickness * 2
        height: parent.height + cover_root.ring_thickness * 2
        radius: cover_root.corner_radius + cover_root.ring_thickness
        color: "transparent"
        border.width: cover_root.ring_thickness
        border.color: cover_root.mask_color
        visible: cover_root.has_valid_art
    }

    Text {
        id: fallback_glyph
        anchors.centerIn: parent
        visible: !cover_root.has_valid_art
        text: "󰎆"
        font.family: Style.font_mono
        font.pixelSize: Math.max(11, Math.round(cover_root.cover_size * 0.48))
        color: Colors.primary
    }

    Rectangle {
        id: rim_border
        anchors.fill: parent
        radius: cover_root.corner_radius
        color: "transparent"
        border.width: 1
        border.color: Style.alpha(Colors.primary, 0.24)
    }
}
