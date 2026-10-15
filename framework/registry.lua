
local Registry = {}

Registry.Modules = {}

------------------------------------------------------------
-- DEFAULT TABS
------------------------------------------------------------

Registry.ByTab = {
    Visuals = {},
    Movement = {},
    Combat = {},
    Events = {},
    Customization = {},
    Utilities = {},
}

------------------------------------------------------------
-- REGISTER
------------------------------------------------------------

function Registry:Register(Module)
    if type(Module) ~= "table" or not Module.Name then
        warn("[Registry] Invalid module.")
        return false
    end

    if self.Modules[Module.Name] then
        warn("[Registry] Module already registered: " .. Module.Name)
        return false
    end

    local Tab = Module.Tab or "Utilities"

    if type(Tab) ~= "string" or Tab == "" then
        Tab = "Utilities"
    end

    Module.Tab = Tab

    self.Modules[Module.Name] = Module

    if not self.ByTab[Tab] then
        self.ByTab[Tab] = {}
    end

    table.insert(self.ByTab[Tab], Module)

    return true
end

------------------------------------------------------------
-- LOAD MANIFEST
------------------------------------------------------------

function Registry:LoadManifest(Manifest, BaseURL)
    if type(Manifest) ~= "table" then
        warn("[Registry] Invalid manifest.")
        return false
    end

    if type(BaseURL) ~= "string" then
        warn("[Registry] Invalid BaseURL.")
        return false
    end

    for _, Entry in ipairs(Manifest) do
        if type(Entry) ~= "table" then
            warn("[Registry] Invalid manifest entry.")
            continue
        end

        local Name = Entry.Name
        local File = Entry.File
        local Tab = Entry.Tab

        if type(Name) ~= "string" or Name == ""
            or type(File) ~= "string" or File == "" then
            warn("[Registry] Manifest entry is missing a valid Name or File.")
            continue
        end

        local DownloadSuccess, Source = pcall(function()
            return game:HttpGet(BaseURL .. File)
        end)

        if not DownloadSuccess then
            warn("[Registry] Failed to download: " .. File)
            warn(tostring(Source))
            continue
        end

        if type(Source) ~= "string" or Source == "" then
            warn("[Registry] Empty source: " .. File)
            continue
        end

        local CompileSuccess, Chunk, CompileError = pcall(loadstring, Source)

        if not CompileSuccess or type(Chunk) ~= "function" then
            warn("[Registry] Failed to compile: " .. File)
            warn(tostring(CompileError or Chunk))
            continue
        end

        local ExecuteSuccess, Module = pcall(Chunk)

        if not ExecuteSuccess then
            warn("[Registry] Failed to execute: " .. File)
            warn(tostring(Module))
            continue
        end

        if type(Module) ~= "table" then
            warn("[Registry] Module did not return a table: " .. File)
            continue
        end

        -- Manifest metadata takes priority.
        Module.Name = Name

        if type(Tab) == "string" and Tab ~= "" then
            Module.Tab = Tab
        end

        if self:Register(Module) then
            print("[Registry] Loaded: " .. Name .. " [" .. Module.Tab .. "]")
        end
    end

    return true
end

------------------------------------------------------------
-- UNREGISTER
------------------------------------------------------------

function Registry:Unregister(Name)
    local Module = self.Modules[Name]

    if not Module then
        return false
    end

    if type(Module.Destroy) == "function" then
        local Success, Err = pcall(function()
            Module:Destroy()
        end)

        if not Success then
            warn("[Registry] Destroy failed for " .. Name .. ": " .. tostring(Err))
        end
    elseif type(Module.Disable) == "function" then
        pcall(function()
            Module:Disable()
        end)
    end

    self.Modules[Name] = nil

    local Tab = Module.Tab
    local TabModules = Tab and self.ByTab[Tab]

    if TabModules then
        for Index = #TabModules, 1, -1 do
            if TabModules[Index] == Module then
                table.remove(TabModules, Index)
            end
        end
    end

    return true
end

------------------------------------------------------------
-- GET MODULE
------------------------------------------------------------

function Registry:Get(Name)
    return self.Modules[Name]
end

------------------------------------------------------------
-- GET ALL MODULES
------------------------------------------------------------

function Registry:GetAll()
    return self.Modules
end

------------------------------------------------------------
-- GET MODULES BY TAB
------------------------------------------------------------

function Registry:GetByTab(Tab)
    return self.ByTab[Tab] or {}
end

------------------------------------------------------------
-- ENABLE / DISABLE
------------------------------------------------------------

function Registry:Enable(Name)
    local Module = self:Get(Name)

    if not Module or type(Module.Enable) ~= "function" then
        return false
    end

    local Success, Result = pcall(function()
        return Module:Enable()
    end)

    if not Success then
        warn("[Registry] Enable failed for " .. Name .. ": " .. tostring(Result))
        return false
    end

    if Module.Settings then
        Module.Settings.Enabled = true
    end

    return true
end

function Registry:Disable(Name)
    local Module = self:Get(Name)

    if not Module or type(Module.Disable) ~= "function" then
        return false
    end

    local Success, Result = pcall(function()
        return Module:Disable()
    end)

    if not Success then
        warn("[Registry] Disable failed for " .. Name .. ": " .. tostring(Result))
        return false
    end

    if Module.Settings then
        Module.Settings.Enabled = false
    end

    return true
end

------------------------------------------------------------
-- TOGGLE
------------------------------------------------------------

function Registry:Toggle(Name)
    local Module = self:Get(Name)

    if not Module or not Module.Settings then
        return false
    end

    if Module.Settings.Enabled then
        return self:Disable(Name)
    else
        return self:Enable(Name)
    end
end

------------------------------------------------------------
-- SETTING MANAGEMENT
------------------------------------------------------------

function Registry:SetSetting(Name, Setting, Value)
    local Module = self:Get(Name)

    if not Module then
        return false
    end

    if type(Module.SetSetting) == "function" then
        local Success, Result = pcall(function()
            return Module:SetSetting(Setting, Value)
        end)

        if not Success then
            warn("[Registry] Setting update failed for " .. Name .. ": " .. tostring(Result))
            return false
        end

        return Result ~= false
    end

    if Module.Settings and Module.Settings[Setting] ~= nil then
        Module.Settings[Setting] = Value
        return true
    end

    return false
end

function Registry:GetSetting(Name, Setting)
    local Module = self:Get(Name)

    if not Module or not Module.Settings then
        return nil
    end

    return Module.Settings[Setting]
end

------------------------------------------------------------
-- DEBUG
------------------------------------------------------------

function Registry:PrintModules()
    print("========== MODULE REGISTRY ==========")

    for Tab, Modules in pairs(self.ByTab) do
        print("[" .. Tab .. "]")

        for _, Module in ipairs(Modules) do
            print("  - " .. Module.Name)
        end
    end

    print("=====================================")
end

return Registry
