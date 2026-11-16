// Single notification toast item with timeout and click-to-dismiss
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../theme"

Rectangle {
    id: popup_root

    required property var modelData
    required property int index

    readonly property bool is_critical: popup_root.modelData
        ? (popup_root.modelData.urgency === NotificationUrgency.Critical)
        : false

    // Здесь я перевожу expireTimeout (секунды) в миллисекунды: 0 = не закрывать само, меньше нуля = 5 секунд
    readonly property int timeout_ms: { // ms = milliseconds
        if (!popup_root.modelData || popup_root.modelData.expireTimeout < 0) {
            return 5000;
        }
        return Math.round(popup_root.modelData.expireTimeout * 1000);
    }

    readonly property string raw_icon: popup_root.modelData && popup_root.modelData.appIcon
        ? popup_root.modelData.appIcon
        : ""

    readonly property string resolved_icon: {
        if (popup_root.raw_icon === "") {
            return "";
        }
        if (popup_root.raw_icon.startsWith("/") || popup_root.raw_icon.startsWith("file://")) {
            return popup_root.raw_icon;
        }
        return Quickshell.iconPath(popup_root.raw_icon, true);
    }

    visible: popup_root.index < 5
    width: 320
    implicitHeight: Math.max(56, text_column.implicitHeight + 20)
    radius: 10
    color: Colors.surface_container_high
    border.width: 1
    border.color: popup_root.is_critical ? Colors.error : Colors.outline_variant

    Timer {
        id: expire_timer
        interval: popup_root.timeout_ms
        running: popup_root.visible && !popup_root.is_critical && popup_root.timeout_ms > 0
        repeat: false
        onTriggered: {
            if (popup_root.modelData) {
                popup_root.modelData.expire();
            }
        }
    }

    Rectangle {
        id: icon_box
        anchors {
            left: parent.left
            leftMargin: 10
            top: parent.top
            topMargin: 10
        }
        width: 36
        height: 36
        radius: 8
        color: Colors.surface_variant

        Image {
            id: app_image // app = application
            anchors.centerIn: parent
            width: 24
            height: 24
            visible: popup_root.resolved_icon !== ""
            source: popup_root.resolved_icon
            smooth: true
        }

        Text {
            id: fallback_glyph
            anchors.centerIn: parent
            visible: popup_root.resolved_icon === ""
            text: "󰂚"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            color: popup_root.is_critical ? Colors.error : Colors.primary
        }
    }

    Column {
        id: text_column
        anchors {
            left: icon_box.right
            leftMargin: 10
            right: parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        spacing: 4

        Text {
            id: summary_label
            width: parent.width
            text: popup_root.modelData && popup_root.modelData.summary ? popup_root.modelData.summary : "Notification"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            font.bold: true
            color: Colors.on_surface
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            id: body_label
            width: parent.width
            visible: body_label.text !== ""
            text: popup_root.modelData && popup_root.modelData.body ? popup_root.modelData.body : ""
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Colors.on_surface_variant
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: dismiss_area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (popup_root.modelData) {
                popup_root.modelData.dismiss();
            }
        }
    }
}
