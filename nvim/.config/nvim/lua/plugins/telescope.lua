-- Fuzzy finder configuration with Telescope and Plenary
-- This work made by Anfinogentov Nikita

return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    config = function()
        local telescope = require("telescope")
        local builtin_pickers = require("telescope.builtin")
        local map_key = vim.keymap.set

        telescope.setup({
            defaults = {
                layout_strategy = "horizontal",
                sorting_strategy = "ascending",
            },
        })

        map_key("n", "<leader>ff", builtin_pickers.find_files, { desc = "Find files" })
        map_key("n", "<leader>fg", builtin_pickers.live_grep, { desc = "Live grep" })
        map_key("n", "<leader>fb", builtin_pickers.buffers, { desc = "Find buffers" })
        map_key("n", "<leader>fh", builtin_pickers.help_tags, { desc = "Find help tags" })
    end,
}
