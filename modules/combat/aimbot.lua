local Aimbot = {}

Aimbot.Settings = {
    Enabled = false,
    Smoothness = 0.35,
    FOV = 45,
    Range = 1000,
    WallCheck = true,
    TeamCheck = false,
}

function Aimbot:Enable()
    -- Start the training-target logic.
end

function Aimbot:Disable()
    -- Stop updates and clean up connections.
end

function Aimbot:SetSetting(name, value)
    if self.Settings[name] == nil then
        return false
    end

    self.Settings[name] = value
    return true
end

function Aimbot:Destroy()
    self:Disable()
    -- Release remaining resources.
end

return Aimbot
