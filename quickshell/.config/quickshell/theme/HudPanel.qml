// HUD panel: chamfered corners, neon outline with glow, corner brackets and faint scanlines
// This work made by Anfinogentov Nikita

import QtQuick
import QtQuick.Shapes

Item {
    id: panel_root

    // accent = цвет неона рамки; active = ярче и со свечением; cut = размер скоса углов
    property color accent: Colors.cyan
    property bool active: false
    property int cut: Style.chamfer
    property real fill_opacity: Style.hud_fill_opacity
    property bool scanlines: true
    property bool brackets: true
    default property alias content: content_item.data

    // Здесь я задаю контур со скосом левого верхнего и правого нижнего угла, как у панелей в играх
    function outline(path_w, path_h, inset) { // inset = отступ контура внутрь, чтобы обводка не обрезалась
        const c = panel_root.cut;
        return [Qt.point(c + inset, inset), Qt.point(path_w - inset, inset), Qt.point(path_w - inset, path_h - c - inset),
                Qt.point(path_w - c - inset, path_h - inset), Qt.point(inset, path_h - inset), Qt.point(inset, c + inset),
                Qt.point(c + inset, inset)];
    }

    // Свечение: несколько расходящихся контуров с затухающей прозрачностью
    Repeater {
        model: panel_root.active ? 3 : 1

        delegate: Shape {
            required property int index
            anchors.fill: parent
            anchors.margins: -(index + 1) * 2
            ShapePath {
                strokeWidth: 2
                strokeColor: Style.alpha(panel_root.accent, (panel_root.active ? Style.hud_glow_opacity : 0.18) / (index + 1.5))
                fillColor: "transparent"
                PathPolyline {
                    path: panel_root.outline(panel_root.width + (index + 1) * 4, panel_root.height + (index + 1) * 4, 1)
                }
            }
        }
    }

    Shape {
        id: body_shape
        anchors.fill: parent
        ShapePath {
            strokeWidth: 1
            strokeColor: Style.alpha(panel_root.accent, panel_root.active ? 1.0 : 0.65)
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: panel_root.height
                GradientStop { position: 0.0; color: Style.alpha(Colors.surface_container_high, panel_root.fill_opacity) }
                GradientStop { position: 1.0; color: Style.alpha(Colors.void_black, panel_root.fill_opacity) }
            }
            PathPolyline {
                path: panel_root.outline(panel_root.width, panel_root.height, 0.5)
            }
        }
    }

    // Скан-линии рисую один раз на холсте: тонкие полосы через 3 пикселя
    Canvas {
        anchors.fill: parent
        anchors.margins: 2
        visible: panel_root.scanlines
        opacity: Style.scanline_opacity
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = Colors.cyan;
            for (let y = 0; y < height; y += 3) {
                ctx.fillRect(0, y, width, 1);
            }
        }
    }

    // Уголки-скобки у двух прямых углов
    Repeater {
        model: panel_root.brackets ? [{ right: true, bottom: false }, { right: false, bottom: true }] : []

        delegate: Item {
            required property var modelData
            width: 14
            height: 14
            x: modelData.right ? panel_root.width - width - 4 : 4
            y: modelData.bottom ? panel_root.height - height - 4 : 4
            Rectangle {
                width: 14
                height: 2
                color: panel_root.accent
                y: parent.modelData.bottom ? 12 : 0
            }
            Rectangle {
                width: 2
                height: 14
                color: panel_root.accent
                x: parent.modelData.right ? 12 : 0
            }
        }
    }

    Item {
        id: content_item
        anchors.fill: parent
    }

    Behavior on accent {
        ColorAnimation { duration: Style.motion_normal }
    }
}
