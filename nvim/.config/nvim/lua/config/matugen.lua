-- Loader for Matugen Material You palette via mini.base16 with habamax fallback
-- This work made by Anfinogentov Nikita

local matugen_module = {}

local function build_base16_palette(raw_colors)
    local surface_color = raw_colors.surface or "#1e1e2e"
    local on_surface_color = raw_colors.on_surface or "#cdd6f4"

    -- Здесь я раскладываю 12 токенов Material You по 16 слотам спецификации Base16
    return {
        base00 = surface_color,
        base01 = raw_colors.surface_container or surface_color,
        base02 = raw_colors.surface_container_high or raw_colors.surface_variant or surface_color,
        base03 = raw_colors.outline or "#585b70",
        base04 = raw_colors.on_surface_variant or on_surface_color,
        base05 = on_surface_color,
        base06 = on_surface_color,
        base07 = raw_colors.surface_variant or surface_color,
        base08 = raw_colors.error or "#f38ba8",
        base09 = raw_colors.tertiary or "#fab387",
        base0A = raw_colors.secondary or "#f9e2af",
        base0B = raw_colors.primary or "#a6e3a1",
        base0C = raw_colors.tertiary or "#94e2d5",
        base0D = raw_colors.primary or "#89b4fa",
        base0E = raw_colors.secondary or "#cba6f7",
        base0F = raw_colors.on_primary or raw_colors.outline or "#f2cdcd",
    }
end

function matugen_module.load_matugen_colors()
    local colors_file = vim.fn.expand("~/.cache/matugen/nvim-colors.lua")
    local uv_loop = vim.uv or vim.loop

    if not uv_loop.fs_stat(colors_file) then
        vim.cmd.colorscheme("habamax")
        return
    end

    -- Здесь я использую dofile вместо require, чтобы при :MatugenReload файл перечитывался с диска без кеша Lua
    local file_ok, matugen_colors = pcall(dofile, colors_file)
    if not file_ok or type(matugen_colors) ~= "table" then
        vim.cmd.colorscheme("habamax")
        return
    end

    local base16_ok, mini_base16 = pcall(require, "mini.base16")
    if not base16_ok then
        vim.cmd.colorscheme("habamax")
        return
    end

    mini_base16.setup({
        palette = build_base16_palette(matugen_colors),
        use_cterm = true,
    })
end

vim.api.nvim_create_user_command("MatugenReload", function()
    matugen_module.load_matugen_colors()
end, { desc = "Reload Matugen colorscheme" })

return matugen_module
