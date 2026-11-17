// Angular album artwork frame with fallback music glyph
// This work made by Anfinogentov Nikita

import QtQuick
import "../theme"

HudPanel {
    id: cover_root
    property string art_url: ""
    property int cover_size: 22
    readonly property bool has_valid_art: art_url !== "" && cover_image.status === Image.Ready
    width: cover_size
    height: cover_size
    cut: Math.min(6, cover_size / 5)
    brackets: false
    scanlines: false
    accent: Colors.cyan
    // Здесь я оставляю отступ изображения, чтобы прямоугольная обложка не перекрывала скос рамки.
    Image {
        id: cover_image
        anchors.fill: parent
        anchors.margins: cover_root.cover_size > 30 ? 7 : 4
        source: cover_root.art_url
        sourceSize.width: cover_root.cover_size * 2
        sourceSize.height: cover_root.cover_size * 2
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: cover_root.has_valid_art
    }
    // Здесь я показываю знак музыки при отсутствии или ошибке загрузки обложки.
    NeonText {
        anchors.centerIn: parent
        visible: !cover_root.has_valid_art
        text: "󰎆"
        pixel_size: Math.max(11, Math.round(cover_root.cover_size * 0.4))
        color: Colors.cyan
    }
}
