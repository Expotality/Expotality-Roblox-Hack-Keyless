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

return {
    Name = "Get Tool",

    Type = "Action",

    Description = "Gives you the selected tool.",

    Open = function(self)
        Module:GiveSelectedTool()
    end
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

function Module:Enable()

    self.Settings.Enabled =
        true

end


--------------------------------------------------
-- DISABLE
--------------------------------------------------

function Module:Disable()

    self.Settings.Enabled =
        false

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


-- UI calls this when rendering the settings panel to refresh dropdown options.
-- Returns a plain array of strings like {"Sword", "Shield", "Speed Coil"}.
-- The UI repopulates the dropdown from this each time it renders.
-- RefreshInterval (seconds) can be used by the UI to determine how often
-- to call this, but the UI controls the call frequency.
function Module:GetDropdownOptions(settingName)

    if settingName == "SelectedTool" then
        return self:GetToolNames()
    end

    return nil

end


-- UI calls this to give the selected tool to the player's backpack.
function Module:GiveSelectedTool()

    if not self.Settings.Enabled then

        return false

    end


    local selectedName = self.Settings.SelectedTool

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


-- UI calls this to refresh the tool name list for the dropdown.
-- Returns current tool names as a plain array; UI repopulates dropdown from this.
-- The UI determines when to call this — potentially every RefreshInterval seconds.
function Module:RefreshToolList()

    return self:GetToolNames()

end


-- Optional: filter tools by name pattern. Returns matching tool names array.
-- UI can call this in response to a search input field.
function Module:SearchTools(pattern)

    local tools = self:GetTools()

    local filtered = {}

    if pattern and pattern ~= "" then

        for _, tool in ipairs(tools) do

            if string.find(tool.Name:lower(), pattern:lower()) then

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
-- SETTINGS
--------------------------------------------------

function Module:SetSetting(
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


    if Setting == "ShowTools" then

        self.Settings.ShowTools = Value

        -- UI reads self.Settings.ShowTools to toggle tool list visibility in the panel.

    end


    if Setting == "SearchTools" then

        self.Settings.SearchTools = Value

        -- UI reads self.Settings.SearchTools as the search pattern string;
        -- UI can pass this to Module:SearchTools() to filter dropdown options.

    end


    self.Settings[Setting] =
        Value


    return true

end


--------------------------------------------------
-- DESTROY
--------------------------------------------------

function Module:Destroy()

    self:Disable()

end


--[[
-- ui.lua "Get" button integration example:
--
-- The UI framework can create a "Get" button with Type = "Action" that calls
-- Module:GiveSelectedTool() when clicked. This retrieves the currently selected
-- tool from the dropdown and gives it to the player.
--
-- Example button config:
-- {
--     Type = "Action",
--     Text = "Get",
--     OnClick = function()
--         module:GiveSelectedTool()
--     end
-- }
--
-- The module does not contain the button creation itself — the UI framework
-- handles button rendering. The module only provides the GiveSelectedTool()
-- method for the button to call.
--]]

return Module
