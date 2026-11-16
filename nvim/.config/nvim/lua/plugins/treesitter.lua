-- Syntax highlighting and parser management via nvim-treesitter
-- This work made by Anfinogentov Nikita

local parser_list = {
    "lua",
    "bash",
    "fish",
    "python",
    "javascript",
    "typescript",
    "java",
    "rust",
    "sql",
    "json",
    "toml",
    "yaml",
    "markdown",
    "qmljs",
}

return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    opts = {
        ensure_installed = parser_list,
        auto_install = false,
        highlight = {
            enable = true,
        },
        indent = {
            enable = true,
        },
    },
    config = function(_, plugin_opts)
        -- Здесь я проверяю наличие старого модуля configs и новой ветки main для совместимости с Neovim 0.12
        local configs_ok, ts_configs = pcall(require, "nvim-treesitter.configs")
        if configs_ok then
            ts_configs.setup(plugin_opts)
            return
        end

        local ts_ok, ts_main = pcall(require, "nvim-treesitter")
        if ts_ok and type(ts_main.setup) == "function" then
            ts_main.setup()
        end

        vim.api.nvim_create_autocmd("FileType", {
            callback = function(event_args)
                pcall(vim.treesitter.start, event_args.buf)
            end,
        })
    end,
}
