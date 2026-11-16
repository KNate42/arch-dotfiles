-- Global key mappings with space as leader key
-- This work made by Anfinogentov Nikita

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map_key = vim.keymap.set

map_key("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlights" })
map_key("n", "<leader>w", "<cmd>w<CR>", { desc = "Save buffer" })
map_key("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic location list" })
map_key("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show line diagnostics" })

map_key("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to left window" })
map_key("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to right window" })
map_key("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to lower window" })
map_key("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to upper window" })

map_key("n", "<leader>o", "<cmd>Oil<CR>", { desc = "Open Oil file manager" })
map_key("n", "<leader>cm", "<cmd>MatugenReload<CR>", { desc = "Reload Matugen colorscheme" })
