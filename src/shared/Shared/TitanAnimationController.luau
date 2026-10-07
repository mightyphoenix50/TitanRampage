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

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local TitanConfig = require(ConfigFolder:WaitForChild("TitanConfig") :: ModuleScript)

export type AnimationController = {
    Character: Model,
    Humanoid: Humanoid,
    Animator: Animator,
    Motors: { [string]: Motor6D },
    OrigC0: { [string]: CFrame },
    Tracks: { [string]: AnimationTrack },
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

    -- Pre-load any configured Animation assets
    local ravagerConfig = TitanConfig.Ravager
    if ravagerConfig and ravagerConfig.Abilities then
        for actionName, ability in pairs(ravagerConfig.Abilities) do
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

    local self = setmetatable({
        Character = character,
        Humanoid = humanoid,
        Animator = animator,
        Motors = motors,
        OrigC0 = origC0,
        Tracks = tracks,
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
    if self.Motors["TailBaseJoint"] then
        local dur = self:PlayTailSweep()
        return "TailSweep", dur
    end
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
    if track then
        track:Play(0.06)
    end

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
                tweenMotor(leftShoulder, origLeft * CFrame.Angles(math.rad(25), math.rad(45), math.rad(-30)), 0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
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
                tweenMotor(leftShoulder, origLeft * CFrame.Angles(math.rad(95), math.rad(-75), math.rad(40)), 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            if rootJoint and origRoot then
                tweenMotor(rootJoint, origRoot * CFrame.Angles(math.rad(6), math.rad(30), 0), 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            if neck and origNeck then
                tweenMotor(neck, origNeck * CFrame.Angles(0, math.rad(-15), 0), 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            task.wait(0.14)

            -- Phase 3: Recovery / Return (0.19s)
            if leftShoulder and origLeft then
                tweenMotor(leftShoulder, origLeft, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            if rootJoint and origRoot then
                tweenMotor(rootJoint, origRoot, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            if neck and origNeck then
                tweenMotor(neck, origNeck, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            task.wait(0.19)

        elseif variant == "RightSwipe" then
            -- ATTACK 2: RIGHT SWIPE (Retargeted 0.42s total)
            -- Phase 1: Anticipation / Coil (0.09s) - Torso twists left, Right Arm winds back
            if rightShoulder and origRight then
                tweenMotor(rightShoulder, origRight * CFrame.Angles(math.rad(25), math.rad(-45), math.rad(30)), 0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
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
                tweenMotor(rightShoulder, origRight * CFrame.Angles(math.rad(95), math.rad(75), math.rad(-40)), 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            if rootJoint and origRoot then
                tweenMotor(rootJoint, origRoot * CFrame.Angles(math.rad(6), math.rad(-30), 0), 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            if neck and origNeck then
                tweenMotor(neck, origNeck * CFrame.Angles(0, math.rad(15), 0), 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            task.wait(0.14)

            -- Phase 3: Recovery / Return (0.19s)
            if rightShoulder and origRight then
                tweenMotor(rightShoulder, origRight, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            if rootJoint and origRoot then
                tweenMotor(rootJoint, origRoot, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            if neck and origNeck then
                tweenMotor(neck, origNeck, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            task.wait(0.19)

        else
            -- ATTACK 3: DOWNWARD SMASH (Two-Handed Overhead Slam - Retargeted 0.42s total)
            -- Phase 1: Overhead Windup (0.09s) - Both arms raise high overhead, torso arches back
            if rightShoulder and origRight then
                tweenMotor(rightShoulder, origRight * CFrame.Angles(math.rad(130), math.rad(-20), math.rad(25)), 0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            if leftShoulder and origLeft then
                tweenMotor(leftShoulder, origLeft * CFrame.Angles(math.rad(130), math.rad(20), math.rad(-25)), 0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            if rootJoint and origRoot then
                tweenMotor(rootJoint, origRoot * CFrame.Angles(math.rad(-14), 0, 0), 0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            task.wait(0.09)

            -- Phase 2: Downward Hammer Impact (0.14s) - Both arms slam down with forward torso crunch
            if rightShoulder and origRight then
                tweenMotor(rightShoulder, origRight * CFrame.Angles(math.rad(-35), math.rad(-10), 0), 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            if leftShoulder and origLeft then
                tweenMotor(leftShoulder, origLeft * CFrame.Angles(math.rad(-35), math.rad(10), 0), 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            if rootJoint and origRoot then
                tweenMotor(rootJoint, origRoot * CFrame.Angles(math.rad(22), 0, 0), 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            task.wait(0.14)

            -- Phase 3: Recovery / Return (0.19s)
            if rightShoulder and origRight then
                tweenMotor(rightShoulder, origRight, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            if leftShoulder and origLeft then
                tweenMotor(leftShoulder, origLeft, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            if rootJoint and origRoot then
                tweenMotor(rootJoint, origRoot, 0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
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
    if self.Motors["TailBaseJoint"] then
        return self:PlayHeavyStomp()
    end
    local duration = 0.75
    self.IsStomping = true

    local track = self.Tracks["Stomp"]
    if track then
        track:Play(0.1)
    end

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
            tweenMotor(rootJoint, origRoot * CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(-10), 0, 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if rightHip and origHip then
            tweenMotor(rightHip, origHip * CFrame.Angles(math.rad(25), 0, 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if rightShoulder and origRight then
            tweenMotor(rightShoulder, origRight * CFrame.Angles(math.rad(-25), 0, math.rad(20)), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if leftShoulder and origLeft then
            tweenMotor(leftShoulder, origLeft * CFrame.Angles(math.rad(-25), 0, math.rad(-20)), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        task.wait(0.15)

        -- Phase 2: Leg Raise (0.20s) - Total elapsed = 0.35s (exact match to server windup!)
        if rightHip and origHip then
            tweenMotor(rightHip, origHip * CFrame.new(0, 2.5, -1.5) * CFrame.Angles(math.rad(65), 0, 0), 0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot * CFrame.new(0, 0.8, 0) * CFrame.Angles(math.rad(-15), 0, 0), 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        task.wait(0.20)

        -- Phase 3: Thunderous Ground Slam Impact (0.10s)
        if rightHip and origHip then
            tweenMotor(rightHip, origHip * CFrame.new(0, -0.6, 0.5) * CFrame.Angles(math.rad(-15), 0, 0), 0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot * CFrame.new(0, -1.8, 0) * CFrame.Angles(math.rad(18), 0, 0), 0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if rightShoulder and origRight then
            tweenMotor(rightShoulder, origRight * CFrame.Angles(math.rad(45), 0, math.rad(35)), 0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if leftShoulder and origLeft then
            tweenMotor(leftShoulder, origLeft * CFrame.Angles(math.rad(45), 0, math.rad(-35)), 0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        task.wait(0.10)

        -- Phase 4: Recovery (0.30s)
        if rightHip and origHip then
            tweenMotor(rightHip, origHip, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if rightShoulder and origRight then
            tweenMotor(rightShoulder, origRight, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if leftShoulder and origLeft then
            tweenMotor(leftShoulder, origLeft, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
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
    if self.Motors["TailBaseJoint"] then
        local duration = 1.10
        self.IsRoaring = true
        local neckBase = self.Motors["NeckBaseJoint"]
        local neck = self.Motors["Neck"]
        local tailBase = self.Motors["TailBaseJoint"]
        local origNeckBase = self.OrigC0["NeckBaseJoint"] or CFrame.new()
        local origNeck = self.OrigC0["Neck"] or CFrame.new()
        local origTailBase = self.OrigC0["TailBaseJoint"] or CFrame.new()

        task.spawn(function()
            if neckBase and origNeckBase then tweenMotor(neckBase, origNeckBase * CFrame.Angles(math.rad(-40), 0, 0), 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
            if neck and origNeck then tweenMotor(neck, origNeck * CFrame.Angles(math.rad(30), 0, 0), 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
            if tailBase and origTailBase then tweenMotor(tailBase, origTailBase * CFrame.Angles(math.rad(25), 0, 0), 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
            task.wait(0.35)
            task.wait(0.45)
            if neckBase and origNeckBase then tweenMotor(neckBase, origNeckBase, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
            if neck and origNeck then tweenMotor(neck, origNeck, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
            if tailBase and origTailBase then tweenMotor(tailBase, origTailBase, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
            task.wait(0.30)
            self.IsRoaring = false
        end)
        return duration
    end
    local duration = 1.00
    self.IsRoaring = true

    local track = self.Tracks["Roar"]
    if track then
        track:Play(0.15)
    end

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
            tweenMotor(rightShoulder, origRight * CFrame.Angles(math.rad(30), math.rad(65), math.rad(55)), 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if leftShoulder and origLeft then
            tweenMotor(leftShoulder, origLeft * CFrame.Angles(math.rad(30), math.rad(-65), math.rad(-55)), 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
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
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if neck and origNeck then
            tweenMotor(neck, origNeck, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if rightShoulder and origRight then
            tweenMotor(rightShoulder, origRight, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if leftShoulder and origLeft then
            tweenMotor(leftShoulder, origLeft, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        task.wait(0.25)

        self.IsRoaring = false
    end)

    return duration
end

--[=[
    Plays Brontara's Tail Sweep procedural animation.
]=]
function TitanAnimationController:PlayTailSweep(): number
    local duration = 0.65
    self.IsAttacking = true

    local rootJoint = self.Motors["RootJoint"]
    local tailBase = self.Motors["TailBaseJoint"]
    local tailMid = self.Motors["TailMidJoint"]
    local tailTip = self.Motors["TailTipJoint"]

    local origRoot = self.OrigC0["RootJoint"] or CFrame.new()
    local origTailBase = self.OrigC0["TailBaseJoint"] or CFrame.new()
    local origTailMid = self.OrigC0["TailMidJoint"] or CFrame.new()
    local origTailTip = self.OrigC0["TailTipJoint"] or CFrame.new()

    task.spawn(function()
        -- Phase 1: Anticipation / Windup (0.14s)
        if tailBase and origTailBase then
            tweenMotor(tailBase, origTailBase * CFrame.Angles(0, math.rad(-30), 0), 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if tailMid and origTailMid then
            tweenMotor(tailMid, origTailMid * CFrame.Angles(0, math.rad(-35), 0), 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if tailTip and origTailTip then
            tweenMotor(tailTip, origTailTip * CFrame.Angles(0, math.rad(-40), 0), 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot * CFrame.Angles(0, math.rad(12), 0), 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        task.wait(0.14)

        -- Phase 2: Massive Horizontal Sweep Strike (0.22s)
        if tailBase and origTailBase then
            tweenMotor(tailBase, origTailBase * CFrame.Angles(0, math.rad(55), 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if tailMid and origTailMid then
            tweenMotor(tailMid, origTailMid * CFrame.Angles(0, math.rad(65), 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if tailTip and origTailTip then
            tweenMotor(tailTip, origTailTip * CFrame.Angles(0, math.rad(70), 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot * CFrame.Angles(0, math.rad(-20), 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        task.wait(0.22)

        -- Phase 3: Recovery (0.29s)
        if tailBase and origTailBase then
            tweenMotor(tailBase, origTailBase, 0.29, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if tailMid and origTailMid then
            tweenMotor(tailMid, origTailMid, 0.29, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if tailTip and origTailTip then
            tweenMotor(tailTip, origTailTip, 0.29, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot, 0.29, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        task.wait(0.29)

        self.IsAttacking = false
    end)

    return duration
end

--[=[
    Plays Brontara's Heavy Stomp rear-up and front-pillar slam procedural animation.
]=]
function TitanAnimationController:PlayHeavyStomp(): number
    local duration = 1.00
    self.IsStomping = true

    local rootJoint = self.Motors["RootJoint"]
    local leftShoulder = self.Motors["Left Shoulder"]
    local rightShoulder = self.Motors["Right Shoulder"]
    local leftHip = self.Motors["Left Hip"]
    local rightHip = self.Motors["Right Hip"]
    local neckBase = self.Motors["NeckBaseJoint"]

    local origRoot = self.OrigC0["RootJoint"] or CFrame.new()
    local origLeftShoulder = self.OrigC0["Left Shoulder"] or CFrame.new()
    local origRightShoulder = self.OrigC0["Right Shoulder"] or CFrame.new()
    local origLeftHip = self.OrigC0["Left Hip"] or CFrame.new()
    local origRightHip = self.OrigC0["Right Hip"] or CFrame.new()
    local origNeckBase = self.OrigC0["NeckBaseJoint"] or CFrame.new()

    task.spawn(function()
        -- Phase 1: Colossal Rear Up on Hind Legs (0.50s)
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot * CFrame.new(0, 3.5, -2) * CFrame.Angles(math.rad(28), 0, 0), 0.50, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if leftShoulder and origLeftShoulder then
            tweenMotor(leftShoulder, origLeftShoulder * CFrame.Angles(math.rad(45), 0, 0), 0.50, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if rightShoulder and origRightShoulder then
            tweenMotor(rightShoulder, origRightShoulder * CFrame.Angles(math.rad(45), 0, 0), 0.50, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if leftHip and origLeftHip then
            tweenMotor(leftHip, origLeftHip * CFrame.Angles(math.rad(-22), 0, 0), 0.50, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if rightHip and origRightHip then
            tweenMotor(rightHip, origRightHip * CFrame.Angles(math.rad(-22), 0, 0), 0.50, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if neckBase and origNeckBase then
            tweenMotor(neckBase, origNeckBase * CFrame.Angles(math.rad(-20), 0, 0), 0.50, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        task.wait(0.50)

        -- Phase 2: Thunderous Front Pillar Impact (0.15s)
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot * CFrame.new(0, -1.5, 0) * CFrame.Angles(math.rad(-14), 0, 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if leftShoulder and origLeftShoulder then
            tweenMotor(leftShoulder, origLeftShoulder * CFrame.Angles(math.rad(-20), 0, 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if rightShoulder and origRightShoulder then
            tweenMotor(rightShoulder, origRightShoulder * CFrame.Angles(math.rad(-20), 0, 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if neckBase and origNeckBase then
            tweenMotor(neckBase, origNeckBase * CFrame.Angles(math.rad(22), 0, 0), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        task.wait(0.15)

        -- Phase 3: Recovery (0.35s)
        if rootJoint and origRoot then tweenMotor(rootJoint, origRoot, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if leftShoulder and origLeftShoulder then tweenMotor(leftShoulder, origLeftShoulder, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if rightShoulder and origRightShoulder then tweenMotor(rightShoulder, origRightShoulder, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if leftHip and origLeftHip then tweenMotor(leftHip, origLeftHip, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if rightHip and origRightHip then tweenMotor(rightHip, origRightHip, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if neckBase and origNeckBase then tweenMotor(neckBase, origNeckBase, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        task.wait(0.35)

        self.IsStomping = false
    end)

    return duration
end

--[=[
    Plays Brontara's Neck Strike overhead plunge procedural animation.
]=]
function TitanAnimationController:PlayNeckStrike(): number
    local duration = 0.70
    self.IsAttacking = true

    local rootJoint = self.Motors["RootJoint"]
    local neckBase = self.Motors["NeckBaseJoint"]
    local neckMid = self.Motors["NeckMidJoint"]
    local neckUpper = self.Motors["NeckUpperJoint"]
    local neck = self.Motors["Neck"]

    local origRoot = self.OrigC0["RootJoint"] or CFrame.new()
    local origNeckBase = self.OrigC0["NeckBaseJoint"] or CFrame.new()
    local origNeckMid = self.OrigC0["NeckMidJoint"] or CFrame.new()
    local origNeckUpper = self.OrigC0["NeckUpperJoint"] or CFrame.new()
    local origNeck = self.OrigC0["Neck"] or CFrame.new()

    task.spawn(function()
        -- Phase 1: High Neck Coil & Windup (0.22s)
        if neckBase and origNeckBase then
            tweenMotor(neckBase, origNeckBase * CFrame.Angles(math.rad(-30), 0, 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if neckMid and origNeckMid then
            tweenMotor(neckMid, origNeckMid * CFrame.Angles(math.rad(-25), 0, 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if neckUpper and origNeckUpper then
            tweenMotor(neckUpper, origNeckUpper * CFrame.Angles(math.rad(-20), 0, 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if neck and origNeck then
            tweenMotor(neck, origNeck * CFrame.Angles(math.rad(25), 0, 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot * CFrame.Angles(math.rad(-10), 0, 0), 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        task.wait(0.22)

        -- Phase 2: Downward Whip Plunge (0.18s)
        if neckBase and origNeckBase then
            tweenMotor(neckBase, origNeckBase * CFrame.Angles(math.rad(38), 0, 0), 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if neckMid and origNeckMid then
            tweenMotor(neckMid, origNeckMid * CFrame.Angles(math.rad(32), 0, 0), 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if neckUpper and origNeckUpper then
            tweenMotor(neckUpper, origNeckUpper * CFrame.Angles(math.rad(28), 0, 0), 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if neck and origNeck then
            tweenMotor(neck, origNeck * CFrame.Angles(math.rad(-25), 0, 0), 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        if rootJoint and origRoot then
            tweenMotor(rootJoint, origRoot * CFrame.Angles(math.rad(15), 0, 0), 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        task.wait(0.18)

        -- Phase 3: Recovery (0.30s)
        if neckBase and origNeckBase then tweenMotor(neckBase, origNeckBase, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if neckMid and origNeckMid then tweenMotor(neckMid, origNeckMid, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if neckUpper and origNeckUpper then tweenMotor(neckUpper, origNeckUpper, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if neck and origNeck then tweenMotor(neck, origNeck, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        if rootJoint and origRoot then tweenMotor(rootJoint, origRoot, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
        task.wait(0.30)

        self.IsAttacking = false
    end)

    return duration
end

function TitanAnimationController:StopAll()
    for _, track in pairs(self.Tracks) do
        track:Stop(0.1)
    end
    for name, motor in pairs(self.Motors) do
        local orig = self.OrigC0[name]
        if orig and motor then
            motor.C0 = orig
        end
    end
    self.IsAttacking = false
    self.IsStomping = false
    self.IsRoaring = false
end

function TitanAnimationController:Destroy()
    self:StopAll()
    table.clear(self.Tracks)
    table.clear(self.Motors)
    table.clear(self.OrigC0)
end

return TitanAnimationController
