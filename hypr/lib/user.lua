-- Loads optional files from the user's config directory.

local paths = require("hypr.lib.paths")

package.path = paths.user_dir .. "/?.lua;" .. package.path

local M = {}

---Shows a config problem on screen.
---@param text string message to show
function M.report(text)
    hl.notification.create({ text = "HyprDora: " .. text, timeout = 10000 })
end

---Runs a user file if it exists. An error is reported and does not stop the defaults from loading.
---Files go through require, because Hyprland reloads the config when a required file changes.
---@param name string file name without the extension
---@return any value the value returned by the file, or nil
function M.load(name)
    local file = io.open(paths.user_dir .. "/" .. name .. ".lua", "r")
    if file == nil then
        return nil
    end
    file:close()

    local ok, result = pcall(require, name)
    if not ok then
        M.report(tostring(result))
        return nil
    end
    return result
end

return M
