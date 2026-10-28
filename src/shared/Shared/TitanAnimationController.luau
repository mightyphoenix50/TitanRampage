--!strict
--[[
    TitanAnimationController.luau
    Modular Animation Controller for Titan Rampage.
    Responsibility:
    - Manages animation playback, tracks, and procedural joint attack choreography.
    - Supports Roblox AnimationTrack (via Animator) with clean fallback to expressive procedural Motor6D poses.
    - Implements 3 distinct Basic Attack variants:
        1. LeftSwipe (horizontal left-arm sweep across torso)
        2. RightSwipe (horizontal right-arm sweep across torso)
        3. DownwardSmash (two-handed overhead downward slam)
    - Implements Stomp sequence: Anticipation/Crouch -> Leg Raise -> Earth-shattering Impact -> Recovery.
    - Implements Roar sequence: Chest expansion -> Head tilt -> Arm flare -> Roar hold -> Recovery.
    - Ensures non-locking movement: only upper body/targeted limbs animate during attacks, legs continue WASD stride.
    - Loaded once per character lifecycle, cleans up on respawn.
--]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local TitanRegistry = require(SharedFolder:WaitForChild("TitanRegistry") :: ModuleScript)

export type AnimationController = {
    Character: Model,
    Humanoid: Humanoid,
    Animator: Animator,
    TitanId: string,
    Motors: { [string]: Motor6D },
    OrigC0: { [string]: CFrame },
    Tracks: { [string]: AnimationTrack },
    WalkConnection: RBXScriptConnection?,
    LastVariantIndex: number,
    IsAttacking: boolean,
    IsStomping: boolean,
    IsRoaring: boolean,
    PlayBasicAttack: (self: AnimationController, variantOverride: string?) -> (string, number),
    PlayTailSweep: (self: AnimationController) -> number,
    PlayHeavyStomp: (self: AnimationController) -> number,
    PlayNeckStrike: (self: AnimationController) -> number,
    PlayStomp: (self: AnimationController) -> number,
    PlayRoar: (self: AnimationController) -> number,
    PlayBrontaraRoar: (self: AnimationController) -> number,
    PlayAbility: (self: AnimationController, actionName: string, ...any) -> any,
    StopAll: (self: AnimationController) -> (),
    Destroy: (self: AnimationController) -> (),
}

local TitanAnimationController = {}
TitanAnimationController.__index = TitanAnimationController

local ATTACK_VARIANTS = { "LeftSwipe", "RightSwipe", "DownwardSmash" }

-- Helper function to tween a Motor6D C0 smoothly
local function tweenMotor(motor: Motor6D, targetC0: CFrame, duration: number, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
    local tweenInfo = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
    local t = TweenService:Create(motor, tweenInfo, { C0 = targetC0 })
    t:Play()
    return t
end

function TitanAnimationController.new(character: Model): AnimationController
    local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    local motors: { [string]: Motor6D } = {}
    local origC0: { [string]: CFrame } = {}

    for _, desc in ipairs(character:GetDescendants()) do
        if desc:IsA("Motor6D") then
            motors[desc.Name] = desc
            origC0[desc.Name] = desc.C0
        end
    end

    local tracks: { [string]: AnimationTrack } = {}

    local titanId = character:GetAttribute("TitanId") or "Ravager"
    local titanDef = TitanRegistry.Get(titanId) or TitanRegistry.Get("Ravager")

    -- Pre-load any configured Animation assets for this Titan
    if titanDef and titanDef.Abilities then
        for actionName, ability in pairs(titanDef.Abilities) do
            if ability.AnimationIds then
                for variantName, animId in pairs(ability.AnimationIds) do
                    if animId and animId ~= "rbxassetid://0" and animId ~= "" then
                        pcall(function()
                            local anim = Instance.new("Animation")
                            anim.AnimationId = animId
                            local track = animator:LoadAnimation(anim)
                            track.Priority = Enum.AnimationPriority.Action4
                            tracks[variantName] = track
                        end)
                    end
                end
            end
        end
    end

    local walkConn: RBXScriptConnection? = nil

    -- Shared with the procedural walk loop below and exposed as self.AnimState so ability methods can pause it
    local animState = {
        IsAttacking = false,
        IsStomping = false,
        IsRoaring = false,
        IsTailSweeping = false,
        IsNeckStriking = false,
    }

    if titanId == "Brontara" then
        local RunService = game:GetService("RunService")
        local stridePhase = 0
        local idlePhase = 0
        local lastYaw = 0
        local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if rootPart then lastYaw = select(2, rootPart.CFrame:ToEulerAnglesYXZ()) end

        local leftShoulder = motors["Left Shoulder"]
        local rightShoulder = motors["Right Shoulder"]
        local leftHip = motors["Left Hip"]
        local rightHip = motors["Right Hip"]
        local neckBase = motors["NeckBaseJoint"]
        local neckMid = motors["NeckMidJoint"]
        local tailBase = motors["TailBaseJoint"]
        local tailMid = motors["TailMidJoint"]
        local tailTip = motors["TailTipJoint"]

        local origLS = origC0["Left Shoulder"]
        local origRS = origC0["Right Shoulder"]
        local origLH = origC0["Left Hip"]
        local origRH = origC0["Right Hip"]
        local origNB = origC0["NeckBaseJoint"]
        local origNM = origC0["NeckMidJoint"]
        local origTB = origC0["TailBaseJoint"]
        local origTM = origC0["TailMidJoint"]
        local origTT = origC0["TailTipJoint"]

        walkConn = RunService.RenderStepped:Connect(function(dt)
            if not character.Parent or humanoid.Health <= 0 then
                if walkConn then walkConn:Disconnect() end
                return
            end

            local moveMag = humanoid.MoveDirection.Magnitude
            local isMoving = moveMag > 0.05

            -- Calculate turn rate from RootPart yaw delta
            local currentYaw = lastYaw
            local turnYaw = 0
            if rootPart and rootPart.Parent then
                currentYaw = select(2, rootPart.CFrame:ToEulerAnglesYXZ())
                local deltaYaw = currentYaw - lastYaw
                if deltaYaw > math.pi then
                    deltaYaw -= 2 * math.pi
                elseif deltaYaw < -math.pi then
                    deltaYaw += 2 * math.pi
                end
                turnYaw = math.clamp(deltaYaw / math.max(0.001, dt), -3, 3)
                lastYaw = currentYaw
            end

            if isMoving then
                -- Quadruped stride (diagonal gait: FL+RR forward while FR+RL backward)
                local speed = humanoid.WalkSpeed or 20
                local strideRate = speed * 0.28
                stridePhase = (stridePhase + dt * strideRate) % (2 * math.pi)

                local legAngle = math.sin(stridePhase) * math.rad(14)
                local neckBob = math.sin(stridePhase * 2) * math.rad(1.5)
                local neckTurnAngle = math.clamp(turnYaw * 0.04, -math.rad(8), math.rad(8))
                local tailSway = math.sin(stridePhase - 1.2) * math.rad(4)
                local tailTurnAngle = -math.clamp(turnYaw * 0.06, -math.rad(12), math.rad(12))

                if not animState.IsStomping then
                    if leftShoulder and origLS then leftShoulder.C0 = origLS * CFrame.Angles(legAngle, 0, 0) end
                    if rightShoulder and origRS then rightShoulder.C0 = origRS * CFrame.Angles(-legAngle, 0, 0) end
                    if leftHip and origLH then leftHip.C0 = origLH * CFrame.Angles(-legAngle, 0, 0) end
                    if rightHip and origRH then rightHip.C0 = origRH * CFrame.Angles(legAngle, 0, 0) end
                end

                if not animState.IsNeckStriking and not animState.IsRoaring and not animState.IsStomping then
                    if neckBase and origNB then neckBase.C0 = origNB * CFrame.Angles(neckBob, neckTurnAngle, 0) end
                    if neckMid and origNM then neckMid.C0 = origNM * CFrame.Angles(neckBob * 0.6, neckTurnAngle * 0.7, 0) end
                end

                if not animState.IsTailSweeping and not animState.IsStomping then
                    if tailBase and origTB then tailBase.C0 = origTB * CFrame.Angles(0, tailSway + tailTurnAngle, 0) end
                    if tailMid and origTM then tailMid.C0 = origTM * CFrame.Angles(0, tailSway * 1.3 + tailTurnAngle * 1.2, 0) end
                    if tailTip and origTT then tailTip.C0 = origTT * CFrame.Angles(0, tailSway * 1.6 + tailTurnAngle * 1.4, 0) end
                end
            else
                -- Idle resting stance with subtle breathing sway in neck and tail
                idlePhase = (idlePhase + dt * 1.2) % (2 * math.pi)
                local breathAngle = math.sin(idlePhase) * math.rad(1.2)
                local tailIdle = math.sin(idlePhase * 0.7) * math.rad(1.8)

                if not animState.IsStomping then
                    local lerpAlpha = math.clamp(dt * 8, 0, 1)
                    if leftShoulder and origLS then leftShoulder.C0 = leftShoulder.C0:Lerp(origLS, lerpAlpha) end
                    if rightShoulder and origRS then rightShoulder.C0 = rightShoulder.C0:Lerp(origRS, lerpAlpha) end
                    if leftHip and origLH then leftHip.C0 = leftHip.C0:Lerp(origLH, lerpAlpha) end
                    if rightHip and origRH then rightHip.C0 = rightHip.C0:Lerp(origRH, lerpAlpha) end
                end

                if not animState.IsNeckStriking and not animState.IsRoaring and not animState.IsStomping then
                    if neckBase and origNB then neckBase.C0 = origNB * CFrame.Angles(breathAngle, 0, 0) end
                    if neckMid and origNM then neckMid.C0 = origNM * CFrame.Angles(breathAngle * 0.7, 0, 0) end
                end

                if not animState.IsTailSweeping and not animState.IsStomping then
                    if tailBase and origTB then tailBase.C0 = origTB * CFrame.Angles(0, tailIdle, 0) end
                    if tailMid and origTM then tailMid.C0 = origTM * CFrame.Angles(0, tailIdle * 1.2, 0) end
                    if tailTip and origTT then tailTip.C0 = origTT * CFrame.Angles(0, tailIdle * 1.5, 0) end
                end
            end
        end)
    end

    local self = setmetatable({
        Character = character,
        Humanoid = humanoid,
        Animator = animator,
        TitanId = titanId,
        Motors = motors,
        OrigC0 = origC0,
        Tracks = tracks,
        WalkConnection = walkConn,
        AnimState = animState,
        LastVariantIndex = 0,
        IsAttacking = false,
        IsStomping = false,
        IsRoaring = false,
    }, TitanAnimationController)

    return (self :: any) :: AnimationController
end

--[=[
    Plays one of 3 Basic Attack animation variations.
    Returns (variantUsed: string, duration: number).
]=]
function TitanAnimationController:PlayBasicAttack(variantOverride: string?): (string, number)
    if self.TitanId == "Brontara" then return "None", 0 end
    local variant = variantOverride
    if not variant then
        -- Cycle through the 3 variants
        self.LastVariantIndex = (self.LastVariantIndex % #ATTACK_VARIANTS) + 1
        variant = ATTACK_VARIANTS[self.LastVariantIndex]
    end

    local duration = 0.42
    self.IsAttacking = true

    -- If a custom AnimationTrack exists, play it
    local track = self.Tracks[variant]
    if track then track:Play(0.06) end

    -- Procedural Motor6D Joint Animation (Works in all conditions)
    local rootJoint = self.Motors["RootJoint"]
    local neck = self.Motors["Neck"]
    local rightShoulder = self.Motors["Right Shoulder"]
    local leftShoulder = self.Motors["Left Shoulder"]

    local origRoot = self.OrigC0["RootJoint"] or CFrame.new()
    local origNeck = self.OrigC0["Neck"] or CFrame.new()
    local origRight = self.OrigC0["Right Shoulder"] or CFrame.new()
    local origLeft = self.OrigC0["Left Shoulder"] or CFrame.new()

    task.spawn(function()
        if variant == "LeftSwipe" then
            -- ATTACK 1: LEFT SWIPE (Retargeted 0.42s total)
            -- Phase 1: Anticipation / Coil (0.09s) - Torso twists right, Left Arm winds back
            if leftShoulder and origLeft then
                tweenMotor(
                    leftShoulder,
                    origLeft * CFrame.Angles(math.rad(25), math.rad(45), math.rad(-30)),
                    0.09,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                )
            end
            if rootJoint and origRoot then
                tweenMotor(rootJoint, origRoot * CFrame.Angles(0, math.rad(-15), 0), 0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            if neck and origNeck then
                tweenMotor(neck, origNeck * CFrame.Angles(0, math.rad(12), 0), 0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            task.wait(0.09)

            -- Phase 2: Powerful Horizontal Sweep & Strike (0.14s) - Left Arm swings across chest
            if leftShoulder and origLeft then
                tweenMotor(
                    leftShoulder,
                    origLeft * CFrame.Angles(math.rad(95), math.rad(-75), math.rad(40)),
                    0.14,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.In
                )
            end
            if rootJoint and origRoot then
                tweenMotor(
                    rootJoint,
                    origRoot * CFrame.Angles(math.rad(6), math.rad(30), 0),
                    0.14,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.In
                )
            end
            if neck and origNeck then
                tweenMotor(neck, origNeck * CFrame.Angles(0, math.rad(-15), 0), 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            task.wait(0.14)

            -- Phase 3: Recovery / Return (0.19s)
            if leftShoulder and origLeft then tweenMotor(leftShoulder, origLeft, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
            if rootJoint and origRoot then tweenMotor(rootJoint, origRoot, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
            if neck and origNeck then tweenMotor(neck, origNeck, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
            task.wait(0.19)
        elseif variant == "RightSwipe" then
            -- ATTACK 2: RIGHT SWIPE (Retargeted 0.42s total)
            -- Phase 1: Anticipation / Coil (0.09s) - Torso twists left, Right Arm winds back
            if rightShoulder and origRight then
                tweenMotor(
                    rightShoulder,
                    origRight * CFrame.Angles(math.rad(25), math.rad(-45), math.rad(30)),
                    0.09,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                )
            end
            if rootJoint and origRoot then
                tweenMotor(rootJoint, origRoot * CFrame.Angles(0, math.rad(15), 0), 0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            if neck and origNeck then
                tweenMotor(neck, origNeck * CFrame.Angles(0, math.rad(-12), 0), 0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            task.wait(0.09)

            -- Phase 2: Powerful Horizontal Sweep & Strike (0.14s) - Right Arm swings across chest
            if rightShoulder and origRight then
                tweenMotor(
                    rightShoulder,
                    origRight * CFrame.Angles(math.rad(95), math.rad(75), math.rad(-40)),
                    0.14,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.In
                )
            end
            if rootJoint and origRoot then
                tweenMotor(
                    rootJoint,
                    origRoot * CFrame.Angles(math.rad(6), math.rad(-30), 0),
                    0.14,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.In
                )
            end
            if neck and origNeck then
                tweenMotor(neck, origNeck * CFrame.Angles(0, math.rad(15), 0), 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            task.wait(0.14)

            -- Phase 3: Recovery / Return (0.19s)
            if rightShoulder and origRight then
                tweenMotor(rightShoulder, origRight, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            if rootJoint and origRoot then tweenMotor(rootJoint, origRoot, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
            if neck and origNeck then tweenMotor(neck, origNeck, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
            task.wait(0.19)
        else
            -- ATTACK 3: DOWNWARD SMASH (Two-Handed Overhead Slam - Retargeted 0.42s total)
            -- Phase 1: Overhead Windup (0.09s) - Both arms raise high overhead, torso arches back
            if rightShoulder and origRight then
                tweenMotor(
                    rightShoulder,
                    origRight * CFrame.Angles(math.rad(130), math.rad(-20), math.rad(25)),
                    0.09,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                )
            end
            if leftShoulder and origLeft then
                tweenMotor(
                    leftShoulder,
                    origLeft * CFrame.Angles(math.rad(130), math.rad(20), math.rad(-25)),
                    0.09,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                )
            end
            if rootJoint and origRoot then
                tweenMotor(rootJoint, origRoot * CFrame.Angles(math.rad(-14), 0, 0), 0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            task.wait(0.09)

            -- Phase 2: Downward Hammer Impact (0.14s) - Both arms slam down with forward torso crunch
            if rightShoulder and origRight then
                tweenMotor(
                    rightShoulder,
                    origRight * CFrame.Angles(math.rad(-35), math.rad(-10), 0),
                    0.14,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.In
                )
            end
            if leftShoulder and origLeft then
                tweenMotor(
                    leftShoulder,
                    origLeft * CFrame.Angles(math.rad(-35), math.rad(10), 0),
                    0.14,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.In
                )
            end
            if rootJoint and origRoot then
                tweenMotor(rootJoint, origRoot * CFrame.Angles(math.rad(22), 0, 0), 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            task.wait(0.14)

            -- Phase 3: Recovery / Return (0.19s)
            if rightShoulder and origRight then
                tweenMotor(rightShoulder, origRight, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            if leftShoulder and origLeft then tweenMotor(leftShoulder, origLeft, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
            if rootJoint and origRoot then tweenMotor(rootJoint, origRoot, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
            task.wait(0.19)
        end

        self.IsAttacking = false
    end)

    return variant, duration
end

--[=[
    Plays the dedicated Stomp animation sequence.
    Synchronized with the 0.35s server windup delay and impact moment.
]=]
function TitanAnimationController:PlayStomp(): number
    if self.TitanId == "Brontara" then return 0 end
    local duration = 0.75
    self.IsStomping = true

    local track = self.Tracks["Stomp"]
    if track then track:Play(0.1) end

    local rootJoint = self.Motors["RootJoint"]
    local rightHip = self.Motors["Right Hip"]
    local rightShoulder = self.Motors["Right Shoulder"]
    local leftShoulder = self.Motors["Left Shoulder"]

    local origRoot = self.OrigC0["RootJoint"] or CFrame.new()
    local origHip = self.OrigC0["Right Hip"] or CFrame.new()
    local origRight = self.OrigC0["Right Shoulder"] or CFrame.new()
    local origLeft = self.OrigC0["Left Shoulder"] or CFrame.new()

    task.spawn(function()
        -- Phase 1: Anticipation & Crouch (0.15s)
        if rootJoint and origRoot then
            tweenMotor(
                rootJoint,
                origRoot * CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(-10), 0, 0),
                0.15,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            )
        end
        if rightHip and origHip then
            tweenMotor(rightHip, origHip * CFrame.Angles(math.rad(25), 0, 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if rightShoulder and origRight then
            tweenMotor(
                rightShoulder,
                origRight * CFrame.Angles(math.rad(-25), 0, math.rad(20)),
                0.15,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            )
        end
        if leftShoulder and origLeft then
            tweenMotor(
                leftShoulder,
                origLeft * CFrame.Angles(math.rad(-25), 0, math.rad(-20)),
                0.15,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            )
        end
        task.wait(0.15)

        -- Phase 2: Leg Raise (0.20s) - Total elapsed = 0.35s (exact match to server windup!)
        if rightHip and origHip then
            tweenMotor(
                rightHip,
                origHip * CFrame.new(0, 2.5, -1.5) * CFrame.Angles(math.rad(65), 0, 0),
                0.20,
                Enum.EasingStyle.Back,
                Enum.EasingDirection.Out
            )
        end
        if rootJoint and origRoot then
            tweenMotor(
                rootJoint,
                origRoot * CFrame.new(0, 0.8, 0) * CFrame.Angles(math.rad(-15), 0, 0),
                0.20,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            )
        end
        task.wait(0.20)

        -- Phase 3: Thunderous Ground Slam Impact (0.10s)
        if rightHip and origHip then
            tweenMotor(
                rightHip,
                origHip * CFrame.new(0, -0.6, 0.5) * CFrame.Angles(math.rad(-15), 0, 0),
                0.10,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.In
            )
        end
        if rootJoint and origRoot then
            tweenMotor(
                rootJoint,
                origRoot * CFrame.new(0, -1.8, 0) * CFrame.Angles(math.rad(18), 0, 0),
                0.10,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.In
            )
        end
        if rightShoulder and origRight then
            tweenMotor(
                rightShoulder,
                origRight * CFrame.Angles(math.rad(45), 0, math.rad(35)),
                0.10,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.In
            )
        end
        if leftShoulder and origLeft then
            tweenMotor(
                leftShoulder,
                origLeft * CFrame.Angles(math.rad(45), 0, math.rad(-35)),
                0.10,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.In
            )
        end
        task.wait(0.10)

        -- Phase 4: Recovery (0.30s)
        if rightHip and origHip then tweenMotor(rightHip, origHip, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if rootJoint and origRoot then tweenMotor(rootJoint, origRoot, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if rightShoulder and origRight then tweenMotor(rightShoulder, origRight, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if leftShoulder and origLeft then tweenMotor(leftShoulder, origLeft, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        task.wait(0.30)

        self.IsStomping = false
    end)

    return duration
end

--[=[
    Plays the thunderous Roar animation sequence.
    Sequence: Chest expands -> Head tilts up -> Arms spread wide -> Roar hold -> Recovery.
]=]
function TitanAnimationController:PlayRoar(): number
    if self.TitanId == "Brontara" then return self:PlayBrontaraRoar() end
    local duration = 1.00
    self.IsRoaring = true

    local track = self.Tracks["Roar"]
    if track then track:Play(0.15) end

    local rootJoint = self.Motors["RootJoint"]
    local neck = self.Motors["Neck"]
    local rightShoulder = self.Motors["Right Shoulder"]
    local leftShoulder = self.Motors["Left Shoulder"]

    local origRoot = self.OrigC0["RootJoint"] or CFrame.new()
    local origNeck = self.OrigC0["Neck"] or CFrame.new()
    local origRight = self.OrigC0["Right Shoulder"] or CFrame.new()
    local origLeft = self.OrigC0["Left Shoulder"] or CFrame.new()

    task.spawn(function()
        -- Phase 1: Inhale, Chest Expansion & Head Tilt (0.30s)
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot * CFrame.Angles(math.rad(-18), 0, 0), 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if neck and origNeck then
            tweenMotor(neck, origNeck * CFrame.Angles(math.rad(35), 0, 0), 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if rightShoulder and origRight then
            tweenMotor(
                rightShoulder,
                origRight * CFrame.Angles(math.rad(30), math.rad(65), math.rad(55)),
                0.30,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            )
        end
        if leftShoulder and origLeft then
            tweenMotor(
                leftShoulder,
                origLeft * CFrame.Angles(math.rad(30), math.rad(-65), math.rad(-55)),
                0.30,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            )
        end
        task.wait(0.30)

        -- Phase 2: Roar Tremor / Hold (0.45s)
        for _ = 1, 4 do
            if neck and origNeck then
                neck.C0 = origNeck * CFrame.Angles(math.rad(35 + math.random(-2, 2)), math.rad(math.random(-2, 2)), 0)
            end
            task.wait(0.10)
        end

        -- Phase 3: Recovery / Return to Stance (0.25s)
        if rootJoint and origRoot then tweenMotor(rootJoint, origRoot, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if neck and origNeck then tweenMotor(neck, origNeck, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if rightShoulder and origRight then tweenMotor(rightShoulder, origRight, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if leftShoulder and origLeft then tweenMotor(leftShoulder, origLeft, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        task.wait(0.25)

        if rootJoint and origRoot then rootJoint.C0 = origRoot end
        if neck and origNeck then neck.C0 = origNeck end
        if rightShoulder and origRight then rightShoulder.C0 = origRight end
        if leftShoulder and origLeft then leftShoulder.C0 = origLeft end

        self.IsRoaring = false
    end)

    return duration
end

--[=[
    Plays Brontara's Tail Sweep procedural animation.
    Sequence: Tail coils left (0.15s) -> Violent horizontal sweep right (0.22s) -> Recovery (0.28s). Total: 0.65s.
]=]
function TitanAnimationController:PlayTailSweep(): number
    if self.TitanId ~= "Brontara" then return 0 end
    local duration = 0.65
    self.IsAttacking = true
    if (self :: any).AnimState then (self :: any).AnimState.IsTailSweeping = true end

    local track = self.Tracks["TailSweep"]
    if track then track:Play(0.08) end

    local rootJoint = self.Motors["RootJoint"]
    local tailBase = self.Motors["TailBaseJoint"]
    local tailMid = self.Motors["TailMidJoint"]
    local tailTip = self.Motors["TailTipJoint"]
    local neckBase = self.Motors["NeckBaseJoint"]

    local origRoot = self.OrigC0["RootJoint"] or CFrame.new()
    local origTB = self.OrigC0["TailBaseJoint"] or CFrame.new()
    local origTM = self.OrigC0["TailMidJoint"] or CFrame.new()
    local origTT = self.OrigC0["TailTipJoint"] or CFrame.new()
    local origNB = self.OrigC0["NeckBaseJoint"] or CFrame.new()

    task.spawn(function()
        -- Phase 1: Coil / Windup (0.15s) - Tail coils to the left, body counter-twists
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot * CFrame.Angles(0, math.rad(-14), 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if tailBase and origTB then
            tweenMotor(tailBase, origTB * CFrame.Angles(0, math.rad(28), 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if tailMid and origTM then
            tweenMotor(tailMid, origTM * CFrame.Angles(0, math.rad(34), 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if tailTip and origTT then
            tweenMotor(tailTip, origTT * CFrame.Angles(0, math.rad(40), 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if neckBase and origNB then
            tweenMotor(neckBase, origNB * CFrame.Angles(0, math.rad(-10), 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        task.wait(0.15)

        -- Phase 2: Violent Horizontal Sweep (0.22s) - Massive whip across right flank
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot * CFrame.Angles(0, math.rad(22), 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if tailBase and origTB then
            tweenMotor(tailBase, origTB * CFrame.Angles(0, math.rad(-48), 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if tailMid and origTM then
            tweenMotor(tailMid, origTM * CFrame.Angles(0, math.rad(-58), 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if tailTip and origTT then
            tweenMotor(tailTip, origTT * CFrame.Angles(0, math.rad(-68), 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if neckBase and origNB then
            tweenMotor(neckBase, origNB * CFrame.Angles(0, math.rad(14), 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        task.wait(0.22)

        -- Phase 3: Recovery (0.28s) - Smoothly return to exact rest pose
        if rootJoint and origRoot then tweenMotor(rootJoint, origRoot, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if tailBase and origTB then tweenMotor(tailBase, origTB, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if tailMid and origTM then tweenMotor(tailMid, origTM, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if tailTip and origTT then tweenMotor(tailTip, origTT, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if neckBase and origNB then tweenMotor(neckBase, origNB, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        task.wait(0.28)

        -- Zero drift insurance
        if rootJoint and origRoot then rootJoint.C0 = origRoot end
        if tailBase and origTB then tailBase.C0 = origTB end
        if tailMid and origTM then tailMid.C0 = origTM end
        if tailTip and origTT then tailTip.C0 = origTT end
        if neckBase and origNB then neckBase.C0 = origNB end

        self.IsAttacking = false
        if (self :: any).AnimState then (self :: any).AnimState.IsTailSweeping = false end
    end)

    return duration
end

--[=[
    Plays Brontara's Heavy Stomp procedural animation.
    Sequence: Colossal rear-up on hind legs (0.50s windup) -> Seismic pillar slam (0.15s) -> Heavy recovery (0.35s). Total: 1.00s.
]=]
function TitanAnimationController:PlayHeavyStomp(): number
    if self.TitanId ~= "Brontara" then return 0 end
    local duration = 1.00
    self.IsStomping = true
    if (self :: any).AnimState then (self :: any).AnimState.IsStomping = true end

    local track = self.Tracks["HeavyStomp"]
    if track then track:Play(0.1) end

    local rootJoint = self.Motors["RootJoint"]
    local leftShoulder = self.Motors["Left Shoulder"]
    local rightShoulder = self.Motors["Right Shoulder"]
    local leftHip = self.Motors["Left Hip"]
    local rightHip = self.Motors["Right Hip"]
    local neckBase = self.Motors["NeckBaseJoint"]
    local tailBase = self.Motors["TailBaseJoint"]

    local origRoot = self.OrigC0["RootJoint"] or CFrame.new()
    local origLS = self.OrigC0["Left Shoulder"] or CFrame.new()
    local origRS = self.OrigC0["Right Shoulder"] or CFrame.new()
    local origLH = self.OrigC0["Left Hip"] or CFrame.new()
    local origRH = self.OrigC0["Right Hip"] or CFrame.new()
    local origNB = self.OrigC0["NeckBaseJoint"] or CFrame.new()
    local origTB = self.OrigC0["TailBaseJoint"] or CFrame.new()

    task.spawn(function()
        -- Phase 1: Colossal Rear-Up (0.50s) - Exact match to server 0.50s windup
        if rootJoint and origRoot then
            tweenMotor(
                rootJoint,
                origRoot * CFrame.new(0, 3.5, -0.8) * CFrame.Angles(math.rad(-28), 0, 0),
                0.50,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            )
        end
        if leftShoulder and origLS then
            tweenMotor(
                leftShoulder,
                origLS * CFrame.Angles(math.rad(42), 0, math.rad(-12)),
                0.50,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            )
        end
        if rightShoulder and origRS then
            tweenMotor(
                rightShoulder,
                origRS * CFrame.Angles(math.rad(42), 0, math.rad(12)),
                0.50,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            )
        end
        if leftHip and origLH then
            tweenMotor(leftHip, origLH * CFrame.Angles(math.rad(18), 0, 0), 0.50, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if rightHip and origRH then
            tweenMotor(rightHip, origRH * CFrame.Angles(math.rad(18), 0, 0), 0.50, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if neckBase and origNB then
            tweenMotor(neckBase, origNB * CFrame.Angles(math.rad(-18), 0, 0), 0.50, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if tailBase and origTB then
            tweenMotor(tailBase, origTB * CFrame.Angles(math.rad(-16), 0, 0), 0.50, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        task.wait(0.50)

        -- Phase 2: Downward Seismic Pillar Slam (0.15s) - Exact impact moment
        if rootJoint and origRoot then
            tweenMotor(
                rootJoint,
                origRoot * CFrame.new(0, -1.8, 0.4) * CFrame.Angles(math.rad(14), 0, 0),
                0.15,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.In
            )
        end
        if leftShoulder and origLS then
            tweenMotor(leftShoulder, origLS * CFrame.Angles(math.rad(-18), 0, 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if rightShoulder and origRS then
            tweenMotor(rightShoulder, origRS * CFrame.Angles(math.rad(-18), 0, 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if leftHip and origLH then
            tweenMotor(leftHip, origLH * CFrame.Angles(math.rad(-10), 0, 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if rightHip and origRH then
            tweenMotor(rightHip, origRH * CFrame.Angles(math.rad(-10), 0, 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if neckBase and origNB then
            tweenMotor(neckBase, origNB * CFrame.Angles(math.rad(22), 0, 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if tailBase and origTB then
            tweenMotor(tailBase, origTB * CFrame.Angles(math.rad(12), 0, 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        task.wait(0.15)

        -- Phase 3: Heavy Recovery (0.35s)
        if rootJoint and origRoot then tweenMotor(rootJoint, origRoot, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if leftShoulder and origLS then tweenMotor(leftShoulder, origLS, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if rightShoulder and origRS then tweenMotor(rightShoulder, origRS, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if leftHip and origLH then tweenMotor(leftHip, origLH, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if rightHip and origRH then tweenMotor(rightHip, origRH, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if neckBase and origNB then tweenMotor(neckBase, origNB, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if tailBase and origTB then tweenMotor(tailBase, origTB, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        task.wait(0.35)

        -- Exact rest pose restoration
        if rootJoint and origRoot then rootJoint.C0 = origRoot end
        if leftShoulder and origLS then leftShoulder.C0 = origLS end
        if rightShoulder and origRS then rightShoulder.C0 = origRS end
        if leftHip and origLH then leftHip.C0 = origLH end
        if rightHip and origRH then rightHip.C0 = origRH end
        if neckBase and origNB then neckBase.C0 = origNB end
        if tailBase and origTB then tailBase.C0 = origTB end

        self.IsStomping = false
        if (self :: any).AnimState then (self :: any).AnimState.IsStomping = false end
    end)

    return duration
end

--[=[
    Plays Brontara's Neck Strike procedural animation.
    Sequence: Neck arch & drawback (0.22s) -> Violent downward hammer plunge (0.18s) -> Recovery (0.30s). Total: 0.70s.
]=]
function TitanAnimationController:PlayNeckStrike(): number
    if self.TitanId ~= "Brontara" then return 0 end
    local duration = 0.70
    self.IsAttacking = true
    if (self :: any).AnimState then (self :: any).AnimState.IsNeckStriking = true end

    local track = self.Tracks["NeckStrike"]
    if track then track:Play(0.08) end

    local rootJoint = self.Motors["RootJoint"]
    local neckBase = self.Motors["NeckBaseJoint"]
    local neckMid = self.Motors["NeckMidJoint"]
    local neckUpper = self.Motors["NeckUpperJoint"]
    local neck = self.Motors["Neck"]

    local origRoot = self.OrigC0["RootJoint"] or CFrame.new()
    local origNB = self.OrigC0["NeckBaseJoint"] or CFrame.new()
    local origNM = self.OrigC0["NeckMidJoint"] or CFrame.new()
    local origNU = self.OrigC0["NeckUpperJoint"] or CFrame.new()
    local origN = self.OrigC0["Neck"] or CFrame.new()

    task.spawn(function()
        -- Phase 1: High Neck Coil / Drawback (0.22s)
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot * CFrame.Angles(math.rad(-10), 0, 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if neckBase and origNB then
            tweenMotor(neckBase, origNB * CFrame.Angles(math.rad(-25), 0, 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if neckMid and origNM then
            tweenMotor(neckMid, origNM * CFrame.Angles(math.rad(-30), 0, 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if neckUpper and origNU then
            tweenMotor(neckUpper, origNU * CFrame.Angles(math.rad(-25), 0, 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if neck and origN then
            tweenMotor(neck, origN * CFrame.Angles(math.rad(-18), 0, 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        task.wait(0.22)

        -- Phase 2: Downward Hammer Plunge (0.18s) - Deep forward siege strike
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot * CFrame.Angles(math.rad(16), 0, 0), 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if neckBase and origNB then
            tweenMotor(neckBase, origNB * CFrame.Angles(math.rad(38), 0, 0), 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if neckMid and origNM then
            tweenMotor(neckMid, origNM * CFrame.Angles(math.rad(44), 0, 0), 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if neckUpper and origNU then
            tweenMotor(neckUpper, origNU * CFrame.Angles(math.rad(38), 0, 0), 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if neck and origN then
            tweenMotor(neck, origN * CFrame.Angles(math.rad(28), 0, 0), 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        task.wait(0.18)

        -- Phase 3: Recovery (0.30s)
        if rootJoint and origRoot then tweenMotor(rootJoint, origRoot, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if neckBase and origNB then tweenMotor(neckBase, origNB, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if neckMid and origNM then tweenMotor(neckMid, origNM, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if neckUpper and origNU then tweenMotor(neckUpper, origNU, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if neck and origN then tweenMotor(neck, origN, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        task.wait(0.30)

        -- Exact rest pose restoration
        if rootJoint and origRoot then rootJoint.C0 = origRoot end
        if neckBase and origNB then neckBase.C0 = origNB end
        if neckMid and origNM then neckMid.C0 = origNM end
        if neckUpper and origNU then neckUpper.C0 = origNU end
        if neck and origN then neck.C0 = origN end

        self.IsAttacking = false
        if (self :: any).AnimState then (self :: any).AnimState.IsNeckStriking = false end
    end)

    return duration
end

--[=[
    Plays Brontara's Roar procedural animation.
    Sequence: Skyward neck extension (0.35s) -> Seismic tremor rumble (0.45s) -> Recovery (0.30s). Total: 1.10s.
]=]
function TitanAnimationController:PlayBrontaraRoar(): number
    local duration = 1.10
    self.IsRoaring = true
    if (self :: any).AnimState then (self :: any).AnimState.IsRoaring = true end

    local track = self.Tracks["Roar"]
    if track then track:Play(0.15) end

    local rootJoint = self.Motors["RootJoint"]
    local neckBase = self.Motors["NeckBaseJoint"]
    local neckMid = self.Motors["NeckMidJoint"]
    local neckUpper = self.Motors["NeckUpperJoint"]
    local neck = self.Motors["Neck"]
    local leftShoulder = self.Motors["Left Shoulder"]
    local rightShoulder = self.Motors["Right Shoulder"]

    local origRoot = self.OrigC0["RootJoint"] or CFrame.new()
    local origNB = self.OrigC0["NeckBaseJoint"] or CFrame.new()
    local origNM = self.OrigC0["NeckMidJoint"] or CFrame.new()
    local origNU = self.OrigC0["NeckUpperJoint"] or CFrame.new()
    local origN = self.OrigC0["Neck"] or CFrame.new()
    local origLS = self.OrigC0["Left Shoulder"] or CFrame.new()
    local origRS = self.OrigC0["Right Shoulder"] or CFrame.new()

    task.spawn(function()
        -- Phase 1: Inhale & Skyward Neck Extension (0.35s)
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot * CFrame.Angles(math.rad(-14), 0, 0), 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if neckBase and origNB then
            tweenMotor(neckBase, origNB * CFrame.Angles(math.rad(-35), 0, 0), 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if neckMid and origNM then
            tweenMotor(neckMid, origNM * CFrame.Angles(math.rad(-30), 0, 0), 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if neckUpper and origNU then
            tweenMotor(neckUpper, origNU * CFrame.Angles(math.rad(-25), 0, 0), 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if neck and origN then
            tweenMotor(neck, origN * CFrame.Angles(math.rad(-28), 0, 0), 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if leftShoulder and origLS then
            tweenMotor(
                leftShoulder,
                origLS * CFrame.Angles(math.rad(-8), 0, math.rad(-10)),
                0.35,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            )
        end
        if rightShoulder and origRS then
            tweenMotor(
                rightShoulder,
                origRS * CFrame.Angles(math.rad(-8), 0, math.rad(10)),
                0.35,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            )
        end
        task.wait(0.35)

        -- Phase 2: Seismic Tremor / Bellow (0.45s)
        for _ = 1, 4 do
            if neck and origN then neck.C0 = origN * CFrame.Angles(math.rad(-28 + math.random(-2, 2)), math.rad(math.random(-2, 2)), 0) end
            if neckUpper and origNU then
                neckUpper.C0 = origNU * CFrame.Angles(math.rad(-25 + math.random(-2, 2)), math.rad(math.random(-2, 2)), 0)
            end
            task.wait(0.10)
        end

        -- Phase 3: Recovery / Return to Stance (0.30s)
        if rootJoint and origRoot then tweenMotor(rootJoint, origRoot, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if neckBase and origNB then tweenMotor(neckBase, origNB, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if neckMid and origNM then tweenMotor(neckMid, origNM, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if neckUpper and origNU then tweenMotor(neckUpper, origNU, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if neck and origN then tweenMotor(neck, origN, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if leftShoulder and origLS then tweenMotor(leftShoulder, origLS, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if rightShoulder and origRS then tweenMotor(rightShoulder, origRS, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        task.wait(0.30)

        -- Exact rest pose restoration
        if rootJoint and origRoot then rootJoint.C0 = origRoot end
        if neckBase and origNB then neckBase.C0 = origNB end
        if neckMid and origNM then neckMid.C0 = origNM end
        if neckUpper and origNU then neckUpper.C0 = origNU end
        if neck and origN then neck.C0 = origN end
        if leftShoulder and origLS then leftShoulder.C0 = origLS end
        if rightShoulder and origRS then rightShoulder.C0 = origRS end

        self.IsRoaring = false
        if (self :: any).AnimState then (self :: any).AnimState.IsRoaring = false end
    end)

    return duration
end

function TitanAnimationController:PlayAbility(actionName: string, ...): any
    if actionName == "BasicAttack" then
        return self:PlayBasicAttack(...)
    elseif actionName == "Stomp" then
        return self:PlayStomp()
    elseif actionName == "Roar" then
        return self:PlayRoar()
    elseif actionName == "TailSweep" then
        return self:PlayTailSweep()
    elseif actionName == "HeavyStomp" then
        return self:PlayHeavyStomp()
    elseif actionName == "NeckStrike" then
        return self:PlayNeckStrike()
    end
    return nil
end

function TitanAnimationController:StopAll()
    if self.WalkConnection then
        self.WalkConnection:Disconnect()
        self.WalkConnection = nil
    end
    for _, track in pairs(self.Tracks) do
        track:Stop(0.1)
    end
    for name, motor in pairs(self.Motors) do
        local orig = self.OrigC0[name]
        if orig and motor then motor.C0 = orig end
    end
    self.IsAttacking = false
    self.IsStomping = false
    self.IsRoaring = false
end

function TitanAnimationController:Destroy()
    if self.WalkConnection then
        self.WalkConnection:Disconnect()
        self.WalkConnection = nil
    end
    self:StopAll()
    table.clear(self.Tracks)
    table.clear(self.Motors)
    table.clear(self.OrigC0)
end

return TitanAnimationController
