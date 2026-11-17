// Expanded island notification card with app icon or image, summary, two-line body and click-to-invoke
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

    Rectangle {
        id: icon_box
        anchors {
            left: parent.left
            leftMargin: Style.space_lg
            verticalCenter: parent.verticalCenter
        }
        width: 56
        height: 56
        radius: Style.radius_md
        clip: true
        color: Style.alpha(Colors.surface_container_high, 0.85)
        border.width: 1
        border.color: notif_card_root.is_critical
            ? Style.alpha(Colors.error, 0.65)
            : Style.alpha(Colors.primary, 0.25)

        Image {
            id: notif_img // img = image
            anchors.centerIn: parent
            width: notif_card_root.resolved_image !== "" ? 56 : 32
            height: notif_card_root.resolved_image !== "" ? 56 : 32
            source: notif_card_root.effective_source
            fillMode: notif_card_root.resolved_image !== "" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            visible: notif_card_root.effective_source !== "" && notif_img.status === Image.Ready
        }

        Text {
            id: fallback_bell
            anchors.centerIn: parent
            visible: notif_card_root.effective_source === "" || notif_img.status !== Image.Ready
            text: notif_card_root.is_critical ? "󰂞" : "󰂚"
            font.family: Style.font_mono
            font.pixelSize: Style.text_xl
            color: notif_card_root.is_critical ? Colors.error : Colors.primary
        }
    }

    // Здесь я размещаю заголовок, индикатор очереди и текст уведомления максимум в две строки
    Column {
        id: text_column
        anchors {
            left: icon_box.right
            leftMargin: Style.space_md
            right: parent.right
            rightMargin: Style.space_lg
            verticalCenter: parent.verticalCenter
        }
        spacing: Style.space_xs

        Item {
            id: header_line
            width: parent.width
            height: 20

            Text {
                id: summary_label
                anchors {
                    left: parent.left
                    right: meta_badge.visible ? meta_badge.left : parent.right
                    rightMargin: meta_badge.visible ? Style.space_sm : 0
                    verticalCenter: parent.verticalCenter
                }
                text: notif_card_root.summary_text
                font.family: Style.font_ui
                font.pixelSize: Style.text_md
                font.weight: Font.DemiBold
                color: notif_card_root.is_critical ? Colors.error : Colors.on_surface
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Rectangle {
                id: meta_badge // meta = metadata
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                visible: notif_card_root.queue_count > 1 || notif_card_root.app_title !== ""
                height: 18
                width: badge_text.implicitWidth + Style.space_sm * 2
                radius: Style.radius_pill
                color: notif_card_root.queue_count > 1
                    ? Style.alpha(Colors.primary, 0.22)
                    : Style.alpha(Colors.surface_variant, 0.65)

                Text {
                    id: badge_text
                    anchors.centerIn: parent
                    text: notif_card_root.queue_count > 1
                        ? ("+" + (notif_card_root.queue_count - 1))
                        : notif_card_root.app_title
                    font.family: Style.font_ui
                    font.pixelSize: Style.text_xs
                    font.weight: Font.Medium
                    color: notif_card_root.queue_count > 1 ? Colors.primary : Colors.on_surface_variant
                }
            }
        }

        Text {
            id: body_label
            width: parent.width
            visible: notif_card_root.body_text !== ""
            text: notif_card_root.body_text
            font.family: Style.font_ui
            font.pixelSize: Style.text_sm
            color: Colors.on_surface_variant
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    // Здесь я вызываю действие по умолчанию и закрываю уведомление по клику на карточку
    MouseArea {
        id: card_mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: notif_card_root.activated()
    }
}
