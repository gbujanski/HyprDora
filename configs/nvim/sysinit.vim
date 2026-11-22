" Neovim's system config, read before the user's. Neovim skips Fedora's own (/usr/share/nvim/sysinit.vim) once
" this file exists, so it is read here first. HyprDora's default config, LazyVim, then starts, unless the user
" has an init file of their own in ~/.config/nvim, which replaces it whole.
if filereadable('/usr/share/nvim/sysinit.vim')
  source /usr/share/nvim/sysinit.vim
endif

lua << LUA
local user = vim.fn.stdpath("config")
if vim.uv.fs_stat(user .. "/init.lua") or vim.uv.fs_stat(user .. "/init.vim") then
  return
end
-- HYPRDORA_NVIM points at the repository's copy, to try a change before installing it.
local root = vim.env.HYPRDORA_NVIM or "/usr/share/hyprdora/configs/nvim"
vim.opt.rtp:prepend(root)
dofile(root .. "/init.lua")
LUA
