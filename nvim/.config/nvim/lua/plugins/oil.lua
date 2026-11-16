-- Buffer-based file explorer configuration using oil.nvim
-- This work made by Anfinogentov Nikita

return {
    "stevearc/oil.nvim",
    lazy = false,
    opts = {
        default_file_explorer = true,
        view_options = {
            show_hidden = true,
        },
    },
    config = function(_, plugin_opts)
        require("oil").setup(plugin_opts)
        vim.keymap.set("n", "-", "<cmd>Oil<CR>", { desc = "Open parent directory in Oil" })
    end,
}
