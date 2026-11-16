// Network connectivity indicator for the status bar
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell.Networking
import "../theme"

Rectangle {
    id: network_root

    readonly property int conn_state: Networking.connectivity // conn = connectivity
    readonly property bool is_online: network_root.conn_state === NetworkConnectivity.Full
        || network_root.conn_state === NetworkConnectivity.Limited
        || network_root.conn_state === NetworkConnectivity.Portal

    readonly property string net_icon: { // net = network
        if (network_root.conn_state === NetworkConnectivity.Full) {
            return "󰖩";
        }
        if (network_root.conn_state === NetworkConnectivity.Limited || network_root.conn_state === NetworkConnectivity.Portal) {
            return "󰖪";
        }
        return "󰖪";
    }

    implicitWidth: network_label.implicitWidth + 14
    implicitHeight: 22
    radius: 6
    color: Colors.surface_container_high

    Text {
        id: network_label
        anchors.centerIn: parent
        text: network_root.net_icon
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: network_root.is_online ? Colors.on_surface : Colors.on_surface_variant
    }
}
