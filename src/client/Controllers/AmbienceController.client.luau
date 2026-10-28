--!strict
--[[
    AmbienceController.client.luau
    Client-side ambience beds for Titan Rampage (Milestone 13).
    Responsibility:
    - Listens for "CityLightingChanged" on CityFeedback (the same event that drives LightingController).
    - Crossfades to the zone's looped ambience (LightingProfile.AmbientLoop, an AudioConfig.Sounds key):
      Kaiju Hub volcanic rumble, SmallTown surf, Metrovale distant traffic.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local CityFeedbackRemote = RemotesFolder:WaitForChild("CityFeedback") :: RemoteEvent
local AudioController = require(SharedFolder:WaitForChild("AudioController") :: ModuleScript)
local CityConfig = require(ConfigFolder:WaitForChild("CityConfig") :: ModuleScript)

local CROSSFADE_TIME = 2.0
-- Players always join in the Kaiju Hub. The join-time CityLightingChanged can be consumed by
-- LightingController before this script connects, so fall back to the hub bed after this delay.
local JOIN_FALLBACK_DELAY = 3.0
local fadeInfo = TweenInfo.new(CROSSFADE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local currentKey: string? = nil
local currentSound: Sound? = nil

local function fadeOutAndDestroy(sound: Sound)
    local tween = TweenService:Create(sound, fadeInfo, { Volume = 0 })
    tween.Completed:Once(function()
        sound:Destroy()
    end)
    tween:Play()
end

local function setAmbience(soundKey: string?)
    if soundKey == currentKey then return end
    currentKey = soundKey

    if currentSound then
        fadeOutAndDestroy(currentSound)
        currentSound = nil
    end
    if not soundKey then return end

    local sound, targetVolume = AudioController.CreateLoopedSound(soundKey)
    if not sound then return end
    currentSound = sound
    sound:Play()
    TweenService:Create(sound, fadeInfo, { Volume = targetVolume }):Play()
end

CityFeedbackRemote.OnClientEvent:Connect(function(action: string, payload: any)
    if action ~= "CityLightingChanged" or type(payload) ~= "table" then return end
    local loopKey = payload.AmbientLoop
    setAmbience(if type(loopKey) == "string" then loopKey else nil)
end)

task.delay(JOIN_FALLBACK_DELAY, function()
    if currentKey ~= nil then return end
    local hubProfile = CityConfig.GetLightingProfile("KaijuHub")
    if hubProfile then setAmbience(hubProfile.AmbientLoop) end
end)

print("[AmbienceController] Client ambience controller initialized.")
