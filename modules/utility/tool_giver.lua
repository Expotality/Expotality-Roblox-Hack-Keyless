local Module = {}

Module.Name =
    "Tool Giver"

Module.Tab =
    "Utilities"

Module.Description =
    "Gives you tools from the game world."


Module.Settings = {
    Enabled = false,
    ShowTools = true,
    SearchTools = "",
    RefreshInterval = 2,
    SelectedTool = "",
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
-- ENABLE / DISABLE
--------------------------------------------------

function Module:Enable()
    self.Settings.Enabled = true
end


function Module:Disable()
    self.Settings.Enabled = false
end


--------------------------------------------------
-- PUBLIC METHODS
--------------------------------------------------

function Module:GetTools()
    return findTools()
end


function Module:GetToolNames()

    local tools = self:GetTools()
    local names = {}

    for _, tool in ipairs(tools) do
        table.insert(names, tool.Name)
    end

    return names

end


function Module:GetDropdownOptions(settingName)

    if settingName == "SelectedTool" then
        return self:GetToolNames()
    end

    return nil

end


function Module:GiveSelectedTool()

    if not self.Settings.Enabled then
        return false
    end

    local selectedName =
        self.Settings.SelectedTool

    if not selectedName or selectedName == "" then
        return false
    end

    local tools = self:GetTools()

    for _, tool in ipairs(tools) do

        if tool.Name == selectedName then
            cloneToBackpack(tool)
            return true
        end

    end

    return false

end


function Module:RefreshToolList()
    return self:GetToolNames()
end


function Module:SearchTools(pattern)

    local tools = self:GetTools()
    local filtered = {}

    if pattern and pattern ~= "" then

        for _, tool in ipairs(tools) do

            if string.find(
                tool.Name:lower(),
                pattern:lower()
            ) then

                table.insert(filtered, tool.Name)

            end

        end

    else
        filtered = self:GetToolNames()
    end

    return filtered

end


function Module:GiveTool(tool)

    if self.Settings.Enabled and tool and tool:IsA("Tool") then
        cloneToBackpack(tool)
        return true
    end

    return false

end


--------------------------------------------------
-- ACTION BUTTON
--------------------------------------------------

Module.Actions = {
    {
        Name = "Get Tool",

        Type = "Action",

        Description = "Gives you the selected tool.",

        Open = function(self)
            Module:GiveSelectedTool()
        end
    }
}


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

function Module:SetSetting(Setting, Value)

    if self.Settings[Setting] == nil then
        return false
    end

    if Setting == "Enabled" then

        Value = Value and true or false

        if Value then
            self:Enable()
        else
            self:Disable()
        end

        return true

    end

    if Setting == "ShowTools" then
        self.Settings.ShowTools = Value
    end

    if Setting == "SearchTools" then
        self.Settings.SearchTools = Value
    end

    self.Settings[Setting] = Value

    return true

end


--------------------------------------------------
-- DESTROY
--------------------------------------------------

function Module:Destroy()
    self:Disable()
end


return Module
