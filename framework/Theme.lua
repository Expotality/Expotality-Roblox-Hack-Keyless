
-- framework/Theme.lua
-- Shared styling helpers. Colors always derive from UI:ApplyTheme().

local Theme = {}

local function darker(color, amount)
    return color:Lerp(Color3.new(0, 0, 0), amount or 0.25)
end

local function lighter(color, amount)
    return color:Lerp(Color3.new(1, 1, 1), amount or 0.15)
end

function Theme.Round(object, radius)
    local corner = object:FindFirstChildOfClass("UICorner")

    if not corner then
        corner = Instance.new("UICorner")
        corner.Parent = object
    end

    corner.CornerRadius = UDim.new(0, radius or 8)
    return corner
end

function Theme.Stroke(object, color, transparency, thickness)
    local outline = object:FindFirstChildOfClass("UIStroke")

    if not outline then
        outline = Instance.new("UIStroke")
        outline.Parent = object
    end

    outline.Color = color
    outline.Transparency = transparency or 0
    outline.Thickness = thickness or 1

    return outline
end

function Theme.Gradient(object, accent, rotation)
    local gradient = object:FindFirstChildOfClass("UIGradient")

    if not gradient then
        gradient = Instance.new("UIGradient")
        gradient.Parent = object
    end

    -- Accent-derived colors: no hardcoded purple/cyan palette.
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, lighter(accent, 0.18)),
        ColorSequenceKeypoint.new(1, darker(accent, 0.28)),
    })

    gradient.Rotation = rotation or 0
    return gradient
end

function Theme.StyleCard(object, palette)
    object.BorderSizePixel = 0
    object.BackgroundColor3 = palette.ElementBackground

    Theme.Round(object, 9)
    Theme.Stroke(object, palette.BorderColor, 0.12, 1)

    return object
end

function Theme.StyleAccentButton(object, palette)
    object.BorderSizePixel = 0
    object.BackgroundColor3 = palette.Accent
    object.TextColor3 = Color3.new(1, 1, 1)
    object.AutoButtonColor = false

    Theme.Round(object, 7)
    Theme.Gradient(object, palette.Accent, 0)

    return object
end

function Theme.BuildPalette(theme, current)
    theme = theme or {}
    current = current or {}

    return {
        Accent = theme.Accent or current.Accent,
        Background = theme.Background or current.Background,
        SidebarBackground =
            theme.SidebarBackground or current.SidebarBackground,
        ElementBackground =
            theme.ElementBackground or current.ElementBackground,
        ElementHover = theme.ElementHover or current.ElementHover,
        TextColor = theme.TextColor or current.TextColor,
        SubTextColor = theme.SubTextColor or current.SubTextColor,
        BorderColor = theme.BorderColor or current.BorderColor,
    }
end

function Theme.ApplyWindow(main, topBar, palette)
    if main then
        main.BackgroundColor3 = palette.Background
        Theme.Round(main, 11)
        Theme.Stroke(main, palette.BorderColor, 0.05, 1)
    end

    if topBar then
        topBar.BackgroundColor3 = palette.Background
        Theme.Gradient(topBar, palette.Accent, 0)
    end
end

return Theme
