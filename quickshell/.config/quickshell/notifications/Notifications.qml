// Desktop notification daemon and top-right popup stack
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../theme"

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
        WlrLayershell.namespace: "dots-notify"
        anchors {
            top: true
            right: true
        }
        margins {
            top: Style.bar_margin_top
            right: Style.bar_margin_side
        }
        exclusiveZone: 0
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        implicitWidth: Style.space_xl * 14
        implicitHeight: notif_column.implicitHeight
        color: "transparent"

        Column {
            id: notif_column
            width: Style.space_xl * 14
            spacing: Style.space_sm

            Repeater {
                model: notif_server.trackedNotifications

                delegate: Popup {}
            }
        }
    }
}
