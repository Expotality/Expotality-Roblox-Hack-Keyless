
local HttpService = game:GetService("HttpService")

local ConfigManager = {}

local ROOT = "ExpotalityMenu"
local PRESETS = ROOT .. "/Presets"

local function ensureFolders()
    if not isfolder(ROOT) then
        makefolder(ROOT)
    end

    if not isfolder(PRESETS) then
        makefolder(PRESETS)
    end
end

local function cleanName(name)
    name = tostring(name or "")
    name = name:gsub("[^%w _%-]", "")
    name = name:match("^%s*(.-)%s*$")

    assert(name ~= "", "Enter a preset name.")
    assert(#name <= 40, "Preset names must be 40 characters or less.")

    return name
end

local function pathFor(name)
    return PRESETS .. "/" .. cleanName(name) .. ".json"
end

function ConfigManager.Save(name, settings)
    ensureFolders()

    assert(type(settings) == "table", "Settings must be a table.")

    local path = pathFor(name)
    writefile(path, HttpService:JSONEncode(settings))

    return cleanName(name)
end

function ConfigManager.Load(name)
    ensureFolders()

    local path = pathFor(name)
    assert(isfile(path), "Preset not found.")

    local result = HttpService:JSONDecode(readfile(path))
    assert(type(result) == "table", "Preset file is invalid.")

    return result
end

function ConfigManager.SaveLast(settings)
    return ConfigManager.Save("LastSession", settings)
end

function ConfigManager.LoadLast()
    ensureFolders()

    if not isfile(pathFor("LastSession")) then
        return nil
    end

    return ConfigManager.Load("LastSession")
end

function ConfigManager.List()
    ensureFolders()

    local results = {}

    for _, file in ipairs(listfiles(PRESETS)) do
        local name = file:match("[/\\]([^/\\]+)%.json$")

        if name and name ~= "LastSession" then
            table.insert(results, name)
        end
    end

    table.sort(results)
    return results
end

function ConfigManager.Delete(name)
    ensureFolders()

    name = cleanName(name)
    assert(name ~= "LastSession", "The automatic session cannot be deleted here.")

    local path = pathFor(name)
    assert(isfile(path), "Preset not found.")

    delfile(path)
end

return ConfigManager
