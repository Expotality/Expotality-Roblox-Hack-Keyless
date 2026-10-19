local Module = {
    Name = "Reach",

    Settings = {
        Enabled = false,
        ReachDistance = 3.5,
        ReachShape = false,
        DamageMode = true,
        Visualizer = true,
        AutoClicker = false,
        ClickSpeed = 20,
    },
    _connections = {},
    _visualizer = nil,
    _running = false,
    _plr = nil,
    _initialized = false,
    _autoClickerThread = nil,
}

function Module:initialize()
    if self._initialized then return end
    repeat task.wait() until game:IsLoaded()
    repeat task.wait() until game.Players.LocalPlayer
    self._plr = game.Players.LocalPlayer
    self._initialized = true
end

function Module:validateSettings()
    if typeof(self.Settings.ClickSpeed) ~= "number" or self.Settings.ClickSpeed < 1 or self.Settings.ClickSpeed > 100 then
        self.Settings.ClickSpeed = 20
    end
    if typeof(self.Settings.ReachDistance) ~= "number" or self.Settings.ReachDistance < 0.1 then
        self.Settings.ReachDistance = 3.5
    end
end

function Module:Enable()
    if self._running then return end

    self:initialize()
    self:validateSettings()

    self._running = true
    self.Settings.Enabled = true

    self._visualizer = Instance.new("Part")
    self._visualizer.BrickColor = BrickColor.new("Bright red")
    self._visualizer.Transparency = 0.7
    self._visualizer.Anchored = true
    self._visualizer.CanCollide = false
    self._visualizer.Size = Vector3.new(0.5, 0.5, 0.5)
    self._visualizer.Material = Enum.Material.Neon
    self._visualizer.BottomSurface = Enum.SurfaceType.Smooth
    self._visualizer.TopSurface = Enum.SurfaceType.Smooth
    self._visualizer.Parent = nil

    if self._autoClickerThread then
        self._autoClickerThread = nil
    end
    self._autoClickerThread = task.spawn(function()
        while self._running and self._plr do
            if self.Settings.AutoClicker and self._plr.Character then
                local tool = self._plr.Character:FindFirstChildOfClass("Tool")
                if tool then
                    tool:Activate()
                end
            end
            task.wait(1 / self.Settings.ClickSpeed)
        end
    end)

    local renderConn
    renderConn = game:GetService("RunService").RenderStepped:Connect(function()
        if not self._running or not self.Settings.Enabled then
            renderConn:Disconnect()
            return
        end

        local character = self._plr.Character
        if not character then
            self._visualizer.Parent = nil
            return
        end

        local s = character:FindFirstChildOfClass("Tool")
        if not s then
            self._visualizer.Parent = nil
            return
        end

        local handle = s:FindFirstChild("Handle") or s:FindFirstChildOfClass("Part")
        if not handle then
            self._visualizer.Parent = nil
            return
        end

        if self.Settings.Visualizer then
            self._visualizer.Parent = workspace
        else
            self._visualizer.Parent = nil
        end

        local reach = self.Settings.ReachDistance

        if not self.Settings.ReachShape then
            self._visualizer.Shape = Enum.PartType.Ball
            self._visualizer.Size = Vector3.new(reach, reach, reach)
            self._visualizer.CFrame = handle.CFrame

            for _, player in ipairs(game.Players:GetPlayers()) do
                if player ~= self._plr and player.Character then
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and handle then
                        local mag = (hrp.Position - handle.Position).magnitude
                        if mag <= reach then
                            self:onHit(hrp, handle)
                        end
                    end
                end
            end
        else
            local origin = (handle.CFrame * CFrame.new(0, 0, -2)).p
            local ray = Ray.new(origin, handle.CFrame.lookVector * -reach)
            local p, pos = workspace:FindPartOnRayWithWhitelist(ray, self:getWhiteList())

            self._visualizer.Shape = Enum.PartType.Block
            self._visualizer.Size = Vector3.new(1, 0.8, reach)
            self._visualizer.CFrame = handle.CFrame * CFrame.new(0, 0, (reach / 2) + 2)

            if p then
                self:onHit(p, handle)
            else
                for _, part in ipairs(handle:GetTouchingParts()) do
                    self:onHit(part, handle)
                end
            end
        end
    end)

    table.insert(self._connections, renderConn)
end

function Module:Disable()
    self._running = false
    self.Settings.Enabled = false
    self._autoClickerThread = nil

    for _, conn in ipairs(self._connections) do
        if conn then conn:Disconnect() end
    end
    self._connections = {}

    if self._visualizer then
        self._visualizer:Destroy()
        self._visualizer = nil
    end
end

function Module:onHit(hit, handle)
    if not hit or not hit.Parent then return end

    local victim = hit.Parent:FindFirstChildOfClass("Humanoid")
    if not victim or not victim.Parent then return end
    if victim.Parent.Name == self._plr.Name then return end

    pcall(function()
        if self.Settings.DamageMode then
            for _, part in ipairs(hit.Parent:GetChildren()) do
                if part:IsA("BasePart") then
                    firetouchinterest(part, handle, 0)
                    firetouchinterest(part, handle, 1)
                end
            end
        else
            firetouchinterest(hit, handle, 0)
            firetouchinterest(hit, handle, 1)
        end
    end)
end

function Module:getWhiteList()
    local wl = {}
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player ~= self._plr and player.Character then
            for _, part in ipairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") then
                    table.insert(wl, part)
                end
            end
        end
    end
    return wl
end

return Module
