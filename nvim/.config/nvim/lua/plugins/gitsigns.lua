-- Git decorations and hunk actions via gitsigns.nvim
-- This work made by Anfinogentov Nikita

return {
    "lewis6991/gitsigns.nvim",
    opts = {
        signs = {
            add = { text = "+" },
            change = { text = "~" },
            delete = { text = "_" },
            topdelete = { text = "‾" },
            changedelete = { text = "~" },
        },
        on_attach = function(buf_num)
            local gitsigns = package.loaded.gitsigns
            local map_key = vim.keymap.set
            local map_opts = { buffer = buf_num }

            map_key("n", "]c", function()
                if vim.wo.diff then
                    vim.cmd.normal({ "]c", bang = true })
                else
                    gitsigns.nav_hunk("next")
                end
            end, map_opts)

            map_key("n", "[c", function()
                if vim.wo.diff then
                    vim.cmd.normal({ "[c", bang = true })
                else
                    gitsigns.nav_hunk("prev")
                end
            end, map_opts)

            map_key("n", "<leader>hs", gitsigns.stage_hunk, map_opts)
            map_key("n", "<leader>hr", gitsigns.reset_hunk, map_opts)
            map_key("n", "<leader>hp", gitsigns.preview_hunk, map_opts)
            map_key("n", "<leader>hb", function()
                gitsigns.blame_line({ full = true })
            end, map_opts)
        end,
    },
}
