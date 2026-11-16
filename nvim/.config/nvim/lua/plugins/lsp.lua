-- Native Neovim 0.11+ LSP setup with Mason and blink.cmp capabilities
-- This work made by Anfinogentov Nikita

local lsp_servers = {
    "lua_ls",
    "pyright",
    "ts_ls",
    "rust_analyzer",
    "jdtls",
    "bashls",
}

return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "saghen/blink.cmp",
    },
    config = function()
        require("mason").setup()
        require("mason-lspconfig").setup({
            ensure_installed = lsp_servers,
            automatic_enable = false,
        })

        local lsp_capabilities = vim.lsp.protocol.make_client_capabilities()
        local blink_ok, blink_cmp = pcall(require, "blink.cmp")
        if blink_ok and type(blink_cmp.get_lsp_capabilities) == "function" then
            lsp_capabilities = blink_cmp.get_lsp_capabilities(lsp_capabilities)
        end

        vim.api.nvim_create_autocmd("LspAttach", {
            group = vim.api.nvim_create_augroup("user_lsp_attach", { clear = true }),
            callback = function(event_args)
                local map_opts = { buffer = event_args.buf }
                local map_key = vim.keymap.set

                map_key("n", "gd", vim.lsp.buf.definition, map_opts)
                map_key("n", "gD", vim.lsp.buf.declaration, map_opts)
                map_key("n", "gr", vim.lsp.buf.references, map_opts)
                map_key("n", "gi", vim.lsp.buf.implementation, map_opts)
                map_key("n", "K", vim.lsp.buf.hover, map_opts)
                map_key("n", "<leader>rn", vim.lsp.buf.rename, map_opts)
                map_key("n", "<leader>ca", vim.lsp.buf.code_action, map_opts)
                map_key("n", "<leader>f", function()
                    vim.lsp.buf.format({ async = true })
                end, map_opts)
            end,
        })

        -- Здесь я настраиваю серверы через встроенный в Neovim 0.11+ интерфейс vim.lsp.config и включаю их через vim.lsp.enable
        vim.lsp.config("*", {
            capabilities = lsp_capabilities,
        })

        vim.lsp.config("lua_ls", {
            capabilities = lsp_capabilities,
            settings = {
                Lua = {
                    diagnostics = {
                        globals = { "vim" },
                    },
                    -- Здесь я подключаю заглушки Hyprland, чтобы в hyprland.lua работало автодополнение hl.*
                    workspace = {
                        checkThirdParty = false,
                        library = { "/usr/share/hypr/stubs" },
                    },
                },
            },
        })

        for _, server_name in ipairs(lsp_servers) do
            if server_name ~= "lua_ls" then
                vim.lsp.config(server_name, {
                    capabilities = lsp_capabilities,
                })
            end
        end

        vim.lsp.enable(lsp_servers)
    end,
}
