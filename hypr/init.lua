-- Entry point of the HyprDora config. The user's hyprland.lua only loads this file.

local hypr_dir = debug.getinfo(1, "S").source:match("^@(.*)/init%.lua$")
package.path = hypr_dir:match("^(.*)/[^/]+$") .. "/?.lua;" .. package.path

local paths = require("hypr.lib.paths")
local user = require("hypr.lib.user")

_G.act = require("hypr.lib.actions")

require("hypr.env")
require("hypr.look")
require("hypr.input")
require("hypr.rules")
require("hypr.autostart")

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
user.load("monitors")
-- Settings the shell writes, such as the touchpad's scrolling direction; settings.lua below can override them.
user.load("input")

require("hypr.lib.binds").apply(require("hypr.binds"), user.load("binds"), paths.dev)

user.load("settings")
