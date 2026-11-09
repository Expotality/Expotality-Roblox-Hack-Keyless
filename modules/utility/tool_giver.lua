local Module = {}

Module.Name =
    "Tool Giver"

Module.Tab =
    "Utilities"

Module.Description =
    "Gives you tools from the game world."


Module.Settings = {

    Enabled = false,

}


local Players =
    game:GetService("Players")

local LocalPlayer =
    Players.LocalPlayer


local Backpack =
    LocalPlayer:WaitForChild("Backpack")


--------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------

local function cloneToBackpack(tool)

    if not tool or not tool:IsA("Tool") then
        return
    end


    local clonedTool =
        tool:Clone()

    clonedTool.Parent =
        Backpack

end


local function findTools()

    local tools = {}

    for _, obj in pairs(game:GetDescendants()) do

        if obj:IsA("Tool") then

            local owner =
                obj:FindFirstAncestorWhichIsA("Player")

            if owner ~= LocalPlayer then

                table.insert(tools, obj)

            end

        end

    end


    return tools

end


--------------------------------------------------
-- ENABLE
--------------------------------------------------

function ToolGiver:Enable()

    self.Settings.Enabled =
        true

end


--------------------------------------------------
-- DISABLE
--------------------------------------------------

function ToolGiver:Disable()

    self.Settings.Enabled =
        false

end


--------------------------------------------------
-- PUBLIC METHODS
--------------------------------------------------

function ToolGiver:GetTools()

    return findTools()

end


function ToolGiver:GiveTool(tool)

    if self.Settings.Enabled and tool and tool:IsA("Tool") then

        cloneToBackpack(tool)

        return true

    end


    return false

end


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

function ToolGiver:SetSetting(
    Setting,
    Value
)

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


    self.Settings[Setting] =
        Value


    return true

end


--------------------------------------------------
-- DESTROY
--------------------------------------------------

function ToolGiver:Destroy()

    self:Disable()

end


return ToolGiver
