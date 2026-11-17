// HUD notification with application heading, typed message and default action
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../theme"

Item {
    id: notif_card_root // notif = notification

    property var notification_data: null
    property int queue_count: 0

    signal activated()

    readonly property bool is_critical: notif_card_root.notification_data
        ? (notif_card_root.notification_data.urgency === NotificationUrgency.Critical)
        : false

    readonly property string raw_image: notif_card_root.notification_data && notif_card_root.notification_data.image
        ? String(notif_card_root.notification_data.image)
        : ""

    readonly property string raw_icon: notif_card_root.notification_data && notif_card_root.notification_data.appIcon
        ? String(notif_card_root.notification_data.appIcon)
        : ""

    // Здесь я разрешаю путь к картинке или иконке приложения через Quickshell.iconPath с безопасным откатом
    function resolve_source(raw_val) { // val = value
        if (!raw_val || raw_val === "") {
            return "";
        }
        if (raw_val.startsWith("/") || raw_val.startsWith("file://") || raw_val.startsWith("image://")) {
            return raw_val;
        }
        return Quickshell.iconPath(raw_val, true);
    }

    readonly property string resolved_image: notif_card_root.resolve_source(notif_card_root.raw_image)
    readonly property string resolved_icon: notif_card_root.resolve_source(notif_card_root.raw_icon)
    readonly property string effective_source: notif_card_root.resolved_image !== ""
        ? notif_card_root.resolved_image
        : notif_card_root.resolved_icon

    readonly property string app_title: notif_card_root.notification_data && notif_card_root.notification_data.appName
        ? String(notif_card_root.notification_data.appName)
        : ""

    readonly property string summary_text: {
        if (notif_card_root.notification_data && notif_card_root.notification_data.summary) {
            return String(notif_card_root.notification_data.summary);
        }
        if (notif_card_root.app_title !== "") {
            return notif_card_root.app_title;
        }
        return "Уведомление";
    }

    readonly property string body_text: notif_card_root.notification_data && notif_card_root.notification_data.body
        ? String(notif_card_root.notification_data.body)
        : ""

    TextEdit {
        id: body_decoder
        visible: false
        readOnly: true
        textFormat: TextEdit.AutoText
        text: notif_card_root.body_text
    }
    readonly property string plain_body: body_decoder.text === "" ? "" : body_decoder.getText(0, body_decoder.length)
    readonly property string message_text: summary_text + (plain_body !== "" ? "\n" + plain_body : "")
    readonly property var message_chars: Array.from(message_text)
    property int typed_count: 0
    function glitch() { app_heading.glitch(); }
    function restart_type() {
        type_timer.stop();
        typed_count = 0;
        if (notification_data && visible) {
            type_timer.restart();
            app_heading.glitch();
        }
    }
    onNotification_dataChanged: Qt.callLater(restart_type)
    onMessage_textChanged: Qt.callLater(restart_type)
    onVisibleChanged: Qt.callLater(restart_type)
    Component.onCompleted: restart_type()

    Timer {
        id: type_timer
        interval: Style.type_step
        repeat: true
        onTriggered: {
            if (notif_card_root.typed_count < notif_card_root.message_chars.length)
                notif_card_root.typed_count++;
            else stop();
        }
    }
    HudPanel {
        id: icon_box
        anchors { left: parent.left; leftMargin: Style.space_lg; verticalCenter: parent.verticalCenter }
        width: 56; height: 56; cut: 7
        brackets: false; scanlines: false
        accent: Colors.magenta
        Image {
            id: notif_image
            anchors.centerIn: parent
            width: notif_card_root.resolved_image !== "" ? 42 : 32
            height: width
            source: notif_card_root.effective_source
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: source !== "" && status === Image.Ready
        }
        NeonText {
            anchors.centerIn: parent
            visible: !notif_image.visible
            text: notif_card_root.is_critical ? "󰂞" : "󰂚"
            color: notif_card_root.is_critical ? Colors.alarm : Colors.magenta
            pixel_size: Style.text_xl
        }
    }
    Column {
        anchors {
            left: icon_box.right; leftMargin: Style.space_md
            right: parent.right; rightMargin: Style.space_lg
            verticalCenter: parent.verticalCenter
        }
        spacing: 5
        Item {
            width: parent.width
            height: app_heading.implicitHeight + 2
            clip: true
            NeonText {
                id: app_heading
                text: "// " + (notif_card_root.app_title || "NOTIFICATION")
                    + (notif_card_root.queue_count > 1 ? " [+" + (notif_card_root.queue_count - 1) + "]" : "")
                pixel_size: Style.text_sm
                color: Colors.magenta
                glow_color: Colors.magenta
            }
        }
        // Здесь я фиксирую высоту сообщения, чтобы печать букв не двигала остров.
        Text {
            width: parent.width
            height: 54
            text: notif_card_root.message_chars.slice(0, notif_card_root.typed_count).join("")
            textFormat: Text.PlainText
            font.family: Style.font_hud
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.5
            font.pixelSize: Style.text_sm
            color: Colors.on_surface
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }
    // Здесь я оставляю прежнее действие карточки и закрытие уведомления.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: notif_card_root.activated()
    }
}
