// Root entry point for the Quickshell desktop shell
// This work made by Anfinogentov Nikita

import Quickshell
import "./bar"
import "./notifications"
import "./osd"
import "./power"
import "./wallpaper"

ShellRoot {
    Bar {
        onPower_requested: power_menu.toggle_menu()
    }
    Notifications {}
    VolumeOsd {}
    PowerMenu {
        id: power_menu
    }
    Picker {}
}
