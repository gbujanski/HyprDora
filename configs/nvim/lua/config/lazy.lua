-- LazyVim with the languages HyprDora and its tools use. Plugins are fetched from GitHub on the first start
-- and live in ~/.local/share/nvim, with the lock file, since this folder belongs to the package. Plugins of
-- one's own go in ~/.config/nvim/lua/plugins/, which is read after these.

local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))))
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
    local out = vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "--branch=stable",
        "https://github.com/folke/lazy.nvim.git",
        lazypath,
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({ { "Failed to clone lazy.nvim:\n", "ErrorMsg" }, { out, "WarningMsg" } }, true, {})
        return
    end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = {
        { "LazyVim/LazyVim", import = "lazyvim.plugins" },
        -- HyprDora's own languages; Lua and shell come with LazyVim.
        { import = "lazyvim.plugins.extras.lang.python" },
        { import = "lazyvim.plugins.extras.lang.json" },
        { import = "lazyvim.plugins.extras.lang.yaml" },
        { import = "lazyvim.plugins.extras.lang.toml" },
        { import = "lazyvim.plugins.extras.lang.markdown" },
        { import = "lazyvim.plugins.extras.lang.git" },
        -- Web.
        { import = "lazyvim.plugins.extras.lang.typescript" },
        { import = "lazyvim.plugins.extras.lang.tailwind" },
        { import = "lazyvim.plugins.extras.lang.docker" },
        -- .NET and Java, whose language servers start only with a project of theirs.
        { import = "lazyvim.plugins.extras.lang.dotnet" },
        { import = "lazyvim.plugins.extras.lang.java" },
        { import = "plugins" },
    },
    defaults = { lazy = false, version = false },
    install = { colorscheme = { "tokyonight", "habamax" } },
    -- New plugin versions are looked for now and then, without a message; :Lazy update installs them.
    checker = { enabled = true, notify = false },
    lockfile = vim.fn.stdpath("data") .. "/lazy-lock.json",
    performance = {
        rtp = {
            -- Kept when lazy.nvim resets the runtime path, or this config could not find its own files.
            paths = { root },
            disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
        },
    },
})
