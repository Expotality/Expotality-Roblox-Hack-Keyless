local Module = {}

Module.Name = "ESP"
Module.Tab = "Visuals"
Module.Description = "Simple player ESP."

Module.Settings = {
    Enabled = false,

    -- Box
    BoxESP = false,
    BoxStyle = "Corner",
    BoxColor = Color3.fromRGB(255, 25, 25),

    -- Chams
    ChamsEnabled = false,
    ChamsFillColor = Color3.fromRGB(255, 0, 0),
    ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
    ChamsTransparency = 0.5,

    -- Username
    Username = false,
    UsernameColor = Color3.fromRGB(255, 255, 255),

    -- Distance
    StudsAway = true,
    DistanceColor = Color3.fromRGB(200, 200, 200),

    -- Team filtering
    EnemyOnly = false,

    -- NPC detection
    NPCESP = false,
    NPCDetection = {
    Humanoid = true,
    AnimationController = true,
    CollectionServiceTags = true,
    NPCNames = true,
    NPCFolders = true,
    },
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local ESPObjects = {}
local CharacterConnections = {}

local function getCharacter(player)
    return player.Character
end

local function getRoot(player)
    local character = getCharacter(player)

    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Torso")
end

local function getHumanoid(player)
    local character = getCharacter(player)

    if not character then
        return nil
    end

    return character:FindFirstChildOfClass("Humanoid")
end

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
    local box = {
        Top = createLine(),
        Bottom = createLine(),
        Left = createLine(),
        Right = createLine(),

        -- Corner box uses the same four lines.
        -- Full box and corner box are handled by visibility/coordinates.
    }

    return box
end

local function hideDrawing(object)
    if object then
        object.Visible = false
    end
end

local function hideESP(player)
    local data = ESPObjects[player]

    if not data then
        return
    end

    if data.Box then
        for _, line in pairs(data.Box) do
            hideDrawing(line)
        end
    end

    hideDrawing(data.Username)
    hideDrawing(data.Distance)

    if data.Highlight then
        data.Highlight.Enabled = false
    end
end

local function removeESP(player)
    local data = ESPObjects[player]

    if not data then
        return
    end

    if data.Box then
        for _, line in pairs(data.Box) do
            pcall(function()
                line:Remove()
            end)
        end
    end

    if data.Username then
        pcall(function()
            data.Username:Remove()
        end)
    end

    if data.Distance then
        pcall(function()
            data.Distance:Remove()
        end)
    end

    if data.Highlight then
        pcall(function()
            data.Highlight:Destroy()
        end)
    end

    ESPObjects[player] = nil
end

local function createESP(player)
    if player == LocalPlayer then
        return
    end

    if ESPObjects[player] then
        return ESPObjects[player]
    end

    local data = {
        Box = createBox(),
        Username = createText(),
        Distance = createText(),
        Highlight = nil,
    }

    ESPObjects[player] = data

    local character = player.Character

    if character then
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESP_Chams"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Enabled = false
        highlight.FillTransparency = Module.Settings.ChamsTransparency
        highlight.OutlineTransparency = 0
        highlight.FillColor = Module.Settings.ChamsFillColor
        highlight.OutlineColor = Module.Settings.ChamsOutlineColor
        highlight.Parent = character

        data.Highlight = highlight
    end

    return data
end

local function updateHighlight(player, data, character)
    if not data.Highlight or data.Highlight.Parent ~= character then
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
        highlight.Parent = character

        data.Highlight = highlight
    end

    local highlight = data.Highlight

    highlight.Enabled = Module.Settings.Enabled
        and Module.Settings.ChamsEnabled

    highlight.FillColor = Module.Settings.ChamsFillColor
    highlight.OutlineColor = Module.Settings.ChamsOutlineColor
    highlight.FillTransparency = Module.Settings.ChamsTransparency
    highlight.OutlineTransparency = 0
end

local function drawCornerBox(box, x, y, width, height)
    local cornerX = width * 0.25
    local cornerY = height * 0.25

    -- Top left
    box.Top.From = Vector2.new(x, y)
    box.Top.To = Vector2.new(x + cornerX, y)

    box.Left.From = Vector2.new(x, y)
    box.Left.To = Vector2.new(x, y + cornerY)

    -- Top right
    -- Stored using Bottom/Right temporarily for corner segments
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

local function updateBox(player, data, root)
    if not Module.Settings.BoxESP then
        setBoxVisible(data.Box, false)
        return
    end

    local camera = workspace.CurrentCamera

    if not camera then
        setBoxVisible(data.Box, false)
        return
    end

    local character = player.Character

    if not character then
        setBoxVisible(data.Box, false)
        return
    end

    local humanoid = getHumanoid(player)

    if not humanoid or humanoid.Health <= 0 then
        setBoxVisible(data.Box, false)
        return
    end

    local cf, size = character:GetBoundingBox()

    local topWorld = cf.Position + Vector3.new(0, size.Y / 2, 0)
    local bottomWorld = cf.Position - Vector3.new(0, size.Y / 2, 0)

    local topScreen, topVisible = camera:WorldToViewportPoint(topWorld)
    local bottomScreen, bottomVisible = camera:WorldToViewportPoint(bottomWorld)

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

local function updateText(player, data, root)
    local camera = workspace.CurrentCamera

    if not camera then
        hideDrawing(data.Username)
        hideDrawing(data.Distance)
        return
    end

    local screenPosition, visible = camera:WorldToViewportPoint(
        root.Position + Vector3.new(0, 3.5, 0)
    )

    if not visible then
        hideDrawing(data.Username)
        hideDrawing(data.Distance)
        return
    end

    local distance = (camera.CFrame.Position - root.Position).Magnitude

    if Module.Settings.Username then
        data.Username.Text = player.DisplayName
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

local function updatePlayer(player)
    if player == LocalPlayer then
        return
    end

    local data = createESP(player)

    if not Module.Settings.Enabled then
        hideESP(player)
        return
    end

    local character = player.Character
    local root = getRoot(player)
    local humanoid = getHumanoid(player)

    if not character or not root or not humanoid or humanoid.Health <= 0 then
        hideESP(player)
        return
    end

    if character.Parent == nil then
        hideESP(player)
        return
    end

    updateHighlight(player, data, character)
    updateBox(player, data, root)
    updateText(player, data, root)
end

local function updateAll()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            updatePlayer(player)
        end
    end
end

local function setupPlayer(player)
    if player == LocalPlayer then
        return
    end

    createESP(player)

    if CharacterConnections[player] then
        CharacterConnections[player]:Disconnect()
    end

    CharacterConnections[player] = player.CharacterAdded:Connect(function(character)
        task.wait(0.1)

        local data = ESPObjects[player]

        if not data then
            return
        end

        if data.Highlight then
            pcall(function()
                data.Highlight:Destroy()
            end)
        end

        local highlight = Instance.new("Highlight")
        highlight.Name = "ESP_Chams"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Enabled = false
        highlight.FillTransparency = Module.Settings.ChamsTransparency
        highlight.OutlineTransparency = 0
        highlight.FillColor = Module.Settings.ChamsFillColor
        highlight.OutlineColor = Module.Settings.ChamsOutlineColor
        highlight.Parent = character

        data.Highlight = highlight
    end)
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
    if CharacterConnections[player] then
        CharacterConnections[player]:Disconnect()
        CharacterConnections[player] = nil
    end

    removeESP(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end

local UpdateConnection = RunService.RenderStepped:Connect(updateAll)

function Module:Enable()
    self.Settings.Enabled = true
end

function Module:Disable()
    self.Settings.Enabled = false

    for player in pairs(ESPObjects) do
        hideESP(player)
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

    for player, connection in pairs(CharacterConnections) do
        connection:Disconnect()
        CharacterConnections[player] = nil
    end

    for player in pairs(ESPObjects) do
        removeESP(player)
    end
end

return Module
