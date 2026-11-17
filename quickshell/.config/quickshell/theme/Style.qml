// Design tokens shared by every shell surface: fonts, sizes, spacing, radii, glass, motion
// This work made by Anfinogentov Nikita

pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: style_root

    // Здесь я держу два шрифта: Inter для интерфейса, JetBrains Mono только для цифр и кода
    readonly property string font_ui: "Inter"
    readonly property string font_mono: "JetBrainsMono Nerd Font"

    readonly property int text_xs: 11
    readonly property int text_sm: 12
    readonly property int text_md: 13
    readonly property int text_lg: 16
    readonly property int text_xl: 22
    readonly property int text_display: 64

    // Сетка отступов кратна 4
    readonly property int space_xs: 4
    readonly property int space_sm: 8
    readonly property int space_md: 12
    readonly property int space_lg: 16
    readonly property int space_xl: 24

    readonly property int radius_sm: 8
    readonly property int radius_md: 12
    readonly property int radius_lg: 18
    readonly property int radius_pill: 999

    // Панель-остров: отступ от краёв экрана, высота, размер «кнопок» внутри
    readonly property int bar_height: 38
    readonly property int bar_margin_top: 8
    readonly property int bar_margin_side: 12
    readonly property int bar_item_height: 26

    // Стекло: полупрозрачная поверхность, размытие даёт Hyprland по namespace dots-*
    readonly property real glass_opacity: 0.72
    readonly property real glass_border_opacity: 0.35
    readonly property real hover_opacity: 0.10
    readonly property real press_opacity: 0.18

    // Движение: короткие и мягкие анимации, одна кривая на всё
    readonly property int motion_fast: 120
    readonly property int motion_normal: 220
    readonly property int motion_slow: 360
    readonly property int easing: Easing.OutCubic

    // Остров: капсула сверху по центру, перетекает между состояниями пружиной
    readonly property int island_height: 36
    readonly property int island_margin_top: 8
    readonly property int island_expanded_radius: 26
    readonly property real island_opacity: 0.92
    readonly property real spring: 3.2
    readonly property real spring_damping: 0.28

    // Центр управления: панель справа из плиток
    readonly property int control_width: 400
    readonly property int tile_gap: 10
    readonly property int tile_radius: 20

    // HUD: скошенные углы, неоновая рамка со свечением, скан-линии, моноширинный шрифт капсом
    readonly property string font_hud: "JetBrainsMono Nerd Font"
    readonly property int chamfer: 12
    readonly property real hud_fill_opacity: 0.80
    readonly property real hud_glow_opacity: 0.45
    readonly property real scanline_opacity: 0.05
    readonly property real hud_letter_spacing: 1.6
    readonly property int glitch_duration: 140
    readonly property int type_step: 22

    // Здесь я делаю цвет полупрозрачным, не трогая сам цвет темы
    function alpha(base, amount) { // base = theme color, amount = opacity 0..1
        return Qt.rgba(base.r, base.g, base.b, amount);
    }
}
