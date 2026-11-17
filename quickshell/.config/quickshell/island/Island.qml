// Dynamic top-center desktop island morphing between idle, media player, volume OSD and notifications
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import "../theme"

Scope {
    id: island_root

    // --- Clock ---
    SystemClock {
        id: sys_clock // sys = system
        precision: SystemClock.Minutes
    }

    // --- Keyboard layout (Hyprland activelayout + initial hyprctl query) ---
    property string current_layout: "EN"

    // Здесь я разбираю событие activelayout вида "клавиатура,раскладка" с учётом запятых в названии устройства
    function update_layout_from_event(raw_payload) {
        if (!raw_payload) {
            return;
        }
        const comma_idx = raw_payload.indexOf(","); // idx = index
        const layout_part = (comma_idx >= 0 ? raw_payload.substring(comma_idx + 1) : raw_payload).trim().toLowerCase();
        if (layout_part.includes("ru") || layout_part.includes("рус")) {
            island_root.current_layout = "RU";
        } else if (layout_part.includes("en") || layout_part.includes("us") || layout_part.includes("англ")) {
            island_root.current_layout = "EN";
        } else if (layout_part.length >= 2) {
            island_root.current_layout = layout_part.substring(0, 2).toUpperCase();
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event && event.name === "activelayout") {
                island_root.update_layout_from_event(event.data);
            }
        }
    }

    Process {
        id: layout_query
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(this.text).keyboards || [];
                    const main_kb = keyboards.find(kb => kb.main) || keyboards[0]; // kb = keyboard
                    if (main_kb && main_kb.active_keymap) {
                        island_root.update_layout_from_event("," + main_kb.active_keymap);
                    }
                } catch (err) {
                    return;
                }
            }
        }
    }

    // --- Network connectivity ---
    readonly property int conn_state: Networking.connectivity // conn = connectivity
    readonly property bool is_online: island_root.conn_state === NetworkConnectivity.Full
        || island_root.conn_state === NetworkConnectivity.Limited
        || island_root.conn_state === NetworkConnectivity.Portal
    readonly property string net_icon: island_root.conn_state === NetworkConnectivity.Full ? "󰖩" : "󰖪" // net = network

    // --- PipeWire default audio sink + Volume OSD state ---
    property bool volume_osd_active: false
    property bool audio_ready: false

    readonly property var sink_node: Pipewire.defaultAudioSink
    readonly property var sink_audio: island_root.sink_node ? island_root.sink_node.audio : null
    readonly property bool has_audio: island_root.sink_audio !== null && island_root.sink_audio !== undefined
    readonly property bool is_muted: island_root.has_audio ? Boolean(island_root.sink_audio.muted) : false
    readonly property real volume_level: island_root.has_audio && !isNaN(island_root.sink_audio.volume)
        ? island_root.sink_audio.volume
        : 0.0
    readonly property real clamped_level: Math.max(0.0, Math.min(1.0, island_root.volume_level))
    readonly property int volume_percent: Math.round(island_root.volume_level * 100)

    readonly property string volume_icon: {
        if (!island_root.has_audio || island_root.is_muted) {
            return "󰝟";
        }
        if (island_root.volume_percent < 33) {
            return "󰕿";
        }
        if (island_root.volume_percent < 66) {
            return "󰖀";
        }
        return "󰕾";
    }

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    Timer {
        id: audio_warmup_timer
        interval: 250
        running: island_root.has_audio && !island_root.audio_ready
        repeat: false
        onTriggered: island_root.audio_ready = true
    }

    Timer {
        id: volume_hide_timer
        interval: 1500
        repeat: false
        onTriggered: island_root.volume_osd_active = false
    }

    function trigger_volume_osd() {
        if (!island_root.has_audio || !island_root.audio_ready) {
            return;
        }
        island_root.volume_osd_active = true;
        volume_hide_timer.restart();
    }

    onVolume_levelChanged: island_root.trigger_volume_osd()
    onIs_mutedChanged: island_root.trigger_volume_osd()

    function toggle_mute() {
        if (island_root.has_audio) {
            island_root.sink_audio.muted = !island_root.sink_audio.muted;
        }
    }

    function set_volume_ratio(ratio) {
        if (island_root.has_audio) {
            island_root.sink_audio.volume = Math.max(0.0, Math.min(1.0, ratio));
        }
    }

    // --- MPRIS Media ---
    readonly property var player_list: Mpris.players ? Mpris.players.values : []

    // Здесь я выбираю активно играющий MPRIS-плеер, а если все на паузе — беру первый доступный
    readonly property var active_player: {
        const list = island_root.player_list;
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

    readonly property bool has_media: island_root.active_player !== null
    readonly property bool is_playing: island_root.active_player
        ? Boolean(island_root.active_player.isPlaying || island_root.active_player.playbackState === MprisPlaybackState.Playing)
        : false

    readonly property string artist_name: {
        if (!island_root.active_player) {
            return "";
        }
        if (island_root.active_player.trackArtist) {
            return String(island_root.active_player.trackArtist);
        }
        if (island_root.active_player.trackArtists && island_root.active_player.trackArtists.length > 0) {
            return island_root.active_player.trackArtists.join(", ");
        }
        return "";
    }

    readonly property string track_title: {
        if (!island_root.active_player) {
            return "";
        }
        if (island_root.active_player.trackTitle) {
            return String(island_root.active_player.trackTitle);
        }
        if (island_root.active_player.identity) {
            return String(island_root.active_player.identity);
        }
        return "Media";
    }

    readonly property string art_url: island_root.active_player && island_root.active_player.trackArtUrl
        ? String(island_root.active_player.trackArtUrl)
        : ""

    property int position_tick: 0
    readonly property real progress_ratio: {
        const tick = island_root.position_tick;
        const pl = island_root.active_player; // pl = player
        if (!pl) {
            return 0.0;
        }
        if (pl.length && !isNaN(pl.length) && pl.length > 0) {
            const pos = (!isNaN(pl.position) && pl.position >= 0) ? pl.position : 0.0; // pos = position
            return Math.max(0.0, Math.min(1.0, pos / pl.length));
        }
        return 0.0;
    }

    Timer {
        id: mpris_pos_timer
        interval: 1000
        repeat: true
        running: island_root.is_playing
        onTriggered: {
            island_root.position_tick = (island_root.position_tick + 1) % 86400;
        }
    }

    function media_toggle() {
        if (!island_root.active_player) {
            return;
        }
        if (typeof island_root.active_player.togglePlaying === "function") {
            island_root.active_player.togglePlaying();
        } else if (island_root.is_playing) {
            island_root.active_player.pause();
        } else {
            island_root.active_player.play();
        }
    }

    function media_next() {
        if (island_root.active_player && typeof island_root.active_player.next === "function") {
            island_root.active_player.next();
        }
    }

    function media_previous() {
        if (island_root.active_player && typeof island_root.active_player.previous === "function") {
            island_root.active_player.previous();
        }
    }

    // --- Notifications server and queue ---
    readonly property var notif_queue: notif_server.trackedNotifications.values // notif = notification
    readonly property var current_notif: (!Panels.dnd && island_root.notif_queue.length > 0)
        ? island_root.notif_queue[0]
        : null
    readonly property bool current_notif_critical: island_root.current_notif
        ? (island_root.current_notif.urgency === NotificationUrgency.Critical)
        : false
    readonly property int current_notif_timeout_ms: { // ms = milliseconds
        if (!island_root.current_notif || island_root.current_notif.expireTimeout < 0) {
            return 5000;
        }
        if (island_root.current_notif.expireTimeout === 0) {
            return 0;
        }
        return Math.round(island_root.current_notif.expireTimeout * 1000);
    }

    // Здесь я храню очередь в модели сервера: закрытые приложением уведомления исчезают и во время DND.
    NotificationServer {
        id: notif_server
        keepOnReload: false
        onNotification: notification => {
            if (notification) {
                notification.tracked = true;
            }
        }
    }

    function invoke_and_close_current_notif() {
        const notif = island_root.current_notif;
        if (!notif) {
            return;
        }
        try {
            if (notif.actions && notif.actions.length > 0) {
                let chosen = null;
                for (let i = 0; i < notif.actions.length; i++) {
                    const act = notif.actions[i]; // act = action
                    if (act && act.identifier === "default") {
                        chosen = act;
                        break;
                    }
                }
                if (chosen && typeof chosen.invoke === "function") {
                    chosen.invoke();
                }
            }
        } catch (err) {
        }
        try {
            if (notif_server.trackedNotifications.values.indexOf(notif) >= 0) {
                notif.dismiss();
            }
        } catch (err) {
        }
    }

    onCurrent_notifChanged: {
        notif_expire_timer.stop();
        if (island_root.current_notif && !island_root.current_notif_critical && island_root.current_notif_timeout_ms > 0) {
            notif_expire_timer.interval = island_root.current_notif_timeout_ms;
            notif_expire_timer.restart();
        }
    }

    Timer {
        id: notif_expire_timer
        interval: 5000
        repeat: false
        onTriggered: {
            const expired = island_root.current_notif;
            if (expired && typeof expired.expire === "function") {
                try {
                    expired.expire();
                } catch (err) {
                }
            }
        }
    }

    // --- Per-screen Island Window ---
    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: island_window
            required property var modelData

            property bool player_hovered: false
            property int ws_impulse_extra: 0 // ws = workspace
            property bool ws_pulse_glow: false

            readonly property bool pointer_in_capsule: capsule_hover.hovered

            onPointer_in_capsuleChanged: {
                if (!island_window.pointer_in_capsule) {
                    island_window.player_hovered = false;
                } else if (island_root.has_media && !workspaces_widget.contains_mouse) {
                    island_window.player_hovered = true;
                }
            }

            readonly property string state_mode: {
                if (island_root.current_notif !== null) {
                    return "notification";
                }
                if (island_root.volume_osd_active) {
                    return "volume";
                }
                if (island_root.has_media && island_window.player_hovered) {
                    return "player";
                }
                return "compact";
            }

            readonly property int compact_width: Math.max(
                236,
                compact_row.implicitWidth + Style.space_lg * 2 + island_window.ws_impulse_extra
            )

            readonly property int target_width: {
                if (island_window.state_mode === "notification") {
                    return 440;
                }
                if (island_window.state_mode === "player") {
                    return 420;
                }
                if (island_window.state_mode === "volume") {
                    return 320;
                }
                return island_window.compact_width;
            }

            readonly property int target_height: {
                if (island_window.state_mode === "notification") {
                    return 110;
                }
                if (island_window.state_mode === "player") {
                    return 96;
                }
                if (island_window.state_mode === "volume") {
                    return 44;
                }
                return Style.island_height;
            }

            readonly property int target_radius: {
                if (island_window.state_mode === "notification" || island_window.state_mode === "player") {
                    return Style.island_expanded_radius;
                }
                if (island_window.state_mode === "volume") {
                    return 22;
                }
                return Math.round(Style.island_height / 2);
            }

            readonly property color dark_glass_base: Qt.darker(Colors.surface, 1.5)

            function pulse_on_workspace_switch() {
                island_window.ws_impulse_extra = 26;
                island_window.ws_pulse_glow = true;
                ws_recoil_timer.restart();
                ws_glow_timer.restart();
            }

            Timer {
                id: ws_recoil_timer
                interval: 160
                repeat: false
                onTriggered: island_window.ws_impulse_extra = 0
            }

            Timer {
                id: ws_glow_timer
                interval: 800
                repeat: false
                onTriggered: island_window.ws_pulse_glow = false
            }

            screen: island_window.modelData
            WlrLayershell.namespace: "dots-island"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            focusable: false
            mask: Region { item: island_capsule }
            anchors {
                top: true
                left: true
                right: true
            }
            exclusiveZone: Style.island_margin_top + Style.island_height + 4
            implicitHeight: Style.island_margin_top + Math.max(Style.island_height, Math.ceil(island_capsule.height)) + Style.space_md
            color: "transparent"

            // Soft layered drop shadow behind the capsule
            Rectangle {
                id: shadow_outer
                x: island_capsule.x - 6
                y: island_capsule.y - 3
                width: island_capsule.width + 12
                height: island_capsule.height + 9
                radius: island_capsule.radius + 6
                color: Style.alpha(Colors.shadow, 0.08)
            }

            Rectangle {
                id: shadow_mid
                x: island_capsule.x - 3
                y: island_capsule.y - 1
                width: island_capsule.width + 6
                height: island_capsule.height + 5
                radius: island_capsule.radius + 3
                color: Style.alpha(Colors.shadow, 0.16)
            }

            Rectangle {
                id: shadow_inner
                x: island_capsule.x - 1
                y: island_capsule.y
                width: island_capsule.width + 2
                height: island_capsule.height + 2
                radius: island_capsule.radius + 1
                color: Style.alpha(Colors.shadow, 0.28)
            }

            // Subtle primary outer glow halo
            Rectangle {
                id: primary_halo
                anchors {
                    fill: island_capsule
                    margins: -1
                }
                radius: island_capsule.radius + 1
                color: "transparent"
                border.width: 1
                border.color: island_window.state_mode === "notification" && island_root.current_notif_critical
                    ? Style.alpha(Colors.error, 0.24)
                    : Style.alpha(Colors.primary, island_window.ws_pulse_glow ? 0.28 : 0.12)

                Behavior on border.color {
                    ColorAnimation {
                        duration: Style.motion_normal
                        easing.type: Style.easing
                    }
                }
            }

            // Main morphing capsule
            Rectangle {
                id: island_capsule
                anchors.horizontalCenter: parent.horizontalCenter
                y: Style.island_margin_top
                width: island_window.target_width
                height: island_window.target_height
                radius: island_window.target_radius
                clip: true
                color: Style.alpha(island_window.dark_glass_base, Style.island_opacity)
                border.width: 1
                border.color: island_window.state_mode === "notification" && island_root.current_notif_critical
                    ? Style.alpha(Colors.error, 0.60)
                    : Style.alpha(
                        Colors.primary,
                        (island_window.ws_pulse_glow || island_window.state_mode === "player") ? 0.42 : 0.25
                    )

                Behavior on width {
                    SpringAnimation {
                        spring: Style.spring
                        damping: Style.spring_damping
                        epsilon: 0.25
                    }
                }

                Behavior on height {
                    SpringAnimation {
                        spring: Style.spring
                        damping: Style.spring_damping
                        epsilon: 0.25
                    }
                }

                Behavior on radius {
                    SpringAnimation {
                        spring: Style.spring
                        damping: Style.spring_damping
                        epsilon: 0.25
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Style.motion_normal
                        easing.type: Style.easing
                    }
                }

                // Subtle top primary sheen inside the dark glass capsule
                Rectangle {
                    id: top_sheen
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 1
                    }
                    height: Math.min(20, parent.height * 0.5)
                    radius: Math.max(0, parent.radius - 1)
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: Style.alpha(Colors.primary, 0.10)
                        }
                        GradientStop {
                            position: 1.0
                            color: "transparent"
                        }
                    }
                }

                HoverHandler {
                    id: capsule_hover
                }

                MouseArea {
                    id: capsule_bg_mouse // bg = background
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: {
                        if (island_root.has_media && !workspaces_widget.contains_mouse) {
                            island_window.player_hovered = true;
                        }
                    }
                    onClicked: {
                        if (island_window.state_mode !== "notification") {
                            Panels.toggle_control();
                        }
                    }
                }

                // 1. Compact state (Покой + compact Музыка играет)
                Item {
                    id: compact_layer
                    anchors.fill: parent
                    enabled: island_window.state_mode === "compact"
                    opacity: island_window.state_mode === "compact" ? 1.0 : 0.0
                    visible: compact_layer.opacity > 0.01
                    scale: island_window.state_mode === "compact" ? 1.0 : 0.95

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Style.motion_fast
                            easing.type: Style.easing
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Style.motion_normal
                            easing.type: Style.easing
                        }
                    }

                    Row {
                        id: compact_row
                        anchors.centerIn: parent
                        spacing: Style.space_md

                        Workspaces {
                            id: workspaces_widget
                            anchors.verticalCenter: parent.verticalCenter
                            island_screen: island_window.modelData
                            onWorkspace_pulsed: island_window.pulse_on_workspace_switch()
                            onContains_mouseChanged: {
                                if (!workspaces_widget.contains_mouse && island_window.pointer_in_capsule && island_root.has_media) {
                                    island_window.player_hovered = true;
                                }
                            }
                        }

                        Row {
                            id: center_cluster
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space_sm

                            AlbumCover {
                                id: mini_cover
                                visible: island_root.has_media
                                anchors.verticalCenter: parent.verticalCenter
                                cover_size: 22
                                corner_radius: 6
                                art_url: island_root.art_url
                                mask_color: island_window.dark_glass_base
                            }

                            Text {
                                id: clock_label
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatTime(sys_clock.date, "HH:mm")
                                font.family: Style.font_ui
                                font.pixelSize: Style.text_md
                                font.weight: Font.DemiBold
                                color: Colors.on_surface
                            }

                            Equalizer {
                                id: mini_equalizer
                                visible: island_root.has_media
                                anchors.verticalCenter: parent.verticalCenter
                                is_playing: island_root.is_playing
                            }
                        }

                        Row {
                            id: status_icons_row
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space_sm

                            Text {
                                id: layout_text
                                anchors.verticalCenter: parent.verticalCenter
                                text: island_root.current_layout
                                font.family: Style.font_ui
                                font.pixelSize: Style.text_xs
                                font.weight: Font.DemiBold
                                color: Colors.on_surface_variant
                            }

                            Text {
                                id: compact_vol_icon
                                anchors.verticalCenter: parent.verticalCenter
                                text: island_root.volume_icon
                                font.family: Style.font_mono
                                font.pixelSize: Style.text_md
                                color: island_root.is_muted ? Colors.on_surface_variant : Colors.on_surface
                            }

                            Text {
                                id: compact_net_icon
                                anchors.verticalCenter: parent.verticalCenter
                                text: island_root.net_icon
                                font.family: Style.font_mono
                                font.pixelSize: Style.text_md
                                color: island_root.is_online ? Colors.on_surface : Colors.on_surface_variant
                            }
                        }
                    }
                }

                // 2. Expanded Media Player state (Музыка играет — hover)
                MediaPlayer {
                    id: player_layer
                    anchors.fill: parent
                    enabled: island_window.state_mode === "player"
                    opacity: island_window.state_mode === "player" ? 1.0 : 0.0
                    visible: player_layer.opacity > 0.01
                    scale: island_window.state_mode === "player" ? 1.0 : 0.95
                    track_title: island_root.track_title
                    artist_name: island_root.artist_name
                    art_url: island_root.art_url
                    is_playing: island_root.is_playing
                    progress_ratio: island_root.progress_ratio
                    mask_color: island_window.dark_glass_base
                    onPrevious_requested: island_root.media_previous()
                    onToggle_requested: island_root.media_toggle()
                    onNext_requested: island_root.media_next()

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Style.motion_normal
                            easing.type: Style.easing
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Style.motion_normal
                            easing.type: Style.easing
                        }
                    }
                }

                // 3. Volume OSD state (Громкость)
                VolumeView {
                    id: volume_layer
                    anchors.fill: parent
                    enabled: island_window.state_mode === "volume"
                    opacity: island_window.state_mode === "volume" ? 1.0 : 0.0
                    visible: volume_layer.opacity > 0.01
                    scale: island_window.state_mode === "volume" ? 1.0 : 0.95
                    volume_icon: island_root.volume_icon
                    is_muted: island_root.is_muted
                    clamped_level: island_root.clamped_level
                    volume_percent: island_root.volume_percent
                    onMute_toggled: {
                        island_root.toggle_mute();
                        island_root.trigger_volume_osd();
                    }
                    onLevel_selected: ratio => {
                        island_root.set_volume_ratio(ratio);
                        island_root.trigger_volume_osd();
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Style.motion_fast
                            easing.type: Style.easing
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Style.motion_normal
                            easing.type: Style.easing
                        }
                    }
                }

                // 4. Notification card state (Уведомление)
                NotificationCard {
                    id: notif_layer
                    anchors.fill: parent
                    enabled: island_window.state_mode === "notification"
                    opacity: island_window.state_mode === "notification" ? 1.0 : 0.0
                    visible: notif_layer.opacity > 0.01
                    scale: island_window.state_mode === "notification" ? 1.0 : 0.95
                    notification_data: island_root.current_notif
                    queue_count: island_root.notif_queue.length
                    onActivated: island_root.invoke_and_close_current_notif()

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Style.motion_normal
                            easing.type: Style.easing
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Style.motion_normal
                            easing.type: Style.easing
                        }
                    }
                }
            }
        }
    }
}
