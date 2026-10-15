local UI = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local Registry
local Theme
local ConfigManager
local IsRestoringSettings = false
local ScreenGui
local Main
local Content
local Sidebar
local TopBar

local CurrentTab = "Visuals"
local MenuVisible = true

local Accent = Color3.fromRGB(90, 120, 255)
local Background = Color3.fromRGB(15, 16, 20)
local SidebarBackground = Color3.fromRGB(19, 20, 25)
local ElementBackground = Color3.fromRGB(24, 25, 31)
local ElementHover = Color3.fromRGB(31, 33, 41)
local TextColor = Color3.fromRGB(235, 235, 240)
local SubTextColor = Color3.fromRGB(145, 148, 158)
local BorderColor = Color3.fromRGB(43, 44, 52)

local TabButtons = {}
local Keybinds = {}
local ListeningForKeybind = nil

local TAB_ORDER = {
    "Visuals",
    "Movement",
    "Events",
    "Customization",
    "Utilities"
}

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------

local function create(className, properties)
    local object = Instance.new(className)

    for property, value in pairs(properties or {}) do
        object[property] = value
    end

    return object
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = parent
    return c
end

local function stroke(parent, color, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or BorderColor
    s.Transparency = transparency or 0
    s.Thickness = 1
    s.Parent = parent
    return s
end

local function gradient(parent, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Accent),
        ColorSequenceKeypoint.new(1, ElementHover),
    })
    g.Rotation = rotation or 0
    g.Parent = parent
    return g
end

local function tween(object, properties, duration)
    local animation = TweenService:Create(
        object,
        TweenInfo.new(
            duration or 0.18,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out
        ),
        properties
    )
    animation:Play()
    return animation
end

local function getSetting(module, name)

    if module.GetSetting then
        return module:GetSetting(name)
    end

    if module.Settings then

        local value = module.Settings[name]

        if typeof(value) == "table" then
            return value.Value or value.Default
        end

        return value
    end

    return nil
end


local saveLastSession

local function setSetting(module, name, value)
    if module.SetSetting then
        module:SetSetting(name, value)
    elseif module.Settings then
        local setting = module.Settings[name]

        if typeof(setting) == "table" then
            setting.Value = value
        else
            module.Settings[name] = value
        end
    end

    if not IsRestoringSettings and saveLastSession then
        saveLastSession()
    end
end


local function encodeValue(value)
    if typeof(value) == "Color3" then
        return {
            __type = "Color3",
            R = value.R,
            G = value.G,
            B = value.B,
        }
    end

    if type(value) == "table" then
        local result = {}

        for key, item in pairs(value) do
            if type(key) == "string" or type(key) == "number" then
                result[key] = encodeValue(item)
            end
        end

        return result
    end

    if type(value) == "string"
        or type(value) == "number"
        or type(value) == "boolean" then
        return value
    end

    return nil
end

local function decodeValue(value)
    if type(value) ~= "table" then
        return value
    end

    if value.__type == "Color3"
        and type(value.R) == "number"
        and type(value.G) == "number"
        and type(value.B) == "number" then
        return Color3.new(value.R, value.G, value.B)
    end

    local result = {}

    for key, item in pairs(value) do
        result[key] = decodeValue(item)
    end

    return result
end


local function createSettingsSnapshot()
    local snapshot = {
        Version = 2,
        Modules = {},
        Keybinds = {},
    }

    if not Registry then
        return snapshot
    end

    for moduleName, module in pairs(Registry:GetAll()) do
        local moduleSettings = {}

        for settingName in pairs(module.Settings or {}) do
            local value = getSetting(module, settingName)

            if value ~= nil then
                moduleSettings[settingName] = encodeValue(value)
            end
        end

        snapshot.Modules[moduleName] = moduleSettings
    end

    for moduleName, module in pairs(Registry:GetAll()) do
        local data = Keybinds[module]

        if data and data.Key then
            snapshot.Keybinds[moduleName] = data.Key.Name
        end
    end

    return snapshot
end


saveLastSession = function()
    if IsRestoringSettings or not ConfigManager then
        return
    end

    local success, err = pcall(function()
        ConfigManager.SaveLast(createSettingsSnapshot())
    end)

    if not success then
        warn("[Menu] Autosave failed: " .. tostring(err))
    end
end



local function restoreLastSession()
    if not ConfigManager or not Registry then
        return
    end

    local success, snapshot = pcall(function()
        return ConfigManager.LoadLast()
    end)

    if not success then
        warn("[Menu] Could not load LastSession: " .. tostring(snapshot))
        return
    end

    -- Restore module settings and enabled states.
    if type(snapshot.Modules) == "table" then
        for moduleName, settings in pairs(snapshot.Modules) do
            local module = Registry:Get(moduleName)

            if module and type(settings) == "table" then
                for settingName, value in pairs(settings) do
                    local decodedValue = decodeValue(value)

                    if decodedValue ~= nil then
                        setSetting(module, settingName, decodedValue)
                    end
                end
            end
        end
    end

    -- Restore keybinds.
    if type(snapshot.Keybinds) == "table" then
        for moduleName, keyName in pairs(snapshot.Keybinds) do
            local module = Registry:Get(moduleName)
            local data = module and Keybinds[module]

            if data and type(keyName) == "string" then
                local keyCode = Enum.KeyCode[keyName]

                if keyCode then
                    data.Key = keyCode

                    if data.Button then
                        data.Button.Text = keyName
                        data.Button.TextColor3 = TextColor
                    end
                end
            end
        end
    end
end


    if type(snapshot) ~= "table"
        or type(snapshot.Modules) ~= "table" then
        return
    end

    IsRestoringSettings = true

    local restoreSuccess, restoreError = pcall(function()
        for moduleName, savedSettings in pairs(snapshot.Modules) do
            local module = Registry:Get(moduleName)

            if module and type(savedSettings) == "table" then
                for settingName, savedValue in pairs(savedSettings) do
                    local value = decodeValue(savedValue)

                    if module.Settings
                        and module.Settings[settingName] ~= nil then
                        setSetting(module, settingName, value)
                    end
                end
            end
        end

        -- Reapply enabled states after restoring all settings.
        for moduleName, savedSettings in pairs(snapshot.Modules) do
            local module = Registry:Get(moduleName)
            local enabled = savedSettings
                and savedSettings.Enabled

            if module and type(enabled) == "boolean" then
                if enabled then
                    if module.Enable then
                        module:Enable()
                    end
                else
                    if module.Disable then
                        module:Disable()
                    end
                end
            end
        end
    end)

    IsRestoringSettings = false

    if not restoreSuccess then
        warn("[Menu] Settings restore failed: " .. tostring(restoreError))
    end

    -- Rewrite the session using the current version of the settings.
    saveLastSession()
end


local function enableModule(module)

    setSetting(module, "Enabled", true)

    if module.Enable then
        module:Enable()
    end
end

local function disableModule(module)

    setSetting(module, "Enabled", false)

    if module.Disable then
        module:Disable()
    end
end

local function toggleModule(module)

    if getSetting(module, "Enabled") then
        disableModule(module)
    else
        enableModule(module)
    end
end

local function prettyName(name)
    return tostring(name):gsub("(%l)(%u)", "%1 %2")
end

------------------------------------------------------------
-- DROPDOWN OPTIONS
------------------------------------------------------------

local function getDropdownOptions(module, settingName)

    if module.GetDropdownOptions then

        local Options =
            module:GetDropdownOptions(settingName)

        if Options then
            return Options
        end

    end


    if settingName == "BoxStyle" then

        return {
            "Box",
            "Corner",
        }

    elseif settingName == "NameMode" then

        return {
            "DisplayName",
            "Username",
        }

    end


    return nil

end

------------------------------------------------------------
-- TOGGLE
------------------------------------------------------------


local function createToggle(parent, module, settingName, title)
    local row = create("Frame", {
        BackgroundColor3 = ElementBackground,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 42),
        ZIndex = 5,
        Parent = parent,
    })

    corner(row, 6)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = TextColor,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -80, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        ZIndex = 6,
        Parent = row,
    })

    local button = create("TextButton", {
        BackgroundColor3 = ElementBackground,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Active = true,
        Size = UDim2.fromOffset(42, 22),
        Position = UDim2.new(1, -56, 0.5, -11),
        ZIndex = 7,
        Parent = row,
    })

    corner(button, 12)

    local knob = create("Frame", {
        BackgroundColor3 = SubTextColor,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromOffset(3, 3),
        ZIndex = 8,
        Parent = button,
    })

    corner(knob, 10)

    local function refresh(animated)
        local enabled = getSetting(module, settingName) == true

        local targetPosition = enabled
            and UDim2.new(1, -19, 0, 3)
            or UDim2.fromOffset(3, 3)

        local targetColor = enabled and Accent or ElementBackground
        local knobColor = enabled and TextColor or SubTextColor

        if animated then
            tween(button, {BackgroundColor3 = targetColor})
            tween(knob, {
                Position = targetPosition,
                BackgroundColor3 = knobColor,
            })
        else
            button.BackgroundColor3 = targetColor
            knob.Position = targetPosition
            knob.BackgroundColor3 = knobColor
        end
    end

    button.MouseButton1Click:Connect(function()
        local enabled = getSetting(module, settingName) ~= true
        setSetting(module, settingName, enabled)
        refresh(true)
    end)

    refresh(false)

    return row
end

        refresh()
    end)

    refresh()

    return row
end

------------------------------------------------------------
-- NUMBER
------------------------------------------------------------

local function createNumber(parent, module, settingName, title)

    local row = create("Frame", {
        BackgroundColor3 = ElementBackground,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 42),
        ZIndex = 5,
        Parent = parent,
    })

    corner(row, 6)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = TextColor,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -100, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        ZIndex = 6,
        Parent = row,
    })

    local input = create("TextBox", {
        BackgroundColor3 = Color3.fromRGB(18, 19, 24),
        BorderSizePixel = 0,
        Text = tostring(
            getSetting(module, settingName)
        ),
        TextColor3 = TextColor,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Center,
        Active = true,
        Size = UDim2.fromOffset(65, 28),
        Position = UDim2.new(1, -79, 0.5, -14),
        ZIndex = 7,
        Parent = row,
    })

    corner(input, 5)

    input.FocusLost:Connect(function()

        local value = tonumber(input.Text)

        if value then

            setSetting(
                module,
                settingName,
                value
            )

            input.Text = tostring(value)

        else

            input.Text = tostring(
                getSetting(module, settingName)
            )
        end
    end)

    return row
end


------------------------------------------------------------
-- COLOR
------------------------------------------------------------

local COLOR_OPTIONS = {
    Color3.fromRGB(255, 25, 25),
    Color3.fromRGB(255, 100, 100),
    Color3.fromRGB(255, 170, 0),
    Color3.fromRGB(255, 255, 0),
    Color3.fromRGB(0, 255, 100),
    Color3.fromRGB(0, 200, 255),
    Color3.fromRGB(90, 120, 255),
    Color3.fromRGB(180, 80, 255),
    Color3.fromRGB(255, 80, 180),
    Color3.fromRGB(255, 255, 255),
}

local function closestColorIndex(color)

    local bestIndex = 1
    local bestDistance = math.huge

    if typeof(color) ~= "Color3" then
        return 1
    end

    for i, option in ipairs(COLOR_OPTIONS) do

        local distance =
            math.abs(color.R - option.R) +
            math.abs(color.G - option.G) +
            math.abs(color.B - option.B)

        if distance < bestDistance then

            bestDistance = distance
            bestIndex = i
        end
    end

    return bestIndex
end

local function createColor(parent, module, settingName, title)

    local row = create("Frame", {
        BackgroundColor3 = ElementBackground,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 42),
        ZIndex = 5,
        Parent = parent,
    })

    corner(row, 6)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = TextColor,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -70, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        ZIndex = 6,
        Parent = row,
    })

    local colorButton = create("TextButton", {
        BackgroundColor3 =
            getSetting(module, settingName),

        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Active = true,
        Size = UDim2.fromOffset(34, 24),
        Position = UDim2.new(1, -48, 0.5, -12),
        ZIndex = 7,
        Parent = row,
    })

    corner(colorButton, 5)
    stroke(
        colorButton,
        Color3.fromRGB(70, 71, 80)
    )

    local index =
        closestColorIndex(
            getSetting(module, settingName)
        )

    colorButton.MouseButton1Click:Connect(function()

        index += 1

        if index > #COLOR_OPTIONS then
            index = 1
        end

        local color =
            COLOR_OPTIONS[index]

        setSetting(
            module,
            settingName,
            color
        )

        colorButton.BackgroundColor3 =
            color
    end)

    return row
end

------------------------------------------------------------
-- DROPDOWN
------------------------------------------------------------

local function createDropdown(
    parent,
    module,
    settingName,
    title
)

    local options =
        getDropdownOptions(
            module,
            settingName
        )

    if not options then
        return nil, 42
    end

    local closedHeight = 42
    local optionHeight = 32

    local openHeight =
        closedHeight
        + 6
        + (#options * optionHeight)

    local container = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(
            1,
            0,
            0,
            closedHeight
        ),
        ZIndex = 10,
        Parent = parent,
    })

    local row = create("Frame", {
        BackgroundColor3 = ElementBackground,
        BorderSizePixel = 0,
        Size = UDim2.new(
            1,
            0,
            0,
            closedHeight
        ),
        ZIndex = 11,
        Parent = container,
    })

    corner(row, 6)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = TextColor,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(
            0.5,
            0,
            1,
            0
        ),
        Position = UDim2.fromOffset(14, 0),
        ZIndex = 12,
        Parent = row,
    })

    local button = create("TextButton", {
        BackgroundColor3 =
            Color3.fromRGB(18, 19, 24),

        BorderSizePixel = 0,

        Text =
            tostring(
                getSetting(module, settingName)
            )
            .. "  ▼",

        TextColor3 = TextColor,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        AutoButtonColor = false,
        Active = true,

        Size = UDim2.fromOffset(130, 28),

        Position =
            UDim2.new(
                1,
                -144,
                0.5,
                -14
            ),

        ZIndex = 13,
        Parent = row,
    })

    corner(button, 5)

    local dropdown = create("Frame", {

        BackgroundColor3 =
            Color3.fromRGB(18, 19, 24),

        BorderSizePixel = 0,
        Visible = false,

        Size =
            UDim2.new(
                1,
                0,
                0,
                #options * optionHeight
            ),

        Position =
            UDim2.fromOffset(0, 48),

        ZIndex = 20,
        Parent = container,
    })

    corner(dropdown, 6)

    stroke(
        dropdown,
        Color3.fromRGB(55, 56, 65)
    )

    local open = false

    local function refreshText()

        button.Text =
            tostring(
                getSetting(module, settingName)
            )
            .. (open and "  ▲" or "  ▼")
    end

    local function setOpen(value)

        open = value

        dropdown.Visible = open

        if open then

            container.Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    openHeight
                )

        else

            container.Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    closedHeight
                )
        end

        refreshText()
    end

    for index, option in ipairs(options) do

        local optionButton = create("TextButton", {

            BackgroundColor3 =
                Color3.fromRGB(18, 19, 24),

            BorderSizePixel = 0,
            Text = option,
            TextColor3 = TextColor,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            AutoButtonColor = false,
            Active = true,

            Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    optionHeight
                ),

            Position =
                UDim2.fromOffset(
                    0,
                    (index - 1) * optionHeight
                ),

            ZIndex = 21,
            Parent = dropdown,
        })

        optionButton.MouseEnter:Connect(function()

            optionButton.BackgroundColor3 =
                ElementHover
        end)

        optionButton.MouseLeave:Connect(function()

            optionButton.BackgroundColor3 =
                Color3.fromRGB(18, 19, 24)
        end)

        optionButton.MouseButton1Click:Connect(function()

            setSetting(
                module,
                settingName,
                option
            )

            setOpen(false)
        end)
    end

    button.MouseButton1Click:Connect(function()

        setOpen(not open)
    end)

    return container, closedHeight
end

------------------------------------------------------------
-- KEYBIND
------------------------------------------------------------

local function createKeybind(parent, module)

    local row = create("Frame", {
        BackgroundColor3 = ElementBackground,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 42),
        ZIndex = 5,
        Parent = parent,
    })

    corner(row, 6)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Text = "Keybind",
        TextColor3 = TextColor,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        ZIndex = 6,
        Parent = row,
    })

    local keyButton = create("TextButton", {
        BackgroundColor3 =
            Color3.fromRGB(18, 19, 24),

        BorderSizePixel = 0,
        Text = "None",
        TextColor3 = SubTextColor,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        AutoButtonColor = false,
        Active = true,

        Size =
            UDim2.fromOffset(100, 28),

        Position =
            UDim2.new(
                1,
                -114,
                0.5,
                -14
            ),

        ZIndex = 7,
        Parent = row,
    })

    corner(keyButton, 5)

local data = Keybinds[module] or {
    Button = nil,
    Key = nil,
}

data.Button = keyButton
Keybinds[module] = data

keyButton.Text = data.Key and data.Key.Name or "None"
keyButton.TextColor3 = data.Key and TextColor or SubTextColor

    keyButton.MouseButton1Click:Connect(function()

        if ListeningForKeybind then
            return
        end

        ListeningForKeybind = module

        keyButton.Text = "Press key..."
        keyButton.TextColor3 = Accent
    end)

    return row
end

------------------------------------------------------------
-- KEY INPUT MANAGER
------------------------------------------------------------

UserInputService.InputBegan:Connect(function(
    input,
    processed
)

    if processed then
        return
    end

    --------------------------------------------------------
    -- KEYBIND ASSIGNMENT
    --------------------------------------------------------

    if ListeningForKeybind then

        if input.UserInputType
            ~= Enum.UserInputType.Keyboard then

            return
        end

        local module =
            ListeningForKeybind

        local data =
            Keybinds[module]

        ListeningForKeybind = nil

        if input.KeyCode == Enum.KeyCode.Escape then

            data.Key = nil
            data.Button.Text = "None"
            data.Button.TextColor3 =
                SubTextColor
            saveLastSession()

            return
        end

        data.Key =
            input.KeyCode

        data.Button.Text =
            input.KeyCode.Name

        data.Button.TextColor3 =
            TextColor
            
            saveLastSession()

        return
    end

    --------------------------------------------------------
    -- MODULE KEYBINDS
    --------------------------------------------------------

    if input.UserInputType
        == Enum.UserInputType.Keyboard then

        for module, data in pairs(Keybinds) do

            if data.Key
                and input.KeyCode == data.Key then

                toggleModule(module)
            end
        end
    end

    --------------------------------------------------------
    -- MENU TOGGLE
    --------------------------------------------------------

    if input.KeyCode
        == Enum.KeyCode.Insert then

        UI:Toggle()
    end
end)

------------------------------------------------------------
-- MODULE CARD
------------------------------------------------------------

local function createModule(parent, module)

    local settings =
        module.Settings or {}

    local settingsHeight = 0

    local card = create("Frame", {
        BackgroundColor3 =
            SidebarBackground,

        BorderSizePixel = 0,

        Size =
            UDim2.new(
                1,
                0,
                0,
                52
            ),

        ZIndex = 2,
        Parent = parent,
    })

    corner(card, 8)
    stroke(card, BorderColor)

    --------------------------------------------------------
    -- HEADER
    --------------------------------------------------------

    local header = create("TextButton", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Active = true,

        Size =
            UDim2.new(
                1,
                0,
                0,
                52
            ),

        ZIndex = 4,
        Parent = card,
    })

    create("TextLabel", {
        BackgroundTransparency = 1,
        Text = module.Name or "Module",
        TextColor3 = TextColor,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,

        Size =
            UDim2.new(
                1,
                -90,
                0,
                22
            ),

        Position =
            UDim2.fromOffset(16, 6),

        ZIndex = 5,
        Parent = header,
    })

    create("TextLabel", {
        BackgroundTransparency = 1,
        Text = module.Description or "",
        TextColor3 = SubTextColor,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,

        Size =
            UDim2.new(
                1,
                -100,
                0,
                16
            ),

        Position =
            UDim2.fromOffset(16, 29),

        ZIndex = 5,
        Parent = header,
    })

    local arrow = create("TextLabel", {
        BackgroundTransparency = 1,
        Text = "›",
        TextColor3 = SubTextColor,
        TextSize = 24,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,

        Size =
            UDim2.fromOffset(35, 35),

        Position =
            UDim2.new(
                1,
                -45,
                0,
                8
            ),

        ZIndex = 5,
        Parent = header,
    })

    --------------------------------------------------------
    -- SETTINGS CONTAINER
    --------------------------------------------------------

    local settingsFrame = create("Frame", {
        BackgroundTransparency = 1,
        Visible = false,

        Size =
            UDim2.new(
                1,
                -24,
                0,
                0
            ),

        Position =
            UDim2.fromOffset(12, 58),

        ZIndex = 10,
        Parent = card,
    })

    local layout =
        Instance.new("UIListLayout")

    layout.Padding =
        UDim.new(0, 6)

    layout.SortOrder =
        Enum.SortOrder.LayoutOrder

    layout.Parent =
        settingsFrame

    --------------------------------------------------------
    -- ENABLED
    --------------------------------------------------------

    if module.Type ~= "Action" then

        createToggle(
            settingsFrame,
            module,
            "Enabled",
            "Enabled"
        )

        settingsHeight += 42 + 6
    end

    --------------------------------------------------------
    -- KEYBIND
    --------------------------------------------------------

    if module.Type ~= "Action" then

        createKeybind(
            settingsFrame,
            module
        )

        settingsHeight += 42 + 6

    end

    --------------------------------------------------------
    -- ACTION BUTTON
    --------------------------------------------------------

    if module.Type == "Action" then

        local actionButton = create("TextButton", {

            BackgroundColor3 = Accent,
            BorderSizePixel = 0,

            Text = module.Name or "Execute",

            TextColor3 = Color3.new(1, 1, 1),

            TextSize = 13,
            Font = Enum.Font.GothamBold,

            Size = UDim2.new(
                1,
                0,
                0,
                38
            ),

            AutoButtonColor = true,
            ZIndex = 11,

            Parent = settingsFrame,
        })

        corner(actionButton, 6)

        actionButton.MouseButton1Click:Connect(function()

            if module.Open then
                module:Open()
            end

        end)

        settingsHeight += 38 + 6

    end
    --------------------------------------------------------
    -- TELEPORT UI
    --------------------------------------------------------

    if module.Type == "Teleport" then

        ----------------------------------------------------
        -- CURRENT COORDINATES
        ----------------------------------------------------

        local coordsLabel = create("TextLabel", {

            BackgroundTransparency = 1,

            Text =
                "X: 0.0   Y: 0.0   Z: 0.0",

            TextColor3 = TextColor,
            TextSize = 13,
            Font = Enum.Font.Gotham,
            TextXAlignment =
                Enum.TextXAlignment.Left,

            Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    30
                ),

            ZIndex = 11,
            Parent = settingsFrame,
        })

        settingsHeight += 30 + 6

        task.spawn(function()

            while coordsLabel.Parent do

                local Position =
                    module:GetCoordinates()

                if Position then

                    coordsLabel.Text =
                        string.format(
                            "X: %.1f   Y: %.1f   Z: %.1f",
                            Position.X,
                            Position.Y,
                            Position.Z
                        )

                else

                    coordsLabel.Text =
                        "X: --   Y: --   Z: --"
                end

                task.wait(0.1)
            end
        end)

        ----------------------------------------------------
        -- X
        ----------------------------------------------------

        createNumber(
            settingsFrame,
            module,
            "X",
            "X"
        )

        settingsHeight += 42 + 6

        ----------------------------------------------------
        -- Y
        ----------------------------------------------------

        createNumber(
            settingsFrame,
            module,
            "Y",
            "Y"
        )

        settingsHeight += 42 + 6

        ----------------------------------------------------
        -- Z
        ----------------------------------------------------

        createNumber(
            settingsFrame,
            module,
            "Z",
            "Z"
        )

        settingsHeight += 42 + 6

        ----------------------------------------------------
        -- TELEPORT TO COORDINATES
        ----------------------------------------------------

        local teleportButton = create("TextButton", {

            BackgroundColor3 = Accent,
            BorderSizePixel = 0,

            Text =
                "Teleport to Coordinates",

            TextColor3 =
                Color3.new(1, 1, 1),

            TextSize = 13,
            Font = Enum.Font.GothamBold,

            Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    38
                ),

            AutoButtonColor = true,
            ZIndex = 11,
            Parent = settingsFrame,
        })

        corner(teleportButton, 6)

        teleportButton.MouseButton1Click:Connect(function()

            local X =
                getSetting(
                    module,
                    "X"
                )

            local Y =
                getSetting(
                    module,
                    "Y"
                )

            local Z =
                getSetting(
                    module,
                    "Z"
                )

            if X and Y and Z then

                module:TeleportToCoordinates(
                    X,
                    Y,
                    Z
                )
            end
        end)

        settingsHeight += 38 + 6

        ----------------------------------------------------
        -- PLAYER TELEPORT
        ----------------------------------------------------

        local playerLabel = create("TextLabel", {

            BackgroundTransparency = 1,

            Text =
                "Teleport to Player",

            TextColor3 = TextColor,
            TextSize = 13,
            Font = Enum.Font.GothamBold,

            TextXAlignment =
                Enum.TextXAlignment.Left,

            Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    25
                ),

            ZIndex = 11,
            Parent = settingsFrame,
        })

        settingsHeight += 25 + 6

        local selectedPlayer = nil

        local playerDropdown = create("TextButton", {

            BackgroundColor3 =
                ElementBackground,

            BorderSizePixel = 0,
            Text = "Select Player",
            TextColor3 = TextColor,
            TextSize = 12,
            Font = Enum.Font.Gotham,

            Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    38
                ),

            AutoButtonColor = true,
            ZIndex = 11,
            Parent = settingsFrame,
        })

        corner(playerDropdown, 6)
        stroke(playerDropdown, BorderColor)

        local playerList = create("ScrollingFrame", {

            BackgroundColor3 =
                ElementBackground,

            BorderSizePixel = 0,
            Visible = false,

            Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    120
                ),

            Position =
                UDim2.fromOffset(0, 44),

            CanvasSize =
                UDim2.new(
                    0,
                    0,
                    0,
                    0
                ),

            ScrollBarThickness = 4,
            ZIndex = 20,

            Parent = settingsFrame,
        })

        corner(playerList, 6)
        stroke(playerList, BorderColor)

        local playerLayout =
            Instance.new("UIListLayout")

        playerLayout.Padding =
            UDim.new(0, 2)

        playerLayout.Parent =
            playerList

        local function updatePlayerList()

            for _, child in
                ipairs(playerList:GetChildren()) do

                if child:IsA("TextButton") then
                    child:Destroy()
                end
            end

            for _, targetPlayer in
                ipairs(Players:GetPlayers()) do

                if targetPlayer ~= LocalPlayer then

                    local button = create("TextButton", {

                        BackgroundColor3 =
                            ElementBackground,

                        BorderSizePixel = 0,

                        Text =
                            targetPlayer.DisplayName
                            .. " (@"
                            .. targetPlayer.Name
                            .. ")",

                        TextColor3 = TextColor,
                        TextSize = 11,
                        Font = Enum.Font.Gotham,

                        Size =
                            UDim2.new(
                                1,
                                -8,
                                0,
                                32
                            ),

                        AutoButtonColor = true,
                        ZIndex = 21,
                        Parent = playerList,
                    })

                    button.MouseButton1Click:Connect(function()

                        selectedPlayer =
                            targetPlayer

                        playerDropdown.Text =
                            targetPlayer.DisplayName
                            .. " (@"
                            .. targetPlayer.Name
                            .. ")"

                        playerList.Visible =
                            false
                    end)
                end
            end

            playerList.CanvasSize =
                UDim2.new(
                    0,
                    0,
                    0,
                    playerLayout.AbsoluteContentSize.Y
                    + 6
                )
        end

        playerDropdown.MouseButton1Click:Connect(function()

            playerList.Visible =
                not playerList.Visible

            if playerList.Visible then
                updatePlayerList()
            end
        end)

        settingsHeight += 38 + 6

        ----------------------------------------------------
        -- TELEPORT TO PLAYER BUTTON
        ----------------------------------------------------

        local teleportPlayerButton =
            create("TextButton", {

                BackgroundColor3 = Accent,
                BorderSizePixel = 0,

                Text =
                    "Teleport to Player",

                TextColor3 =
                    Color3.new(1, 1, 1),

                TextSize = 13,
                Font = Enum.Font.GothamBold,

                Size =
                    UDim2.new(
                        1,
                        0,
                        0,
                        38
                    ),

                AutoButtonColor = true,
                ZIndex = 11,
                Parent = settingsFrame,
            })

        corner(teleportPlayerButton, 6)

        teleportPlayerButton.MouseButton1Click:Connect(function()

            if selectedPlayer then

                module:TeleportToPlayer(
                    selectedPlayer
                )
            end
        end)

        settingsHeight += 38 + 6

        ----------------------------------------------------
        -- WAYPOINTS
        ----------------------------------------------------

        local waypointLabel = create("TextLabel", {

            BackgroundTransparency = 1,
            Text = "Waypoints",

            TextColor3 = TextColor,
            TextSize = 13,
            Font = Enum.Font.GothamBold,

            TextXAlignment =
                Enum.TextXAlignment.Left,

            Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    25
                ),

            ZIndex = 11,
            Parent = settingsFrame,
        })

        settingsHeight += 25 + 6

        local waypointInput = create("TextBox", {

            BackgroundColor3 =
                ElementBackground,

            BorderSizePixel = 0,

            PlaceholderText =
                "Waypoint name",

            Text = "",
            TextColor3 = TextColor,

            PlaceholderColor3 =
                SubTextColor,

            TextSize = 12,
            Font = Enum.Font.Gotham,

            ClearTextOnFocus = false,

            Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    38
                ),

            ZIndex = 11,
            Parent = settingsFrame,
        })

        corner(waypointInput, 6)
        stroke(waypointInput, BorderColor)

        settingsHeight += 38 + 6

        ----------------------------------------------------
        -- WAYPOINT LIST
        ----------------------------------------------------

        local waypointList =
            create("ScrollingFrame", {

                BackgroundColor3 =
                    ElementBackground,

                BorderSizePixel = 0,

                Size =
                    UDim2.new(
                        1,
                        0,
                        0,
                        150
                    ),

                CanvasSize =
                    UDim2.new(
                        0,
                        0,
                        0,
                        0
                    ),

                ScrollBarThickness = 4,
                ZIndex = 11,
                Parent = settingsFrame,
            })

        corner(waypointList, 6)
        stroke(waypointList, BorderColor)

        local waypointLayout =
            Instance.new("UIListLayout")

        waypointLayout.Padding =
            UDim.new(0, 4)

        waypointLayout.Parent =
            waypointList

        settingsHeight += 150 + 6

        ----------------------------------------------------
        -- WAYPOINT UPDATE
        ----------------------------------------------------

        local updateWaypoints

        updateWaypoints = function()

            for _, child in
                ipairs(waypointList:GetChildren()) do

                if child:IsA("Frame") then
                    child:Destroy()
                end
            end

            for Name, Waypoint in
                pairs(module.Waypoints) do

                local waypointFrame =
                    create("Frame", {

                        BackgroundColor3 =
                            SidebarBackground,

                        BorderSizePixel = 0,

                        Size =
                            UDim2.new(
                                1,
                                -8,
                                0,
                                42
                            ),

                        ZIndex = 12,
                        Parent = waypointList,
                    })

                corner(waypointFrame, 6)

                create("TextLabel", {

                    BackgroundTransparency = 1,

                    Text = Name,

                    TextColor3 = TextColor,
                    TextSize = 11,
                    Font = Enum.Font.GothamBold,

                    TextXAlignment =
                        Enum.TextXAlignment.Left,

                    Size =
                        UDim2.new(
                            1,
                            -100,
                            1,
                            0
                        ),

                    Position =
                        UDim2.fromOffset(8, 0),

                    ZIndex = 13,
                    Parent = waypointFrame,
                })

                local goButton =
                    create("TextButton", {

                        BackgroundColor3 =
                            Accent,

                        BorderSizePixel = 0,
                        Text = "Go",

                        TextColor3 =
                            Color3.new(1, 1, 1),

                        TextSize = 11,
                        Font = Enum.Font.GothamBold,

                        Size =
                            UDim2.fromOffset(
                                38,
                                28
                            ),

                        Position =
                            UDim2.new(
                                1,
                                -82,
                                0.5,
                                -14
                            ),

                        ZIndex = 13,
                        Parent = waypointFrame,
                    })

                corner(goButton, 5)

                goButton.MouseButton1Click:Connect(function()

                    module:TeleportToWaypoint(
                        Name
                    )
                end)

                local deleteButton =
                    create("TextButton", {

                        BackgroundColor3 =
                            ElementBackground,

                        BorderSizePixel = 0,
                        Text = "X",
                        TextColor3 = TextColor,

                        TextSize = 11,
                        Font = Enum.Font.GothamBold,

                        Size =
                            UDim2.fromOffset(
                                38,
                                28
                            ),

                        Position =
                            UDim2.new(
                                1,
                                -40,
                                0.5,
                                -14
                            ),

                        ZIndex = 13,
                        Parent = waypointFrame,
                    })

                corner(deleteButton, 5)

                deleteButton.MouseButton1Click:Connect(function()

                    module:DeleteWaypoint(
                        Name
                    )

                    updateWaypoints()
                end)
            end

            waypointList.CanvasSize =
                UDim2.new(
                    0,
                    0,
                    0,
                    waypointLayout.AbsoluteContentSize.Y
                    + 6
                )
        end

        ----------------------------------------------------
        -- SAVE WAYPOINT
        ----------------------------------------------------

        local saveWaypointButton =
            create("TextButton", {

                BackgroundColor3 = Accent,
                BorderSizePixel = 0,

                Text =
                    "Save Current Position",

                TextColor3 =
                    Color3.new(1, 1, 1),

                TextSize = 13,
                Font = Enum.Font.GothamBold,

                Size =
                    UDim2.new(
                        1,
                        0,
                        0,
                        38
                    ),

                AutoButtonColor = true,
                ZIndex = 11,
                Parent = settingsFrame,
            })

        corner(saveWaypointButton, 6)

        saveWaypointButton.MouseButton1Click:Connect(function()

            local Name =
                waypointInput.Text

            if Name ~= "" then

                module:SaveWaypoint(Name)

                waypointInput.Text = ""

                updateWaypoints()
            end
        end)

        settingsHeight += 38 + 6

        updateWaypoints()

    else

        ----------------------------------------------------
        -- NORMAL SETTINGS
        ----------------------------------------------------

        for settingName, value in
            pairs(settings) do

            if settingName ~= "Enabled" then

                local title =
                    prettyName(settingName)

                ------------------------------------------------
                -- SIMPLE VALUES
                ------------------------------------------------

                if typeof(value) == "boolean" then

                    createToggle(
                        settingsFrame,
                        module,
                        settingName,
                        title
                    )

                    settingsHeight += 42 + 6

                elseif typeof(value) == "number" then

                    createNumber(
                        settingsFrame,
                        module,
                        settingName,
                        title
                    )

                    settingsHeight += 42 + 6

                elseif typeof(value) == "Color3" then

                    createColor(
                        settingsFrame,
                        module,
                        settingName,
                        title
                    )

                    settingsHeight += 42 + 6

                elseif typeof(value) == "string" then

                    local dropdown =
                        getDropdownOptions(
                            module,
                            settingName
                        )

                    if dropdown then

                        local _, height =
                            createDropdown(
                                settingsFrame,
                                module,
                                settingName,
                                title
                            )

                        settingsHeight +=
                            height + 6
                    end

                ------------------------------------------------
                -- TYPED SETTINGS
                ------------------------------------------------

                elseif typeof(value) == "table" then

                    local settingType =
                        value.Type

                    local default =
                        value.Default

                    if settingType == "Number" then

                        if getSetting(
                            module,
                            settingName
                        ) == nil then

                            setSetting(
                                module,
                                settingName,
                                default
                            )
                        end

                        createNumber(
                            settingsFrame,
                            module,
                            settingName,
                            title
                        )

                        settingsHeight +=
                            42 + 6

                    elseif settingType == "Boolean" then

                        if getSetting(
                            module,
                            settingName
                        ) == nil then

                            setSetting(
                                module,
                                settingName,
                                default
                            )
                        end

                        createToggle(
                            settingsFrame,
                            module,
                            settingName,
                            title
                        )

                        settingsHeight +=
                            42 + 6
                    end
                end
            end
        end
    end

    --------------------------------------------------------
    -- EXPAND / COLLAPSE
    --------------------------------------------------------

    header.MouseButton1Click:Connect(function()

        settingsFrame.Visible =
            not settingsFrame.Visible

        if settingsFrame.Visible then

            arrow.Text = "⌄"

            card.Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    52
                    + settingsHeight
                    + 12
                )

            settingsFrame.Size =
                UDim2.new(
                    1,
                    -24,
                    0,
                    settingsHeight
                )

        else

            arrow.Text = "›"

            card.Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    52
                )
        end

        parent.CanvasSize =
            UDim2.new(
                0,
                0,
                0,
                parent.UIListLayout.AbsoluteContentSize.Y
                + 10
            )
    end)

    return card
end

------------------------------------------------------------
-- CONTENT
------------------------------------------------------------

local function clearContent()

    for _, child in
        ipairs(Content:GetChildren()) do

        if child:IsA("Frame")
            or child:IsA("TextLabel") then

            child:Destroy()
        end
    end
end

local function renderTab(tabName)

    if not Registry then
        return
    end

    CurrentTab = tabName

    clearContent()

    for name, button in
        pairs(TabButtons) do

        if name == tabName then

            button.BackgroundColor3 =
                Accent

            button.TextColor3 =
                Color3.fromRGB(
                    255,
                    255,
                    255
                )

        else

            button.BackgroundColor3 =
                SidebarBackground

            button.TextColor3 =
                SubTextColor
        end
    end

    
    --------------------------------------------------------
    -- PRESETS PANEL (UTILITIES)
    --------------------------------------------------------

    if tabName == "Utilities" then
        local panel = create("Frame", {
            BackgroundColor3 = SidebarBackground,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 250),
            ZIndex = 3,
            Parent = Content,
        })

        corner(panel, 8)
        stroke(panel, BorderColor)

        create("TextLabel", {
            BackgroundTransparency = 1,
            Text = "Presets",
            TextColor3 = TextColor,
            TextSize = 16,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(14, 8),
            Size = UDim2.new(1, -28, 0, 24),
            ZIndex = 4,
            Parent = panel,
        })

        local nameInput = create("TextBox", {
            BackgroundColor3 = ElementBackground,
            BorderSizePixel = 0,
            PlaceholderText = "Enter preset name...",
            Text = "",
            PlaceholderColor3 = SubTextColor,
            TextColor3 = TextColor,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            ClearTextOnFocus = false,
            Position = UDim2.fromOffset(12, 40),
            Size = UDim2.new(1, -122, 0, 32),
            ZIndex = 4,
            Parent = panel,
        })

        corner(nameInput, 5)

        local saveButton = create("TextButton", {
            BackgroundColor3 = Accent,
            BorderSizePixel = 0,
            Text = "Save Preset",
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            Position = UDim2.new(1, -102, 0, 40),
            Size = UDim2.fromOffset(90, 32),
            ZIndex = 4,
            Parent = panel,
        })

        corner(saveButton, 5)

        local status = create("TextLabel", {
            BackgroundTransparency = 1,
            Text = "",
            TextColor3 = SubTextColor,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(14, 75),
            Size = UDim2.new(1, -28, 0, 20),
            ZIndex = 4,
            Parent = panel,
        })

        local presetList = create("ScrollingFrame", {
            BackgroundColor3 = ElementBackground,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(12, 99),
            Size = UDim2.new(1, -24, 0, 138),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = Accent,
            Active = true,
            ZIndex = 4,
            Parent = panel,
        })

        corner(presetList, 5)

        local listLayout = Instance.new("UIListLayout")
        listLayout.Padding = UDim.new(0, 5)
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Parent = presetList

        local listPadding = Instance.new("UIPadding")
        listPadding.PaddingTop = UDim.new(0, 5)
        listPadding.PaddingLeft = UDim.new(0, 5)
        listPadding.PaddingRight = UDim.new(0, 5)
        listPadding.PaddingBottom = UDim.new(0, 5)
        listPadding.Parent = presetList

        local function refreshPresets()
            for _, child in ipairs(presetList:GetChildren()) do
                if child:IsA("Frame") then
                    child:Destroy()
                end
            end

            if not ConfigManager then
                status.Text = "Config manager unavailable."
                return
            end

            local success, presets = pcall(function()
                return ConfigManager.List()
            end)

            if not success then
                status.Text = "Could not list presets."
                warn("[Menu] Preset list failed: " .. tostring(presets))
                return
            end

            if #presets == 0 then
                status.Text = "No named presets saved yet."
                return
            end

            status.Text = "Saved presets: " .. tostring(#presets)

            for index, presetName in ipairs(presets) do
                local row = create("Frame", {
                    BackgroundColor3 = SidebarBackground,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, -2, 0, 36),
                    LayoutOrder = index,
                    ZIndex = 5,
                    Parent = presetList,
                })

                corner(row, 4)

                create("TextLabel", {
                    BackgroundTransparency = 1,
                    Text = presetName,
                    TextColor3 = TextColor,
                    TextSize = 11,
                    Font = Enum.Font.GothamMedium,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Position = UDim2.fromOffset(8, 0),
                    Size = UDim2.new(1, -145, 1, 0),
                    ZIndex = 6,
                    Parent = row,
                })

                local loadButton = create("TextButton", {
                    BackgroundColor3 = Accent,
                    BorderSizePixel = 0,
                    Text = "Load",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextSize = 10,
                    Font = Enum.Font.GothamBold,
                    Position = UDim2.new(1, -132, 0.5, -12),
                    Size = UDim2.fromOffset(58, 24),
                    ZIndex = 6,
                    Parent = row,
                })

                corner(loadButton, 4)

                loadButton.MouseButton1Click:Connect(function()
                    local loaded, snapshot = pcall(function()
                        return ConfigManager.Load(presetName)
                    end)

                    if not loaded or type(snapshot) ~= "table"
                        or type(snapshot.Modules) ~= "table" then
                        status.Text = "Could not load preset."
                        warn("[Menu] Preset load failed: " .. tostring(snapshot))
                        return
                    end

                    IsRestoringSettings = true

                    local applied, applyError = pcall(function()
                        for moduleName, savedSettings in pairs(snapshot.Modules) do
                            local module = Registry:Get(moduleName)

                            if module and type(savedSettings) == "table" then
                                for settingName, savedValue in pairs(savedSettings) do
                                    if module.Settings
                                        and module.Settings[settingName] ~= nil then
                                        setSetting(
                                            module,
                                            settingName,
                                            decodeValue(savedValue)
                                        )
                                    end
                                end
                            end
                        end

                        for moduleName, savedSettings in pairs(snapshot.Modules) do
                            local module = Registry:Get(moduleName)
                            local enabled = savedSettings
                                and savedSettings.Enabled

                            if module and type(enabled) == "boolean" then
                                if enabled and module.Enable then
                                    module:Enable()
                                elseif not enabled and module.Disable then
                                    module:Disable()
                                end
                            end
                        end
                    end)

                    IsRestoringSettings = false

                    if not applied then
                        status.Text = "Preset apply failed."
                        warn("[Menu] Preset apply failed: " .. tostring(applyError))
                        return
                    end

                    saveLastSession()
                    status.Text = "Loaded: " .. presetName
                    renderTab("Utilities")
                end)

                local deleteButton = create("TextButton", {
                    BackgroundColor3 = ElementBackground,
                    BorderSizePixel = 0,
                    Text = "Delete",
                    TextColor3 = TextColor,
                    TextSize = 10,
                    Font = Enum.Font.GothamBold,
                    Position = UDim2.new(1, -68, 0.5, -12),
                    Size = UDim2.fromOffset(60, 24),
                    ZIndex = 6,
                    Parent = row,
                })

                corner(deleteButton, 4)

                deleteButton.MouseButton1Click:Connect(function()
                    local deleted, deleteError = pcall(function()
                        ConfigManager.Delete(presetName)
                    end)

                    if not deleted then
                        status.Text = "Delete failed."
                        warn("[Menu] Preset delete failed: " .. tostring(deleteError))
                        return
                    end

                    status.Text = "Deleted: " .. presetName
                    refreshPresets()
                end)
            end
        end

        saveButton.MouseButton1Click:Connect(function()
            if not ConfigManager then
                status.Text = "Config manager unavailable."
                return
            end

            local name = nameInput.Text
            if name:match("^%s*$") then
                status.Text = "Enter a preset name first."
                return
            end

            local saved, result = pcall(function()
                return ConfigManager.Save(name, createSettingsSnapshot())
            end)

            if not saved then
                status.Text = "Save failed."
                warn("[Menu] Preset save failed: " .. tostring(result))
                return
            end

            nameInput.Text = ""
            status.Text = "Saved: " .. tostring(result)
            refreshPresets()
        end)

        refreshPresets()
    end


    
    local modules =
        Registry:GetByTab(tabName)

    if not modules
        or #modules == 0 then

        create("TextLabel", {

            BackgroundTransparency = 1,

            Text =
                "No modules in this tab.",

            TextColor3 =
                SubTextColor,

            TextSize = 13,
            Font = Enum.Font.Gotham,

            TextXAlignment =
                Enum.TextXAlignment.Center,

            Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    40
                ),

            ZIndex = 2,
            Parent = Content,
        })

        return
    end

    for _, module in
        ipairs(modules) do

        createModule(
            Content,
            module
        )
    end
end

------------------------------------------------------------
-- THEME
------------------------------------------------------------

function UI:ApplyTheme(theme)

    if not theme then
        return
    end

    Accent =
        theme.Accent or Accent

    Background =
        theme.Background or Background

    SidebarBackground =
        theme.SidebarBackground
        or SidebarBackground

    ElementBackground =
        theme.ElementBackground
        or ElementBackground

    ElementHover =
        theme.ElementHover
        or ElementHover

    TextColor =
        theme.TextColor
        or TextColor

    SubTextColor =
        theme.SubTextColor
        or SubTextColor

    BorderColor =
        theme.BorderColor
        or BorderColor

    --------------------------------------------------------
    -- MAIN
    --------------------------------------------------------

    if Main then

        Main.BackgroundColor3 =
            Background

        local mainStroke =
            Main:FindFirstChildOfClass(
                "UIStroke"
            )

        if mainStroke then
            mainStroke.Color =
                BorderColor
        end
    end

    --------------------------------------------------------
    -- CONTENT
    --------------------------------------------------------

    if Content then

        Content.BackgroundColor3 =
            Background

        Content.ScrollBarImageColor3 =
            Accent
    end

    --------------------------------------------------------
    -- SIDEBAR
    --------------------------------------------------------

    if Sidebar then
        Sidebar.BackgroundColor3 =
            SidebarBackground
    end

    --------------------------------------------------------
    -- TOP BAR
    --------------------------------------------------------

    if TopBar then
        TopBar.BackgroundColor3 =
            Background
    end

    --------------------------------------------------------
    -- TAB BUTTONS
    --------------------------------------------------------

    for name, button in
        pairs(TabButtons) do

        if name == CurrentTab then

            button.BackgroundColor3 =
                Accent

            button.TextColor3 =
                Color3.fromRGB(
                    255,
                    255,
                    255
                )

        else

            button.BackgroundColor3 =
                SidebarBackground

            button.TextColor3 =
                SubTextColor
        end
    end

    --------------------------------------------------------
    -- REBUILD CURRENT TAB
    --------------------------------------------------------

    renderTab(CurrentTab)
end

------------------------------------------------------------
-- SIDEBAR
------------------------------------------------------------

local function createSidebar()

    Sidebar = create("Frame", {

        BackgroundColor3 =
            SidebarBackground,

        BorderSizePixel = 0,

        Size =
            UDim2.new(
                0,
                175,
                1,
                0
            ),

        ZIndex = 10,
        Parent = Main,
    })

    create("TextLabel", {

        BackgroundTransparency = 1,

        Text = "◈ MENU",

        TextColor3 =
            TextColor,

        TextSize = 18,
        Font = Enum.Font.GothamBold,

        TextXAlignment =
            Enum.TextXAlignment.Left,

        Size =
            UDim2.new(
                1,
                -30,
                0,
                30
            ),

        Position =
            UDim2.fromOffset(
                18,
                14
            ),

        ZIndex = 11,
        Parent = Sidebar,
    })

    create("TextLabel", {

        BackgroundTransparency = 1,

        Text = "EXPOTALITY",

        TextColor3 =
            SubTextColor,

        TextSize = 9,
        Font = Enum.Font.GothamMedium,

        TextXAlignment =
            Enum.TextXAlignment.Left,

        Size =
            UDim2.new(
                1,
                -30,
                0,
                18
            ),

        Position =
            UDim2.fromOffset(
                19,
                38
            ),

        ZIndex = 11,
        Parent = Sidebar,
    })

    local tabs = create("Frame", {

        BackgroundTransparency = 1,

        Size =
            UDim2.new(
                1,
                -24,
                0,
                230
            ),

        Position =
            UDim2.fromOffset(
                12,
                75
            ),

        ZIndex = 11,
        Parent = Sidebar,
    })

    local layout =
        Instance.new("UIListLayout")

    layout.Padding =
        UDim.new(0, 6)

    layout.SortOrder =
        Enum.SortOrder.LayoutOrder

    layout.Parent = tabs

    for index, tabName in
        ipairs(TAB_ORDER) do

        local button = create("TextButton", {

            BackgroundColor3 =
                SidebarBackground,

            BorderSizePixel = 0,

            Text = tabName,

            TextColor3 =
                SubTextColor,

            TextSize = 13,
            Font = Enum.Font.GothamMedium,

            TextXAlignment =
                Enum.TextXAlignment.Left,

            AutoButtonColor = false,
            Active = true,

            Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    38
                ),

            LayoutOrder = index,

            ZIndex = 12,
            Parent = tabs,
        })

        corner(button, 6)

        local padding =
            Instance.new("UIPadding")

        padding.PaddingLeft =
            UDim.new(0, 14)

        padding.Parent = button

        TabButtons[tabName] =
            button

        button.MouseEnter:Connect(function()

            if CurrentTab ~= tabName then

                button.BackgroundColor3 =
                    ElementHover
            end
        end)

        button.MouseLeave:Connect(function()

            if CurrentTab ~= tabName then

                button.BackgroundColor3 =
                    SidebarBackground
            end
        end)

        button.MouseButton1Click:Connect(function()

            renderTab(tabName)
        end)
    end
end

------------------------------------------------------------
-- TOP BAR
------------------------------------------------------------

local function createTopBar()

    TopBar = create("Frame", {

        BackgroundColor3 =
            Background,

        BorderSizePixel = 0,

        Size =
            UDim2.new(
                1,
                0,
                0,
                48
            ),

        ZIndex = 30,
        Parent = Main,
    })

    create("TextLabel", {

        BackgroundTransparency = 1,

        Text =
            "Expotality's Suite",

        TextColor3 =
            TextColor,

        TextSize = 15,
        Font = Enum.Font.GothamBold,

        TextXAlignment =
            Enum.TextXAlignment.Left,

        Size =
            UDim2.new(
                1,
                -250,
                1,
                0
            ),

        Position =
            UDim2.fromOffset(
                195,
                0
            ),

        ZIndex = 31,
        Parent = TopBar,
    })

    create("TextLabel", {

        BackgroundTransparency = 1,

        Text = "v1.0",

        TextColor3 =
            SubTextColor,

        TextSize = 10,
        Font = Enum.Font.Gotham,

        TextXAlignment =
            Enum.TextXAlignment.Center,

        Size =
            UDim2.fromOffset(
                40,
                48
            ),

        Position =
            UDim2.new(
                1,
                -85,
                0,
                0
            ),

        ZIndex = 31,
        Parent = TopBar,
    })

    local close = create("TextButton", {

        BackgroundTransparency = 1,

        Text = "×",

        TextColor3 =
            SubTextColor,

        TextSize = 23,
        Font = Enum.Font.Gotham,

        AutoButtonColor = false,
        Active = true,

        Size =
            UDim2.fromOffset(
                45,
                48
            ),

        Position =
            UDim2.new(
                1,
                -45,
                0,
                0
            ),

        ZIndex = 32,
        Parent = TopBar,
    })

    close.MouseEnter:Connect(function()

        close.TextColor3 =
            TextColor
    end)

    close.MouseLeave:Connect(function()

        close.TextColor3 =
            SubTextColor
    end)

    close.MouseButton1Click:Connect(function()

        UI:SetVisible(false)
    end)

    --------------------------------------------------------
    -- DRAGGING
    --------------------------------------------------------

    local dragging = false
    local dragStart
    local startPosition

    TopBar.InputBegan:Connect(function(input)

        if input.UserInputType
            == Enum.UserInputType.MouseButton1 then

            dragging = true

            dragStart =
                input.Position

            startPosition =
                Main.Position
        end
    end)

    TopBar.InputEnded:Connect(function(input)

        if input.UserInputType
            == Enum.UserInputType.MouseButton1 then

            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)

        if not dragging then
            return
        end

        if input.UserInputType
            ~= Enum.UserInputType.MouseMovement then

            return
        end

        local delta =
            input.Position
            - dragStart

        Main.Position =
            UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset
                    + delta.X,

                startPosition.Y.Scale,
                startPosition.Y.Offset
                    + delta.Y
            )
    end)
end

------------------------------------------------------------
-- CONTENT
------------------------------------------------------------

local function createContent()

    Content = create("ScrollingFrame", {

        BackgroundColor3 =
            Background,

        BorderSizePixel = 0,

        Position =
            UDim2.fromOffset(
                175,
                48
            ),

        Size =
            UDim2.new(
                1,
                -175,
                1,
                -48
            ),

        CanvasSize =
            UDim2.new(
                0,
                0,
                0,
                0
            ),

        AutomaticCanvasSize =
            Enum.AutomaticSize.Y,

        ScrollBarThickness = 5,

        ScrollBarImageColor3 =
            Accent,

        ScrollBarImageTransparency =
            0.2,

        Active = true,
        ClipsDescendants = true,

        ZIndex = 2,
        Parent = Main,
    })

    local padding =
        Instance.new("UIPadding")

    padding.PaddingLeft =
        UDim.new(0, 20)

    padding.PaddingRight =
        UDim.new(0, 20)

    padding.PaddingTop =
        UDim.new(0, 20)

    padding.PaddingBottom =
        UDim.new(0, 20)

    padding.Parent = Content

    local layout =
        Instance.new("UIListLayout")

    layout.Padding =
        UDim.new(0, 10)

    layout.SortOrder =
        Enum.SortOrder.LayoutOrder

    layout.Parent = Content
end

------------------------------------------------------------
-- PUBLIC
------------------------------------------------------------

function UI:SelectTab(tabName)

    if TabButtons[tabName] then
        renderTab(tabName)
    end
end

function UI:SetVisible(visible)

    MenuVisible = visible

    if Main then
        Main.Visible = visible
    end
end

function UI:Toggle()

    self:SetVisible(
        not MenuVisible
    )
end

function UI:Initialize(registry, configManager)
    Registry = registry
    ConfigManager = configManager

    for _, module in pairs(Registry:GetAll()) do
        Keybinds[module] = Keybinds[module] or {
            Button = nil,
            Key = nil,
        }
    end
    --------------------------------------------------------
    -- GUI
    --------------------------------------------------------

    ScreenGui =
        Instance.new("ScreenGui")

    ScreenGui.Name =
        "RobloxHackMenu"

    ScreenGui.ResetOnSpawn =
        false

    ScreenGui.IgnoreGuiInset =
        true

    ScreenGui.ZIndexBehavior =
        Enum.ZIndexBehavior.Sibling

    local success =
        pcall(function()

            ScreenGui.Parent =
                game:GetService("CoreGui")
        end)

    if not success
        or not ScreenGui.Parent then

        ScreenGui.Parent =
            LocalPlayer:WaitForChild(
                "PlayerGui"
            )
    end

    --------------------------------------------------------
    -- MAIN
    --------------------------------------------------------

    Main = create("Frame", {

        BackgroundColor3 =
            Background,

        BorderSizePixel = 0,

        Size =
            UDim2.fromOffset(
                760,
                500
            ),

        Position =
            UDim2.new(
                0.5,
                -380,
                0.5,
                -250
            ),

        Active = true,

        ZIndex = 1,
        Parent = ScreenGui,
    })

    corner(Main, 8)
    stroke(Main, BorderColor)

    --------------------------------------------------------
    -- BUILD
    --------------------------------------------------------

    createContent()
    createSidebar()
    createTopBar()

    --------------------------------------------------------
    -- FIRST TAB
    --------------------------------------------------------

        --------------------------------------------------------
    -- CONNECT CUSTOMIZATION
    --------------------------------------------------------

    local customizationModules =
        Registry:GetByTab("Customization")

    if customizationModules and customizationModules[1] then
        customizationModules[1]._UI = self
    end

    --------------------------------------------------------
    -- RESTORE SETTINGS BEFORE DISPLAYING THE FIRST TAB
    --------------------------------------------------------

    restoreLastSession()

    --------------------------------------------------------
    -- FIRST TAB
    --------------------------------------------------------

    renderTab("Visuals")

    return self
end

return UI
