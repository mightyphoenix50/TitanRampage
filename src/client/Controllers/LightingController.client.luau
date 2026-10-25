--!strict
--[[
    LightingController.client.luau
    Client-side lighting manager for Titan Rampage.
    Responsibility:
    - Listens for "CityLightingChanged" events from CityFeedback RemoteEvent.
    - Smoothly transitions Lighting, Atmosphere, Bloom, and ColorCorrection via TweenService.
    - Eliminates jarring lighting pops when teleporting between Kaiju Hub, SmallTown, and Metrovale.
--]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local CityFeedbackRemote = RemotesFolder:WaitForChild("CityFeedback") :: RemoteEvent

local TRANSITION_TIME = 1.2
local tweenInfo = TweenInfo.new(TRANSITION_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function applyLightingProfile(profile: any)
    if not profile then return end

    -- Base Lighting Properties
    local lightingProps = {}
    if profile.ClockTime ~= nil then lightingProps.ClockTime = profile.ClockTime end
    if profile.Brightness ~= nil then lightingProps.Brightness = profile.Brightness end
    if profile.OutdoorAmbient ~= nil then lightingProps.OutdoorAmbient = profile.OutdoorAmbient end
    if profile.Ambient ~= nil then lightingProps.Ambient = profile.Ambient end
    if profile.ShadowSoftness ~= nil then lightingProps.ShadowSoftness = profile.ShadowSoftness end

    pcall(function()
        local tw = TweenService:Create(Lighting, tweenInfo, lightingProps)
        tw:Play()
    end)

    -- Atmosphere
    if profile.Atmosphere then
        local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmo then
            local atmoProps = {}
            if profile.Atmosphere.Density ~= nil then atmoProps.Density = profile.Atmosphere.Density end
            if profile.Atmosphere.Offset ~= nil then atmoProps.Offset = profile.Atmosphere.Offset end
            if profile.Atmosphere.Color ~= nil then atmoProps.Color = profile.Atmosphere.Color end
            if profile.Atmosphere.Decay ~= nil then atmoProps.Decay = profile.Atmosphere.Decay end
            if profile.Atmosphere.Glare ~= nil then atmoProps.Glare = profile.Atmosphere.Glare end
            if profile.Atmosphere.Haze ~= nil then atmoProps.Haze = profile.Atmosphere.Haze end

            pcall(function()
                local twAtmo = TweenService:Create(atmo, tweenInfo, atmoProps)
                twAtmo:Play()
            end)
        end
    end

    -- Bloom
    if profile.Bloom then
        local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
        if bloom then
            local bloomProps = {}
            if profile.Bloom.Intensity ~= nil then bloomProps.Intensity = profile.Bloom.Intensity end
            if profile.Bloom.Size ~= nil then bloomProps.Size = profile.Bloom.Size end
            if profile.Bloom.Threshold ~= nil then bloomProps.Threshold = profile.Bloom.Threshold end

            pcall(function()
                local twBloom = TweenService:Create(bloom, tweenInfo, bloomProps)
                twBloom:Play()
            end)
        end
    end

    -- ColorCorrection
    if profile.ColorCorrection then
        local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
        if cc then
            local ccProps = {}
            if profile.ColorCorrection.Brightness ~= nil then ccProps.Brightness = profile.ColorCorrection.Brightness end
            if profile.ColorCorrection.Contrast ~= nil then ccProps.Contrast = profile.ColorCorrection.Contrast end
            if profile.ColorCorrection.Saturation ~= nil then ccProps.Saturation = profile.ColorCorrection.Saturation end
            if profile.ColorCorrection.TintColor ~= nil then ccProps.TintColor = profile.ColorCorrection.TintColor end

            pcall(function()
                local twCC = TweenService:Create(cc, tweenInfo, ccProps)
                twCC:Play()
            end)
        end
    end
end

CityFeedbackRemote.OnClientEvent:Connect(function(action: string, payload: any)
    if action == "CityLightingChanged" and payload then
        applyLightingProfile(payload)
    end
end)

print("[LightingController] Client lighting controller initialized.")
