// MPRIS HUD player with framed cover, transport buttons and neon gradient progress
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell.Services.Mpris
import "../theme"

BentoTile {
    id: media_root
    tile_index: 3
    visible: media_root.active_player !== null
    implicitHeight: media_root.active_player !== null ? 178 : 0

    readonly property var player_list: Mpris.players ? Mpris.players.values : []

    // Здесь я показываю плитку только для плеера, который сейчас воспроизводит музыку
    readonly property var active_player: {
        const list = media_root.player_list;
        if (!list || list.length === 0) {
            return null;
        }
        for (let i = 0; i < list.length; i++) {
            const candidate = list[i];
            if (candidate && (candidate.isPlaying || candidate.playbackState === MprisPlaybackState.Playing)) {
                return candidate;
            }
        }
        return null;
    }

    readonly property bool is_playing: media_root.active_player
        ? Boolean(media_root.active_player.isPlaying || media_root.active_player.playbackState === MprisPlaybackState.Playing)
        : false

    readonly property string track_title: {
        if (!media_root.active_player) {
            return "";
        }
        if (media_root.active_player.trackTitle && String(media_root.active_player.trackTitle).trim() !== "") {
            return String(media_root.active_player.trackTitle);
        }
        if (media_root.active_player.identity) {
            return String(media_root.active_player.identity);
        }
        return "Мультимедиа";
    }

    readonly property string artist_name: {
        if (!media_root.active_player) {
            return "";
        }
        if (media_root.active_player.trackArtist && String(media_root.active_player.trackArtist).trim() !== "") {
            return String(media_root.active_player.trackArtist);
        }
        if (media_root.active_player.trackArtists && media_root.active_player.trackArtists.length > 0) {
            return media_root.active_player.trackArtists.join(", ");
        }
        return "Неизвестный исполнитель";
    }

    readonly property string art_url: media_root.active_player && media_root.active_player.trackArtUrl
        ? String(media_root.active_player.trackArtUrl)
        : ""
    readonly property bool has_art: media_root.art_url !== ""

    readonly property real track_length: media_root.active_player && media_root.active_player.length > 0
        ? Number(media_root.active_player.length)
        : 0.0
    property int position_tick: 0
    readonly property real track_position: {
        const tick = media_root.position_tick;
        return media_root.active_player && media_root.active_player.position >= 0
            ? Number(media_root.active_player.position)
            : 0.0;
    }
    readonly property real progress_ratio: media_root.track_length > 0
        ? Math.max(0.0, Math.min(1.0, media_root.track_position / media_root.track_length))
        : 0.0

    function format_seconds(sec_val) { // sec_val = duration or position in seconds
        if (!sec_val || isNaN(sec_val) || sec_val < 0) {
            return "0:00";
        }
        const total = Math.floor(sec_val);
        const mins = Math.floor(total / 60);
        const secs = total % 60;
        return mins + ":" + (secs < 10 ? "0" + secs : secs);
    }

    function toggle_play() {
        if (!media_root.active_player) {
            return;
        }
        if (typeof media_root.active_player.togglePlaying === "function") {
            media_root.active_player.togglePlaying();
        } else if (media_root.is_playing) {
            media_root.active_player.pause();
        } else {
            media_root.active_player.play();
        }
    }

    Timer {
        id: position_timer
        interval: 1000
        running: media_root.is_playing && Panels.control_open
        repeat: true
        onTriggered: {
            media_root.position_tick = (media_root.position_tick + 1) % 86400;
        }
    }

    // Здесь я оставляю обложку только в рамке, чтобы телеметрия читалась на тёмном фоне.
    Column {
        id: media_content
        anchors {
            fill: parent
            margins: Style.space_md
        }
        spacing: Style.space_sm

        Row {
            id: top_media_row
            width: parent.width
            height: 72
            spacing: Style.space_md

            HudPanel {
                id: cover_frame
                width: 72
                height: 72
                cut: 8
                accent: Colors.magenta
                active: true
                brackets: false

                Image {
                    id: cover_sharp
                    anchors.fill: parent
                    anchors.margins: 8
                    visible: media_root.has_art
                    source: media_root.art_url
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 144
                    sourceSize.height: 144
                    smooth: true
                    asynchronous: true
                }

                Text {
                    id: fallback_music_icon
                    anchors.centerIn: parent
                    visible: !media_root.has_art || cover_sharp.status !== Image.Ready
                    text: "󰎆"
                    font.family: Style.font_hud
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Style.hud_letter_spacing
                    font.pixelSize: 28
                    color: Colors.primary
                }
            }

            Column {
                id: meta_column
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - cover_frame.width - parent.spacing)
                spacing: 4

                Text {
                    id: title_text
                    width: parent.width
                    text: media_root.track_title
                    font.family: Style.font_hud
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Style.hud_letter_spacing
                    font.pixelSize: Style.text_md
                    font.weight: Font.DemiBold
                    color: Colors.on_surface
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    id: artist_text
                    width: parent.width
                    text: media_root.artist_name
                    font.family: Style.font_hud
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Style.hud_letter_spacing
                    font.pixelSize: Style.text_sm
                    color: Colors.on_surface_variant
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        Row {
            id: controls_row
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space_xs

            Rectangle {
                id: prev_btn // btn = button
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 0
                color: prev_mouse.pressed
                    ? Style.alpha(Colors.on_surface, Style.press_opacity)
                    : (prev_mouse.containsMouse
                        ? Style.alpha(Colors.on_surface, Style.hover_opacity)
                        : Style.alpha(Colors.surface_container_high, 0.65))

                border.width: 1
                border.color: prev_mouse.containsMouse ? Colors.magenta : Colors.cyan

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
                    onClicked: {
                        if (media_root.active_player) {
                            media_root.active_player.previous();
                        }
                    }
                }
            }

            Rectangle {
                id: play_btn
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 38
                radius: 0
                color: play_mouse.pressed
                    ? Qt.darker(Colors.primary, 1.12)
                    : (play_mouse.containsMouse ? Qt.lighter(Colors.primary, 1.08) : Colors.primary)

                Behavior on color {
                    ColorAnimation {
                        duration: Style.motion_fast
                        easing.type: Style.easing
                    }
                }

                border.width: 1
                border.color: play_mouse.containsMouse ? Colors.magenta : Colors.cyan

                Text {
                    anchors.centerIn: parent
                    text: media_root.is_playing ? "󰏤" : "󰐊"
                    font.family: Style.font_hud
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Style.hud_letter_spacing
                    font.pixelSize: Style.text_lg
                    color: Colors.on_primary
                }

                MouseArea {
                    id: play_mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: media_root.toggle_play()
                }
            }

            Rectangle {
                id: next_btn
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 0
                color: next_mouse.pressed
                    ? Style.alpha(Colors.on_surface, Style.press_opacity)
                    : (next_mouse.containsMouse
                        ? Style.alpha(Colors.on_surface, Style.hover_opacity)
                        : Style.alpha(Colors.surface_container_high, 0.65))

                border.width: 1
                border.color: next_mouse.containsMouse ? Colors.magenta : Colors.cyan

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
                    onClicked: {
                        if (media_root.active_player) {
                            media_root.active_player.next();
                        }
                    }
                }
            }
        }

        Column {
            id: progress_section
            width: parent.width
            spacing: 4

            Rectangle {
                id: progress_track
                width: parent.width
                height: 6
                radius: 0
                color: Style.alpha(Colors.surface_container_high, 0.9)

                Rectangle {
                    id: progress_fill
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    width: media_root.progress_ratio * parent.width
                    radius: 0
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Colors.cyan }
                        GradientStop { position: 1; color: Colors.magenta }
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Style.motion_fast
                            easing.type: Style.easing
                        }
                    }
                }

                // Здесь я позволяю перемотать трек кликом по полосе прогресса, если плеер поддерживает позиционирование
                MouseArea {
                    id: seek_mouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (media_root.active_player && media_root.track_length > 0 && media_root.active_player.canSeek) {
                            const ratio = Math.max(0.0, Math.min(1.0, mouse.x / progress_track.width));
                            media_root.active_player.position = ratio * media_root.track_length;
                        }
                    }
                }
            }

            Item {
                id: timestamps_row
                width: parent.width
                height: pos_label.implicitHeight

                Text {
                    id: pos_label // pos = position
                    anchors.left: parent.left
                    text: media_root.format_seconds(media_root.track_position)
                    font.family: Style.font_hud
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Style.hud_letter_spacing
                    font.pixelSize: Style.text_xs
                    color: Colors.on_surface_variant
                }

                Text {
                    id: len_label // len = length
                    anchors.right: parent.right
                    text: media_root.track_length > 0
                        ? media_root.format_seconds(media_root.track_length)
                        : "--:--"
                    font.family: Style.font_hud
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Style.hud_letter_spacing
                    font.pixelSize: Style.text_xs
                    color: Colors.on_surface_variant
                }
            }
        }
    }
}
