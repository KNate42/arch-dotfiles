// Root entry point for the Quickshell desktop shell: island, control center, desktop clock, power menu, wallpaper picker
// This work made by Anfinogentov Nikita

import Quickshell
import "./island"
import "./control"
import "./desktop"
import "./power"
import "./wallpaper"

ShellRoot {
    Island {}
    ControlCenter {}
    Desktop {}
    PowerMenu {}
    Picker {}
}
