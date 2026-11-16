-- Colorscheme plugin specification using mini.base16 and Matugen palette
-- This work made by Anfinogentov Nikita

return {
    "echasnovski/mini.base16",
    version = false,
    lazy = false,
    priority = 1000,
    config = function()
        local matugen = require("config.matugen")
        matugen.load_matugen_colors()
    end,
}
