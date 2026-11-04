--!strict
--[[
    TrainingController.client.luau
    Client feedback for the Titan Punching Bags (Milestone 15).
    Responsibility:
    - Swings a bag on its chain when any titan hits it (bag model's "Swing" sub-model pivots at the chain top).
    - Floating "+TP" numbers and a training meter toward the cap for the local player.
    - Notices when a bag is locked behind Power or training is capped.
    Purely cosmetic; TrainingService decides every gain.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local TrainingFeedback = RemotesFolder:WaitForChild("TrainingFeedback") :: RemoteEvent

local SWING_ANGLE = math.rad(22)
local SWING_TIME = 1.6

-- Live swings: each bag's rest pivot, swing axis and start time
local swings: { [Model]: { Rest: CFrame, Axis: Vector3, Start: number } } = {}

local function getSwingModel(bag: Instance): Model?
    local swing = bag:FindFirstChild("Swing")
    if swing and swing:IsA("Model") then return swing end
    return nil
end

local function startSwing(bag: Instance, attacker: Player?)
    local swing = getSwingModel(bag)
    if not swing then return end
    local existing = swings[swing]
    local rest = if existing then existing.Rest else swing:GetPivot()
    -- Swing away from the attacker: rotate around the horizontal axis perpendicular to them
    local axis = Vector3.new(1, 0, 0)
    local root = attacker and attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if root then
        local away = Vector3.new(rest.Position.X - root.Position.X, 0, rest.Position.Z - root.Position.Z)
        if away.Magnitude > 0.1 then axis = Vector3.new(away.Z, 0, -away.X).Unit end
    end
    swings[swing] = { Rest = rest, Axis = axis, Start = os.clock() }
end

RunService.RenderStepped:Connect(function()
    local now = os.clock()
    for swing, state in pairs(swings) do
        local t = now - state.Start
        if not swing.Parent or t >= SWING_TIME then
            if swing.Parent then swing:PivotTo(state.Rest) end
            swings[swing] = nil
        else
            -- Damped pendulum
            local angle = SWING_ANGLE * math.exp(-2.2 * t) * math.sin(t * 7)
            swing:PivotTo(state.Rest * CFrame.fromAxisAngle(state.Rest:VectorToObjectSpace(state.Axis), angle))
        end
    end
end)

-- ====================================================================
-- Meter and floating numbers
-- ====================================================================
local gui = Instance.new("ScreenGui")
gui.Name = "TrainingHUD"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local meter = Instance.new("TextLabel")
meter.AnchorPoint = Vector2.new(0.5, 1)
meter.Position = UDim2.new(0.5, 0, 1, -180)
meter.Size = UDim2.new(0, 360, 0, 30)
meter.BackgroundColor3 = Color3.fromRGB(20, 18, 22)
meter.BackgroundTransparency = 0.25
meter.TextColor3 = Color3.fromRGB(255, 210, 140)
meter.Font = Enum.Font.GothamBlack
meter.TextSize = 16
meter.Visible = false
meter.Parent = gui
local meterCorner = Instance.new("UICorner")
meterCorner.CornerRadius = UDim.new(0, 8)
meterCorner.Parent = meter

local hideToken = 0
local function showMeter(text: string, color: Color3?)
    meter.Text = text
    meter.TextColor3 = color or Color3.fromRGB(255, 210, 140)
    meter.Visible = true
    hideToken += 1
    local token = hideToken
    task.delay(4, function()
        if token == hideToken then meter.Visible = false end
    end)
end

local function floatNumber(bag: Instance, text: string)
    local anchorPart = if bag:IsA("Model") then bag.PrimaryPart else (if bag:IsA("BasePart") then bag else nil)
    if not anchorPart then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 140, 0, 36)
    billboard.StudsOffset = Vector3.new(math.random(-3, 3), 6, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = anchorPart
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.fromScale(1, 1)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
    textLabel.TextStrokeTransparency = 0.2
    textLabel.Font = Enum.Font.GothamBlack
    textLabel.TextSize = 22
    textLabel.Parent = billboard
    billboard.Parent = gui
    TweenService:Create(
        billboard,
        TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { StudsOffset = billboard.StudsOffset + Vector3.new(0, 8, 0) }
    ):Play()
    TweenService:Create(textLabel, TweenInfo.new(1.0), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
    task.delay(1.05, function()
        billboard:Destroy()
    end)
end

TrainingFeedback.OnClientEvent:Connect(function(eventType: string, data: any)
    if type(data) ~= "table" then return end
    if eventType == "BagSwing" then
        if typeof(data.Bag) == "Instance" then startSwing(data.Bag, data.Attacker) end
    elseif eventType == "BagGain" then
        if typeof(data.Bag) == "Instance" then floatNumber(data.Bag, string.format("+%.2f TP", data.Gain or 0)) end
        local text = string.format("🥊 Training %.1f / %d", data.TrainingPower or 0, data.Cap or 0)
        if data.Fatigued then
            text ..= "  (tired: hit something else!)"
        end
        showMeter(text, if data.Fatigued then Color3.fromRGB(240, 170, 150) else nil)
    elseif eventType == "BagCapped" then
        showMeter(string.format("🥊 Training capped at %d: destroy cities to raise it!", data.Cap or 0), Color3.fromRGB(240, 170, 150))
    elseif eventType == "BagLocked" then
        showMeter(
            string.format("🔒 %s needs %d Power from upgrades", data.BagName or "This bag", data.RequiredPower or 0),
            Color3.fromRGB(240, 170, 150)
        )
    end
end)

print("[TrainingController] Punching bag feedback initialized.")
