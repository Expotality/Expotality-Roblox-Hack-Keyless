local Aimbot = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- Settings
Aimbot.Settings = {
    Enabled = false,
    Smoothness = 0.35,
    FOV = 45,
    Range = 1000,
    WallCheck = true,
    TeamCheck = false,
    MouseAim = false,
    HoldMode = false,
    Key = Enum.KeyCode.E,
    MouseKey = nil,
}

-- State
local holding = false
local bound = false
local HAS_MOUSE = (type(mousemoverel) == "function")
local EXCLUDE = Enum.RaycastFilterType.Exclude or Enum.RaycastFilterType.Blacklist

-- Raycast params for wall check
local rayParams = RaycastParams.new()
rayParams.FilterType = EXCLUDE
rayParams.IgnoreWater = true

local function isVisible(part)
    local cam = Workspace.CurrentCamera
    if not cam or not part then return false end

    local ignore = {}
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    if part.Parent then table.insert(ignore, part.Parent) end
    rayParams.FilterDescendantsInstances = ignore

    local origin = cam.CFrame.Position
    local hit = Workspace:Raycast(origin, part.Position - origin, rayParams)
    return hit == nil
end

local function isTeammate(plr)
    if not plr.Team or not LocalPlayer.Team then return false end
    return plr.Team == LocalPlayer.Team
end

local function inFOV(worldPos, cam, maxDeg)
    local dir = (worldPos - cam.CFrame.Position).Unit
    local look = cam.CFrame.LookVector
    local ang = math.deg(math.acos(math.clamp(dir:Dot(look), -1, 1)))
    return ang <= maxDeg
end

local function getTarget()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end

    local camPos = cam.CFrame.Position
    local best, bestDist = nil, math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not (Aimbot.Settings.TeamCheck and isTeammate(plr)) then
            local char = plr.Character
            if char then
                local head = char:FindFirstChild("Head")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if head and hum and hum.Health > 0 then
                    local dist = (head.Position - camPos).Magnitude
                    if dist < bestDist and dist <= Aimbot.Settings.Range and inFOV(head.Position, cam, Aimbot.Settings.FOV) then
                        if not Aimbot.Settings.WallCheck or isVisible(head) then
                            best, bestDist = head, dist
                        end
                    end
                end
            end
        end
    end

    return best
end

local function aimWithMouse(targetPos)
    if not HAS_MOUSE then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end

    local sp, onScreen = cam:WorldToViewportPoint(targetPos)
    if not onScreen or sp.Z <= 0 then return end

    local vp = cam.ViewportSize
    local centre = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    local delta = Vector2.new(sp.X, sp.Y) - centre

    if delta.Magnitude < 0.5 then return end

    local factor = 1 - math.clamp(Aimbot.Settings.Smoothness, 0, 0.98)
    mousemoverel(delta.X * factor, delta.Y * factor)
end

local function aimWithCamera(targetPos, dt)
    local cam = Workspace.CurrentCamera
    if not cam then return end

    local alpha = 1 - math.clamp(Aimbot.Settings.Smoothness, 0, 0.98)
    alpha = 1 - (1 - alpha) ^ (dt * 60)

    if Aimbot.Settings.Smoothness <= 0.001 then
        cam.CFrame = CFrame.lookAt(cam.CFrame.Position, targetPos)
    else
        cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, targetPos), alpha)
    end
end

local function isActive()
    if Aimbot.Settings.HoldMode then return holding end
    return Aimbot.Settings.Enabled
end

local function isAimInput(input)
    if Aimbot.Settings.MouseKey then
        return input.UserInputType == Aimbot.Settings.MouseKey
    end
    return Aimbot.Settings.Key ~= nil and input.KeyCode == Aimbot.Settings.Key
end

-- Keybind handling
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if isAimInput(input) then
        if Aimbot.Settings.HoldMode then
            holding = true
        else
            Aimbot.Settings.Enabled = not Aimbot.Settings.Enabled
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if Aimbot.Settings.HoldMode and isAimInput(input) then
        holding = false
    end
end

-- Main render loop
local function renderStep(dt)
    if not isActive() then return end

    local cam = Workspace.CurrentCamera
    if not cam then return end

    local target = getTarget()
    if not target then return end

    if Aimbot.Settings.MouseAim and HAS_MOUSE then
        aimWithMouse(target.Position)
    else
        aimWithCamera(target.Position, dt)
    end
end

function Aimbot:Enable()
    if bound then return end
    bound = true
    RunService:BindToRenderStep("Aimbot", Enum.RenderPriority.Camera.Value + 1, renderStep)
end

function Aimbot:Disable()
    if not bound then return end
    bound = false
    pcall(function() RunService:UnbindFromRenderStep("Aimbot") end)
    holding = false
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
end

return Aimbot
