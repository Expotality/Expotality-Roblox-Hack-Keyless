local Module = {}

Module.Name =
    "Head Sitter"

Module.Tab =
    "Utilities"

Module.Description =
    "Lets you sit on other players."


Module.Settings = {
    Enabled = false,
    SelectedPlayer = "",
    RefreshInterval = 2,
}


local Players =
    game:GetService("Players")

local LocalPlayer =
    Players.LocalPlayer


local RunService =
    game:GetService("RunService")


local SelectedPlayer = nil
local IsSitting = false
local SitTrack = nil
local SitRenderStepped = nil


--------------------------------------------------
-- PUBLIC METHODS
--------------------------------------------------

function Module:Enable()

    self.Settings.Enabled =
        true

end


function Module:Disable()

    self.Settings.Enabled =
        false

    IsSitting = false

    if SitTrack then

        SitTrack:Stop(0.2)

        SitTrack:Destroy()

        SitTrack = nil

    end

    if SitRenderStepped then

        SitRenderStepped:Disconnect()

        SitRenderStepped = nil

    end

end


function Module:GetTools()

    local tools = {}

    for _, obj in pairs(game:GetDescendants()) do

        if obj:IsA("Tool") then

            local owner = obj:FindFirstAncestorWhichIsA("Player")

            if owner and owner ~= LocalPlayer then

                table.insert(tools, obj.Name)

            end

        end

    end

    return tools

end


function Module:GetToolNames()

    -- Returns player names for dropdown, matches RefreshPlayerList()

    local names = {}

    for _, target in ipairs(Players:GetPlayers()) do

        if target ~= LocalPlayer then

            table.insert(names, target.Name)

        end

    end

    return names

end


function Module:GetDropdownOptions(settingName)

    if settingName == "SelectedPlayer" then

        return self:GetToolNames()

    end

    return nil

end


function Module:SelectPlayer(playerName)

    -- Accept exact usernames to match RefreshPlayerList() output

    local found = nil

    for _, target in ipairs(Players:GetPlayers()) do

        if target.Name == playerName then

            found = target

            break

        end

    end

    if found then

        SelectedPlayer = found

    end

    return found ~= nil

end


function Module:StartSit()

    if not SelectedPlayer or not SelectedPlayer.Character then

        return false

    end

    if IsSitting then

        return false

    end

    IsSitting = true

    local character = LocalPlayer.Character

    if not character then

        IsSitting = false

        return false

    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if not humanoid then

        IsSitting = false

        return false

    end

    -- Load sit animation

    local animator = humanoid:FindFirstChildOfClass("Animator")

    if not animator then

        animator = Instance.new("Animator")

        animator.Parent = character

    end

    local animation = Instance.new("Animation")

    animation.AnimationId = "rbxassetid://2506281703"


    local success, track = pcall(function()

        return animator:LoadAnimation(animation)

    end)


    -- Do NOT destroy animation; we need track to persist

    if success and track then

        SitTrack = track

        SitTrack.Looped = true

        SitTrack.Priority = Enum.AnimationPriority.Action

        SitTrack:Play()

    end

    -- Position tracking

    local rootPart = character:FindFirstChild("HumanoidRootPart")

    if not rootPart then

        -- cleanup

        if SitTrack then

            SitTrack:Stop()

            SitTrack:Destroy()

            SitTrack = nil

        end

        IsSitting = false

        return false

    end


    -- Reset velocities

    rootPart.AssemblyLinearVelocity = Vector3.zero

    rootPart.AssemblyAngularVelocity = Vector3.zero


    -- Track position every frame

    SitRenderStepped = RunService.RenderStepped:Connect(function()

        if not IsSitting then

            SitRenderStepped:Disconnect()

            return

        end


        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then

            return

        end


        if not SelectedPlayer or not SelectedPlayer.Character then

            return

        end


        local targetHead = SelectedPlayer.Character:FindFirstChild("Head")

        if targetHead then

            LocalPlayer.Character.HumanoidRootPart.CFrame = targetHead.CFrame * CFrame.new(0, 2.5, 0)

        end

    end)


    return true

end


function Module:StopSit()

    IsSitting = false

    if SitRenderStepped then

        SitRenderStepped:Disconnect()

        SitRenderStepped = nil

    end

    if SitTrack then

        SitTrack:Stop(0.2)

        SitTrack:Destroy()

        SitTrack = nil

    end

end


function Module:RefreshPlayerList()

    -- Returns player USRNAMES (target.Name) - consistent with SelectPlayer()

    local names = {}

    for _, target in ipairs(Players:GetPlayers()) do

        if target ~= LocalPlayer then

            table.insert(names, target.Name)

        end

    end

    return names

end


function Module:SearchPlayers(pattern)

    local names = {}

    for _, target in ipairs(Players:GetPlayers()) do

        if target ~= LocalPlayer then

            if pattern and pattern ~= "" then

                if string.find(target.Name:lower(), pattern:lower()) then

                    table.insert(names, target.Name)

                end

            else

                table.insert(names, target.Name)

            end

        end

    end

    return names

end


function Module:GiveSelectedTool()

    -- Format consistency with tool_giver module - not used for sitting

    return false

end


function Module:SetSetting(Setting, Value)

    if self.Settings[Setting] == nil then

        return false

    end


    if Setting == "Enabled" then

        Value = Value and true or false

        if Value == true then

            self:Enable()

        else

            self:Disable()

        end


        return true

    end


    if Setting == "SelectedPlayer" then

        self.Settings.SelectedPlayer = Value

        -- Synchronize the local variable too

        SelectedPlayer = Value ~= "" and self:SelectPlayer(Value) or nil

    end


    self.Settings[Setting] =
        Value


    return true

end


function Module:Destroy()

    self:Disable()

end


return Module
