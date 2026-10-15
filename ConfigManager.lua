
-- ConfigManager.lua
-- Named configuration presets for supported executor environments

local HttpService = game:GetService("HttpService")

local ConfigManager = {}

local FOLDER = "RobloxHackMenu"
local PRESET_FOLDER = FOLDER .. "/Presets"

local function ensureFolders()
    if not isfolder(FOLDER) then
        makefolder(FOLDER)
    end

    if not isfolder(PRESET_FOLDER) then
        makefolder(PRESET_FOLDER)
    end
end

local function presetPath(name)
    -- Prevent invalid paths and directory traversal
    name = tostring(name or "")
    name = name:gsub("[^%w _%-]", "")
    name = name:match("^%s*(.-)%s*$")

    assert(name ~= "", "Enter a valid preset name")
    assert(#name <= 40, "Preset names must be 40 characters or less")

    return PRESET_FOLDER .. "/" .. name .. ".json", name
end

function ConfigManager.Save(name, settings)
    assert(type(settings) == "table", "Settings must be a table")
    ensureFolders()

    local path, cleanName = presetPath(name)
    local encoded = HttpService:JSONEncode(settings)

    writefile(path, encoded)

    return cleanName
end

function ConfigManager.Load(name)
    ensureFolders()

    local path = presetPath(name)
    assert(isfile(path), "Preset not found: " .. tostring(name))

    local decoded = HttpService:JSONDecode(readfile(path))
    assert(type(decoded) == "table", "Invalid preset file")

    return decoded
end

function ConfigManager.List()
    ensureFolders()

    local presets = {}

    for _, path in ipairs(listfiles(PRESET_FOLDER)) do
        local name = path:match("[/\\]([^/\\]+)%.json$")

        if name then
            table.insert(presets, name)
        end
    end

    table.sort(presets)
    return presets
end

function ConfigManager.Delete(name)
    ensureFolders()

    local path = presetPath(name)
    assert(isfile(path), "Preset not found")

    delfile(path)
end

return ConfigManager
