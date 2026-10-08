--!strict
--[[
    TitanController.client.luau
    Client-side controller for Titan Rampage.
    Responsibility:
    - Captures player inputs (WASD, Jump, LMB, E, R, Q).
    - Requests server-authoritative abilities via TitanAction RemoteEvent.
    - Resolves active Titan identity, abilities, and camera bounds through TitanRegistry.
    - Renders client-side visual and auditory effects upon receiving TitanEffect events.
    - Manages camera perspective for colossal Titan character scale.
    - Milestone 9A: Multi-Titan Architecture.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local SharedFolder = ReplicatedStorage:WaitForChild("Shared")

local TitanRegistry = require(SharedFolder:WaitForChild("TitanRegistry") :: ModuleScript)
local TitanAnimationController = require(SharedFolder:WaitForChild("TitanAnimationController") :: ModuleScript)
local AudioController = require(SharedFolder:WaitForChild("AudioController") :: ModuleScript)

local TitanActionRemote = RemotesFolder:WaitForChild("TitanAction") :: RemoteEvent
local TitanEffectRemote = RemotesFolder:WaitForChild("TitanEffect") :: RemoteEvent
local TitanFeedbackRemote = RemotesFolder:WaitForChild("TitanFeedback") :: RemoteEvent

local currentTitanId = "Ravager"
local currentTitanDef = TitanRegistry.Get(currentTitanId)

local function updateActiveTitan(titanId: string)
    local def = TitanRegistry.Get(titanId)
    if not def then return end
    currentTitanId = titanId
    currentTitanDef = def
    print("[TitanController] Active Titan switched to: " .. titanId)
end

-- Animation Controller Registry per character Model
local activeAnimControllers: { [Model]: any } = {}

local function getAnimController(character: Model)
    if not character or not character.Parent then return nil end
    if not activeAnimControllers[character] then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return nil end

        local animCtrl = TitanAnimationController.new(character)
        activeAnimControllers[character] = animCtrl

        character.Destroying:Connect(function()
            if activeAnimControllers[character] then
                activeAnimControllers[character]:Destroy()
                activeAnimControllers[character] = nil
            end
        end)
    end
    return activeAnimControllers[character]
end

-- Client-side predicted cooldown timers (prevents client network flooding)
local clientCooldowns: { [string]: number } = {
    BasicAttack = 0,
    Stomp = 0,
    Roar = 0,
    TailSweep = 0,
    HeavyStomp = 0,
    NeckStrike = 0,
}

--[=[
    Initializes camera zoom parameters and offsets for the Titan scale from TitanRegistry.
]=]
local function setupCamera(character: Model)
    local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
    if not humanoid then return end

    local attrTitan = character:GetAttribute("TitanId")
    if attrTitan and type(attrTitan) == "string" and TitanRegistry.Get(attrTitan) then
        updateActiveTitan(attrTitan)
    end

    if currentTitanDef and currentTitanDef.CameraZoom then
        LocalPlayer.CameraMinZoomDistance = currentTitanDef.CameraZoom.Min
        LocalPlayer.CameraMaxZoomDistance = currentTitanDef.CameraZoom.Max
        humanoid.CameraOffset = currentTitanDef.CameraZoom.CameraOffset
    end

    -- Pre-initialize animation controller on spawn
    getAnimController(character)
end

TitanFeedbackRemote.OnClientEvent:Connect(function(eventType: string, data: any)
    if eventType == "TitanSelected" or eventType == "TitanSpawned" then
        if data and data.TitanId and type(data.TitanId) == "string" then
            updateActiveTitan(data.TitanId)
            if LocalPlayer.Character then
                setupCamera(LocalPlayer.Character)
            end
        end
    end
end)

-- Setup on character spawn
if LocalPlayer.Character then
    setupCamera(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(setupCamera)

-- Client-side immediate ability anticipation table for responsive input feel
local ClientAbilityAnticipation: { [string]: (char: Model, animCtrl: any, titanId: string) -> () } = {
    BasicAttack = function(char, animCtrl, titanId)
        local variant = animCtrl:PlayBasicAttack()
        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        AudioController.PlayTitanAttackWhoosh(titanId, variant, hrp)
    end,
    TailSweep = function(char, animCtrl, titanId)
        animCtrl:PlayTailSweep()
        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        AudioController.PlayTitanAttackWhoosh(titanId, "LeftSwipe", hrp)
    end,
    Stomp = function(char, _animCtrl, _titanId)
        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        AudioController.PlayStompAnticipation(hrp)
    end,
    HeavyStomp = function(char, _animCtrl, _titanId)
        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        AudioController.PlayStompAnticipation(hrp)
    end,
    NeckStrike = function(char, animCtrl, titanId)
        animCtrl:PlayNeckStrike()
        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        AudioController.PlayTitanAttackWhoosh(titanId, "DownwardSmash", hrp)
    end,
}

--[=[
    Requests an ability from the server if client predicted cooldown allows.
]=]
local function tryRequestAbility(actionName: string)
    if not currentTitanDef then return end
    local abilityDef = currentTitanDef.Abilities[actionName]
    if not abilityDef then return end

    local now = os.clock()
    local lastTime = clientCooldowns[actionName] or 0
    local cd = abilityDef.Cooldown or 1.0

    if (now - lastTime) < cd then
        return
    end

    clientCooldowns[actionName] = now

    -- Immediate client-side animation and whoosh trigger for zero input latency
    if LocalPlayer.Character then
        local animCtrl = getAnimController(LocalPlayer.Character)
        if animCtrl then
            local anticipator = ClientAbilityAnticipation[actionName]
            if anticipator then
                anticipator(LocalPlayer.Character, animCtrl, currentTitanId)
            end
        end
    end

    TitanActionRemote:FireServer(actionName)
end

-- Helper to find ability by slot authoritatively from TitanRegistry
local function getAbilityNameBySlot(slot: TitanRegistry.AbilitySlot): string?
    local ab = TitanRegistry.GetAbilityForSlot(currentTitanId, slot)
    return if ab then ab.Name else nil
end

-- Input Bindings:
-- Primary (LMB / 1) -> BasicAttack for Ravager
-- Stomp (E / 2) -> Stomp for Ravager
-- Signature (Q) -> None for Ravager
-- Utility (R / 3) -> Roar for Ravager
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.One then
        local ability = getAbilityNameBySlot("Primary")
        if ability then tryRequestAbility(ability) end
    elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Two then
        local ability = getAbilityNameBySlot("Stomp")
        if ability then tryRequestAbility(ability) end
    elseif input.KeyCode == Enum.KeyCode.Q then
        local ability = getAbilityNameBySlot("Signature")
        if ability then tryRequestAbility(ability) end
    elseif input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.Three then
        local ability = getAbilityNameBySlot("Utility")
        if ability then tryRequestAbility(ability) end
    end
end)

-- Visual effect handlers map for clean modular rendering
local EffectHandlers: { [string]: (sourceChar: Model?, data: any) -> () } = {
    StompWindup = function(sourceChar, data)
        local pos = data.Position or Vector3.zero
        local windUpTime = data.WindUp or 0.35
        local radius = data.Radius or 30

        if sourceChar then
            local animCtrl = getAnimController(sourceChar)
            if animCtrl then
                animCtrl:PlayStomp()
            end
            if sourceChar ~= LocalPlayer.Character then
                local hrp = sourceChar:FindFirstChild("HumanoidRootPart") :: BasePart?
                AudioController.PlayStompAnticipation(hrp)
            end
        end

        local windupRing = Instance.new("Part")
        windupRing.Name = "StompAnticipation"
        windupRing.Shape = Enum.PartType.Cylinder
        windupRing.Material = Enum.Material.Neon
        windupRing.Color = Color3.fromRGB(255, 60, 20)
        windupRing.Size = Vector3.new(0.3, radius * 1.5, radius * 1.5)
        windupRing.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
        windupRing.Anchored = true
        windupRing.CanCollide = false
        windupRing.CanQuery = false
        windupRing.CanTouch = false
        windupRing.Transparency = 0.8
        windupRing.Parent = Workspace

        local tween = TweenService:Create(windupRing, TweenInfo.new(windUpTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = Vector3.new(0.6, 6, 6),
            Transparency = 0.1,
            Color = Color3.fromRGB(255, 200, 50),
        })
        tween:Play()
        tween.Completed:Connect(function()
            windupRing:Destroy()
        end)
    end,

    Stomp = function(_sourceChar, data)
        local pos = data.Position or Vector3.zero
        local targetRadius = data.Radius or 30

        AudioController.PlayStompImpact(pos)

        local ring = Instance.new("Part")
        ring.Name = "StompShockwave"
        ring.Shape = Enum.PartType.Cylinder
        ring.Material = Enum.Material.Neon
        ring.Color = Color3.fromRGB(255, 120, 20)
        ring.Size = Vector3.new(1.2, 6, 6)
        ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
        ring.Anchored = true
        ring.CanCollide = false
        ring.CanQuery = false
        ring.CanTouch = false
        ring.Transparency = 0.15
        ring.Parent = Workspace

        local outerRing = Instance.new("Part")
        outerRing.Name = "StompOuterWave"
        outerRing.Shape = Enum.PartType.Cylinder
        outerRing.Material = Enum.Material.Neon
        outerRing.Color = Color3.fromRGB(255, 220, 80)
        outerRing.Size = Vector3.new(0.6, 4, 4)
        outerRing.CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
        outerRing.Anchored = true
        outerRing.CanCollide = false
        outerRing.CanQuery = false
        outerRing.CanTouch = false
        outerRing.Transparency = 0.3
        outerRing.Parent = Workspace

        local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local t1 = TweenService:Create(ring, tweenInfo, {
            Size = Vector3.new(0.3, targetRadius * 2, targetRadius * 2),
            Transparency = 1,
        })
        local t2 = TweenService:Create(outerRing, TweenInfo.new(0.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = Vector3.new(0.2, targetRadius * 2.4, targetRadius * 2.4),
            Transparency = 1,
        })
        t1:Play()
        t2:Play()
        t1.Completed:Connect(function() ring:Destroy() end)
        t2.Completed:Connect(function() outerRing:Destroy() end)

        for i = 1, 6 do
            local angle = (i / 6) * math.pi * 2
            local debris = Instance.new("Part")
            debris.Size = Vector3.new(1.2, 1.2, 1.2)
            debris.Material = Enum.Material.Concrete
            debris.Color = Color3.fromRGB(90, 85, 80)
            debris.CFrame = CFrame.new(pos + Vector3.new(math.cos(angle) * 3, 1, math.sin(angle) * 3))
            debris.Anchored = true
            debris.CanCollide = false
            debris.CanQuery = false
            debris.CanTouch = false
            debris.Parent = Workspace

            local targetDebrisPos = debris.Position + Vector3.new(math.cos(angle) * (targetRadius * 0.6), 4 + math.random() * 3, math.sin(angle) * (targetRadius * 0.6))
            local dt = TweenService:Create(debris, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = targetDebrisPos,
                Transparency = 1,
                Size = Vector3.new(0.3, 0.3, 0.3),
            })
            dt:Play()
            dt.Completed:Connect(function() debris:Destroy() end)
        end

        if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
            local dist = (LocalPlayer.Character.PrimaryPart.Position - pos).Magnitude
            local maxDist = targetRadius * 2.8
            if dist < maxDist then
                local falloff = math.clamp(1 - (dist / maxDist), 0, 1)
                local intensity = (falloff ^ 1.5) * 1.2
                task.spawn(function()
                    for step = 1, 6 do
                        local decay = (7 - step) / 6
                        Camera.CFrame = Camera.CFrame * CFrame.Angles(
                            math.rad(math.random(-12, 12) * 0.08 * intensity * decay),
                            math.rad(math.random(-12, 12) * 0.08 * intensity * decay),
                            math.rad(math.random(-8, 8) * 0.05 * intensity * decay)
                        )
                        task.wait(0.025)
                    end
                end)
            end
        end
    end,

    Roar = function(sourceChar, data)
        local pos = data.Position or Vector3.zero
        local targetRadius = data.Radius or 45
        local titanId = data.Titan or "Ravager"

        if sourceChar then
            local animCtrl = getAnimController(sourceChar)
            if animCtrl then
                animCtrl:PlayRoar()
            end
            local headOrHrp = sourceChar:FindFirstChild("Head") or sourceChar:FindFirstChild("HumanoidRootPart")
            AudioController.PlayTitanRoar(titanId, headOrHrp :: BasePart?)
        else
            AudioController.PlayTitanRoar(titanId, nil)
        end

        local pulse = Instance.new("Part")
        pulse.Name = "RoarPulse"
        pulse.Shape = Enum.PartType.Ball
        pulse.Material = Enum.Material.Neon
        pulse.Color = Color3.fromRGB(255, 60, 0)
        pulse.Size = Vector3.new(4, 4, 4)
        pulse.Position = pos
        pulse.Anchored = true
        pulse.CanCollide = false
        pulse.CanQuery = false
        pulse.CanTouch = false
        pulse.Transparency = 0.3
        pulse.Parent = Workspace

        local tweenInfo = TweenInfo.new(0.65, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        local tween = TweenService:Create(pulse, tweenInfo, {
            Size = Vector3.new(targetRadius * 1.5, targetRadius * 1.5, targetRadius * 1.5),
            Transparency = 1,
        })
        tween:Play()
        tween.Completed:Connect(function()
            pulse:Destroy()
        end)
    end,

    BasicAttack = function(sourceChar, data)
        local pos = data.Position or Vector3.zero
        local look = data.LookVector or Vector3.new(0, 0, -1)
        local variant = data.Variant or "LeftSwipe"

        if sourceChar and sourceChar ~= LocalPlayer.Character then
            local animCtrl = getAnimController(sourceChar)
            if animCtrl then
                animCtrl:PlayBasicAttack(variant)
            end
            local hrp = sourceChar:FindFirstChild("HumanoidRootPart") :: BasePart?
            AudioController.PlayBasicAttackWhoosh(variant, hrp)
        end

        local swipeCFrame = CFrame.lookAt(pos, pos + look)
        local swipeInitialSize = Vector3.new(8, 2, 4)
        local swipeTargetSize = Vector3.new(16, 4, 7)

        if variant == "LeftSwipe" then
            swipeCFrame = swipeCFrame * CFrame.Angles(0, math.rad(-22), math.rad(15))
            swipeInitialSize = Vector3.new(10, 2.2, 4.5)
            swipeTargetSize = Vector3.new(18, 4.5, 8)
        elseif variant == "RightSwipe" then
            swipeCFrame = swipeCFrame * CFrame.Angles(0, math.rad(22), math.rad(-15))
            swipeInitialSize = Vector3.new(10, 2.2, 4.5)
            swipeTargetSize = Vector3.new(18, 4.5, 8)
        elseif variant == "DownwardSmash" then
            swipeCFrame = swipeCFrame * CFrame.Angles(math.rad(45), 0, 0)
            swipeInitialSize = Vector3.new(3.5, 12, 4)
            swipeTargetSize = Vector3.new(5.5, 20, 8)
        end

        local swipe = Instance.new("Part")
        swipe.Name = "AttackSwipe"
        swipe.Material = Enum.Material.Neon
        swipe.Color = if variant == "DownwardSmash" then Color3.fromRGB(255, 100, 30) else Color3.fromRGB(255, 170, 50)
        swipe.Size = swipeInitialSize
        swipe.CFrame = swipeCFrame
        swipe.Anchored = true
        swipe.CanCollide = false
        swipe.CanQuery = false
        swipe.CanTouch = false
        swipe.Transparency = 0.2
        swipe.Parent = Workspace

        local flash = Instance.new("Part")
        flash.Name = "ImpactFlash"
        flash.Shape = Enum.PartType.Ball
        flash.Material = Enum.Material.Neon
        flash.Color = if variant == "DownwardSmash" then Color3.fromRGB(255, 200, 80) else Color3.fromRGB(255, 230, 120)
        flash.Size = if variant == "DownwardSmash" then Vector3.new(5, 5, 5) else Vector3.new(3, 3, 3)
        flash.Position = pos
        flash.Anchored = true
        flash.CanCollide = false
        flash.CanQuery = false
        flash.CanTouch = false
        flash.Transparency = 0.2
        flash.Parent = Workspace

        local swipeTween = TweenService:Create(swipe, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = swipeTargetSize,
            Transparency = 1,
        })
        local flashTween = TweenService:Create(flash, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = if variant == "DownwardSmash" then Vector3.new(10, 10, 10) else Vector3.new(7, 7, 7),
            Transparency = 1,
        })
        swipeTween:Play()
        flashTween:Play()
        swipeTween.Completed:Connect(function() swipe:Destroy() end)
        flashTween.Completed:Connect(function() flash:Destroy() end)

        if sourceChar == LocalPlayer.Character then
            task.spawn(function()
                if variant == "LeftSwipe" then
                    Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(-1.2), math.rad(1.2), math.rad(0.6))
                    task.wait(0.04)
                    Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(0.6), math.rad(-0.6), math.rad(-0.3))
                elseif variant == "RightSwipe" then
                    Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(-1.2), math.rad(-1.2), math.rad(-0.6))
                    task.wait(0.04)
                    Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(0.6), math.rad(0.6), math.rad(0.3))
                elseif variant == "DownwardSmash" then
                    Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(-2.4), 0, 0)
                    task.wait(0.05)
                    Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(1.2), 0, 0)
                end
            end)
        end
    end,

    TailSweep = function(sourceChar, data)
        local pos = data.Position or Vector3.zero
        local look = data.LookVector or Vector3.new(0, 0, -1)

        if sourceChar and sourceChar ~= LocalPlayer.Character then
            local animCtrl = getAnimController(sourceChar)
            if animCtrl then
                animCtrl:PlayTailSweep()
            end
            local hrp = sourceChar:FindFirstChild("HumanoidRootPart") :: BasePart?
            AudioController.PlayBasicAttackWhoosh("LeftSwipe", hrp)
        end

        local sweepCFrame = CFrame.lookAt(pos, pos + look) * CFrame.Angles(0, math.rad(90), 0)
        local sweep = Instance.new("Part")
        sweep.Name = "TailSweepArc"
        sweep.Material = Enum.Material.Neon
        sweep.Color = Color3.fromRGB(255, 140, 40)
        sweep.Size = Vector3.new(18, 2.5, 6)
        sweep.CFrame = sweepCFrame
        sweep.Anchored = true
        sweep.CanCollide = false
        sweep.CanQuery = false
        sweep.CanTouch = false
        sweep.Transparency = 0.2
        sweep.Parent = Workspace

        local sweepTween = TweenService:Create(sweep, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(32, 5, 12),
            Transparency = 1,
        })
        sweepTween:Play()
        sweepTween.Completed:Connect(function() sweep:Destroy() end)

        if sourceChar == LocalPlayer.Character then
            task.spawn(function()
                Camera.CFrame = Camera.CFrame * CFrame.Angles(0, math.rad(-1.8), math.rad(0.8))
                task.wait(0.05)
                Camera.CFrame = Camera.CFrame * CFrame.Angles(0, math.rad(1.8), math.rad(-0.8))
            end)
        end
    end,

    HeavyStompWindup = function(sourceChar, data)
        local pos = data.Position or Vector3.zero
        local windUpTime = data.WindUp or 0.50
        local radius = data.Radius or 45

        if sourceChar then
            local animCtrl = getAnimController(sourceChar)
            if animCtrl then
                animCtrl:PlayHeavyStomp()
            end
            if sourceChar ~= LocalPlayer.Character then
                local hrp = sourceChar:FindFirstChild("HumanoidRootPart") :: BasePart?
                AudioController.PlayStompAnticipation(hrp)
            end
        end

        local windupRing = Instance.new("Part")
        windupRing.Name = "HeavyStompAnticipation"
        windupRing.Shape = Enum.PartType.Cylinder
        windupRing.Material = Enum.Material.Neon
        windupRing.Color = Color3.fromRGB(255, 90, 20)
        windupRing.Size = Vector3.new(0.4, radius * 1.8, radius * 1.8)
        windupRing.CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
        windupRing.Anchored = true
        windupRing.CanCollide = false
        windupRing.CanQuery = false
        windupRing.CanTouch = false
        windupRing.Transparency = 0.8
        windupRing.Parent = Workspace

        local tween = TweenService:Create(windupRing, TweenInfo.new(windUpTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = Vector3.new(0.8, 8, 8),
            Transparency = 0.05,
            Color = Color3.fromRGB(255, 220, 60),
        })
        tween:Play()
        tween.Completed:Connect(function() windupRing:Destroy() end)
    end,

    HeavyStomp = function(_sourceChar, data)
        local pos = data.Position or Vector3.zero
        local targetRadius = data.Radius or 45

        AudioController.PlayStompImpact(pos)

        local ring = Instance.new("Part")
        ring.Name = "HeavyStompBlast"
        ring.Shape = Enum.PartType.Cylinder
        ring.Material = Enum.Material.Neon
        ring.Color = Color3.fromRGB(255, 100, 20)
        ring.Size = Vector3.new(1.8, 8, 8)
        ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
        ring.Anchored = true
        ring.CanCollide = false
        ring.CanQuery = false
        ring.CanTouch = false
        ring.Transparency = 0.1
        ring.Parent = Workspace

        local outerWave = Instance.new("Part")
        outerWave.Name = "HeavyStompOuterWave"
        outerWave.Shape = Enum.PartType.Cylinder
        outerWave.Material = Enum.Material.Neon
        outerWave.Color = Color3.fromRGB(255, 200, 50)
        outerWave.Size = Vector3.new(0.8, 6, 6)
        outerWave.CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
        outerWave.Anchored = true
        outerWave.CanCollide = false
        outerWave.CanQuery = false
        outerWave.CanTouch = false
        outerWave.Transparency = 0.25
        outerWave.Parent = Workspace

        local t1 = TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(0.4, targetRadius * 2, targetRadius * 2),
            Transparency = 1,
        })
        local t2 = TweenService:Create(outerWave, TweenInfo.new(1.0, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = Vector3.new(0.3, targetRadius * 2.5, targetRadius * 2.5),
            Transparency = 1,
        })
        t1:Play()
        t2:Play()
        t1.Completed:Connect(function() ring:Destroy() end)
        t2.Completed:Connect(function() outerWave:Destroy() end)

        if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
            local dist = (LocalPlayer.Character.PrimaryPart.Position - pos).Magnitude
            local maxDist = targetRadius * 3.2
            if dist < maxDist then
                local falloff = math.clamp(1 - (dist / maxDist), 0, 1)
                local intensity = (falloff ^ 1.3) * 1.8
                task.spawn(function()
                    for step = 1, 8 do
                        local decay = (9 - step) / 8
                        Camera.CFrame = Camera.CFrame * CFrame.Angles(
                            math.rad(math.random(-16, 16) * 0.1 * intensity * decay),
                            math.rad(math.random(-16, 16) * 0.1 * intensity * decay),
                            math.rad(math.random(-10, 10) * 0.08 * intensity * decay)
                        )
                        task.wait(0.025)
                    end
                end)
            end
        end
    end,

    NeckStrike = function(sourceChar, data)
        local pos = data.Position or Vector3.zero
        local look = data.LookVector or Vector3.new(0, 0, -1)

        if sourceChar and sourceChar ~= LocalPlayer.Character then
            local animCtrl = getAnimController(sourceChar)
            if animCtrl then
                animCtrl:PlayNeckStrike()
            end
            local hrp = sourceChar:FindFirstChild("HumanoidRootPart") :: BasePart?
            AudioController.PlayBasicAttackWhoosh("DownwardSmash", hrp)
        end

        local crater = Instance.new("Part")
        crater.Name = "NeckPlungeCrater"
        crater.Shape = Enum.PartType.Cylinder
        crater.Material = Enum.Material.Neon
        crater.Color = Color3.fromRGB(255, 140, 20)
        crater.Size = Vector3.new(1.0, 4, 4)
        crater.CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
        crater.Anchored = true
        crater.CanCollide = false
        crater.CanQuery = false
        crater.CanTouch = false
        crater.Transparency = 0.1
        crater.Parent = Workspace

        local dustFlash = Instance.new("Part")
        dustFlash.Name = "NeckPlungeFlash"
        dustFlash.Shape = Enum.PartType.Ball
        dustFlash.Material = Enum.Material.Neon
        dustFlash.Color = Color3.fromRGB(255, 220, 100)
        dustFlash.Size = Vector3.new(6, 6, 6)
        dustFlash.Position = pos
        dustFlash.Anchored = true
        dustFlash.CanCollide = false
        dustFlash.CanQuery = false
        dustFlash.CanTouch = false
        dustFlash.Transparency = 0.2
        dustFlash.Parent = Workspace

        local ct = TweenService:Create(crater, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(0.3, 24, 24),
            Transparency = 1,
        })
        local ft = TweenService:Create(dustFlash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(16, 16, 16),
            Transparency = 1,
        })
        ct:Play()
        ft:Play()
        ct.Completed:Connect(function() crater:Destroy() end)
        ft.Completed:Connect(function() dustFlash:Destroy() end)

        if sourceChar == LocalPlayer.Character then
            task.spawn(function()
                Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(-3.0), 0, 0)
                task.wait(0.05)
                Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(1.5), 0, 0)
            end)
        end
    end,
}

TitanEffectRemote.OnClientEvent:Connect(function(effectType: string, sourceChar: Model, data: any)
    local handler = EffectHandlers[effectType]
    if handler then
        handler(sourceChar, data or {})
    end
end)

print("[TitanController] Client controller initialized for " .. currentTitanId .. ".")
