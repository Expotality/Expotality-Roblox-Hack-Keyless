
local BASE_URL = "https://raw.githubusercontent.com/Expotality/Expotality-Roblox-Hack-Keyless/main/"

local function fetch(path)
    local url = BASE_URL .. path

    local success, result = pcall(function()
        return game:HttpGet(url)
    end)

    if not success then
        error("Failed to download " .. path .. ": " .. tostring(result))
    end

    return result
end

local function loadRemote(path)
    local source = fetch(path)

    local success, result = pcall(function()
        return loadstring(source)()
    end)

    if not success then
        warn("[Menu] Failed to load " .. path)
        warn(result)
        return nil
    end

    return result
end

print("[Menu] Loading...")

-- Load manifest
local manifest = loadRemote("manifest.lua")

if not manifest then
    error("[Menu] Manifest failed to load.")
end

-- Load registry
local registry = loadRemote("framework/registry.lua")

if not registry then
    error("[Menu] Registry failed to load.")
end

-- Load configuration manager
local configManager = loadRemote("framework/ConfigManager.lua")

if not configManager then
    error("[Menu] ConfigManager failed to load.")
end

-- Load UI
local ui = loadRemote("framework/ui.lua")

if not ui then
    error("[Menu] UI failed to load.")
end

-- Register modules
registry:LoadManifest(manifest, BASE_URL)

-- Initialize UI with configuration manager
ui:Initialize(registry, configManager)

print("[Menu] Loaded successfully.")

