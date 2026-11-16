// Desktop notification daemon and top-right popup stack
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: notifications_root

    NotificationServer {
        id: notif_server // notif = notification
        keepOnReload: false
        onNotification: notification => {
            if (notification) {
                notification.tracked = true;
            }
        }
    }

    PanelWindow {
        id: notif_window
        visible: notif_server.trackedNotifications.values.length > 0
        anchors {
            top: true
            right: true
        }
        margins {
            top: 8
            right: 8
        }
        exclusiveZone: 0
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        implicitWidth: 320
        implicitHeight: notif_column.implicitHeight
        color: "transparent"

        Column {
            id: notif_column
            width: 320
            spacing: 8

            Repeater {
                model: notif_server.trackedNotifications

                delegate: Popup {}
            }
        }
    }
}
