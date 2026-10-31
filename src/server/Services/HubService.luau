--!strict
--[[
    HubService.luau
    Authoritative construction, visual management, and micro-loops for the Central Kaiju Hub.
    Responsibility:
    - Colossal 4-Tier Volcanic Caldera Sanctuary (850+ studs across):
        Tier 1: Grand Central Plaza (Y = 520, 380-stud dia arena, master spawn, flame core, merchant pavilion, Altar of Ascension)
        Tier 2: The Hall of Titans (Y = 540, 280x140 amphitheater, 8 Tesla columns, illuminated statues of Ravager & Brontara with 3D stat cards)
        Tier 3: The Stargate Promontory (Y = 560, 260x120 high ridge, 42-stud SmallTown and Metrovale electric deployment stargates)
        Tier 4: The Colosseum Proving Grounds (Y = 480, 360x360 sunken pit, Bastion DPS dummy, 5 practice monoliths, 170-stud grand bridge)
    - Dynamic Volcanic Thunderstorm Engine:
        Procedural multi-segmented jagged lightning bolts striking 27 caldera targets every 3.5–6.5s.
        Sky illumination brightness flashes, spatial thunder claps, and impact spark bursts.
        Persistent Tesla lightning conductor rods on columns, skybeam bases, and stargates.
    - Inter-Tier High-Velocity Titan Magma Launch Pads with impulse physics and burst VFX.
    - Bastion Titan DPS & Combo Testing Dummy with live rolling damage-per-second, streak, and hit readout.
    - Master Initial Spawn Enforcer: Guarantees HubSpawnLocation is the sole active spawn in the game.
--]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local ModelsFolder = AssetsFolder:WaitForChild("Models")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local DestructionFeedbackRemote = RemotesFolder:WaitForChild("DestructionFeedback") :: RemoteEvent
local CityFeedbackRemote = RemotesFolder:WaitForChild("CityFeedback") :: RemoteEvent

local HubService = {}

-- DPS dummy state tracking
local dummyCombatState = {
    TotalDamage = 0,
    DamageWindow = {} :: { { Time: number, Damage: number } },
    ComboStreak = 0,
    HighestHit = 0,
    LastHitTime = 0,
}

-- Launch pad cooldown debounce per player
local launchDebounce: { [number]: number } = {}

-- Registry of lightning strike target locations
local lightningStrikeTargets: { Vector3 } = {}

-- Helper to create styled, anchored static parts
local function createPart(
    parent: Instance,
    name: string,
    size: Vector3,
    cframe: CFrame,
    material: Enum.Material,
    color: Color3,
    canCollide: boolean?
): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cframe
    p.Material = material
    p.Color = color
    p.Anchored = true
    p.CanCollide = if canCollide ~= nil then canCollide else true
    p.CanTouch = true
    p.CanQuery = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

--[=[
    Applies atmospheric lighting, bloom, and color correction for the Volcanic Kaiju Sanctuary.
]=]
local function setupAtmosphere()
    pcall(function()
        Lighting.ClockTime = 18.25 -- Atmospheric volcanic twilight
        Lighting.Brightness = 2.2 -- Enhanced brightness for vast 850-stud vista
        Lighting.OutdoorAmbient = Color3.fromRGB(110, 75, 70)
        Lighting.Ambient = Color3.fromRGB(85, 60, 58)
        Lighting.ShadowSoftness = 0.2
    end)

    -- Volcanic Atmosphere
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Parent = Lighting
    end
    atmosphere.Density = 0.28
    atmosphere.Offset = 0.25
    atmosphere.Color = Color3.fromRGB(195, 95, 55)
    atmosphere.Decay = Color3.fromRGB(65, 30, 25)
    atmosphere.Glare = 0.45
    atmosphere.Haze = 1.6

    -- Crisp Magma Bloom
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Parent = Lighting
    end
    bloom.Intensity = 0.70
    bloom.Size = 24
    bloom.Threshold = 1.1

    -- Color Correction for cinematic contrast
    local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if not cc then
        cc = Instance.new("ColorCorrectionEffect")
        cc.Parent = Lighting
    end
    cc.Brightness = 0.03
    cc.Contrast = 0.14
    cc.Saturation = 0.20
    cc.TintColor = Color3.fromRGB(255, 245, 238)
end

--[=[
    Attaches a Tesla Lightning Conductor Rod to an architectural pillar or roof peak.
]=]
local function createLightningConductor(parent: Instance, pos: Vector3, height: number): Part
    local rod = Instance.new("Part")
    rod.Name = "LightningConductorRod"
    rod.Size = Vector3.new(1.8, height, 1.8)
    rod.Position = pos + Vector3.new(0, height / 2, 0)
    rod.Material = Enum.Material.Metal
    rod.Color = Color3.fromRGB(170, 130, 80)
    rod.Anchored = true
    rod.CanCollide = false
    rod.CastShadow = false
    rod.Parent = parent

    local tip = Instance.new("Part")
    tip.Name = "ConductorTip"
    tip.Shape = Enum.PartType.Ball
    tip.Size = Vector3.new(3.6, 3.6, 3.6)
    tip.Position = pos + Vector3.new(0, height, 0)
    tip.Material = Enum.Material.Neon
    tip.Color = Color3.fromRGB(0, 230, 255)
    tip.Anchored = true
    tip.CanCollide = false
    tip.CastShadow = false
    tip.Parent = rod

    local att = Instance.new("Attachment")
    att.Parent = tip

    local arcEmitter = Instance.new("ParticleEmitter")
    arcEmitter.Name = "ElectricArcs"
    arcEmitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 240, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 170, 255)),
    })
    arcEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.0),
        NumberSequenceKeypoint.new(0.6, 2.8),
        NumberSequenceKeypoint.new(1, 0),
    })
    arcEmitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.7, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    arcEmitter.Speed = NumberRange.new(4, 10)
    arcEmitter.SpreadAngle = Vector2.new(180, 180)
    arcEmitter.Lifetime = NumberRange.new(0.3, 0.6)
    arcEmitter.Rate = 16
    arcEmitter.LightEmission = 1
    arcEmitter.LightInfluence = 0
    arcEmitter.Parent = att

    local tipLight = Instance.new("PointLight")
    tipLight.Color = Color3.fromRGB(0, 220, 255)
    tipLight.Brightness = 3.0
    tipLight.Range = 26
    tipLight.Shadows = false
    tipLight.Parent = tip

    table.insert(lightningStrikeTargets, tip.Position)
    return tip
end

--[=[
    Creates a rich holographic 3D billboard for Titan display pedestals.
]=]
local function createTitanHoloCard(
    parent: Instance,
    titanName: string,
    title: string,
    subtitle: string,
    stats: { Health: string, Speed: string, Power: string, Reach: string },
    abilities: { string },
    accentColor: Color3
)
    local bg = Instance.new("BillboardGui")
    bg.Name = "TitanHoloCard"
    bg.Size = UDim2.new(0, 440, 0, 270)
    bg.StudsOffset = Vector3.new(0, 18, 0)
    bg.AlwaysOnTop = true
    bg.MaxDistance = 160
    bg.Parent = parent

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 12, 16)
    mainFrame.BackgroundTransparency = 0.22
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = bg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = accentColor
    stroke.Thickness = 2.5
    stroke.Transparency = 0.15
    stroke.Parent = mainFrame

    -- Title
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -20, 0, 42)
    titleLbl.Position = UDim2.new(0, 10, 0, 8)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = string.upper(title)
    titleLbl.TextColor3 = accentColor
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = 28
    titleLbl.TextXAlignment = Enum.TextXAlignment.Center
    titleLbl.Parent = mainFrame

    -- Subtitle Archetype
    local subLbl = Instance.new("TextLabel")
    subLbl.Size = UDim2.new(1, -20, 0, 22)
    subLbl.Position = UDim2.new(0, 10, 0, 48)
    subLbl.BackgroundTransparency = 1
    subLbl.Text = subtitle
    subLbl.TextColor3 = Color3.fromRGB(220, 225, 235)
    subLbl.Font = Enum.Font.GothamBold
    subLbl.TextSize = 13
    subLbl.TextXAlignment = Enum.TextXAlignment.Center
    subLbl.Parent = mainFrame

    -- Stats Container Grid
    local statRows = {
        { Label = "HEALTH", Value = stats.Health },
        { Label = "SPEED", Value = stats.Speed },
        { Label = "POWER", Value = stats.Power },
        { Label = "REACH", Value = stats.Reach },
    }

    local statsContainer = Instance.new("Frame")
    statsContainer.Size = UDim2.new(1, -24, 0, 80)
    statsContainer.Position = UDim2.new(0, 12, 0, 76)
    statsContainer.BackgroundTransparency = 1
    statsContainer.Parent = mainFrame

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0.48, 0, 0.45, 0)
    grid.CellPadding = UDim2.new(0.04, 0, 0.1, 0)
    grid.Parent = statsContainer

    for _, s in ipairs(statRows) do
        local box = Instance.new("Frame")
        box.BackgroundColor3 = Color3.fromRGB(25, 22, 28)
        box.BorderSizePixel = 0
        box.Parent = statsContainer

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 6)
        bCorner.Parent = box

        local sLbl = Instance.new("TextLabel")
        sLbl.Size = UDim2.new(0.45, 0, 1, 0)
        sLbl.Position = UDim2.new(0, 8, 0, 0)
        sLbl.BackgroundTransparency = 1
        sLbl.Text = s.Label .. ":"
        sLbl.TextColor3 = Color3.fromRGB(160, 170, 185)
        sLbl.Font = Enum.Font.GothamBold
        sLbl.TextSize = 11
        sLbl.TextXAlignment = Enum.TextXAlignment.Left
        sLbl.Parent = box

        local sVal = Instance.new("TextLabel")
        sVal.Size = UDim2.new(0.55, -12, 1, 0)
        sVal.Position = UDim2.new(0.45, 0, 0, 0)
        sVal.BackgroundTransparency = 1
        sVal.Text = s.Value
        sVal.TextColor3 = Color3.fromRGB(255, 255, 255)
        sVal.Font = Enum.Font.GothamBlack
        sVal.TextSize = 11
        sVal.TextXAlignment = Enum.TextXAlignment.Right
        sVal.Parent = box
    end

    -- Abilities List
    local abHeader = Instance.new("TextLabel")
    abHeader.Size = UDim2.new(1, -24, 0, 20)
    abHeader.Position = UDim2.new(0, 12, 0, 164)
    abHeader.BackgroundTransparency = 1
    abHeader.Text = "SIGNATURE COMBAT ARSENAL"
    abHeader.TextColor3 = accentColor
    abHeader.Font = Enum.Font.GothamBlack
    abHeader.TextSize = 11
    abHeader.TextXAlignment = Enum.TextXAlignment.Left
    abHeader.Parent = mainFrame

    local abList = Instance.new("TextLabel")
    abList.Size = UDim2.new(1, -24, 0, 50)
    abList.Position = UDim2.new(0, 12, 0, 186)
    abList.BackgroundTransparency = 1
    abList.Text = "• " .. table.concat(abilities, "\n• ")
    abList.TextColor3 = Color3.fromRGB(210, 220, 235)
    abList.Font = Enum.Font.Gotham
    abList.TextSize = 11
    abList.TextXAlignment = Enum.TextXAlignment.Left
    abList.TextYAlignment = Enum.TextYAlignment.Top
    abList.Parent = mainFrame

    return bg
end

--[=[
    Mounts 1:1 scale static display statue with stage lighting and proximity prompt.
]=]
local function createDisplayStatue(parent: Instance, titanId: string, modelTemplateName: string, statueCFrame: CFrame, accentColor: Color3)
    local template = ModelsFolder:FindFirstChild(modelTemplateName)
    if not template or not template:IsA("Model") then
        warn(string.format("[HubService] Cannot create display statue: Model '%s' not found in Assets.Models", modelTemplateName))
        return
    end

    local statue = template:Clone()
    statue.Name = titanId .. "_DisplayStatue"

    for _, desc in ipairs(statue:GetDescendants()) do
        if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("Animator") then
            desc:Destroy()
        elseif desc:IsA("BasePart") then
            desc.Anchored = true
            desc.CanCollide = false
            desc.CanTouch = false
            desc.CanQuery = false
            desc.Massless = true
            desc.CastShadow = (desc.Size.Magnitude > 6)
        end
    end

    local hum = statue:FindFirstChildOfClass("Humanoid")
    if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end

    statue:PivotTo(statueCFrame)
    statue.Parent = parent

    -- Dual stage lighting
    local underLight = Instance.new("PointLight")
    underLight.Name = "StageUnderglow"
    underLight.Color = accentColor
    underLight.Range = 36
    underLight.Brightness = 4.5
    underLight.Shadows = false
    underLight.Parent = parent

    local spotPart = Instance.new("Part")
    spotPart.Name = "SpotlightRig"
    spotPart.Size = Vector3.new(2, 2, 2)
    spotPart.CFrame = statueCFrame * CFrame.new(0, 42, 24) * CFrame.Angles(math.rad(-60), 0, 0)
    spotPart.Transparency = 1
    spotPart.Anchored = true
    spotPart.CanCollide = false
    spotPart.CanTouch = false
    spotPart.Parent = parent

    local spot = Instance.new("SpotLight")
    spot.Color = Color3.fromRGB(255, 235, 205)
    spot.Range = 75
    spot.Brightness = 3.5
    spot.Angle = 50
    spot.Shadows = true
    spot.Parent = spotPart

    return statue
end

local DEFAULT_PAD_VELOCITIES: { [string]: Vector3 } = {
    Pad_PlazaToColosseum = Vector3.new(0, 140, -280),
    Pad_ColosseumToPlaza = Vector3.new(0, 180, 280),
    Pad_PlazaToStargates = Vector3.new(0, 145, 200),
    Pad_PlazaToTitans = Vector3.new(0, 120, -160),
}

--[=[
    Binds high-velocity launch impulse physics to a launch pad model.
]=]
local function bindLaunchPad(padModel: Model)
    local inner = padModel:FindFirstChild("TriggerPad") :: BasePart?
    if not inner then return end

    -- Avoid duplicate bindings
    if inner:GetAttribute("LaunchBound") == true then return end
    inner:SetAttribute("LaunchBound", true)

    local rawVel = padModel:GetAttribute("LaunchVelocity")
    local launchVelocity: Vector3 = if typeof(rawVel) == "Vector3"
        then rawVel
        else (DEFAULT_PAD_VELOCITIES[padModel.Name] or Vector3.new(0, 150, 0))

    inner.Touched:Connect(function(hit: BasePart)
        local character = hit.Parent
        if not character or not character:IsA("Model") then return end
        local player = Players:GetPlayerFromCharacter(character)
        if not player then return end

        local now = os.clock()
        if (launchDebounce[player.UserId] or 0) > now then return end
        launchDebounce[player.UserId] = now + 1.2

        local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart? or character.PrimaryPart
        if hrp and not hrp.Anchored then
            hrp.AssemblyLinearVelocity = launchVelocity

            local burst = Instance.new("Part")
            burst.Size = Vector3.new(16, 1.2, 16)
            burst.CFrame = inner.CFrame
            burst.Anchored = true
            burst.CanCollide = false
            burst.CanTouch = false
            burst.Material = Enum.Material.Neon
            burst.Color = Color3.fromRGB(255, 160, 45)
            burst.Transparency = 0.15
            burst.Parent = Workspace

            local tw = TweenService:Create(burst, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = Vector3.new(36, 0.6, 36),
                Transparency = 1,
            })
            tw:Play()
            tw.Completed:Connect(function()
                burst:Destroy()
            end)
        end
    end)
end

--[=[
    Constructs a directional Magma Launch Pad.
]=]
local function createLaunchPad(parent: Instance, name: string, cframe: CFrame, launchVelocity: Vector3, label: string)
    local padModel = Instance.new("Model")
    padModel.Name = name
    padModel:SetAttribute("LaunchVelocity", launchVelocity)

    -- Outer ring
    local base =
        createPart(padModel, "PadBase", Vector3.new(22, 1.4, 22), cframe, Enum.Material.SmoothPlastic, Color3.fromRGB(20, 20, 25), true)
    base.CastShadow = false

    -- Glowing inner pad
    local inner = createPart(
        padModel,
        "TriggerPad",
        Vector3.new(18, 1.6, 18),
        cframe * CFrame.new(0, 0.25, 0),
        Enum.Material.Neon,
        Color3.fromRGB(255, 95, 15),
        false
    )
    inner.CastShadow = false

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 110, 20)
    light.Range = 30
    light.Brightness = 3.5
    light.Parent = inner

    -- Overhead holographic billboard
    local bg = Instance.new("BillboardGui")
    bg.Size = UDim2.new(0, 180, 0, 42)
    bg.StudsOffset = Vector3.new(0, 5, 0)
    bg.AlwaysOnTop = true
    bg.MaxDistance = 100
    bg.Parent = inner

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "▲ " .. label .. " ▲"
    lbl.TextColor3 = Color3.fromRGB(255, 190, 60)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = 15
    lbl.Parent = bg

    bindLaunchPad(padModel)

    padModel.Parent = parent
    return padModel
end

--[=[
    Constructs the Bastion Titan DPS dummy with live overhead damage readout and lightning rod.
]=]
local function createBastionDPSDummy(parent: Instance, cframe: CFrame): Model
    local dummyModel = Instance.new("Model")
    dummyModel.Name = "Bastion_Titan_Dummy"

    -- Base plinth
    local plinth = createPart(
        dummyModel,
        "Plinth",
        Vector3.new(24, 3, 24),
        cframe * CFrame.new(0, 1.5, 0),
        Enum.Material.Basalt,
        Color3.fromRGB(25, 23, 28)
    )

    -- Heavy Core Monolith
    local core = createPart(
        dummyModel,
        "Core",
        Vector3.new(16, 42, 16),
        cframe * CFrame.new(0, 24, 0),
        Enum.Material.Basalt,
        Color3.fromRGB(30, 28, 34)
    )
    core:SetAttribute("BuildingId", "Bastion_Titan_Dummy")
    core:SetAttribute("BuildingName", "Bastion Titan Combat Dummy")
    core:SetAttribute("BuildingType", "TrainingDummy")
    core:SetAttribute("MaxHealth", 50000)
    core:SetAttribute("CurrentHealth", 50000)
    core:SetAttribute("DestructionReward", 0)
    core:SetAttribute("DestructionPoints", 15)
    core:SetAttribute("DestructionTier", 3)
    core:SetAttribute("IsTrainingDummy", true)
    core:SetAttribute("IsDestroyed", false)

    dummyModel.PrimaryPart = core

    -- Magma Rune Rings on Core
    for _, yOff in ipairs({ 8, 16, 24, 32 }) do
        local rune = createPart(
            dummyModel,
            "RuneRing_" .. yOff,
            Vector3.new(17.2, 1.8, 17.2),
            cframe * CFrame.new(0, yOff, 0),
            Enum.Material.Neon,
            Color3.fromRGB(255, 80, 15),
            false
        )
        rune.CastShadow = false
    end

    -- Lightning Conductor Spire on top of Bastion Dummy
    createLightningConductor(dummyModel, (cframe * CFrame.new(0, 45, 0)).Position, 16)

    -- Live Rolling DPS & Combo Billboard GUI
    local bg = Instance.new("BillboardGui")
    bg.Name = "DPS_Billboard"
    bg.Size = UDim2.new(0, 360, 0, 170)
    bg.StudsOffset = Vector3.new(0, 32, 0)
    bg.AlwaysOnTop = true
    bg.MaxDistance = 180
    bg.Parent = core

    local frame = Instance.new("Frame")
    frame.Name = "Frame"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(15, 12, 16)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = bg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 100, 20)
    stroke.Thickness = 2
    stroke.Parent = frame

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name = "TitleLabel"
    titleLbl.Size = UDim2.new(1, 0, 0, 26)
    titleLbl.Position = UDim2.new(0, 0, 0, 6)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "BASTION TITAN • 50,000 HP"
    titleLbl.TextColor3 = Color3.fromRGB(255, 190, 50)
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = 14
    titleLbl.Parent = frame

    local dpsLbl = Instance.new("TextLabel")
    dpsLbl.Name = "DPSLabel"
    dpsLbl.Size = UDim2.new(1, 0, 0, 46)
    dpsLbl.Position = UDim2.new(0, 0, 0, 32)
    dpsLbl.BackgroundTransparency = 1
    dpsLbl.Text = "0 DPS"
    dpsLbl.TextColor3 = Color3.fromRGB(255, 235, 60)
    dpsLbl.Font = Enum.Font.GothamBlack
    dpsLbl.TextSize = 34
    dpsLbl.Parent = frame

    local streakLbl = Instance.new("TextLabel")
    streakLbl.Name = "StreakLabel"
    streakLbl.Size = UDim2.new(1, 0, 0, 22)
    streakLbl.Position = UDim2.new(0, 0, 0, 78)
    streakLbl.BackgroundTransparency = 1
    streakLbl.Text = "0 HITS  •  1.0x COMBO"
    streakLbl.TextColor3 = Color3.fromRGB(255, 140, 30)
    streakLbl.Font = Enum.Font.GothamBold
    streakLbl.TextSize = 13
    streakLbl.Parent = frame

    local totalDmgLbl = Instance.new("TextLabel")
    totalDmgLbl.Name = "TotalDamageLabel"
    totalDmgLbl.Size = UDim2.new(1, 0, 0, 20)
    totalDmgLbl.Position = UDim2.new(0, 0, 0, 102)
    totalDmgLbl.BackgroundTransparency = 1
    totalDmgLbl.Text = "Total: 0  |  Best: 0"
    totalDmgLbl.TextColor3 = Color3.fromRGB(180, 195, 215)
    totalDmgLbl.Font = Enum.Font.Gotham
    totalDmgLbl.TextSize = 12
    totalDmgLbl.Parent = frame

    local barBg = Instance.new("Frame")
    barBg.Name = "HealthBarBg"
    barBg.Size = UDim2.new(0.85, 0, 0, 14)
    barBg.Position = UDim2.new(0.075, 0, 0, 134)
    barBg.BackgroundColor3 = Color3.fromRGB(35, 30, 40)
    barBg.BorderSizePixel = 0
    barBg.Parent = frame

    local barBgCorner = Instance.new("UICorner")
    barBgCorner.CornerRadius = UDim.new(0, 6)
    barBgCorner.Parent = barBg

    local barFill = Instance.new("Frame")
    barFill.Name = "HealthBarFill"
    barFill.Size = UDim2.new(1, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(255, 70, 20)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg

    local barFillCorner = Instance.new("UICorner")
    barFillCorner.CornerRadius = UDim.new(0, 6)
    barFillCorner.Parent = barFill

    dummyModel.Parent = parent
    return dummyModel
end

--[=[
    Constructs high-intensity stadium floodlights, glowing magma/electric ground runes,
    monolith combat uplighting, and bridge guidance lamps for the Colosseum Proving Grounds.
]=]
local function setupColosseumLighting(arenaFolder: Folder, arenaOrigin: Vector3, hubOrigin: Vector3)
    local lightingFolder = arenaFolder:FindFirstChild("ArenaLighting") :: Folder?
    if not lightingFolder then
        lightingFolder = Instance.new("Folder")
        lightingFolder.Name = "ArenaLighting"
        lightingFolder.Parent = arenaFolder
    end

    -- 1. 8 Wall Perimeter Floodlight Towers (atop 45-stud walls)
    local pylonHeight = 45
    local pylonPositions = {
        { Pos = arenaOrigin + Vector3.new(0, pylonHeight, -180), Angle = Vector3.new(0, 0, 0) }, -- North Wall
        { Pos = arenaOrigin + Vector3.new(0, pylonHeight, 180), Angle = Vector3.new(0, 180, 0) }, -- South Wall
        { Pos = arenaOrigin + Vector3.new(-180, pylonHeight, 0), Angle = Vector3.new(0, 90, 0) }, -- West Wall
        { Pos = arenaOrigin + Vector3.new(180, pylonHeight, 0), Angle = Vector3.new(0, -90, 0) }, -- East Wall
        { Pos = arenaOrigin + Vector3.new(-170, pylonHeight, -170), Angle = Vector3.new(0, 45, 0) }, -- NW Corner
        { Pos = arenaOrigin + Vector3.new(170, pylonHeight, -170), Angle = Vector3.new(0, -45, 0) }, -- NE Corner
        { Pos = arenaOrigin + Vector3.new(-170, pylonHeight, 170), Angle = Vector3.new(0, 135, 0) }, -- SW Corner
        { Pos = arenaOrigin + Vector3.new(170, pylonHeight, 170), Angle = Vector3.new(0, -135, 0) }, -- SE Corner
    }

    for idx, pDef in ipairs(pylonPositions) do
        local pylonPost = createPart(
            lightingFolder,
            "FloodPylon_" .. idx,
            Vector3.new(4, 14, 4),
            CFrame.new(pDef.Pos + Vector3.new(0, 7, 0)),
            Enum.Material.Metal,
            Color3.fromRGB(40, 42, 48)
        )
        local lampHead = createPart(
            pylonPost,
            "LampHead",
            Vector3.new(8, 3, 4),
            CFrame.new(pDef.Pos + Vector3.new(0, 14, 0)) * CFrame.Angles(math.rad(-25), math.rad(pDef.Angle.Y), 0),
            Enum.Material.Neon,
            Color3.fromRGB(255, 235, 190),
            false
        )
        lampHead.CastShadow = false

        -- High-intensity angled arena floodlight
        local spot = Instance.new("SpotLight")
        spot.Name = "StadiumSpot"
        spot.Color = Color3.fromRGB(255, 220, 170)
        spot.Range = 180
        spot.Angle = 82
        spot.Brightness = 4.2
        spot.Shadows = true
        spot.Face = Enum.NormalId.Front
        spot.Parent = lampHead

        local fill = Instance.new("PointLight")
        fill.Name = "PylonFill"
        fill.Color = Color3.fromRGB(255, 200, 140)
        fill.Range = 40
        fill.Brightness = 2.2
        fill.Parent = lampHead
    end

    -- 2. Inlaid Floor Combat Runes & Ambient Lighting (Y = arenaOrigin.Y + 0.1)
    local floorRunesFolder = Instance.new("Folder")
    floorRunesFolder.Name = "FloorRunes"
    floorRunesFolder.Parent = lightingFolder

    -- Inner Magma Combat Ring (Radius 42 studs around Bastion Dummy)
    local innerRadius = 42
    local innerSegs = 16
    for i = 1, innerSegs do
        local ang = (i - 1) * (math.pi * 2 / innerSegs)
        local rx = arenaOrigin.X + math.cos(ang) * innerRadius
        local rz = arenaOrigin.Z + math.sin(ang) * innerRadius
        local chord = (math.pi * 2 * innerRadius) / innerSegs
        local segPart = createPart(
            floorRunesFolder,
            "InnerRune_" .. i,
            Vector3.new(chord, 0.4, 2.5),
            CFrame.new(rx, arenaOrigin.Y + 0.15, rz) * CFrame.Angles(0, -ang + (math.pi / 2), 0),
            Enum.Material.Neon,
            Color3.fromRGB(255, 110, 15),
            false
        )
        segPart.CastShadow = false
    end

    -- Outer Electric Combat Ring (Radius 120 studs)
    local outerRadius = 120
    local outerSegs = 24
    for i = 1, outerSegs do
        local ang = (i - 1) * (math.pi * 2 / outerSegs)
        local rx = arenaOrigin.X + math.cos(ang) * outerRadius
        local rz = arenaOrigin.Z + math.sin(ang) * outerRadius
        local chord = (math.pi * 2 * outerRadius) / outerSegs
        local segPart = createPart(
            floorRunesFolder,
            "OuterRune_" .. i,
            Vector3.new(chord, 0.4, 3.2),
            CFrame.new(rx, arenaOrigin.Y + 0.15, rz) * CFrame.Angles(0, -ang + (math.pi / 2), 0),
            Enum.Material.Neon,
            Color3.fromRGB(40, 215, 255),
            false
        )
        segPart.CastShadow = false
    end

    -- 4 Floor Ambient Field PointLights
    local floorLightOffsets = {
        Vector3.new(0, 4, -75),
        Vector3.new(0, 4, 75),
        Vector3.new(-75, 4, 0),
        Vector3.new(75, 4, 0),
    }
    for idx, fOff in ipairs(floorLightOffsets) do
        local lightPart = createPart(
            floorRunesFolder,
            "ArenaFieldLight_" .. idx,
            Vector3.new(1, 1, 1),
            CFrame.new(arenaOrigin + fOff),
            Enum.Material.Air,
            Color3.fromRGB(0, 0, 0),
            false
        )
        lightPart.Transparency = 1
        lightPart.CanQuery = false
        lightPart.CanTouch = false

        local pLight = Instance.new("PointLight")
        pLight.Color = if idx % 2 == 0 then Color3.fromRGB(255, 140, 40) else Color3.fromRGB(60, 210, 255)
        pLight.Range = 85
        pLight.Brightness = 3.6
        pLight.Shadows = false
        pLight.Parent = lightPart
    end

    -- 3. Bastion Titan DPS Dummy Center Stage Spotlights
    local dummyStagePart = createPart(
        lightingFolder,
        "BastionStageRig",
        Vector3.new(4, 2, 4),
        CFrame.new(arenaOrigin + Vector3.new(0, 42, 0)),
        Enum.Material.Slate,
        Color3.fromRGB(25, 25, 30),
        false
    )
    dummyStagePart.Transparency = 1
    dummyStagePart.CanQuery = false
    dummyStagePart.CanTouch = false

    local dummySpot = Instance.new("SpotLight")
    dummySpot.Name = "BastionFocusSpot"
    dummySpot.Color = Color3.fromRGB(255, 245, 220)
    dummySpot.Range = 58
    dummySpot.Angle = 65
    dummySpot.Brightness = 5.5
    dummySpot.Face = Enum.NormalId.Bottom
    dummySpot.Shadows = true
    dummySpot.Parent = dummyStagePart

    -- Ground ring at dummy base
    local dummyRing = createPart(
        lightingFolder,
        "BastionBaseGlow",
        Vector3.new(22, 0.4, 22),
        CFrame.new(arenaOrigin + Vector3.new(0, 0.2, 0)),
        Enum.Material.Neon,
        Color3.fromRGB(255, 80, 20),
        false
    )
    dummyRing.CastShadow = false

    -- 4. Practice Monoliths Combat Uplighting
    local monolithPositions = {
        arenaOrigin + Vector3.new(-85, 0, -75),
        arenaOrigin + Vector3.new(85, 0, -75),
        arenaOrigin + Vector3.new(-110, 0, 65),
        arenaOrigin + Vector3.new(110, 0, 65),
        arenaOrigin + Vector3.new(0, 0, 110),
    }
    for idx, mPos in ipairs(monolithPositions) do
        local mRing = createPart(
            lightingFolder,
            "MonolithGlowRing_" .. idx,
            Vector3.new(14, 0.4, 14),
            CFrame.new(mPos + Vector3.new(0, 0.2, 0)),
            Enum.Material.Neon,
            Color3.fromRGB(255, 120, 20),
            false
        )
        mRing.CastShadow = false

        local upSpot = Instance.new("SpotLight")
        upSpot.Name = "UplightSpot"
        upSpot.Color = Color3.fromRGB(255, 140, 30)
        upSpot.Range = 55
        upSpot.Angle = 65
        upSpot.Brightness = 4.2
        upSpot.Face = Enum.NormalId.Top
        upSpot.Parent = mRing
    end

    -- 5. Grand Descending Bridge Runway Lanterns (6 pairs along 170-stud bridge)
    local bridgeSteps = 6
    local bridgeLength = 170
    local bridgeAngle = math.rad(-14)
    local bridgeStart = hubOrigin + Vector3.new(0, -20, -215)
    for b = 1, bridgeSteps do
        local frac = (b - 0.5) / bridgeSteps
        local offsetZ = (frac - 0.5) * bridgeLength
        local localPos = Vector3.new(0, offsetZ * math.sin(bridgeAngle), offsetZ * math.cos(bridgeAngle))
        local postCenter = bridgeStart + localPos

        for _, sideX in ipairs({ -22, 22 }) do
            local lantern = createPart(
                lightingFolder,
                string.format("BridgeLantern_%d_%d", b, sideX),
                Vector3.new(1.8, 4.5, 1.8),
                CFrame.new(postCenter + Vector3.new(sideX, 3.5, 0)),
                Enum.Material.Neon,
                Color3.fromRGB(255, 190, 80),
                false
            )
            lantern.CastShadow = false

            local lLight = Instance.new("PointLight")
            lLight.Color = Color3.fromRGB(255, 180, 70)
            lLight.Range = 26
            lLight.Brightness = 2.8
            lLight.Parent = lantern
        end
    end
end

--[=[
    Spawns a multi-segmented jagged lightning strike from the stormy sky down to targetPos.
    Features:
    - Dual-layer photorealistic bolt geometry (neon plasma sheath + supercharged white core).
    - Branching secondary forked bolts splitting off the trunk.
    - Ground impact expanding shockwave disc and vertical plasma spark fountains.
    - Softened acoustic thunder rumble (low volume, bassy, realistic distance attenuation).
    - Cinematic stroboscopic multi-stage flicker and smooth fade.
]=]
local function spawnLightningStrike(targetPos: Vector3)
    local boltModel = Instance.new("Model")
    boltModel.Name = "LightningStrike"

    local skyY = 1350
    local skyX = targetPos.X + math.random(-35, 35)
    local skyZ = targetPos.Z + math.random(-35, 35)
    local startPos = Vector3.new(skyX, skyY, skyZ)

    local segments = 7
    local currentPos = startPos
    local totalDelta = targetPos - startPos

    local isCyan = (math.random() > 0.35)
    local boltColor = if isCyan then Color3.fromRGB(80, 225, 255) else Color3.fromRGB(200, 140, 255)

    local allBolts: { BasePart } = {}

    -- Helper to create a dual-layered bolt segment (core + plasma sheath)
    local function createDualSegment(p1: Vector3, p2: Vector3, coreWidth: number, sheathWidth: number, namePrefix: string)
        local delta = p2 - p1
        local len = delta.Magnitude
        if len < 0.1 then return end
        local cf = CFrame.lookAt(p1 + (delta * 0.5), p2)

        -- Outer plasma sheath
        local sheath = Instance.new("Part")
        sheath.Name = namePrefix .. "_Sheath"
        sheath.Size = Vector3.new(sheathWidth, sheathWidth, len)
        sheath.CFrame = cf
        sheath.Material = Enum.Material.Neon
        sheath.Color = boltColor
        sheath.Transparency = 0.28
        sheath.Anchored = true
        sheath.CanCollide = false
        sheath.CanTouch = false
        sheath.CanQuery = false
        sheath.CastShadow = false
        sheath.Parent = boltModel
        table.insert(allBolts, sheath)

        -- Inner supercharged white core
        local core = Instance.new("Part")
        core.Name = namePrefix .. "_Core"
        core.Size = Vector3.new(coreWidth, coreWidth, len + 0.15)
        core.CFrame = cf
        core.Material = Enum.Material.Neon
        core.Color = Color3.fromRGB(255, 255, 255)
        core.Transparency = 0.0
        core.Anchored = true
        core.CanCollide = false
        core.CanTouch = false
        core.CanQuery = false
        core.CastShadow = false
        core.Parent = boltModel
        table.insert(allBolts, core)
    end

    -- Main trunk generation
    for i = 1, segments do
        local progress = i / segments
        local nextPos: Vector3
        if i == segments then
            nextPos = targetPos
        else
            local idealPos = startPos + (totalDelta * progress)
            local jitterX = math.random(-26, 26)
            local jitterZ = math.random(-26, 26)
            local jitterY = math.random(-14, 14)
            nextPos = idealPos + Vector3.new(jitterX, jitterY, jitterZ)
        end

        createDualSegment(currentPos, nextPos, 1.4, 3.4, "Trunk_" .. i)

        -- Branching secondary fork bolts at middle segments
        if (i == 2 or i == 4 or i == 5) and math.random() < 0.65 then
            task.spawn(function()
                local branchCurrent = nextPos
                local branchSteps = math.random(2, 4)
                local branchDir = Vector3.new(math.random(-38, 38), math.random(-40, -10), math.random(-38, 38))
                for b = 1, branchSteps do
                    local bProgress = b / branchSteps
                    local branchNext = branchCurrent
                        + (branchDir * (1 / branchSteps))
                        + Vector3.new(math.random(-12, 12), math.random(-10, 5), math.random(-12, 12))
                    createDualSegment(branchCurrent, branchNext, 0.7, 1.8, string.format("Fork_%d_%d", i, b))
                    branchCurrent = branchNext
                end
            end)
        end

        currentPos = nextPos
    end

    -- Bright PointLight on bolt contact zone
    local lightPart = Instance.new("Part")
    lightPart.Name = "BoltLightPart"
    lightPart.Size = Vector3.new(1, 1, 1)
    lightPart.Position = targetPos + Vector3.new(0, 20, 0)
    lightPart.Transparency = 1
    lightPart.Anchored = true
    lightPart.CanCollide = false
    lightPart.CanTouch = false
    lightPart.Parent = boltModel

    local light = Instance.new("PointLight")
    light.Color = boltColor
    light.Range = 90
    light.Brightness = 8.5
    light.Parent = lightPart

    -- Ground Impact Expanding Shockwave Disc
    local shockwave = Instance.new("Part")
    shockwave.Name = "ImpactShockwave"
    shockwave.Shape = Enum.PartType.Cylinder
    shockwave.Size = Vector3.new(0.4, 4, 4)
    shockwave.CFrame = CFrame.new(targetPos + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
    shockwave.Material = Enum.Material.Neon
    shockwave.Color = boltColor
    shockwave.Transparency = 0.1
    shockwave.Anchored = true
    shockwave.CanCollide = false
    shockwave.CanTouch = false
    shockwave.CanQuery = false
    shockwave.CastShadow = false
    shockwave.Parent = boltModel

    local shockwaveTween = TweenService:Create(shockwave, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.2, 44, 44),
        Transparency = 1,
    })
    shockwaveTween:Play()

    -- Impact Flash Ball
    local impact = Instance.new("Part")
    impact.Name = "ImpactFlash"
    impact.Shape = Enum.PartType.Ball
    impact.Size = Vector3.new(14, 14, 14)
    impact.Position = targetPos
    impact.Material = Enum.Material.Neon
    impact.Color = Color3.fromRGB(255, 255, 255)
    impact.Anchored = true
    impact.CanCollide = false
    impact.CanTouch = false
    impact.CanQuery = false
    impact.CastShadow = false
    impact.Parent = boltModel
    table.insert(allBolts, impact)

    -- Upward Ground Spark Particle Emitter
    local att = Instance.new("Attachment")
    att.Position = targetPos
    att.Parent = lightPart

    local sparks = Instance.new("ParticleEmitter")
    sparks.Color = ColorSequence.new(boltColor, Color3.fromRGB(255, 255, 255))
    sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
    sparks.Speed = NumberRange.new(45, 95)
    sparks.SpreadAngle = Vector2.new(60, 60)
    sparks.Lifetime = NumberRange.new(0.35, 0.70)
    sparks.Rate = 0
    sparks.Acceleration = Vector3.new(0, -65, 0)
    sparks.LightEmission = 1
    sparks.LightInfluence = 0
    sparks.Parent = att
    sparks:Emit(50)

    -- Thunder Audio: crack plus rolling decay, on its own emitter so it outlives the 0.3 s bolt
    local thunderEmitter = Instance.new("Part")
    thunderEmitter.Name = "ThunderEmitter"
    thunderEmitter.Size = Vector3.new(1, 1, 1)
    thunderEmitter.Position = lightPart.Position
    thunderEmitter.Transparency = 1
    thunderEmitter.Anchored = true
    thunderEmitter.CanCollide = false
    thunderEmitter.CanTouch = false
    thunderEmitter.CanQuery = false
    thunderEmitter.Parent = Workspace

    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://9116282875" -- ProSoundEffects: Lightning Strike Sharp Hissing Crack 5
    sound.Volume = 0.35
    sound.PlaybackSpeed = 0.85 + math.random() * 0.15 -- Bassy, varied per strike
    sound.RollOffMinDistance = 60
    sound.RollOffMaxDistance = 700
    sound.Parent = thunderEmitter
    sound:Play()
    task.delay(8, function()
        thunderEmitter:Destroy()
    end)

    boltModel.Parent = Workspace

    -- Full Sky Illumination Flash (Subtle ambiance pulse)
    pcall(function()
        Lighting.Brightness = 3.2
        task.delay(0.05, function()
            TweenService:Create(Lighting, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Brightness = 2.2,
            }):Play()
        end)
    end)

    -- Cinematic Stroboscopic Flicker Sequence
    task.delay(0.04, function()
        for _, p in ipairs(allBolts) do
            if p:IsA("BasePart") then p.Transparency = 0.65 end
        end
        light.Brightness = 3.5
    end)
    task.delay(0.07, function()
        -- Re-strike flash
        for _, p in ipairs(allBolts) do
            if p:IsA("BasePart") then p.Transparency = 0.15 end
        end
        light.Brightness = 7.0
    end)
    task.delay(0.12, function()
        -- Smooth fade out
        for _, p in ipairs(allBolts) do
            if p:IsA("BasePart") then
                TweenService:Create(p, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Transparency = 1,
                }):Play()
            end
        end
        TweenService:Create(light, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Brightness = 0,
        }):Play()
    end)
    task.delay(0.30, function()
        boltModel:Destroy()
    end)
end

--[=[
    Constructs the entire 4-Tier Volcanic Caldera Sanctuary in Workspace (850+ studs across).
]=]
function HubService.ConstructGrandSanctuary()
    print("[HubService] 🌋 Constructing Grand Volcanic Kaiju Megastructure (850+ studs)...")

    table.clear(lightningStrikeTargets)

    -- Guarantee default spawn in root is cleaned up
    local defaultSpawn = Workspace:FindFirstChild("SpawnLocation")
    if defaultSpawn then defaultSpawn:Destroy() end

    local existing = Workspace:FindFirstChild("KaijuHub")
    if existing then existing:Destroy() end

    local hub = Instance.new("Folder")
    hub.Name = "KaijuHub"

    local hubOrigin = Vector3.new(0, 520, -5000)

    -- =========================================================================
    -- TIER 1: GRAND CENTRAL PLAZA (Y = 520, 380 studs diameter)
    -- =========================================================================
    local plazaFolder = Instance.new("Folder")
    plazaFolder.Name = "GrandCentralPlaza"
    plazaFolder.Parent = hub

    -- Main Arena Disc (380 studs diameter)
    local mainFloor = createPart(
        plazaFolder,
        "PlazaFloor",
        Vector3.new(380, 8, 380),
        CFrame.new(hubOrigin.X, hubOrigin.Y - 4, hubOrigin.Z),
        Enum.Material.Basalt,
        Color3.fromRGB(32, 30, 35)
    )
    mainFloor.CastShadow = true

    -- 4 Concentric Magma Ley-Line Rings
    local ringRadii = { 360, 280, 200, 120 }
    for idx, r in ipairs(ringRadii) do
        local rune = createPart(
            plazaFolder,
            "MagmaRune_Ring" .. idx,
            Vector3.new(r, 0.5, r),
            CFrame.new(hubOrigin.X, hubOrigin.Y + 0.2 + (idx * 0.05), hubOrigin.Z),
            Enum.Material.Neon,
            if idx % 2 == 1 then Color3.fromRGB(255, 80, 15) else Color3.fromRGB(255, 120, 30),
            false
        )
        rune.CastShadow = false
    end

    -- Central Raised Spawn Dais (70 x 70 studs)
    local centerDais = createPart(
        plazaFolder,
        "CenterDais",
        Vector3.new(70, 3.5, 70),
        CFrame.new(hubOrigin.X, hubOrigin.Y + 1.75, hubOrigin.Z),
        Enum.Material.Slate,
        Color3.fromRGB(42, 40, 46)
    )
    centerDais.CastShadow = true

    -- Master HubSpawnLocation (Exclusive player spawn)
    local spawnLoc = Instance.new("SpawnLocation")
    spawnLoc.Name = "HubSpawnLocation"
    spawnLoc.Size = Vector3.new(28, 1.5, 28)
    spawnLoc.CFrame = CFrame.new(hubOrigin.X, hubOrigin.Y + 4.0, hubOrigin.Z)
    spawnLoc.Anchored = true
    spawnLoc.CanCollide = true
    spawnLoc.Material = Enum.Material.Neon
    spawnLoc.Color = Color3.fromRGB(255, 140, 30)
    spawnLoc.Duration = 0
    spawnLoc.Neutral = true
    spawnLoc.Enabled = true
    spawnLoc.Parent = hub

    local spawnLight = Instance.new("PointLight")
    spawnLight.Color = Color3.fromRGB(255, 150, 40)
    spawnLight.Range = 45
    spawnLight.Brightness = 4.0
    spawnLight.Parent = spawnLoc

    -- Central Blazing Magma Flame Core
    local flameCore = createPart(
        plazaFolder,
        "MagmaFlameCore",
        Vector3.new(6, 18, 6),
        CFrame.new(hubOrigin.X, hubOrigin.Y + 12, hubOrigin.Z),
        Enum.Material.Neon,
        Color3.fromRGB(255, 110, 20),
        false
    )
    flameCore.CastShadow = false

    local flameEmitter = Instance.new("ParticleEmitter")
    flameEmitter.Name = "SanctuaryFlames"
    flameEmitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 80)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 30, 10)),
    })
    flameEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 4),
        NumberSequenceKeypoint.new(0.7, 8),
        NumberSequenceKeypoint.new(1, 0),
    })
    flameEmitter.Speed = NumberRange.new(12, 24)
    flameEmitter.SpreadAngle = Vector2.new(20, 20)
    flameEmitter.Lifetime = NumberRange.new(1.0, 1.8)
    flameEmitter.Rate = 35
    flameEmitter.LightEmission = 0.9
    flameEmitter.Parent = flameCore

    -- 4 Monumental Entrance Promenades with Basalt Fire Braziers
    local cardinalAngles = { 0, 90, 180, 270 }
    for _, angleDeg in ipairs(cardinalAngles) do
        local rad = math.rad(angleDeg)
        for dist = 60, 160, 40 do
            local bx = hubOrigin.X + math.cos(rad) * dist
            local bz = hubOrigin.Z + math.sin(rad) * dist
            local brazier = createPart(
                plazaFolder,
                "Brazier_" .. angleDeg .. "_" .. dist,
                Vector3.new(5, 7, 5),
                CFrame.new(bx, hubOrigin.Y + 3.5, bz),
                Enum.Material.Basalt,
                Color3.fromRGB(28, 26, 32)
            )

            local brazierFlame = createPart(
                brazier,
                "Flame",
                Vector3.new(3, 2, 3),
                CFrame.new(bx, hubOrigin.Y + 7.5, bz),
                Enum.Material.Neon,
                Color3.fromRGB(255, 130, 25),
                false
            )
            brazierFlame.CastShadow = false

            local bLight = Instance.new("PointLight")
            bLight.Color = Color3.fromRGB(255, 140, 40)
            bLight.Brightness = 2.5
            bLight.Range = 28
            bLight.Parent = brazierFlame
        end
    end

    -- Merchant Pavilion (Titan Marketplace Kiosk)
    local merchantX = hubOrigin.X + 95
    local merchantY = hubOrigin.Y
    local merchantZ = hubOrigin.Z + 60

    local pavilionModel = Instance.new("Model")
    pavilionModel.Name = "MerchantPavilion"

    local pBase = createPart(
        pavilionModel,
        "BasePedestal",
        Vector3.new(2, 28, 28),
        CFrame.new(merchantX, merchantY + 1, merchantZ) * CFrame.Angles(0, 0, math.rad(90)),
        Enum.Material.Slate,
        Color3.fromRGB(38, 42, 50)
    )
    pBase.Shape = Enum.PartType.Cylinder

    local pRing = createPart(
        pavilionModel,
        "MagmaRing",
        Vector3.new(0.5, 30, 30),
        CFrame.new(merchantX, merchantY + 1.2, merchantZ) * CFrame.Angles(0, 0, math.rad(90)),
        Enum.Material.Neon,
        Color3.fromRGB(255, 130, 20),
        false
    )
    pRing.Shape = Enum.PartType.Cylinder

    local pPillarOffsets = { Vector3.new(9, 0, 9), Vector3.new(-9, 0, 9), Vector3.new(9, 0, -9), Vector3.new(-9, 0, -9) }
    for i, off in ipairs(pPillarOffsets) do
        createPart(
            pavilionModel,
            "Pillar_" .. i,
            Vector3.new(3, 16, 3),
            CFrame.new(merchantX + off.X, merchantY + 9, merchantZ + off.Z),
            Enum.Material.Cobblestone,
            Color3.fromRGB(28, 30, 36)
        )
        createPart(
            pavilionModel,
            "PillarCap_" .. i,
            Vector3.new(4, 1, 4),
            CFrame.new(merchantX + off.X, merchantY + 17, merchantZ + off.Z),
            Enum.Material.Neon,
            Color3.fromRGB(255, 150, 30),
            false
        )
    end

    local pRoof = createPart(
        pavilionModel,
        "CanopyRoof",
        Vector3.new(26, 2.5, 26),
        CFrame.new(merchantX, merchantY + 18, merchantZ),
        Enum.Material.Granite,
        Color3.fromRGB(35, 38, 46)
    )
    local pRoofTrim = createPart(
        pavilionModel,
        "RoofTrim",
        Vector3.new(28, 0.8, 28),
        CFrame.new(merchantX, merchantY + 19.4, merchantZ),
        Enum.Material.Neon,
        Color3.fromRGB(255, 120, 20),
        false
    )

    createLightningConductor(pavilionModel, Vector3.new(merchantX, merchantY + 20, merchantZ), 12)

    local pCounter = createPart(
        pavilionModel,
        "TraderCounter",
        Vector3.new(12, 4.5, 4.5),
        CFrame.new(merchantX, merchantY + 3.2, merchantZ),
        Enum.Material.WoodPlanks,
        Color3.fromRGB(58, 42, 30)
    )

    local pGold = createPart(
        pavilionModel,
        "GoldBarDisplay",
        Vector3.new(3.5, 1.4, 2),
        CFrame.new(merchantX - 2.5, merchantY + 6.1, merchantZ),
        Enum.Material.Metal,
        Color3.fromRGB(255, 215, 0),
        false
    )
    local pCrystal = createPart(
        pavilionModel,
        "CrystalDisplay",
        Vector3.new(2.2, 2.8, 2.2),
        CFrame.new(merchantX + 2.8, merchantY + 6.8, merchantZ),
        Enum.Material.Neon,
        Color3.fromRGB(0, 220, 255),
        false
    )

    local pPrompt = Instance.new("ProximityPrompt")
    pPrompt.Name = "MarketPavilionPrompt"
    pPrompt.ActionText = "Open Marketplace"
    pPrompt.ObjectText = "Titan Trader [B]"
    pPrompt.KeyboardKeyCode = Enum.KeyCode.F
    pPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    pPrompt.MaxActivationDistance = 24
    pPrompt.RequiresLineOfSight = false
    pPrompt.HoldDuration = 0
    pPrompt.Parent = pCounter

    -- 3D Holographic Billboard
    local pSignGui = Instance.new("BillboardGui")
    pSignGui.Name = "MarketBillboard"
    pSignGui.Size = UDim2.new(0, 300, 0, 80)
    pSignGui.StudsOffset = Vector3.new(0, 8, 0)
    pSignGui.AlwaysOnTop = true
    pSignGui.MaxDistance = 200
    pSignGui.Adornee = pRoofTrim
    pSignGui.Parent = pRoofTrim

    local pSignTitle = Instance.new("TextLabel")
    pSignTitle.Size = UDim2.new(1, 0, 0, 38)
    pSignTitle.Position = UDim2.new(0, 0, 0, 0)
    pSignTitle.BackgroundTransparency = 1
    pSignTitle.Text = "🛒 TITAN TRADER MARKET 🛒"
    pSignTitle.Font = Enum.Font.GothamBlack
    pSignTitle.TextSize = 22
    pSignTitle.TextColor3 = Color3.fromRGB(255, 220, 50)
    pSignTitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    pSignTitle.TextStrokeTransparency = 0.2
    pSignTitle.Parent = pSignGui

    local pSignDesc = Instance.new("TextLabel")
    pSignDesc.Size = UDim2.new(1, 0, 0, 24)
    pSignDesc.Position = UDim2.new(0, 0, 0, 36)
    pSignDesc.BackgroundTransparency = 1
    pSignDesc.Text = "Multipliers • Currency Packs • Combat Boosts"
    pSignDesc.Font = Enum.Font.GothamBold
    pSignDesc.TextSize = 13
    pSignDesc.TextColor3 = Color3.fromRGB(255, 170, 40)
    pSignDesc.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    pSignDesc.TextStrokeTransparency = 0.3
    pSignDesc.Parent = pSignGui

    pavilionModel.PrimaryPart = pCounter
    pavilionModel.Parent = plazaFolder

    -- Altar of Ascension (Progression Altar)
    local altarModel = Instance.new("Model")
    altarModel.Name = "AltarOfAscension"
    local altarBase = createPart(
        altarModel,
        "AltarBase",
        Vector3.new(26, 4, 26),
        CFrame.new(hubOrigin.X, hubOrigin.Y + 2, hubOrigin.Z + 140),
        Enum.Material.Basalt,
        Color3.fromRGB(25, 23, 28)
    )
    local altarMonolith = createPart(
        altarModel,
        "Monolith",
        Vector3.new(14, 32, 8),
        CFrame.new(hubOrigin.X, hubOrigin.Y + 18, hubOrigin.Z + 140),
        Enum.Material.Slate,
        Color3.fromRGB(38, 35, 42)
    )
    local runeCore = createPart(
        altarModel,
        "RuneCore",
        Vector3.new(8, 22, 3),
        CFrame.new(hubOrigin.X, hubOrigin.Y + 19, hubOrigin.Z + 136.5),
        Enum.Material.Neon,
        Color3.fromRGB(255, 120, 20),
        false
    )
    runeCore.CastShadow = false

    createLightningConductor(altarModel, Vector3.new(hubOrigin.X, hubOrigin.Y + 34, hubOrigin.Z + 140), 10)

    local altarPrompt = Instance.new("ProximityPrompt")
    altarPrompt.Name = "Prompt"
    altarPrompt.ActionText = "Ascend Titan Stats"
    altarPrompt.ObjectText = "Altar of Ascension"
    altarPrompt.HoldDuration = 0.5
    altarPrompt.MaxActivationDistance = 26
    altarPrompt.KeyboardKeyCode = Enum.KeyCode.F -- E is Stomp
    altarPrompt.RequiresLineOfSight = false
    altarPrompt.Parent = altarMonolith

    altarModel.PrimaryPart = altarMonolith
    altarModel.Parent = plazaFolder

    -- =========================================================================
    -- TIER 2: THE HALL OF TITANS (Y = 540, 280 x 140 studs Elevated North Terrace)
    -- =========================================================================
    local hallFolder = Instance.new("Folder")
    hallFolder.Name = "HallOfTitans"
    hallFolder.Parent = hub

    local terraceOrigin = hubOrigin + Vector3.new(0, 20, -140)

    -- Elevated Terrace Foundation (280 x 140 studs)
    local terraceFloor = createPart(
        hallFolder,
        "TerraceFloor",
        Vector3.new(280, 8, 140),
        CFrame.new(terraceOrigin.X, terraceOrigin.Y - 4, terraceOrigin.Z),
        Enum.Material.Basalt,
        Color3.fromRGB(28, 26, 30)
    )
    terraceFloor.CastShadow = true

    -- Grand Sweeping Steps (100 studs wide)
    for i = 1, 10 do
        local stepY = hubOrigin.Y + (i * 2)
        local stepZ = hubOrigin.Z - 65 - (i * 6)
        createPart(
            hallFolder,
            "Step_" .. i,
            Vector3.new(100, 2, 7),
            CFrame.new(hubOrigin.X, stepY - 1, stepZ),
            Enum.Material.Slate,
            Color3.fromRGB(36, 34, 40)
        )
    end

    -- 8 Monumental Flanking Columns with Tesla Lightning Conductors
    local colOffsets = { -120, -85, -50, -20, 20, 50, 85, 120 }
    for _, xOff in ipairs(colOffsets) do
        local col = createPart(
            hallFolder,
            "Pillar_" .. xOff,
            Vector3.new(10, 60, 10),
            CFrame.new(terraceOrigin.X + xOff, terraceOrigin.Y + 30, terraceOrigin.Z - 50),
            Enum.Material.Basalt,
            Color3.fromRGB(20, 18, 22)
        )
        local cap = createPart(
            hallFolder,
            "PillarCap_" .. xOff,
            Vector3.new(14, 4, 14),
            CFrame.new(terraceOrigin.X + xOff, terraceOrigin.Y + 62, terraceOrigin.Z - 50),
            Enum.Material.Slate,
            Color3.fromRGB(36, 33, 40)
        )
        createLightningConductor(hallFolder, Vector3.new(terraceOrigin.X + xOff, terraceOrigin.Y + 64, terraceOrigin.Z - 50), 14)
    end

    -- Ravager Pedestal (Left, 34 x 34 studs)
    local pedRavPos = terraceOrigin + Vector3.new(-75, 2, 0)
    local pedRav = createPart(
        hallFolder,
        "Pedestal_Ravager",
        Vector3.new(34, 4, 34),
        CFrame.new(pedRavPos),
        Enum.Material.Basalt,
        Color3.fromRGB(22, 20, 25)
    )
    local pedRavGlow = createPart(
        hallFolder,
        "PedRav_GlowRing",
        Vector3.new(36, 0.5, 36),
        CFrame.new(pedRavPos + Vector3.new(0, -1.7, 0)),
        Enum.Material.Neon,
        Color3.fromRGB(255, 95, 15),
        false
    )
    pedRavGlow.CastShadow = false

    local promptRav = Instance.new("ProximityPrompt")
    promptRav.Name = "Prompt"
    promptRav.ObjectText = "Ravager"
    promptRav.ActionText = "Awaken The Ravager"
    promptRav.HoldDuration = 0.5
    promptRav.MaxActivationDistance = 42 -- Titans are ~20 studs wide and the statue fills the pedestal
    promptRav.KeyboardKeyCode = Enum.KeyCode.F -- E is Stomp
    promptRav.RequiresLineOfSight = false
    promptRav.Parent = pedRav

    createTitanHoloCard(pedRav, "Ravager", "The Ravager", "[Colossal Apex Brawler]", {
        Health = "3,000 HP",
        Speed = "28 / 44 Sprint",
        Power = "Extreme Burst",
        Reach = "Close Quarters",
    }, { "Claw Swipe Combo", "Ground Stomp", "Primal Roar" }, Color3.fromRGB(255, 110, 20))

    createDisplayStatue(
        hallFolder,
        "Ravager",
        "Ravager",
        CFrame.new(pedRavPos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(180), 0),
        Color3.fromRGB(255, 100, 20)
    )

    -- Brontara Pedestal (Right, 38 x 38 studs)
    local pedBronPos = terraceOrigin + Vector3.new(75, 2, 0)
    local pedBron = createPart(
        hallFolder,
        "Pedestal_Brontara",
        Vector3.new(38, 4, 38),
        CFrame.new(pedBronPos),
        Enum.Material.Basalt,
        Color3.fromRGB(22, 20, 25)
    )
    local pedBronGlow = createPart(
        hallFolder,
        "PedBron_GlowRing",
        Vector3.new(40, 0.5, 40),
        CFrame.new(pedBronPos + Vector3.new(0, -1.7, 0)),
        Enum.Material.Neon,
        Color3.fromRGB(255, 50, 15),
        false
    )
    pedBronGlow.CastShadow = false

    local promptBron = Instance.new("ProximityPrompt")
    promptBron.Name = "Prompt"
    promptBron.ObjectText = "Brontara"
    promptBron.ActionText = "Awaken Brontara"
    promptBron.HoldDuration = 0.5
    promptBron.MaxActivationDistance = 42 -- Titans are ~20 studs wide and the statue fills the pedestal
    promptBron.KeyboardKeyCode = Enum.KeyCode.F -- E is Stomp
    promptBron.RequiresLineOfSight = false
    promptBron.Parent = pedBron

    createTitanHoloCard(pedBron, "Brontara", "Brontara", "[Armored Behemoth Colossus]", {
        Health = "5,500 HP",
        Speed = "18 / 28 Sprint",
        Power = "Crushing Cleave",
        Reach = "Colossal Sweeping Arc",
    }, { "Heavy Tail Sweep", "Seismic Heavy Stomp", "Volcanic Neck Strike", "Magma Roar" }, Color3.fromRGB(255, 55, 20))

    createDisplayStatue(
        hallFolder,
        "Brontara",
        "Brontara",
        CFrame.new(pedBronPos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(180), 0),
        Color3.fromRGB(255, 55, 20)
    )

    -- =========================================================================
    -- TIER 3: THE STARGATE PROMONTORY (Y = 560, 260 x 120 studs High Ridge)
    -- =========================================================================
    local stargateFolder = Instance.new("Folder")
    stargateFolder.Name = "StargatePromontory"
    stargateFolder.Parent = hub

    local promontoryOrigin = hubOrigin + Vector3.new(0, 40, 180)
    local promFloor = createPart(
        stargateFolder,
        "PromontoryFloor",
        Vector3.new(260, 8, 120),
        CFrame.new(promontoryOrigin.X, promontoryOrigin.Y - 4, promontoryOrigin.Z),
        Enum.Material.Basalt,
        Color3.fromRGB(28, 26, 32)
    )
    promFloor.CastShadow = true

    -- Grand Ascending Stairs (70 studs wide)
    for i = 1, 14 do
        local stepY = hubOrigin.Y + (i * 2.85)
        local stepZ = hubOrigin.Z + 75 + (i * 7)
        createPart(
            stargateFolder,
            "PromStep_" .. i,
            Vector3.new(70, 3, 7.5),
            CFrame.new(hubOrigin.X, stepY - 1.5, stepZ),
            Enum.Material.Slate,
            Color3.fromRGB(36, 34, 40)
        )
    end

    -- Portal: SmallTown (42-stud Runic Stargate, Left Arch)
    local portalSTPos = promontoryOrigin + Vector3.new(-70, 0, 0)
    local portalSTModel = Instance.new("Model")
    portalSTModel.Name = "Portal_SmallTown"

    local archST_L = createPart(
        portalSTModel,
        "ArchPillar_L",
        Vector3.new(6, 42, 6),
        CFrame.new(portalSTPos + Vector3.new(-16, 21, 0)),
        Enum.Material.Basalt,
        Color3.fromRGB(25, 23, 28)
    )
    local archST_R = createPart(
        portalSTModel,
        "ArchPillar_R",
        Vector3.new(6, 42, 6),
        CFrame.new(portalSTPos + Vector3.new(16, 21, 0)),
        Enum.Material.Basalt,
        Color3.fromRGB(25, 23, 28)
    )
    local archST_Top = createPart(
        portalSTModel,
        "ArchBeam",
        Vector3.new(38, 8, 8),
        CFrame.new(portalSTPos + Vector3.new(0, 42, 0)),
        Enum.Material.Slate,
        Color3.fromRGB(35, 32, 38)
    )

    createLightningConductor(portalSTModel, Vector3.new(portalSTPos.X, promontoryOrigin.Y + 46, portalSTPos.Z), 14)

    local fieldST = createPart(
        portalSTModel,
        "PortalField",
        Vector3.new(26, 34, 2.5),
        CFrame.new(portalSTPos + Vector3.new(0, 18, 0)),
        Enum.Material.Neon,
        Color3.fromRGB(0, 215, 255),
        false
    )
    fieldST.Transparency = 0.3
    fieldST.CastShadow = false

    local lightST = Instance.new("PointLight")
    lightST.Color = Color3.fromRGB(0, 215, 255)
    lightST.Range = 45
    lightST.Brightness = 4.5
    lightST.Parent = fieldST

    local promptST = Instance.new("ProximityPrompt")
    promptST.Name = "Prompt"
    promptST.ObjectText = "SmallTown"
    promptST.ActionText = "Deploy to SmallTown"
    promptST.HoldDuration = 0.5
    promptST.MaxActivationDistance = 28
    promptST.KeyboardKeyCode = Enum.KeyCode.F -- E is Stomp
    promptST.RequiresLineOfSight = false
    promptST.Parent = fieldST

    portalSTModel.PrimaryPart = archST_Top
    portalSTModel.Parent = stargateFolder

    -- Portal: Metrovale (42-stud Runic Stargate, Right Arch)
    local portalMVPos = promontoryOrigin + Vector3.new(70, 0, 0)
    local portalMVModel = Instance.new("Model")
    portalMVModel.Name = "Portal_Metrovale"

    local archMV_L = createPart(
        portalMVModel,
        "ArchPillar_L",
        Vector3.new(6, 42, 6),
        CFrame.new(portalMVPos + Vector3.new(-16, 21, 0)),
        Enum.Material.Basalt,
        Color3.fromRGB(25, 23, 28)
    )
    local archMV_R = createPart(
        portalMVModel,
        "ArchPillar_R",
        Vector3.new(6, 42, 6),
        CFrame.new(portalMVPos + Vector3.new(16, 21, 0)),
        Enum.Material.Basalt,
        Color3.fromRGB(25, 23, 28)
    )
    local archMV_Top = createPart(
        portalMVModel,
        "ArchBeam",
        Vector3.new(38, 8, 8),
        CFrame.new(portalMVPos + Vector3.new(0, 42, 0)),
        Enum.Material.Slate,
        Color3.fromRGB(35, 32, 38)
    )

    createLightningConductor(portalMVModel, Vector3.new(portalMVPos.X, promontoryOrigin.Y + 46, portalMVPos.Z), 14)

    local fieldMV = createPart(
        portalMVModel,
        "PortalField",
        Vector3.new(26, 34, 2.5),
        CFrame.new(portalMVPos + Vector3.new(0, 18, 0)),
        Enum.Material.Neon,
        Color3.fromRGB(190, 60, 255),
        false
    )
    fieldMV.Transparency = 0.3
    fieldMV.CastShadow = false

    local lightMV = Instance.new("PointLight")
    lightMV.Color = Color3.fromRGB(190, 60, 255)
    lightMV.Range = 45
    lightMV.Brightness = 4.5
    lightMV.Parent = fieldMV

    local promptMV = Instance.new("ProximityPrompt")
    promptMV.Name = "Prompt"
    promptMV.ObjectText = "Metrovale"
    promptMV.ActionText = "Deploy to Metrovale"
    promptMV.HoldDuration = 0.5
    promptMV.MaxActivationDistance = 28
    promptMV.KeyboardKeyCode = Enum.KeyCode.F -- E is Stomp
    promptMV.RequiresLineOfSight = false
    promptMV.Parent = fieldMV

    portalMVModel.PrimaryPart = archMV_Top
    portalMVModel.Parent = stargateFolder

    -- =========================================================================
    -- TIER 4: THE COLOSSEUM PROVING GROUNDS (Y = 480, 360 x 360 studs Sunken Pit)
    -- =========================================================================
    local arenaFolder = Instance.new("Folder")
    arenaFolder.Name = "ColosseumProvingGrounds"
    arenaFolder.Parent = hub

    local arenaOrigin = hubOrigin + Vector3.new(0, -40, -420)

    -- Sunken Arena Floor (360 x 360 studs)
    local arenaFloor = createPart(
        arenaFolder,
        "ColosseumFloor",
        Vector3.new(360, 10, 360),
        CFrame.new(arenaOrigin.X, arenaOrigin.Y - 5, arenaOrigin.Z),
        Enum.Material.Basalt,
        Color3.fromRGB(30, 28, 34)
    )
    arenaFloor.CastShadow = true

    -- Perimeter Colosseum Amphitheater Walls (45 studs tall)
    local wallThickness = 12
    local wallHeight = 45
    createPart(
        arenaFolder,
        "Wall_North",
        Vector3.new(360, wallHeight, wallThickness),
        CFrame.new(arenaOrigin.X, arenaOrigin.Y + (wallHeight / 2), arenaOrigin.Z - 180),
        Enum.Material.Slate,
        Color3.fromRGB(40, 38, 44)
    )
    createPart(
        arenaFolder,
        "Wall_South",
        Vector3.new(360, wallHeight, wallThickness),
        CFrame.new(arenaOrigin.X, arenaOrigin.Y + (wallHeight / 2), arenaOrigin.Z + 180),
        Enum.Material.Slate,
        Color3.fromRGB(40, 38, 44)
    )
    createPart(
        arenaFolder,
        "Wall_West",
        Vector3.new(wallThickness, wallHeight, 360),
        CFrame.new(arenaOrigin.X - 180, arenaOrigin.Y + (wallHeight / 2), arenaOrigin.Z),
        Enum.Material.Slate,
        Color3.fromRGB(40, 38, 44)
    )
    createPart(
        arenaFolder,
        "Wall_East",
        Vector3.new(wallThickness, wallHeight, 360),
        CFrame.new(arenaOrigin.X + 180, arenaOrigin.Y + (wallHeight / 2), arenaOrigin.Z),
        Enum.Material.Slate,
        Color3.fromRGB(40, 38, 44)
    )

    -- Grand Descending Bridge from Plaza to Colosseum (46 studs wide, 170 studs long)
    local bridgeLength = 170
    local bridgeAngle = math.rad(-14)
    local bridgeCFrame = CFrame.new(hubOrigin.X, hubOrigin.Y - 20, hubOrigin.Z - 215) * CFrame.Angles(bridgeAngle, 0, 0)
    local bridge = createPart(
        arenaFolder,
        "ColosseumBridge",
        Vector3.new(46, 5, bridgeLength),
        bridgeCFrame,
        Enum.Material.Slate,
        Color3.fromRGB(38, 36, 42)
    )

    -- Bastion Titan DPS Dummy (Centered in Colosseum)
    createBastionDPSDummy(arenaFolder, CFrame.new(arenaOrigin.X, arenaOrigin.Y, arenaOrigin.Z))

    -- 5 Strategic Practice Monoliths across Colosseum
    local pillarPositions = {
        { Name = "Pillar_Alpha", Pos = arenaOrigin + Vector3.new(-85, 0, -75) },
        { Name = "Pillar_Beta", Pos = arenaOrigin + Vector3.new(85, 0, -75) },
        { Name = "Pillar_Gamma", Pos = arenaOrigin + Vector3.new(-110, 0, 65) },
        { Name = "Pillar_Delta", Pos = arenaOrigin + Vector3.new(110, 0, 65) },
        { Name = "Pillar_Epsilon", Pos = arenaOrigin + Vector3.new(0, 0, 110) },
    }

    for _, pInfo in ipairs(pillarPositions) do
        local pil = createPart(
            arenaFolder,
            pInfo.Name,
            Vector3.new(10, 38, 10),
            CFrame.new(pInfo.Pos + Vector3.new(0, 19, 0)),
            Enum.Material.Basalt,
            Color3.fromRGB(35, 32, 38)
        )
        pil:SetAttribute("BuildingId", pInfo.Name)
        pil:SetAttribute("BuildingName", "Practice Monolith")
        pil:SetAttribute("BuildingType", "TrainingPillar")
        pil:SetAttribute("MaxHealth", 10000)
        pil:SetAttribute("CurrentHealth", 10000)
        pil:SetAttribute("DestructionReward", 0)
        pil:SetAttribute("DestructionPoints", 10)
        pil:SetAttribute("DestructionTier", 2)
        pil:SetAttribute("IsTrainingDummy", true)
        pil:SetAttribute("IsDestroyed", false)

        local core = createPart(
            pil,
            pInfo.Name .. "_Core",
            Vector3.new(5, 32, 5),
            CFrame.new(pInfo.Pos + Vector3.new(0, 19, 0)),
            Enum.Material.Neon,
            Color3.fromRGB(255, 95, 15),
            false
        )
        core.CastShadow = false

        createLightningConductor(pil, pInfo.Pos + Vector3.new(0, 38, 0), 10)
    end

    -- Proving Grounds Lighting (Floodlight pylons, runes, uplights, dummy staging, bridge lamps)
    setupColosseumLighting(arenaFolder, arenaOrigin, hubOrigin)

    -- =========================================================================
    -- TITAN MAGMA LAUNCH PADS (Inter-Tier High Velocity Travel)
    -- =========================================================================
    local launchFolder = Instance.new("Folder")
    launchFolder.Name = "LaunchPads"
    launchFolder.Parent = hub

    -- 1. Plaza -> Colosseum Jump Pad (Launches South down into Arena)
    createLaunchPad(
        launchFolder,
        "Pad_PlazaToColosseum",
        CFrame.new(hubOrigin.X, hubOrigin.Y + 0.8, hubOrigin.Z - 170),
        Vector3.new(0, 140, -280),
        "TO PROVING GROUNDS"
    )

    -- 2. Colosseum -> Plaza Jump Pad (Launches North back up to Plaza)
    createLaunchPad(
        launchFolder,
        "Pad_ColosseumToPlaza",
        CFrame.new(arenaOrigin.X, arenaOrigin.Y + 0.8, arenaOrigin.Z + 155),
        Vector3.new(0, 180, 280),
        "RETURN TO PLAZA"
    )

    -- 3. Plaza -> Stargate Spire Jump Pad (Launches South up to Promontory)
    createLaunchPad(
        launchFolder,
        "Pad_PlazaToStargates",
        CFrame.new(hubOrigin.X, hubOrigin.Y + 0.8, hubOrigin.Z + 95),
        Vector3.new(0, 145, 200),
        "TO STARGATES"
    )

    -- 4. Plaza -> Hall of Titans Jump Pad (Launches North up to Showcase)
    createLaunchPad(
        launchFolder,
        "Pad_PlazaToTitans",
        CFrame.new(hubOrigin.X, hubOrigin.Y + 0.8, hubOrigin.Z - 60),
        Vector3.new(0, 120, -160),
        "TO HALL OF TITANS"
    )

    -- =========================================================================
    -- VOLCANIC CALDERA MONOLITHS & SKYBEAMS (460 studs radius)
    -- =========================================================================
    local vistaFolder = Instance.new("Folder")
    vistaFolder.Name = "CalderaVista"
    vistaFolder.Parent = hub

    -- 16 Towering Jagged Perimeter Basalt Spires (460 studs radius)
    for i = 1, 16 do
        local angle = math.rad((i - 1) * 22.5)
        local radius = 460
        local spireX = hubOrigin.X + math.cos(angle) * radius
        local spireZ = hubOrigin.Z + math.sin(angle) * radius
        local spireHeight = 180 + ((i % 5) * 35)

        local spire = createPart(
            vistaFolder,
            "Spire_" .. i,
            Vector3.new(24, spireHeight, 24),
            CFrame.new(spireX, hubOrigin.Y + (spireHeight / 2) - 60, spireZ)
                * CFrame.Angles(math.rad((i % 3) * 3), 0, math.rad((i % 2) * -4)),
            Enum.Material.Basalt,
            Color3.fromRGB(20, 18, 22),
            false
        )
        spire.CastShadow = false

        -- Conductor tip on spire summit
        local tipPos = Vector3.new(spireX, hubOrigin.Y + spireHeight - 60, spireZ)
        createLightningConductor(spire, tipPos, 14)
    end

    -- 4 Colossal Cardinal Skybeams (1600 studs tall) with Vertical Lightning Helixes
    local beamOffsets = {
        Vector3.new(0, 0, -200),
        Vector3.new(0, 0, 200),
        Vector3.new(-200, 0, 0),
        Vector3.new(200, 0, 0),
    }

    for idx, bOff in ipairs(beamOffsets) do
        local beamPos = hubOrigin + bOff
        local beam = createPart(
            vistaFolder,
            "SkyBeam_" .. idx,
            Vector3.new(5, 1600, 5),
            CFrame.new(beamPos.X, hubOrigin.Y + 800, beamPos.Z),
            Enum.Material.Neon,
            if idx % 2 == 0 then Color3.fromRGB(255, 110, 20) else Color3.fromRGB(0, 220, 255),
            false
        )
        beam.Transparency = 0.45
        beam.CastShadow = false

        local bAtt = Instance.new("Attachment")
        bAtt.Position = beamPos + Vector3.new(0, 10, 0)
        bAtt.Parent = beam

        local bEmitter = Instance.new("ParticleEmitter")
        bEmitter.Color = ColorSequence.new(Color3.fromRGB(0, 230, 255), Color3.fromRGB(255, 255, 255))
        bEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0) })
        bEmitter.Speed = NumberRange.new(50, 120)
        bEmitter.SpreadAngle = Vector2.new(5, 5)
        bEmitter.Lifetime = NumberRange.new(1.5, 3.0)
        bEmitter.Rate = 25
        bEmitter.LightEmission = 1
        bEmitter.Parent = bAtt
    end

    hub.Parent = Workspace
    print(
        string.format(
            "[HubService] ✅ Grand Kaiju Megastructure successfully built with %d descendants across 850+ studs!",
            #hub:GetDescendants()
        )
    )

    return hub
end

--[=[
    Initializes HubService lifecycle and connects interactive systems.
    Preserves manual Studio edits if KaijuHub already exists in Workspace.
]=]
function HubService.Init()
    print("[HubService] Initializing HubService...")
    setupAtmosphere()

    -- Clean up rogue default spawn at origin if any
    local defaultSpawn = Workspace:FindFirstChild("SpawnLocation")
    if defaultSpawn and defaultSpawn.Parent == Workspace then defaultSpawn:Destroy() end

    local existing = Workspace:FindFirstChild("KaijuHub")
    local forceRegen = Workspace:GetAttribute("ForceRegenerateHub") == true

    if existing and not forceRegen then
        print(
            string.format(
                "[HubService] 🏰 Preserving existing KaijuHub in Workspace (%d descendants). Manual Studio edits are preserved!",
                #existing:GetDescendants()
            )
        )

        -- Register lightning strike targets from existing structure
        table.clear(lightningStrikeTargets)
        for _, desc in ipairs(existing:GetDescendants()) do
            if desc:IsA("BasePart") and desc.Name == "ConductorTip" then table.insert(lightningStrikeTargets, desc.Position) end
        end
        print(string.format("[HubService] ⚡ Registered %d lightning conductor strike targets.", #lightningStrikeTargets))

        -- Bind launch pads
        local launchPadsFolder = existing:FindFirstChild("LaunchPads")
        if launchPadsFolder then
            for _, pad in ipairs(launchPadsFolder:GetChildren()) do
                if pad:IsA("Model") then bindLaunchPad(pad) end
            end
        end

        -- Ensure Proving Grounds Arena Lighting exists
        local arenaFolder = existing:FindFirstChild("ColosseumProvingGrounds") :: Folder?
        if arenaFolder and not arenaFolder:FindFirstChild("ArenaLighting") then
            local hubOrigin = Vector3.new(0, 520, -5000)
            local arenaOrigin = hubOrigin + Vector3.new(0, -40, -420)
            setupColosseumLighting(arenaFolder, arenaOrigin, hubOrigin)
            print("[HubService] 💡 Retrofitted Proving Grounds Arena Lighting into existing KaijuHub.")
        end
    else
        HubService.ConstructGrandSanctuary()
    end
end

--[=[
    Records incoming damage on the Bastion Titan dummy and updates live overhead DPS GUI.
]=]
function HubService.RecordDummyDamage(building: Model, actualDamage: number, newHp: number, maxHp: number, combo: number)
    if building.Name == "Bastion_Titan_Dummy" then
        local now = os.clock()
        dummyCombatState.TotalDamage += actualDamage
        dummyCombatState.ComboStreak += 1
        if actualDamage > dummyCombatState.HighestHit then dummyCombatState.HighestHit = actualDamage end
        dummyCombatState.LastHitTime = now

        table.insert(dummyCombatState.DamageWindow, { Time = now, Damage = actualDamage })

        local windowStart = now - 3.0
        local windowDmg = 0
        local filtered = {}
        for _, entry in ipairs(dummyCombatState.DamageWindow) do
            if entry.Time >= windowStart then
                windowDmg += entry.Damage
                table.insert(filtered, entry)
            end
        end
        dummyCombatState.DamageWindow = filtered

        local rollingDPS = math.floor(windowDmg / 3.0)

        local core = building:FindFirstChild("Core")
        local bg = core and core:FindFirstChild("DPS_Billboard")
        local frame = bg and bg:FindFirstChild("Frame")

        if frame then
            local dpsLbl = frame:FindFirstChild("DPSLabel") :: TextLabel?
            if dpsLbl then dpsLbl.Text = string.format("%s DPS", tostring(rollingDPS)) end

            local streakLbl = frame:FindFirstChild("StreakLabel") :: TextLabel?
            if streakLbl then streakLbl.Text = string.format("%d HITS  •  %.1fx COMBO", dummyCombatState.ComboStreak, combo) end

            local dmgLbl = frame:FindFirstChild("TotalDamageLabel") :: TextLabel?
            if dmgLbl then
                dmgLbl.Text = string.format("Total: %d  |  Best: %d", dummyCombatState.TotalDamage, dummyCombatState.HighestHit)
            end

            local barBg = frame:FindFirstChild("HealthBarBg")
            local barFill = barBg and barBg:FindFirstChild("HealthBarFill") :: Frame?
            if barFill then
                local pct = math.clamp(newHp / maxHp, 0, 1)
                barFill.Size = UDim2.new(pct, 0, 1, 0)
            end
        end
    end
end

--[=[
    Starts the dynamic Volcanic Lightning Storm simulation.
]=]
function HubService.StartLightningStorm()
    print("[HubService] ⚡ Starting Volcanic Thunderstorm Engine...")
    task.spawn(function()
        while true do
            -- Random strike interval: 3.5 to 6.5 seconds
            task.wait(math.random(35, 65) / 10)

            local hub = Workspace:FindFirstChild("KaijuHub")
            if hub and #lightningStrikeTargets > 0 then
                local targetIdx = math.random(1, #lightningStrikeTargets)
                local targetPos = lightningStrikeTargets[targetIdx]
                if targetPos then spawnLightningStrike(targetPos) end
            end
        end
    end)
end

--[=[
    Starts HubService runtime bindings: DPS dummy calculation and lightning storm.
]=]
function HubService.Start()
    print("[HubService] Starting HubService runtime listeners...")

    -- Launch Volcanic Thunderstorm Cycle
    HubService.StartLightningStorm()

    -- Inactivity reset loop for DPS dummy
    task.spawn(function()
        while true do
            task.wait(1.5)
            local now = os.clock()
            if dummyCombatState.LastHitTime > 0 and (now - dummyCombatState.LastHitTime) > 4.5 then
                dummyCombatState.DamageWindow = {}
                dummyCombatState.ComboStreak = 0
                dummyCombatState.LastHitTime = 0

                local hub = Workspace:FindFirstChild("KaijuHub")
                local arena = hub and hub:FindFirstChild("ColosseumProvingGrounds")
                local dummy = arena and arena:FindFirstChild("Bastion_Titan_Dummy")
                local core = dummy and dummy:FindFirstChild("Core")
                local bg = core and core:FindFirstChild("DPS_Billboard")
                local frame = bg and bg:FindFirstChild("Frame")
                if frame then
                    local dpsLbl = frame:FindFirstChild("DPSLabel") :: TextLabel?
                    if dpsLbl then dpsLbl.Text = "0 DPS" end
                    local streakLbl = frame:FindFirstChild("StreakLabel") :: TextLabel?
                    if streakLbl then streakLbl.Text = "0 HITS  •  1.0x COMBO" end
                end
            end
        end
    end)
end

return HubService
