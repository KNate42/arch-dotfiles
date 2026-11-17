// Fixed neon palette of the cyberpunk HUD; old Material role names are kept so every surface reads the same tokens
// This work made by Anfinogentov Nikita

pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: colors_root

    // Здесь я держу неон постоянным: в стиле HUD узнаваемость важнее подстройки под обои
    readonly property color cyan: "#00e5ff"
    readonly property color magenta: "#ff2bd6"
    readonly property color mint: "#7affd4"
    readonly property color amber: "#ffd23f"
    readonly property color alarm: "#ff3355"
    readonly property color void_black: "#05040a"

    readonly property color primary: colors_root.cyan
    readonly property color on_primary: "#02121a"
    readonly property color primary_container: "#06303d"
    readonly property color on_primary_container: "#b8f6ff"
    readonly property color secondary: colors_root.mint
    readonly property color on_secondary: "#02160f"
    readonly property color tertiary: colors_root.magenta
    readonly property color error: colors_root.alarm
    readonly property color on_error: "#1a0006"
    readonly property color surface: "#07060d"
    readonly property color on_surface: "#e8f7ff"
    readonly property color surface_variant: "#101326"
    readonly property color on_surface_variant: "#8fb3c4"
    readonly property color surface_container: "#0a0a14"
    readonly property color surface_container_high: "#12142a"
    readonly property color outline: "#2e5a6e"
    readonly property color outline_variant: "#17303d"
    readonly property color shadow: "#000000"
}
