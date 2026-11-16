-- look and feel: gaps, borders, blur, animations, border colors from matugen
-- This work made by Anfinogentov Nikita

-- Здесь я беру цвета рамок из файла matugen; если его ещё нет, остаются запасные
local active_border = "rgba(8ab4f8ee)"
local inactive_border = "rgba(44474eaa)"
local loaded, palette = pcall(require, "modules.colors")
if loaded and type(palette) == "table" then
    active_border = palette.active_border or active_border
    inactive_border = palette.inactive_border or inactive_border
end

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 12,
        border_size = 2,
        col = {
            active_border = active_border,
            inactive_border = inactive_border,
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 0.96,
        shadow = {
            enabled = true,
            range = 8,
            render_power = 3,
            color = 0xaa0b0b0b,
        },
        blur = {
            enabled = true,
            size = 5,
            passes = 2,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },

    -- Здесь я убираю всплывающие новости обновлений и просьбы о донатах
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})

hl.curve("ease_out_quint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("almost_linear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("soft", { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "ease_out_quint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, spring = "soft" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, spring = "soft", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "almost_linear", style = "popin 87%" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "ease_out_quint" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almost_linear", style = "slide" })
