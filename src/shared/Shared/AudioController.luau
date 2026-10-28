--!strict
--[[
    AudioController.luau
    Central Client-Side Audio Controller for Titan Rampage.
    Responsibility:
    - Centralized management of SoundGroups (Master, Combat, Destruction, UI, Music).
    - Spatial 3D playback (RollOffMode, distances) & 2D HUD sound presentation.
    - Sound variation (dynamic pitch jitter).
    - Audio throttling to prevent overload during simultaneous AoE Stomp destruction.
    - Synchronized triggers for Basic Attack variants, Stomp (0.35s impact), Roar, Combos, and Collapse.
    - Duplicate prevention for local vs. remote players.
--]]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local AudioConfig = require(ConfigFolder:WaitForChild("AudioConfig") :: ModuleScript)

local AudioController = {}

-- SoundGroup cache
local soundGroups: { [string]: SoundGroup } = {}

-- Audio throttling timestamps
local lastPlayTimes: { [string]: number } = {}
local recentImpactCount = 0
local lastImpactResetTime = 0

--[=[
    Initializes SoundGroups in SoundService and pre-caches group references.
]=]
function AudioController.Init()
    print("[AudioController] Initializing AudioController...")

    local master = SoundService:FindFirstChild("Master") :: SoundGroup?
    if not master then
        master = Instance.new("SoundGroup")
        master.Name = "Master"
        master.Volume = AudioConfig.SoundGroups.Master.Volume
        master.Parent = SoundService
    end
    soundGroups["Master"] = master

    for groupName, groupDef in pairs(AudioConfig.SoundGroups) do
        if groupName ~= "Master" then
            local grp = master:FindFirstChild(groupName) :: SoundGroup?
            if not grp then
                grp = Instance.new("SoundGroup")
                grp.Name = groupName
                grp.Volume = groupDef.Volume
                grp.Parent = master
            end
            soundGroups[groupName] = grp
        end
    end
end

--[=[
    Checks if a sound is currently throttled within its configured cooldown window.
]=]
function AudioController.IsThrottled(soundKey: string, customCooldown: number?): boolean
    local now = os.clock()
    local soundDef = AudioConfig.Sounds[soundKey]
    local cd = customCooldown or (soundDef and soundDef.ThrottleTime) or 0
    if cd <= 0 then return false end

    local last = lastPlayTimes[soundKey] or 0
    if (now - last) < cd then return true end

    lastPlayTimes[soundKey] = now
    return false
end

--[=[
    Helper to create and play a Sound object with pitch variation and SoundGroup routing.
]=]
local function playSoundInstance(soundKey: string, parentInstance: Instance, volumeMult: number?, pitchMult: number?): Sound?
    local soundDef = AudioConfig.Sounds[soundKey]
    if not soundDef then
        warn(string.format("[AudioController] Unknown sound definition: '%s'", tostring(soundKey)))
        return nil
    end

    local vol = (soundDef.Volume * (volumeMult or 1.0))
    local basePitch = soundDef.BasePitch * (pitchMult or 1.0)
    local jitter = if soundDef.PitchVariation then (math.random() * 2 - 1) * soundDef.PitchVariation else 0
    local finalPitch = math.clamp(basePitch + jitter, 0.2, 2.5)

    local sound = Instance.new("Sound")
    sound.Name = soundKey
    sound.SoundId = soundDef.SoundId
    sound.Volume = vol
    sound.PlaybackSpeed = finalPitch
    sound.SoundGroup = soundGroups[soundDef.SoundGroup] or soundGroups["Master"]

    if soundDef.RollOffMinDistance then
        sound.RollOffMinDistance = soundDef.RollOffMinDistance
        sound.RollOffMaxDistance = soundDef.RollOffMaxDistance or 300
        sound.RollOffMode = soundDef.RollOffMode or Enum.RollOffMode.InverseTapered
    end

    sound.Parent = parentInstance
    sound:Play()

    -- Automatically clean up sound after playback
    task.spawn(function()
        sound.Ended:Wait()
        sound:Destroy()
    end)
    Debris:AddItem(sound, 8.0) -- Fallback safety cleanup

    -- Play secondary layered sound if configured
    if soundDef.SecondarySoundId then
        task.spawn(function()
            local sec = Instance.new("Sound")
            sec.Name = soundKey .. "_Secondary"
            sec.SoundId = soundDef.SecondarySoundId
            sec.Volume = vol * 0.75
            sec.PlaybackSpeed = finalPitch * 1.05
            sec.SoundGroup = sound.SoundGroup
            if soundDef.RollOffMinDistance then
                sec.RollOffMinDistance = soundDef.RollOffMinDistance
                sec.RollOffMaxDistance = soundDef.RollOffMaxDistance or 300
                sec.RollOffMode = soundDef.RollOffMode or Enum.RollOffMode.InverseTapered
            end
            sec.Parent = parentInstance
            sec:Play()
            task.spawn(function()
                sec.Ended:Wait()
                sec:Destroy()
            end)
            Debris:AddItem(sec, 8.0)
        end)
    end

    return sound
end

--[=[
    Plays a 2D sound directly in SoundService (UI, LevelUp, Combos, Celebrations).
]=]
function AudioController.Play2D(soundKey: string, volumeMult: number?, pitchMult: number?): Sound?
    if AudioController.IsThrottled(soundKey) then return nil end
    local group = (AudioConfig.Sounds[soundKey] and AudioConfig.Sounds[soundKey].SoundGroup) or "UI"
    local targetParent = soundGroups[group] or SoundService
    return playSoundInstance(soundKey, targetParent, volumeMult, pitchMult)
end

--[=[
    Plays a 3D spatial sound at a Vector3 position or attached to a BasePart.
]=]
function AudioController.PlaySpatial(soundKey: string, target: Vector3 | BasePart, volumeMult: number?, pitchMult: number?): Sound?
    if AudioController.IsThrottled(soundKey) then return nil end

    if typeof(target) == "Instance" and target:IsA("BasePart") then
        return playSoundInstance(soundKey, target, volumeMult, pitchMult)
    elseif typeof(target) == "Vector3" then
        local tempPart = Instance.new("Part")
        tempPart.Name = "AudioEmitter_" .. soundKey
        tempPart.Position = target
        tempPart.Transparency = 1
        tempPart.CanCollide = false
        tempPart.CanQuery = false
        tempPart.CanTouch = false
        tempPart.Anchored = true
        tempPart.Size = Vector3.new(0.5, 0.5, 0.5)
        tempPart.Parent = Workspace

        local sound = playSoundInstance(soundKey, tempPart, volumeMult, pitchMult)
        Debris:AddItem(tempPart, 8.5)
        return sound
    end

    return nil
end

-- ====================================================================
-- COMBAT SOUND APIS
-- ====================================================================

--[=[
    Resolves the sound key for a Titan ability from TitanRegistry.
]=]
function AudioController.GetTitanSoundKey(titanId: string?, soundCategory: string, variant: string?): string
    local id = titanId or "Ravager"
    local sharedMod = ReplicatedStorage:FindFirstChild("Shared")
    if sharedMod then
        local titanRegMod = sharedMod:FindFirstChild("TitanRegistry")
        if titanRegMod and titanRegMod:IsA("ModuleScript") then
            local reg = require(titanRegMod)
            local def = reg.Get(id)
            if def and def.AudioProfile then
                local val = def.AudioProfile[soundCategory]
                if type(val) == "table" and variant then
                    return val[variant] or variant
                elseif type(val) == "string" then
                    return val
                end
            end
        end
    end
    return if variant then variant else soundCategory
end

--[=[
    Plays whoosh swing audio matching the attack variant for a specific Titan.
]=]
function AudioController.PlayTitanAttackWhoosh(titanId: string?, variant: string, sourcePart: BasePart?): Sound?
    local soundKey = AudioController.GetTitanSoundKey(titanId, "AttackWhoosh", variant)
    local target = sourcePart or Workspace.CurrentCamera
    return AudioController.PlaySpatial(soundKey, target)
end

--[=[
    Plays whoosh swing audio matching the attack variant (defaulting to Ravager).
]=]
function AudioController.PlayBasicAttackWhoosh(variant: string, sourcePart: BasePart?): Sound?
    return AudioController.PlayTitanAttackWhoosh("Ravager", variant, sourcePart)
end

--[=[
    Plays structural impact sound when Basic Attack hits a building.
    Uses building tier for scaling and throttles concurrent impacts.
]=]
function AudioController.PlayBuildingImpact(tier: number, position: Vector3): Sound?
    local now = os.clock()
    if (now - lastImpactResetTime) > 0.08 then
        recentImpactCount = 0
        lastImpactResetTime = now
    end

    -- Allow up to 3 concurrent impacts within an 80ms window, prioritizing larger tiers
    if recentImpactCount >= 3 and tier < 3 then return nil end
    recentImpactCount += 1

    local soundKey = AudioConfig.GetBuildingImpactKey(tier)
    return AudioController.PlaySpatial(soundKey, position)
end

--[=[
    Plays Stomp anticipation sound during windup phase (0.0s).
]=]
function AudioController.PlayStompAnticipation(sourcePart: BasePart?): Sound?
    local target = sourcePart or Workspace.CurrentCamera
    return AudioController.PlaySpatial("StompAnticipation", target)
end

--[=[
    Plays Titan-specific Stomp impact sound at impact moment.
]=]
function AudioController.PlayTitanStompImpact(titanId: string?, position: Vector3): Sound?
    local soundKey = AudioController.GetTitanSoundKey(titanId, "StompImpact", nil)
    local s = AudioController.PlaySpatial(soundKey, position)
    task.delay(0.1, function()
        AudioController.PlaySpatial("StompDebris", position)
    end)
    return s
end

--[=[
    Plays Stomp impact sound at exact 0.35s impact moment.
]=]
function AudioController.PlayStompImpact(position: Vector3): Sound?
    return AudioController.PlayTitanStompImpact("Ravager", position)
end

--[=[
    Plays Titan-specific Roar audio during the tremor phase.
]=]
function AudioController.PlayTitanRoar(titanId: string?, sourcePart: BasePart?): Sound?
    local soundKey = AudioController.GetTitanSoundKey(titanId, "Roar", nil)
    local target = sourcePart or Workspace.CurrentCamera
    return AudioController.PlaySpatial(soundKey, target)
end

--[=[
    Plays Roar audio during the tremor phase (defaulting to Ravager).
]=]
function AudioController.PlayRoar(sourcePart: BasePart?): Sound?
    return AudioController.PlayTitanRoar("Ravager", sourcePart)
end

-- ====================================================================
-- DESTRUCTION SOUND APIS
-- ====================================================================

--[=[
    Plays structural damage sounds as building health crosses thresholds.
]=]
function AudioController.PlayStructuralDamage(newRatio: number, oldRatio: number?, position: Vector3): Sound?
    local prev = oldRatio or 1.0

    if prev > 0.75 and newRatio <= 0.75 then
        -- Crossed 75%: Window Break
        return AudioController.PlaySpatial("WindowBreak", position)
    elseif prev > 0.50 and newRatio <= 0.50 then
        -- Crossed 50%: Structural Groan
        return AudioController.PlaySpatial("StructuralGroan", position)
    elseif prev > 0.25 and newRatio <= 0.25 then
        -- Crossed 25%: Critical Strain
        return AudioController.PlaySpatial("CriticalStrain", position)
    end
    return nil
end

--[=[
    Plays the multi-stage structural collapse audio sequence.
    Synchronized with the building collapse animation.
]=]
function AudioController.PlayCollapseSequence(tier: number, position: Vector3)
    local volMult, pitchMult = AudioConfig.GetCollapseRumbleTierMultiplier(tier)

    -- Phase 1: Structural fracture/shear
    AudioController.PlaySpatial("CollapseInitiate", position, volMult, pitchMult)

    -- Phase 2: Heavy descent rumble
    task.delay(0.15, function()
        AudioController.PlaySpatial("CollapseRumble", position, volMult, pitchMult)
    end)

    -- Phase 3: Rubble settling onto foundation
    task.delay(0.85, function()
        AudioController.PlaySpatial("RubbleImpact", position, volMult, pitchMult)
    end)
end

-- ====================================================================
-- PROGRESSION & UI SOUND APIS
-- ====================================================================

--[=[
    Plays combo progression cue when combo multiplier increases.
]=]
function AudioController.PlayComboProgress(multiplier: number): Sound?
    if multiplier == 2 then
        return AudioController.Play2D("Combo_2")
    elseif multiplier == 3 then
        return AudioController.Play2D("Combo_3")
    elseif multiplier == 4 then
        return AudioController.Play2D("Combo_4")
    elseif multiplier >= 5 then
        return AudioController.Play2D("Combo_5")
    end
    return nil
end

--[=[
    Plays subtle reward sound (Cash / Points / XP), pitch scaled by combo.
]=]
function AudioController.PlayReward(combo: number?): Sound?
    local c = combo or 1
    local pitchScale = 1.0 + math.clamp((c - 1) * 0.05, 0, 0.25)
    return AudioController.Play2D("RewardEarned", 1.0, pitchScale)
end

--[=[
    Plays Level Up celebratory fanfare stinger.
]=]
function AudioController.PlayLevelUp(): Sound?
    return AudioController.Play2D("LevelUp")
end

--[=[
    Plays City Completion celebratory sequence.
]=]
function AudioController.PlayCityComplete()
    task.delay(0.3, function()
        AudioController.Play2D("CityComplete")
    end)
end

--[=[
    Plays UI interaction sounds.
]=]
function AudioController.PlayUI(uiSoundName: string): Sound?
    return AudioController.Play2D(uiSoundName)
end

-- Initialize on first require
AudioController.Init()

return AudioController
