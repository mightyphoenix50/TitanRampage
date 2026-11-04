--!strict
--[[
    BossHUD.client.luau
    Client UI for boss fights (Milestone 15).
    Responsibility:
    - Boss gate board: each boss's requirements, ticked or crossed, with a Challenge button.
    - Boss health bar with phase, shield state and enrage countdown; titan health bar during a fight.
    - Ground telegraphs for boss attacks (red markers that fill over the wind-up).
    - Result banners: victory and rewards, defeat, knocked out, readiness-test results.
    Rendering only: every decision is made by BossService and arrives over BossFeedback.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local MainUI = (script.Parent :: any):IsA("ScreenGui") and script.Parent or PlayerGui:WaitForChild("MainUI") :: ScreenGui

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local AudioController = require(SharedFolder:WaitForChild("AudioController") :: ModuleScript)
local BossFeedback = RemotesFolder:WaitForChild("BossFeedback") :: RemoteEvent
local BossRequest = RemotesFolder:WaitForChild("BossRequest") :: RemoteEvent

local TELEGRAPH_HEIGHT = 0.6
local FONT = Enum.Font.GothamBlack
local BODY_FONT = Enum.Font.GothamBold

local function formatCommas(n: number): string
    local s = tostring(math.floor(n))
    local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if formatted:sub(1, 1) == "," then formatted = formatted:sub(2) end
    return formatted
end

local function corner(parent: Instance, radius: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
end

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, textSize: number, color: Color3, font: Enum.Font?): TextLabel
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size = size
    l.Position = pos
    l.Text = text
    l.TextSize = textSize
    l.TextColor3 = color
    l.Font = font or BODY_FONT
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.Parent = parent
    return l
end

-- ====================================================================
-- Toasts
-- ====================================================================
local activeToast: TextLabel? = nil
local function showToast(message: string, color: Color3, duration: number?)
    if activeToast then activeToast:Destroy() end
    local toast = Instance.new("TextLabel")
    toast.Name = "BossToast"
    toast.AnchorPoint = Vector2.new(0.5, 0)
    toast.Position = UDim2.new(0.5, 0, 0.3, 0)
    toast.Size = UDim2.new(0, 560, 0, 52)
    toast.BackgroundColor3 = Color3.fromRGB(20, 18, 22)
    toast.BackgroundTransparency = 0.2
    toast.Text = message
    toast.TextColor3 = color
    toast.TextStrokeTransparency = 0.4
    toast.Font = FONT
    toast.TextSize = 22
    toast.TextWrapped = true
    corner(toast, 10)
    toast.Parent = MainUI
    activeToast = toast
    task.delay(duration or 3, function()
        if not toast.Parent then return end
        local fade =
            TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1, BackgroundTransparency = 1 })
        fade:Play()
        fade.Completed:Connect(function()
            toast:Destroy()
        end)
    end)
end

-- ====================================================================
-- Boss health bar
-- ====================================================================
local bossBar = Instance.new("Frame")
bossBar.Name = "BossBar"
bossBar.AnchorPoint = Vector2.new(0.5, 0)
bossBar.Position = UDim2.new(0.5, 0, 0, 110)
bossBar.Size = UDim2.new(0, 560, 0, 64)
bossBar.BackgroundColor3 = Color3.fromRGB(16, 14, 18)
bossBar.BackgroundTransparency = 0.15
bossBar.Visible = false
bossBar.Parent = MainUI
corner(bossBar, 10)

local bossName = label(bossBar, "", UDim2.new(0.6, 0, 0, 24), UDim2.new(0, 14, 0, 4), 20, Color3.fromRGB(255, 200, 150), FONT)
local bossInfo = label(bossBar, "", UDim2.new(0.4, -14, 0, 24), UDim2.new(0.6, 0, 0, 4), 16, Color3.fromRGB(220, 220, 230))
bossInfo.TextXAlignment = Enum.TextXAlignment.Right
local bossTrack = Instance.new("Frame")
bossTrack.Size = UDim2.new(1, -28, 0, 22)
bossTrack.Position = UDim2.new(0, 14, 0, 32)
bossTrack.BackgroundColor3 = Color3.fromRGB(45, 30, 30)
bossTrack.Parent = bossBar
corner(bossTrack, 6)
local bossFill = Instance.new("Frame")
bossFill.Size = UDim2.new(1, 0, 1, 0)
bossFill.BackgroundColor3 = Color3.fromRGB(230, 60, 40)
bossFill.Parent = bossTrack
corner(bossFill, 6)
local bossHpText = label(bossTrack, "", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 15, Color3.new(1, 1, 1), FONT)
bossHpText.TextXAlignment = Enum.TextXAlignment.Center
bossHpText.ZIndex = 3

-- Titan health bar (own titan, fight only)
local titanBar = Instance.new("Frame")
titanBar.Name = "TitanHealthBar"
titanBar.AnchorPoint = Vector2.new(0.5, 1)
titanBar.Position = UDim2.new(0.5, 0, 1, -150)
titanBar.Size = UDim2.new(0, 340, 0, 18)
titanBar.BackgroundColor3 = Color3.fromRGB(30, 40, 30)
titanBar.Visible = false
titanBar.Parent = MainUI
corner(titanBar, 6)
local titanFill = Instance.new("Frame")
titanFill.Size = UDim2.new(1, 0, 1, 0)
titanFill.BackgroundColor3 = Color3.fromRGB(70, 220, 110)
titanFill.Parent = titanBar
corner(titanFill, 6)
local titanText = label(titanBar, "", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 13, Color3.new(1, 1, 1), FONT)
titanText.TextXAlignment = Enum.TextXAlignment.Center
titanText.ZIndex = 3

local enrageDeadline = 0 -- Local os.clock() time the boss enrages
local fightActive = false
local healthConn: RBXScriptConnection? = nil

local function bindTitanHealth()
    if healthConn then healthConn:Disconnect() end
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local function refresh()
        local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
        titanFill.Size = UDim2.new(ratio, 0, 1, 0)
        titanFill.BackgroundColor3 = if ratio > 0.5
            then Color3.fromRGB(70, 220, 110)
            elseif ratio > 0.25 then Color3.fromRGB(240, 190, 60)
            else Color3.fromRGB(235, 70, 60)
        titanText.Text = string.format("TITAN HP %s / %s", formatCommas(humanoid.Health), formatCommas(humanoid.MaxHealth))
    end
    refresh()
    healthConn = humanoid.HealthChanged:Connect(refresh)
end

local function setFightVisible(visible: boolean)
    fightActive = visible
    bossBar.Visible = visible
    titanBar.Visible = visible
    if visible then bindTitanHealth() end
end

local function applyHealth(data: any)
    local ratio = math.clamp((data.Health or 0) / math.max(data.MaxHealth or 1, 1), 0, 1)
    TweenService:Create(bossFill, TweenInfo.new(0.15), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
    bossFill.BackgroundColor3 = if data.Shielded then Color3.fromRGB(150, 120, 255) else Color3.fromRGB(230, 60, 40)
    bossName.Text = string.upper(data.BossName or "BOSS") .. (if data.Shielded then "  🛡️ SHIELDED (stomps only)" else "")
    bossHpText.Text = string.format("%s / %s", formatCommas(data.Health or 0), formatCommas(data.MaxHealth or 0))
    if data.EnrageAt and data.ServerClock then enrageDeadline = os.clock() + (data.EnrageAt - data.ServerClock) end
    bossInfo.Text = string.format("Phase %d • Party %d", data.Phase or 1, data.PartySize or 1)
end

task.spawn(function()
    while true do
        task.wait(0.25)
        if fightActive then
            local left = math.max(0, math.floor(enrageDeadline - os.clock()))
            local base = bossInfo.Text:match("^(Phase %d+ • Party %d+)") or bossInfo.Text
            bossInfo.Text = string.format("%s • ⏱ %d:%02d", base, left // 60, left % 60)
        end
    end
end)

-- ====================================================================
-- Telegraphs
-- ====================================================================
local telegraphFolder = Workspace:FindFirstChild("BossTelegraphs") or Instance.new("Folder")
telegraphFolder.Name = "BossTelegraphs"
telegraphFolder.Parent = Workspace

local function markerPart(size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): BasePart
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Material = Enum.Material.Neon
    p.Color = color
    p.Transparency = 0.85
    p.Size = size
    if shape then p.Shape = shape end
    p.CFrame = cframe
    p.Parent = telegraphFolder
    return p
end

local function disc(center: Vector3, radius: number, color: Color3): BasePart
    -- Cylinders extend along X, so lay them flat by rotating 90° around Z
    return markerPart(
        Vector3.new(TELEGRAPH_HEIGHT, radius * 2, radius * 2),
        CFrame.new(center + Vector3.new(0, TELEGRAPH_HEIGHT * 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        color,
        Enum.PartType.Cylinder
    )
end

local function ringSegments(center: Vector3, inner: number, outer: number, color: Color3): { BasePart }
    local parts = {}
    local count = 36
    local mid = (inner + outer) * 0.5
    local arc = 2 * math.pi * mid / count * 1.08
    for i = 1, count do
        local a = (i / count) * math.pi * 2
        local pos = center + Vector3.new(math.cos(a) * mid, TELEGRAPH_HEIGHT * 0.5, math.sin(a) * mid)
        local cf = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
        table.insert(parts, markerPart(Vector3.new(arc, TELEGRAPH_HEIGHT, outer - inner), cf, color))
    end
    return parts
end

local function coneSegments(origin: Vector3, forward: Vector3, radius: number, halfAngle: number, color: Color3): { BasePart }
    local parts = {}
    local stepDeg = 6
    local steps = math.max(2, math.floor(halfAngle * 2 / stepDeg))
    local base = math.atan2(forward.X, forward.Z)
    for i = 0, steps do
        local a = base + math.rad(-halfAngle + i * (halfAngle * 2 / steps))
        local dir = Vector3.new(math.sin(a), 0, math.cos(a))
        local width = 2 * radius * math.sin(math.rad(stepDeg) * 0.6)
        local pos = origin + dir * (radius * 0.5) + Vector3.new(0, TELEGRAPH_HEIGHT * 0.5, 0)
        -- A wedge-ish strip: wide at the far end is approximated by a strip at half width
        table.insert(parts, markerPart(Vector3.new(width * 0.6, TELEGRAPH_HEIGHT, radius), CFrame.lookAt(pos, pos + dir), color))
    end
    return parts
end

local function playTelegraph(data: any)
    local color = Color3.fromRGB(255, 50, 30)
    local parts: { BasePart } = {}
    local origin: Vector3 = data.Origin or Vector3.zero
    if data.Kind == "Slam" or data.Kind == "Circle" then
        for _, c in ipairs(data.Circles or {}) do
            table.insert(parts, disc(c.Center, c.Radius, color))
        end
    elseif data.Kind == "Donut" then
        parts = ringSegments(origin, data.InnerRadius or 50, data.Radius or 150, color)
    elseif data.Kind == "Cone" then
        parts = coneSegments(origin, data.Forward or Vector3.new(0, 0, -1), data.Radius or 120, data.Angle or 35, color)
    elseif data.Kind == "Lanes" then
        local axis: Vector3 = data.LaneAxis or Vector3.new(1, 0, 0)
        for _, lane in ipairs(data.Lanes or {}) do
            local pos = lane.Center + Vector3.new(0, TELEGRAPH_HEIGHT * 0.5, 0)
            local size = if math.abs(axis.X) > 0.5
                then Vector3.new(lane.Length, TELEGRAPH_HEIGHT, lane.Width)
                else Vector3.new(lane.Width, TELEGRAPH_HEIGHT, lane.Length)
            table.insert(parts, markerPart(size, CFrame.new(pos), color))
        end
    end

    local windUp = data.WindUp or 1.2
    for _, p in ipairs(parts) do
        TweenService:Create(p, TweenInfo.new(windUp, Enum.EasingStyle.Linear), { Transparency = 0.35 }):Play()
    end
    task.delay(windUp, function()
        for _, p in ipairs(parts) do
            p.Transparency = 0.05
            p.Color = Color3.fromRGB(255, 220, 120)
            TweenService:Create(p, TweenInfo.new(0.35), { Transparency = 1 }):Play()
        end
        task.delay(0.4, function()
            for _, p in ipairs(parts) do
                p:Destroy()
            end
        end)
    end)
end

-- ====================================================================
-- Boss gate board
-- ====================================================================
local board = Instance.new("Frame")
board.Name = "BossGatePanel"
board.AnchorPoint = Vector2.new(0.5, 0.5)
board.Position = UDim2.new(0.5, 0, 0.5, 0)
board.Size = UDim2.new(0, 620, 0, 470)
board.BackgroundColor3 = Color3.fromRGB(18, 16, 20)
board.BackgroundTransparency = 0.05
board.Visible = false
board.Parent = MainUI
corner(board, 12)
local boardStroke = Instance.new("UIStroke")
boardStroke.Color = Color3.fromRGB(255, 110, 30)
boardStroke.Thickness = 2
boardStroke.Parent = board

label(board, "⚔️ COLOSSEUM BOSS GATE", UDim2.new(1, -80, 0, 34), UDim2.new(0, 18, 0, 10), 24, Color3.fromRGB(255, 170, 90), FONT)
local boardSub = label(board, "", UDim2.new(1, -36, 0, 22), UDim2.new(0, 18, 0, 44), 15, Color3.fromRGB(200, 200, 210))
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -46, 0, 10)
closeBtn.Text = "X"
closeBtn.Font = FONT
closeBtn.TextSize = 20
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
closeBtn.Parent = board
corner(closeBtn, 8)
closeBtn.MouseButton1Click:Connect(function()
    board.Visible = false
end)

local cardList = Instance.new("Frame")
cardList.BackgroundTransparency = 1
cardList.Size = UDim2.new(1, -36, 1, -84)
cardList.Position = UDim2.new(0, 18, 0, 74)
cardList.Parent = board
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.Parent = cardList

local function renderBoard(data: any)
    for _, child in ipairs(cardList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    boardSub.Text = string.format(
        "Your Titan Power: ⚡ %s   •   Best readiness DPS: %s   (hit the Bastion dummy for 20 s to test)",
        formatCommas(data.Power or 0),
        formatCommas(data.ReadinessDPS or 0)
    )
    for _, boss in ipairs(data.Bosses or {}) do
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 112)
        card.BackgroundColor3 = Color3.fromRGB(30, 27, 33)
        card.Parent = cardList
        corner(card, 10)
        local stripe = Instance.new("Frame")
        stripe.Size = UDim2.new(0, 6, 1, 0)
        stripe.BackgroundColor3 = boss.Color or Color3.fromRGB(255, 100, 40)
        stripe.BorderSizePixel = 0
        stripe.Parent = card

        label(card, boss.DisplayName, UDim2.new(0.6, 0, 0, 26), UDim2.new(0, 18, 0, 6), 20, Color3.new(1, 1, 1), FONT)
        label(card, boss.Description, UDim2.new(0.68, 0, 0, 34), UDim2.new(0, 18, 0, 32), 13, Color3.fromRGB(180, 180, 190))

        local reqText = if boss.Ready then "✅ Ready" else "❌ Needs: " .. table.concat(boss.Missing or {}, " • ")
        local req = label(
            card,
            reqText,
            UDim2.new(0.68, 0, 0, 36),
            UDim2.new(0, 18, 0, 70),
            13,
            if boss.Ready then Color3.fromRGB(110, 230, 140) else Color3.fromRGB(240, 150, 140)
        )
        req.TextYAlignment = Enum.TextYAlignment.Top

        local rewardText = if boss.Clears > 0
            then (if (boss.CooldownLeft or 0) > 0
                then string.format("Repeat reward in %d:%02d", boss.CooldownLeft // 60, boss.CooldownLeft % 60)
                else string.format("Repeat reward: $%s", formatCommas(boss.NextReward)))
            else string.format("First clear: $%s + title", formatCommas(boss.NextReward))
        local reward = label(card, rewardText, UDim2.new(0.3, -12, 0, 36), UDim2.new(0.7, 0, 0, 8), 14, Color3.fromRGB(255, 215, 90))
        reward.TextXAlignment = Enum.TextXAlignment.Right
        local recommended = label(
            card,
            string.format("Power %s • ~%s DPS", formatCommas(boss.RequiredPower), formatCommas(boss.RecommendedDPS)),
            UDim2.new(0.3, -12, 0, 18),
            UDim2.new(0.7, 0, 0, 44),
            12,
            Color3.fromRGB(190, 190, 200)
        )
        recommended.TextXAlignment = Enum.TextXAlignment.Right

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 150, 0, 34)
        btn.Position = UDim2.new(1, -162, 1, -42)
        btn.Font = FONT
        btn.TextSize = 16
        btn.TextColor3 = Color3.new(1, 1, 1)
        local canChallenge = boss.Ready and not data.FightActive
        btn.Text = if data.FightActive then "FIGHT IN PROGRESS" elseif boss.Ready then "CHALLENGE" else "LOCKED"
        btn.BackgroundColor3 = if canChallenge then Color3.fromRGB(230, 90, 30) else Color3.fromRGB(55, 55, 62)
        btn.AutoButtonColor = canChallenge
        btn.Parent = card
        corner(btn, 8)
        btn.MouseButton1Click:Connect(function()
            if not canChallenge then
                AudioController.PlayUI("UpgradeError")
                return
            end
            AudioController.PlayUI("ButtonClick")
            BossRequest:FireServer("Challenge", boss.Id)
            board.Visible = false
        end)
    end
end

-- ====================================================================
-- Server events
-- ====================================================================
BossFeedback.OnClientEvent:Connect(function(eventType: string, data: any)
    if type(data) ~= "table" then return end
    if eventType == "BossBoard" then
        renderBoard(data)
        board.Visible = true
    elseif eventType == "FightStarted" then
        setFightVisible(true)
        applyHealth(data)
        showToast(string.format("⚔️ %s AWAKENS IN THE COLOSSEUM!", string.upper(data.BossName or "BOSS")), Color3.fromRGB(255, 150, 60))
    elseif eventType == "BossHealth" then
        if not fightActive then setFightVisible(true) end
        applyHealth(data)
    elseif eventType == "PhaseChanged" then
        showToast(string.format("%s enters phase %d!", data.BossName or "The boss", data.Phase or 2), Color3.fromRGB(255, 120, 80), 2)
    elseif eventType == "Telegraph" then
        if data.Kind == "Shield" then
            showToast("🛡️ Shield up: only stomps can crack it!", Color3.fromRGB(180, 160, 255), 2.5)
        else
            playTelegraph(data)
        end
    elseif eventType == "Shielded" then
        showToast("🛡️ Shielded: use a stomp!", Color3.fromRGB(180, 160, 255), 1.2)
    elseif eventType == "KnockedOut" then
        setFightVisible(false)
        showToast(
            string.format("💫 Knocked out by %s! Upgrade and try again.", data.BossName or "the boss"),
            Color3.fromRGB(240, 150, 140),
            4
        )
    elseif eventType == "LeftFight" then
        setFightVisible(false)
        showToast("You left the arena and dropped out of the fight.", Color3.fromRGB(220, 200, 190))
    elseif eventType == "FightEnded" then
        setFightVisible(false)
        if data.Victory then
            local mine = data.Rewards and data.Rewards[tostring(LocalPlayer.UserId)]
            local text = string.format("🏆 %s DEFEATED in %ds!", string.upper(data.BossName or "BOSS"), data.Duration or 0)
            if mine then
                if mine.Cash and mine.Cash > 0 then
                    text ..= string.format("  +$%s", formatCommas(mine.Cash))
                end
                if mine.Title then
                    text ..= string.format("  Title: %s", mine.Title)
                end
                if mine.Cash == 0 then
                    text ..= "  (repeat reward on cooldown)"
                end
            else
                text ..= "  (deal 5% of the damage to earn a reward)"
            end
            showToast(text, Color3.fromRGB(255, 220, 90), 5)
            AudioController.PlayCityComplete()
        else
            showToast(string.format("☠️ %s won: %s", data.BossName or "The boss", data.Reason or ""), Color3.fromRGB(240, 140, 130), 4)
        end
    elseif eventType == "ChallengeRejected" then
        showToast(data.Reason or "Can't start that fight.", Color3.fromRGB(240, 170, 150))
    elseif eventType == "ReadinessStarted" then
        showToast(
            string.format("⏱ Readiness test: hit the Bastion for %d seconds!", data.Duration or 20),
            Color3.fromRGB(200, 220, 255),
            2.5
        )
    elseif eventType == "ReadinessResult" then
        local parts = {}
        for _, v in ipairs(data.Verdicts or {}) do
            table.insert(parts, string.format("%s %s", if v.Ready then "✅" else "❌", v.BossName))
        end
        showToast(
            string.format("Readiness: %s DPS  •  %s", formatCommas(data.DPS or 0), table.concat(parts, "  ")),
            Color3.fromRGB(200, 230, 255),
            6
        )
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    if fightActive then task.defer(bindTitanHealth) end
end)

print("[BossHUD] Boss gate, health bars and telegraphs initialized.")
