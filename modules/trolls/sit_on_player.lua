
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

    self.Settings.Enabled = true

    if SelectedPlayer then
        self:StartSit()
    end

end


function Module:Disable()

    self.Settings.Enabled = false

    self:StopSit()

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

    local found = nil

    for _, target in ipairs(Players:GetPlayers()) do

        if target.Name == playerName then

            found = target

            break

        end

    end

    if found then

        SelectedPlayer = found

        self.Settings.SelectedPlayer = found.Name

        if self.Settings.Enabled then

            self:StopSit()
            self:StartSit()

        end

    end

    return found ~= nil

end


function Module:StartSit()

    if not self.Settings.Enabled then
        return false
    end

    if not SelectedPlayer or not SelectedPlayer.Character then
        return false
    end

    if IsSitting then
        return false
    end

    local character = LocalPlayer.Character

    if not character then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if not humanoid then
        return false
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")

    if not rootPart then
        return false
    end

    IsSitting = true

    local animator = humanoid:FindFirstChildOfClass("Animator")

    if not animator then

        animator = Instance.new("Animator")
        animator.Parent = humanoid

    end

    local animation = Instance.new("Animation")

    animation.AnimationId = "rbxassetid://2506281703"

    local success, track = pcall(function()

        return animator:LoadAnimation(animation)

    end)

    if success and track then

        SitTrack = track

        SitTrack.Looped = true

        SitTrack.Priority = Enum.AnimationPriority.Action

        SitTrack:Play()

    end

    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero

    SitRenderStepped = RunService.RenderStepped:Connect(function()

        if not IsSitting then
            return
        end

        local currentCharacter = LocalPlayer.Character

        if not currentCharacter then
            return
        end

        local currentRoot = currentCharacter:FindFirstChild("HumanoidRootPart")

        if not currentRoot then
            return
        end

        if not SelectedPlayer or not SelectedPlayer.Character then
            return
        end

        local targetHead = SelectedPlayer.Character:FindFirstChild("Head")

        if targetHead then

            currentRoot.CFrame =
                targetHead.CFrame * CFrame.new(0, 2.5, 0)

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

    return false

end


function Module:SetSetting(Setting, Value)

    if self.Settings[Setting] == nil then

        return false

    end

    if Setting == "Enabled" then

        if Value then

            self:Enable()

        else

            self:Disable()

        end

        return true

    end

    if Setting == "SelectedPlayer" then

        self.Settings.SelectedPlayer = Value

        SelectedPlayer = nil

        if Value ~= "" then

            self:SelectPlayer(Value)

        else

            self:StopSit()

        end

        return true

    end

    self.Settings[Setting] = Value

    return true

end


function Module:Destroy()

    self:Disable()

end


return Module
