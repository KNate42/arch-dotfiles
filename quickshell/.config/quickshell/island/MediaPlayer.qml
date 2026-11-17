// Expanded island media player view with 64px cover, track metadata, progress bar and transport controls
// This work made by Anfinogentov Nikita

import QtQuick
import "../theme"

Item {
    id: player_root

    property string track_title: ""
    property string artist_name: ""
    property string art_url: ""
    property bool is_playing: false
    property real progress_ratio: 0.0

    function glitch() { title_neon.glitch(); }
    onTrack_titleChanged: Qt.callLater(() => { if (visible) glitch(); })

    signal previous_requested()
    signal toggle_requested()
    signal next_requested()

    AlbumCover {
        id: big_cover
        anchors {
            left: parent.left
            leftMargin: Style.space_lg
            verticalCenter: parent.verticalCenter
        }
        cover_size: 64
        art_url: player_root.art_url
    }

    Item {
        id: right_pane
        anchors {
            left: big_cover.right
            leftMargin: Style.space_md
            right: parent.right
            rightMargin: Style.space_lg
            verticalCenter: parent.verticalCenter
        }
        height: 64

        Item {
            id: top_info_row
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: 44

            // Здесь я ограничиваю ширину названия и исполнителя до блока кнопок, чтобы длинные треки аккуратно обрезались троеточием
            Column {
                id: meta_column // meta = metadata
                anchors {
                    left: parent.left
                    right: controls_row.left
                    rightMargin: Style.space_sm
                    verticalCenter: parent.verticalCenter
                }
                spacing: 2

                Item {
                    width: parent.width
                    height: title_neon.implicitHeight
                    clip: true
                    NeonText {
                        id: title_neon
                        text: player_root.track_title !== "" ? player_root.track_title : "// AUDIO"
                        color: Colors.cyan
                        pixel_size: Style.text_md
                    }
                }

                Text {
                    id: artist_text
                    width: parent.width
                    text: player_root.artist_name !== "" ? player_root.artist_name : "Неизвестный исполнитель"
                    font.family: Style.font_hud
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Style.hud_letter_spacing
                    font.pixelSize: Style.text_sm
                    color: Colors.on_surface_variant
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            Row {
                id: controls_row
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: Style.space_xs

                Rectangle {
                    id: prev_btn // btn = button
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 0
                    border.width: 1
                    border.color: prev_mouse.containsMouse ? Colors.magenta : Colors.outline
                    color: prev_mouse.pressed
                        ? Style.alpha(Colors.on_surface, Style.press_opacity)
                        : (prev_mouse.containsMouse
                            ? Style.alpha(Colors.on_surface, Style.hover_opacity)
                            : Style.alpha(Colors.on_surface, 0.0))

                    Behavior on color {
                        ColorAnimation {
                            duration: Style.motion_fast
                            easing.type: Style.easing
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.family: Style.font_hud
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: Style.hud_letter_spacing
                        font.pixelSize: Style.text_md
                        color: Colors.on_surface
                    }

                    MouseArea {
                        id: prev_mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: player_root.previous_requested()
                    }
                }

                Rectangle {
                    id: play_btn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    radius: 0
                    color: play_mouse.pressed
                        ? Style.alpha(Colors.primary, 0.34)
                        : (play_mouse.containsMouse
                            ? Style.alpha(Colors.primary, 0.24)
                            : Style.alpha(Colors.primary, 0.16))
                    border.width: 1
                    border.color: play_mouse.containsMouse ? Colors.magenta : Colors.cyan

                    Behavior on color {
                        ColorAnimation {
                            duration: Style.motion_fast
                            easing.type: Style.easing
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: player_root.is_playing ? "󰏤" : "󰐊"
                        font.family: Style.font_hud
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: Style.hud_letter_spacing
                        font.pixelSize: Style.text_lg
                        color: Colors.primary
                    }

                    MouseArea {
                        id: play_mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: player_root.toggle_requested()
                    }
                }

                Rectangle {
                    id: next_btn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 0
                    border.width: 1
                    border.color: next_mouse.containsMouse ? Colors.magenta : Colors.outline
                    color: next_mouse.pressed
                        ? Style.alpha(Colors.on_surface, Style.press_opacity)
                        : (next_mouse.containsMouse
                            ? Style.alpha(Colors.on_surface, Style.hover_opacity)
                            : Style.alpha(Colors.on_surface, 0.0))

                    Behavior on color {
                        ColorAnimation {
                            duration: Style.motion_fast
                            easing.type: Style.easing
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.family: Style.font_hud
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: Style.hud_letter_spacing
                        font.pixelSize: Style.text_md
                        color: Colors.on_surface
                    }

                    MouseArea {
                        id: next_mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: player_root.next_requested()
                    }
                }
            }
        }

        // Здесь я рисую тонкую полоску прогресса трека с градиентом primary → tertiary
        Rectangle {
            id: progress_track
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                bottomMargin: 2
            }
            height: 4
            radius: 0
            color: Style.alpha(Colors.surface_variant, 0.75)

            Rectangle {
                id: progress_fill
                width: Math.max(4, parent.width * Math.max(0.0, Math.min(1.0, player_root.progress_ratio)))
                height: parent.height
                radius: 0
                visible: player_root.progress_ratio > 0.001

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0.0
                        color: Colors.primary
                    }

                    GradientStop {
                        position: 1.0
                        color: Colors.tertiary
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Style.motion_normal
                        easing.type: Style.easing
                    }
                }
            }
        }
    }
}
