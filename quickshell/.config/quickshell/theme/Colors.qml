// Dynamic Material color palette singleton loaded from matugen cache
// This work made by Anfinogentov Nikita

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: colors_root

    property color primary: "#89b4fa"
    property color on_primary: "#11111b"
    property color primary_container: "#313244"
    property color on_primary_container: "#cdd6f4"
    property color secondary: "#cba6f7"
    property color on_secondary: "#11111b"
    property color tertiary: "#f9e2af"
    property color error: "#f38ba8"
    property color on_error: "#11111b"
    property color surface: "#1e1e2e"
    property color on_surface: "#cdd6f4"
    property color surface_variant: "#313244"
    property color on_surface_variant: "#a6adc8"
    property color surface_container: "#181825"
    property color surface_container_high: "#313244"
    property color outline: "#6c7086"
    property color outline_variant: "#45475a"
    property color shadow: "#000000"

    // Здесь я читаю ~/.cache без XDG_CACHE_HOME: matugen пишет именно туда (output_path в config.toml)
    readonly property string home_dir: Quickshell.env("HOME") ?? ""
    readonly property string colors_path: colors_root.home_dir + "/.cache/matugen/colors.json"

    function is_valid_color(val) { // val = candidate color value from JSON
        return typeof val === "string" && /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(val);
    }

    // Здесь я разбираю JSON вручную в блоке try/catch, чтобы битый файл не сбрасывал запасную палитру
    function apply_json(raw_text) {
        if (!raw_text || raw_text.trim() === "") {
            return;
        }
        try {
            const parsed = JSON.parse(raw_text);
            if (!parsed || typeof parsed !== "object") {
                return;
            }
            if (colors_root.is_valid_color(parsed.primary)) colors_root.primary = parsed.primary;
            if (colors_root.is_valid_color(parsed.on_primary)) colors_root.on_primary = parsed.on_primary;
            if (colors_root.is_valid_color(parsed.primary_container)) colors_root.primary_container = parsed.primary_container;
            if (colors_root.is_valid_color(parsed.on_primary_container)) colors_root.on_primary_container = parsed.on_primary_container;
            if (colors_root.is_valid_color(parsed.secondary)) colors_root.secondary = parsed.secondary;
            if (colors_root.is_valid_color(parsed.on_secondary)) colors_root.on_secondary = parsed.on_secondary;
            if (colors_root.is_valid_color(parsed.tertiary)) colors_root.tertiary = parsed.tertiary;
            if (colors_root.is_valid_color(parsed.error)) colors_root.error = parsed.error;
            if (colors_root.is_valid_color(parsed.on_error)) colors_root.on_error = parsed.on_error;
            if (colors_root.is_valid_color(parsed.surface)) colors_root.surface = parsed.surface;
            if (colors_root.is_valid_color(parsed.on_surface)) colors_root.on_surface = parsed.on_surface;
            if (colors_root.is_valid_color(parsed.surface_variant)) colors_root.surface_variant = parsed.surface_variant;
            if (colors_root.is_valid_color(parsed.on_surface_variant)) colors_root.on_surface_variant = parsed.on_surface_variant;
            if (colors_root.is_valid_color(parsed.surface_container)) colors_root.surface_container = parsed.surface_container;
            if (colors_root.is_valid_color(parsed.surface_container_high)) colors_root.surface_container_high = parsed.surface_container_high;
            if (colors_root.is_valid_color(parsed.outline)) colors_root.outline = parsed.outline;
            if (colors_root.is_valid_color(parsed.outline_variant)) colors_root.outline_variant = parsed.outline_variant;
            if (colors_root.is_valid_color(parsed.shadow)) colors_root.shadow = parsed.shadow;
        } catch (err) {
            return;
        }
    }

    FileView {
        id: colors_file
        path: colors_root.colors_path
        watchChanges: true
        onFileChanged: colors_file.reload()
        onLoaded: colors_root.apply_json(colors_file.text())
    }
}
