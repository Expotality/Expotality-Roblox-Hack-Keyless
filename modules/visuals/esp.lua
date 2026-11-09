
local Module = {}

Module.Name = "ESP"
Module.Tab = "Visuals"
Module.Description = "Player and NPC ESP."

Module.Settings = {
    Enabled = false,

    -- Player filtering
    EnemyOnly = false,

    -- NPC ESP
    NPCESP = false,

    -- Box
    BoxESP = false,
    BoxStyle = "Corner",
    BoxColor = Color3.fromRGB(255, 25, 25),

    -- Chams
    ChamsEnabled = false,
    ChamsFillColor = Color3.fromRGB(255, 0, 0),
    ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
    ChamsTransparency = 0.5,

    -- Username / Model name
    Username = false,
    UsernameColor = Color3.fromRGB(255, 255, 255),

    -- Distance
    StudsAway = true,
    DistanceColor = Color3.fromRGB(200, 200, 200),
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local ESPObjects = {}
local NPCModels = {}

local Connections = {}

-- ============================================
-- TARGET DETECTION
-- ============================================

local function getRoot(model)
    if not model then
        return nil
    end

    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("UpperTorso")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart", true)
end

local function getHumanoid(model)
    if not model then
        return nil
    end

    return model:FindFirstChildOfClass("Humanoid")
end

local function isNPC(model)
    if not model or not model:IsA("Model") then
        return false
    end

    -- Never classify actual player characters as NPCs.
    if Players:GetPlayerFromCharacter(model) then
        return false
    end

    -- Only two detection methods.
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local animationController =
        model:FindFirstChildOfClass("AnimationController")

    return humanoid ~= nil or animationController ~= nil
end

local function isEnemy(player)
    if not Module.Settings.EnemyOnly then
        return true
    end

    -- Fall back to normal ESP if teams cannot be determined.
    if not LocalPlayer.Team or not player.Team then
        return true
    end

    return player.Team ~= LocalPlayer.Team
end

-- ============================================
-- DRAWING CREATION
-- ============================================

local function createLine()
    local line = Drawing.new("Line")

    line.Visible = false
    line.Thickness = 1
    line.Transparency = 1

    return line
end

local function createText()
    local text = Drawing.new("Text")

    text.Visible = false
    text.Center = true
    text.Outline = true
    text.Size = 14
    text.Transparency = 1

    return text
end

local function createBox()
    return {
        Top = createLine(),
        Bottom = createLine(),
        Left = createLine(),
        Right = createLine(),
    }
end

local function hideDrawing(object)
    if object then
        object.Visible = false
    end
end

-- ============================================
-- ESP OBJECT MANAGEMENT
-- ============================================

local function createESP(key)
    if ESPObjects[key] then
        return ESPObjects[key]
    end

    local data = {
        Box = createBox(),
        Username = createText(),
        Distance = createText(),
        Highlight = nil,
    }

    ESPObjects[key] = data

    return data
end

local function hideESP(key)
    local data = ESPObjects[key]

    if not data then
        return
    end

    for _, line in pairs(data.Box) do
        hideDrawing(line)
    end

    hideDrawing(data.Username)
    hideDrawing(data.Distance)

    if data.Highlight then
        data.Highlight.Enabled = false
    end
end

local function removeESP(key)
    local data = ESPObjects[key]

    if not data then
        return
    end

    for _, line in pairs(data.Box) do
        pcall(function()
            line:Remove()
        end)
    end

    pcall(function()
        data.Username:Remove()
        data.Distance:Remove()
    end)

    if data.Highlight then
        pcall(function()
            data.Highlight:Destroy()
        end)
    end

    ESPObjects[key] = nil
end

-- ============================================
-- CHAMS
-- ============================================

local function updateHighlight(key, data, model)
    if not data.Highlight or data.Highlight.Parent ~= model then
        if data.Highlight then
            pcall(function()
                data.Highlight:Destroy()
            end)
        end

        local highlight = Instance.new("Highlight")

        highlight.Name = "ESP_Chams"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = Module.Settings.ChamsTransparency
        highlight.OutlineTransparency = 0
        highlight.FillColor = Module.Settings.ChamsFillColor
        highlight.OutlineColor = Module.Settings.ChamsOutlineColor
        highlight.Enabled = false
        highlight.Parent = model

        data.Highlight = highlight
    end

    local highlight = data.Highlight

    highlight.Enabled =
        Module.Settings.Enabled
        and Module.Settings.ChamsEnabled

    highlight.FillColor = Module.Settings.ChamsFillColor
    highlight.OutlineColor = Module.Settings.ChamsOutlineColor
    highlight.FillTransparency = Module.Settings.ChamsTransparency
    highlight.OutlineTransparency = 0
end

-- ============================================
-- BOX DRAWING
-- ============================================

local function drawCornerBox(box, x, y, width, height)
    local cornerX = width * 0.25
    local cornerY = height * 0.25

    box.Top.From = Vector2.new(x, y)
    box.Top.To = Vector2.new(x + cornerX, y)

    box.Left.From = Vector2.new(x, y)
    box.Left.To = Vector2.new(x, y + cornerY)

    box.Bottom.From = Vector2.new(x + width - cornerX, y)
    box.Bottom.To = Vector2.new(x + width, y)

    box.Right.From = Vector2.new(x + width, y)
    box.Right.To = Vector2.new(x + width, y + cornerY)
end

local function drawFullBox(box, x, y, width, height)
    box.Top.From = Vector2.new(x, y)
    box.Top.To = Vector2.new(x + width, y)

    box.Bottom.From = Vector2.new(x, y + height)
    box.Bottom.To = Vector2.new(x + width, y + height)

    box.Left.From = Vector2.new(x, y)
    box.Left.To = Vector2.new(x, y + height)

    box.Right.From = Vector2.new(x + width, y)
    box.Right.To = Vector2.new(x + width, y + height)
end

local function setBoxVisible(box, visible)
    for _, line in pairs(box) do
        line.Visible = visible
    end
end

local function updateBox(data, model)
    if not Module.Settings.BoxESP then
        setBoxVisible(data.Box, false)
        return
    end

    local camera = Workspace.CurrentCamera

    if not camera then
        setBoxVisible(data.Box, false)
        return
    end

    local success, cf, size = pcall(function()
        return model:GetBoundingBox()
    end)

    if not success then
        setBoxVisible(data.Box, false)
        return
    end

    local topWorld = cf.Position + Vector3.new(0, size.Y / 2, 0)
    local bottomWorld = cf.Position - Vector3.new(0, size.Y / 2, 0)

    local topScreen, topVisible =
        camera:WorldToViewportPoint(topWorld)

    local bottomScreen, bottomVisible =
        camera:WorldToViewportPoint(bottomWorld)

    if not topVisible and not bottomVisible then
        setBoxVisible(data.Box, false)
        return
    end

    local height = math.abs(bottomScreen.Y - topScreen.Y)

    if height <= 2 then
        setBoxVisible(data.Box, false)
        return
    end

    local width = height * 0.55

    local x = topScreen.X - width / 2
    local y = topScreen.Y

    if Module.Settings.BoxStyle == "Full" then
        drawFullBox(data.Box, x, y, width, height)
    else
        drawCornerBox(data.Box, x, y, width, height)
    end

    for _, line in pairs(data.Box) do
        line.Color = Module.Settings.BoxColor
        line.Thickness = 1
        line.Transparency = 1
        line.Visible = true
    end
end

-- ============================================
-- TEXT DRAWING
-- ============================================

local function updateText(data, model, root, displayName)
    local camera = Workspace.CurrentCamera

    if not camera then
        hideDrawing(data.Username)
        hideDrawing(data.Distance)
        return
    end

    local screenPosition, visible =
        camera:WorldToViewportPoint(
            root.Position + Vector3.new(0, 3.5, 0)
        )

    if not visible then
        hideDrawing(data.Username)
        hideDrawing(data.Distance)
        return
    end

    local distance =
        (camera.CFrame.Position - root.Position).Magnitude

    if Module.Settings.Username then
        data.Username.Text = displayName
        data.Username.Position = Vector2.new(
            screenPosition.X,
            screenPosition.Y
        )

        data.Username.Color = Module.Settings.UsernameColor
        data.Username.Visible = true
    else
        hideDrawing(data.Username)
    end

    if Module.Settings.StudsAway then
        data.Distance.Text = string.format(
            "[%d studs]",
            math.floor(distance + 0.5)
        )

        data.Distance.Position = Vector2.new(
            screenPosition.X,
            screenPosition.Y + 16
        )

        data.Distance.Color = Module.Settings.DistanceColor
        data.Distance.Visible = true
    else
        hideDrawing(data.Distance)
    end
end

-- ============================================
-- GENERAL TARGET UPDATE
-- ============================================

local function updateTarget(key, model, displayName)
    if not Module.Settings.Enabled then
        hideESP(key)
        return
    end

    if not model or model.Parent == nil then
        hideESP(key)
        return
    end

    local root = getRoot(model)

    if not root then
        hideESP(key)
        return
    end

    local humanoid = getHumanoid(model)

    if humanoid and humanoid.Health <= 0 then
        hideESP(key)
        return
    end

    local data = createESP(key)

    updateHighlight(key, data, model)
    updateBox(data, model)
    updateText(data, model, root, displayName)
end

-- ============================================
-- PLAYER ESP
-- ============================================

local function updatePlayer(player)
    if player == LocalPlayer then
        return
    end

    if not isEnemy(player) then
        hideESP(player)
        return
    end

    local character = player.Character

    if not character then
        hideESP(player)
        return
    end

    updateTarget(
        player,
        character,
        player.DisplayName
    )
end

-- ============================================
-- NPC ESP
-- ============================================

local function registerNPCModel(model)
    if model and model:IsA("Model") then
        NPCModels[model] = true
    end
end

local function scanNPCs()
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("Model") then
            registerNPCModel(object)
        end
    end
end

local function updateNPCs()
    for model in pairs(NPCModels) do
        if not model.Parent or not model:IsDescendantOf(Workspace) then
            removeESP(model)
            NPCModels[model] = nil

        elseif not Module.Settings.NPCESP then
            hideESP(model)

        elseif isNPC(model) then
            updateTarget(
                model,
                model,
                model.Name
            )

        else
            hideESP(model)
        end
    end
end

-- Detect newly added NPC components.
Connections.DescendantAdded =
    Workspace.DescendantAdded:Connect(function(object)

        if object:IsA("Model") then
            registerNPCModel(object)

        elseif object:IsA("Humanoid")
            or object:IsA("AnimationController") then

            local parent = object.Parent

            if parent and parent:IsA("Model") then
                registerNPCModel(parent)
            end
        end
    end)

-- ============================================
-- MAIN UPDATE
-- ============================================

local function updateAll()
    if not Module.Settings.Enabled then
        for key in pairs(ESPObjects) do
            hideESP(key)
        end

        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        updatePlayer(player)
    end

    updateNPCs()
end

-- ============================================
-- PLAYER CONNECTIONS
-- ============================================

Connections.PlayerAdded =
    Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then
            createESP(player)
        end
    end)

Connections.PlayerRemoving =
    Players.PlayerRemoving:Connect(function(player)
        removeESP(player)
    end)

-- ============================================
-- INITIALIZATION
-- ============================================

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        createESP(player)
    end
end

scanNPCs()

local UpdateConnection =
    RunService.RenderStepped:Connect(updateAll)

-- ============================================
-- MODULE API
-- ============================================

function Module:Enable()
    self.Settings.Enabled = true
end

function Module:Disable()
    self.Settings.Enabled = false

    for key in pairs(ESPObjects) do
        hideESP(key)
    end
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

    if UpdateConnection then
        UpdateConnection:Disconnect()
        UpdateConnection = nil
    end

    for _, connection in pairs(Connections) do
        if connection then
            connection:Disconnect()
        end
    end

    table.clear(Connections)

    for key in pairs(ESPObjects) do
        removeESP(key)
    end

    table.clear(NPCModels)
end

return Module
