-- Locations and the launch mode, shared by the other config files.

local dev_shell = os.getenv("HYPRDORA_SHELL")
local root = debug.getinfo(1, "S").source:match("^@(.*)/hypr/lib/paths%.lua$")

return {
    root = root,
    user_dir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr",
    dev = dev_shell ~= nil,
    shell = dev_shell and ("qs -p " .. dev_shell) or "qs -c hyprdora",
}
