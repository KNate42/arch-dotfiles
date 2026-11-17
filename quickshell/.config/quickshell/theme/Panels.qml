// Shared shell state: which panels are open and the do-not-disturb switch
// This work made by Anfinogentov Nikita

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: panels_root

    // Центр управления справа; открывают остров (клик), Super+A и qs ipc call control toggle
    property bool control_open: false
    // «Не беспокоить»: остров не разворачивает уведомления, но они не теряются
    property bool dnd: false

    function toggle_control() {
        panels_root.control_open = !panels_root.control_open;
    }

    IpcHandler {
        target: "control"

        function toggle() {
            panels_root.toggle_control();
        }

        function close() {
            panels_root.control_open = false;
        }
    }
}
