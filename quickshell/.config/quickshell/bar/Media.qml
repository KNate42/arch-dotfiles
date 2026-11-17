// MPRIS media player chip showing artist and track with playback controls
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell.Services.Mpris
import "../theme"

BarChip {
    id: media_root

    readonly property var player_list: Mpris.players ? Mpris.players.values : []

    // Здесь я выбираю активно играющий плеер, а если все на паузе — беру первый доступный
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
        return list[0];
    }

    readonly property bool is_playing: media_root.active_player
        ? Boolean(media_root.active_player.isPlaying || media_root.active_player.playbackState === MprisPlaybackState.Playing)
        : false

    readonly property string artist_name: {
        if (!media_root.active_player) {
            return "";
        }
        if (media_root.active_player.trackArtist) {
            return String(media_root.active_player.trackArtist);
        }
        if (media_root.active_player.trackArtists && media_root.active_player.trackArtists.length > 0) {
            return media_root.active_player.trackArtists.join(", ");
        }
        return "";
    }

    readonly property string track_title: media_root.active_player && media_root.active_player.trackTitle
        ? String(media_root.active_player.trackTitle)
        : ""

    readonly property string track_summary: {
        if (media_root.artist_name !== "" && media_root.track_title !== "") {
            return media_root.artist_name + " — " + media_root.track_title;
        }
        if (media_root.track_title !== "") {
            return media_root.track_title;
        }
        if (media_root.artist_name !== "") {
            return media_root.artist_name;
        }
        return media_root.active_player && media_root.active_player.identity
            ? String(media_root.active_player.identity)
            : "Media";
    }

    visible: media_root.active_player !== null
    icon: media_root.is_playing ? "󰏤" : "󰐊"
    icon_color: media_root.is_playing ? Colors.primary : Colors.on_surface_variant
    label: media_root.track_summary
    text_color: Colors.on_surface
    max_label_width: Style.space_xl * 9

    onClicked: {
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

    // Здесь я переключаю треки прокруткой колеса мыши: вверх — следующий, вниз — предыдущий
    onWheel: wheel => {
        if (!media_root.active_player) {
            return;
        }
        if (wheel.angleDelta.y > 0) {
            media_root.active_player.next();
        } else if (wheel.angleDelta.y < 0) {
            media_root.active_player.previous();
        }
    }
}
