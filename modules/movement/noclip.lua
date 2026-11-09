
local Module = {}

Module.Name = "NoClip"
Module.Tab = "Movement"
Module.Description = "Walk through solid objects."

Module.Settings = {
    Enabled = false,
    Interval = 0.21
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Connection = nil
local CharacterConnection = nil
local DescendantConnection = nil

local OriginalCollision = {}
local CurrentCharacter = nil

-- ============================================
-- COLLISION MANAGEMENT
-- ============================================

local function savePart(Object)
    if not Object:IsA("BasePart") then
        return
    end

    if OriginalCollision[Object] ~= nil then
        return
    end

    OriginalCollision[Object] = Object.CanCollide
end

local function applyNoClip()
    local Character = LocalPlayer.Character

    if not Character then
        return
    end

    if CurrentCharacter ~= Character then
        OriginalCollision = {}
        CurrentCharacter = Character
    end

    for _, Object in ipairs(Character:GetDescendants()) do
        if Object:IsA("BasePart") then
            savePart(Object)
            Object.CanCollide = false
        end
    end
end

local function restoreCollision()
    for Object, OriginalValue in pairs(OriginalCollision) do
        if Object and Object.Parent then
            pcall(function()
                Object.CanCollide = OriginalValue
            end)
        end
    end

    table.clear(OriginalCollision)
end

-- ============================================
-- CHARACTER MANAGEMENT
-- ============================================

local function disconnectCharacter()
    if DescendantConnection then
        DescendantConnection:Disconnect()
        DescendantConnection = nil
    end
end

local function setupCharacter(Character)
    disconnectCharacter()
    restoreCollision()

    CurrentCharacter = Character

    if not Character then
        return
    end

    DescendantConnection =
        Character.DescendantAdded:Connect(function(Object)
            if not Module.Settings.Enabled then
                return
            end

            if Object:IsA("BasePart") then
                savePart(Object)
                Object.CanCollide = false
            end
        end)
end

-- ============================================
-- MODULE
-- ============================================

function Module:Enable()
    if Connection then
        return
    end

    self.Settings.Enabled = true

    if LocalPlayer.Character then
        setupCharacter(LocalPlayer.Character)
    end

    Connection = RunService.Stepped:Connect(function()
        if self.Settings.Enabled then
            applyNoClip()
        end
    end)
end

function Module:Disable()
    self.Settings.Enabled = false

    if Connection then
        Connection:Disconnect()
        Connection = nil
    end

    disconnectCharacter()
    restoreCollision()

    CurrentCharacter = nil
end

function Module:SetSetting(Name, Value)
    if self.Settings[Name] == nil then
        return false
    end

    self.Settings[Name] = Value

    if Name == "Enabled" then
        if Value then
            self:Enable()
        else
            self:Disable()
        end
    end

    return true
end

function Module:GetSetting(Name)
    return self.Settings[Name]
end

function Module:GetSettings()
    return self.Settings
end

function Module:Destroy()
    self:Disable()

    if CharacterConnection then
        CharacterConnection:Disconnect()
        CharacterConnection = nil
    end
end

-- ============================================
-- INITIALIZATION
-- ============================================

CharacterConnection = LocalPlayer.CharacterAdded:Connect(function(Character)
    if Module.Settings.Enabled then
        setupCharacter(Character)
    end
end)

return Module
