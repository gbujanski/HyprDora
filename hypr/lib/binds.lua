-- Merges default and user keybindings and registers them.

local user = require("hypr.lib.user")

local M = {}

---Returns a comparable form of a key combination, independent of case and order.
---@param keys string key combination such as "SUPER + T"
---@return string
local function normalized(keys)
    local parts = {}
    for part in keys:gmatch("[^+%s]+") do
        parts[#parts + 1] = part:lower()
    end
    table.sort(parts)
    return table.concat(parts, "+")
end

---Returns what makes an entry unique: its keys, and whether it acts on release.
---@param entry table keybinding entry
---@return string
local function identity(entry)
    local release = entry[4] ~= nil and entry[4].release
    return normalized(entry[1]) .. (release and ":release" or "")
end

---Returns the keybindings of a list with the group heading each comes under, leaving the headings out.
---@param list table[] entries and headings such as { group = "Windows" }
---@return table[] copies of the entries, each with its `group` or none
local function grouped(list)
    local result = {}
    local group = nil
    for _, entry in ipairs(list) do
        if entry.group ~= nil and entry[1] == nil then
            group = entry.group
        else
            result[#result + 1] = { entry[1], entry[2], entry[3], entry[4], group = group }
        end
    end
    return result
end

---Reports keys listed more than once in one file.
---@param entries table[] keybinding entries
---@param source string file name for the message
local function report_duplicates(entries, source)
    local seen = {}
    for _, entry in ipairs(entries) do
        local key = identity(entry)
        if seen[key] then
            user.report("duplicate keybinding in " .. source .. ": " .. entry[1])
        end
        seen[key] = true
    end
end

---Combines the lists. A user entry replaces the default for the same keys, and `false` removes it; a user
---entry without a group of its own keeps the default's.
---@param defaults table[] default entries
---@param overrides table[] user entries
---@return table[] merged entries in order
local function merged(defaults, overrides)
    local result = {}
    local index = {}
    local function put(entry)
        local key = identity(entry)
        if index[key] then
            entry.group = entry.group or result[index[key]].group
            result[index[key]] = entry
        else
            result[#result + 1] = entry
            index[key] = #result
        end
    end
    for _, entry in ipairs(defaults) do
        put(entry)
    end
    for _, entry in ipairs(overrides) do
        put(entry)
    end
    return result
end

---Registers keybindings.
---@param defaults table[] default entries: { keys, action, description, options }, and group headings
---@param overrides table[]|nil entries from the user's binds.lua
---@param dev boolean whether SUPER is replaced by ALT, because an outer session captures SUPER
function M.apply(defaults, overrides, dev)
    if overrides ~= nil and type(overrides) ~= "table" then
        user.report("binds.lua must return a list")
        overrides = nil
    end
    defaults = grouped(defaults)
    overrides = grouped(overrides or {})
    report_duplicates(defaults, "defaults")
    report_duplicates(overrides, "binds.lua")

    for _, entry in ipairs(merged(defaults, overrides)) do
        if entry[2] then
            local options = {}
            for name, value in pairs(entry[4] or {}) do
                options[name] = value
            end
            -- Hyprland keeps one description, so the group goes in front of it, after a tab the shell splits on.
            options.description = entry.group and entry[3] and (entry.group .. "\t" .. entry[3]) or entry[3]
            local keys = dev and entry[1]:gsub("SUPER", "ALT") or entry[1]
            hl.bind(keys, entry[2], options)
        end
    end
end

return M
