// Network connectivity indicator for the status bar
// This work made by Anfinogentov Nikita

import QtQuick
import Quickshell.Networking
import "../theme"

BarChip {
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

    icon: network_root.net_icon
    icon_color: network_root.is_online ? Colors.on_surface : Colors.on_surface_variant
}
