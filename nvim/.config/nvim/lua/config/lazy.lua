-- Bootstrap and setup for lazy.nvim plugin manager
-- This work made by Anfinogentov Nikita

local lazy_path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv_loop = vim.uv or vim.loop

if not uv_loop.fs_stat(lazy_path) then
    local lazy_repo = "https://github.com/folke/lazy.nvim.git"
    local clone_out = vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "--branch=stable",
        lazy_repo,
        lazy_path,
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { clone_out, "WarningMsg" },
        }, true, {})
    end
end

vim.opt.rtp:prepend(lazy_path)

-- Здесь я загружаю модуль matugen заранее, чтобы команда :MatugenReload и запасная схема работали даже до установки плагинов
local matugen_ok, matugen_mod = pcall(require, "config.matugen")
if matugen_ok then
    matugen_mod.load_matugen_colors()
end

local lazy_ok, lazy_plugin = pcall(require, "lazy")
if lazy_ok then
    lazy_plugin.setup({
        spec = {
            { import = "plugins" },
        },
    })
end
