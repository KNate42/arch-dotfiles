-- Core editor options for Neovim 0.12
-- This work made by Anfinogentov Nikita

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local vim_opt = vim.opt

vim_opt.number = true
vim_opt.relativenumber = true
vim_opt.mouse = "a"
vim_opt.showmode = false
vim_opt.clipboard = "unnamedplus"
vim_opt.breakindent = true
vim_opt.undofile = true
vim_opt.ignorecase = true
vim_opt.smartcase = true
vim_opt.signcolumn = "yes"
vim_opt.updatetime = 250
vim_opt.timeoutlen = 300
vim_opt.splitright = true
vim_opt.splitbelow = true
vim_opt.list = true
vim_opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
vim_opt.inccommand = "split"
vim_opt.cursorline = true
vim_opt.scrolloff = 8
vim_opt.shiftwidth = 4
vim_opt.tabstop = 4
vim_opt.softtabstop = 4
vim_opt.expandtab = true
vim_opt.smartindent = true
vim_opt.termguicolors = true
vim_opt.wrap = false
