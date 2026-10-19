
local Module = {}

Module.Name = "Customization"
Module.Description = "Customize the menu and performance HUD."

------------------------------------------------------------
-- SERVICES
------------------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------

Module.Settings = {
    Enabled = true,
    Theme = "Ocean",

    ShowFPS = true,
    ShowPing = true,
    HUDColor = Color3.fromRGB(90, 200, 255),

    FPSUnlocker = false,
    FPSCap = 240,
}

------------------------------------------------------------
-- DROPDOWN OPTIONS
------------------------------------------------------------

Module.DropdownOptions = {
    Theme = {
        "Ocean",
        "Purple",
        "Pink",
        "Crimson",
        "Monochrome",
    },
}

------------------------------------------------------------
-- THEMES
------------------------------------------------------------

Module.Themes = {
    Ocean = {
        Accent = Color3.fromRGB(90, 120, 255),
        Background = Color3.fromRGB(15, 16, 20),
        SidebarBackground = Color3.fromRGB(19, 20, 25),
        ElementBackground = Color3.fromRGB(24, 25, 31),
        ElementHover = Color3.fromRGB(31, 33, 41),
        TextColor = Color3.fromRGB(235, 235, 240),
        SubTextColor = Color3.fromRGB(145, 148, 158),
        BorderColor = Color3.fromRGB(43, 44, 52),
    },

    Purple = {
        Accent = Color3.fromRGB(160, 90, 255),
        Background = Color3.fromRGB(16, 14, 20),
        SidebarBackground = Color3.fromRGB(21, 18, 27),
        ElementBackground = Color3.fromRGB(27, 23, 34),
        ElementHover = Color3.fromRGB(37, 31, 46),
        TextColor = Color3.fromRGB(240, 235, 245),
        SubTextColor = Color3.fromRGB(160, 150, 175),
        BorderColor = Color3.fromRGB(50, 43, 60),
    },

    Pink = {
        Accent = Color3.fromRGB(255, 80, 170),
        Background = Color3.fromRGB(20, 14, 18),
        SidebarBackground = Color3.fromRGB(27, 18, 24),
        ElementBackground = Color3.fromRGB(35, 23, 31),
        ElementHover = Color3.fromRGB(47, 30, 41),
        TextColor = Color3.fromRGB(245, 235, 242),
        SubTextColor = Color3.fromRGB(175, 150, 165),
        BorderColor = Color3.fromRGB(60, 42, 52),
    },

    Crimson = {
        Accent = Color3.fromRGB(255, 55, 65),
        Background = Color3.fromRGB(20, 13, 14),
        SidebarBackground = Color3.fromRGB(27, 17, 18),
        ElementBackground = Color3.fromRGB(35, 22, 23),
        ElementHover = Color3.fromRGB(48, 28, 30),
        TextColor = Color3.fromRGB(245, 235, 235),
        SubTextColor = Color3.fromRGB(175, 150, 152),
        BorderColor = Color3.fromRGB(62, 40, 42),
    },

    Monochrome = {
        Accent = Color3.fromRGB(220, 220, 220),
        Background = Color3.fromRGB(12, 12, 12),
        SidebarBackground = Color3.fromRGB(18, 18, 18),
        ElementBackground = Color3.fromRGB(25, 25, 25),
        ElementHover = Color3.fromRGB(35, 35, 35),
        TextColor = Color3.fromRGB(240, 240, 240),
        SubTextColor = Color3.fromRGB(145, 145, 145),
        BorderColor = Color3.fromRGB(45, 45, 45),
    },
}

------------------------------------------------------------
-- INTERNAL STATE
------------------------------------------------------------

Module._UI = nil
Module._hudGui = nil
Module._hudLabels = {}
Module._hudConnections = {}
Module._dragStates = {}

Module._fpsFrames = 0
Module._fpsElapsed = 0
Module._currentFPS = 0

------------------------------------------------------------
-- SETTINGS API
------------------------------------------------------------

function Module:GetSetting(name)
    return self.Settings[name]
end

function Module:SetSetting(name, value)
    if self.Settings[name] == nil then
        return
    end

    if name == "Theme" then
        if not self.Themes[value] then
            return
        end
    elseif name == "FPSCap" then
        value = tonumber(value)

        if not value then
            return
        end

        value = math.clamp(math.floor(value), 30, 1000)
    elseif name == "HUDColor" then
        if typeof(value) ~= "Color3" then
            return
        end
    elseif name == "ShowFPS"
        or name == "ShowPing"
        or name == "FPSUnlocker"
        or name == "Enabled" then

        if typeof(value) ~= "boolean" then
            return
        end
    end

    self.Settings[name] = value

    if name == "Theme" then
        self:ApplyTheme()
    end

    if name == "FPSUnlocker" or name == "FPSCap" then
        self:ApplyFPSCap()
    end

    if name == "Enabled" then
        if value then
            self:Enable()
        else
            self:Disable()
        end
    end

    self:RefreshHUD()
end

------------------------------------------------------------
-- DROPDOWN API
------------------------------------------------------------

function Module:GetDropdownOptions(name)
    return self.DropdownOptions[name]
end

------------------------------------------------------------
-- THEME API
------------------------------------------------------------

function Module:GetTheme()
    return self.Themes[self.Settings.Theme]
end

function Module:GetThemes()
    return self.Themes
end

function Module:ApplyTheme()
    local theme = self:GetTheme()

    if not theme then
        return
    end

    self.CurrentTheme = theme

    if self._UI then
        self._UI:ApplyTheme(theme)
    end
end

------------------------------------------------------------
-- FPS CAP
------------------------------------------------------------

function Module:ApplyFPSCap()
    if type(setfpscap) ~= "function" then
        if self.Settings.FPSUnlocker then
            warn("[Customization] FPS cap is unsupported here.")
        end
        return
    end

    local cap = 60

    if self.Settings.FPSUnlocker then
        cap = math.clamp(
            tonumber(self.Settings.FPSCap) or 240,
            30,
            1000
        )
    end

    local success, err = pcall(setfpscap, cap)

    if not success then
        warn("[Customization] FPS cap failed: " .. tostring(err))
    end
end

------------------------------------------------------------
-- HUD CREATION
------------------------------------------------------------

function Module:CreateHUD()
    self:DestroyHUD()

    local player = Players.LocalPlayer

    if not player then
        warn("[Customization] LocalPlayer unavailable.")
        return
    end

    local playerGui = player:WaitForChild("PlayerGui")

    local gui = Instance.new("ScreenGui")
    gui.Name = "CustomizationHUD"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 100
    gui.Parent = playerGui

    self._hudGui = gui

    local function createLabel(name, text, position)
        local label = Instance.new("TextLabel")

        label.Name = name
        label.Position = position
        label.Size = UDim2.fromOffset(120, 32)
        label.AutomaticSize = Enum.AutomaticSize.X
        label.BackgroundColor3 = Color3.fromRGB(18, 20, 27)
        label.BackgroundTransparency = 0.15
        label.BorderSizePixel = 0
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 14
        label.Text = text
        label.TextColor3 = self.Settings.HUDColor
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.Active = true
        label.Visible = false
        label.Parent = gui

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 12)
        padding.PaddingRight = UDim.new(0, 12)
        padding.Parent = label

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = label

        self._hudLabels[name] = label

        return label
    end

    local fpsLabel = createLabel(
        "FPSCounter",
        "FPS: --",
        UDim2.fromOffset(20, 20)
    )

    local pingLabel = createLabel(
        "PingCounter",
        "Ping: -- ms",
        UDim2.fromOffset(20, 60)
    )

    --------------------------------------------------------
    -- INDEPENDENT DRAGGING
    --------------------------------------------------------

    local function makeDraggable(label)
        local state = {
            dragging = false,
            pointer = nil,
            startPointer = nil,
            startPosition = nil,
        }

        self._dragStates[label] = state

        local began = label.InputBegan:Connect(function(input)
            local inputType = input.UserInputType

            if inputType ~= Enum.UserInputType.MouseButton1
                and inputType ~= Enum.UserInputType.Touch then
                return
            end

            state.dragging = true
            state.pointer = input

            state.startPointer = Vector2.new(
                input.Position.X,
                input.Position.Y
            )

            state.startPosition = Vector2.new(
                label.Position.X.Offset,
                label.Position.Y.Offset
            )
        end)

        table.insert(self._hudConnections, began)

        local ended = UserInputService.InputEnded:Connect(function(input)
            if input == state.pointer
                or input.UserInputType == Enum.UserInputType.MouseButton1 then

                state.dragging = false
                state.pointer = nil
            end
        end)

        table.insert(self._hudConnections, ended)

        local changed = UserInputService.InputChanged:Connect(function(input)
            if not state.dragging then
                return
            end

            local inputType = input.UserInputType

            if inputType ~= Enum.UserInputType.MouseMovement
                and inputType ~= Enum.UserInputType.Touch then
                return
            end

            local pointer = Vector2.new(
                input.Position.X,
                input.Position.Y
            )

            local delta = pointer - state.startPointer

            label.Position = UDim2.fromOffset(
                math.max(0, state.startPosition.X + delta.X),
                math.max(0, state.startPosition.Y + delta.Y)
            )
        end)

        table.insert(self._hudConnections, changed)
    end

    makeDraggable(fpsLabel)
    makeDraggable(pingLabel)

    --------------------------------------------------------
    -- HUD UPDATER
    --------------------------------------------------------

    self._fpsFrames = 0
    self._fpsElapsed = 0

    local renderConnection = RunService.RenderStepped:Connect(function(dt)
        if not self._hudGui or not self._hudGui.Parent then
            return
        end

        self._fpsFrames += 1
        self._fpsElapsed += dt

        if self._fpsElapsed < 0.5 then
            return
        end

        self._currentFPS = math.floor(
            self._fpsFrames / self._fpsElapsed + 0.5
        )

        self._fpsFrames = 0
        self._fpsElapsed = 0

        fpsLabel.Text = "FPS: " .. self._currentFPS

        local pingText = "--"

        local success, result = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
        end)

        if success and result then
            pingText = tostring(result):gsub("%s*ms", "")
        end

        pingLabel.Text = "Ping: " .. pingText .. " ms"

        self:RefreshHUD()
    end)

    table.insert(self._hudConnections, renderConnection)

    self:RefreshHUD()
end

------------------------------------------------------------
-- HUD REFRESH
------------------------------------------------------------

function Module:RefreshHUD()
    for name, label in pairs(self._hudLabels) do
        if label and label.Parent then
            label.TextColor3 = self.Settings.HUDColor

            if name == "FPSCounter" then
                label.Visible = self.Settings.Enabled
                    and self.Settings.ShowFPS
            elseif name == "PingCounter" then
                label.Visible = self.Settings.Enabled
                    and self.Settings.ShowPing
            end
        end
    end
end

------------------------------------------------------------
-- HUD CLEANUP
------------------------------------------------------------

function Module:DestroyHUD()
    for _, connection in ipairs(self._hudConnections) do
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end

    table.clear(self._hudConnections)
    table.clear(self._hudLabels)
    table.clear(self._dragStates)

    if self._hudGui then
        self._hudGui:Destroy()
        self._hudGui = nil
    end
end

------------------------------------------------------------
-- MODULE API
------------------------------------------------------------

function Module:Enable()
    self.Settings.Enabled = true

    self:ApplyTheme()
    self:CreateHUD()
    self:ApplyFPSCap()
end

function Module:Disable()
    self.Settings.Enabled = false

    self:DestroyHUD()
    self:ApplyFPSCap()
end

function Module:Initialize()
    self:ApplyTheme()

    if self.Settings.Enabled then
        self:CreateHUD()
        self:ApplyFPSCap()
    end
end

return Module
