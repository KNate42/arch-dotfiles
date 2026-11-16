// Root entry point for the Quickshell desktop shell
// This work made by Anfinogentov Nikita

import Quickshell
import "./bar"
import "./notifications"
import "./osd"
import "./wallpaper"

ShellRoot {
    Bar {}
    Notifications {}
    VolumeOsd {}
    Picker {}
}
