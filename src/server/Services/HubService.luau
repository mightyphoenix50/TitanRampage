--!strict
--[[
    HubService.luau
    Responsibility:
    - Server-authoritative construction, visual management, and micro-loops for the Central Kaiju Hub.
    - Grand 4-tier Volcanic Caldera Sanctuary (450+ studs):
        Tier 1: Grand Central Plaza (Y = 520, 220-stud dia arena, master spawn, Altar of Ascension)
        Tier 2: The Hall of Titans (Y = 535, 1:1 illuminated statues of Ravager & Brontara with 3D stat cards)
        Tier 3: The Stargate Promontory (Y = 550, SmallTown and Metrovale deployment stargates)
        Tier 4: The Colosseum Proving Grounds (Y = 492, 200x200 sunken pit, Bastion DPS dummy, practice monoliths)
    - High-velocity directional Titan Launch/Boost Pads with impulse physics and particle bursts.
    - Bastion Titan DPS & Combo Testing Dummy with live damage-per-second, streak, and hit readout.
    - Full atmospheric profile (volcanic twilight Atmosphere, Bloom, ColorCorrection, skybeams, braziers).
    - Production performance optimization: 100% Anchored, CanCollide=false on cosmetics, CastShadow=false on trim.
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

-- Forward declaration of helper
local function createPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, material: Enum.Material, color: Color3, canCollide: boolean?): Part
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
        Lighting.ClockTime = 18.25 -- Atmospheric sunset/twilight
        Lighting.Brightness = 1.8
        Lighting.OutdoorAmbient = Color3.fromRGB(80, 50, 45)
        Lighting.Ambient = Color3.fromRGB(60, 40, 40)
        Lighting.ShadowSoftness = 0.2
    end)

    -- Volcanic Atmosphere
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Parent = Lighting
    end
    atmosphere.Density = 0.32
    atmosphere.Offset = 0.25
    atmosphere.Color = Color3.fromRGB(180, 80, 45)
    atmosphere.Decay = Color3.fromRGB(50, 20, 20)
    atmosphere.Glare = 0.4
    atmosphere.Haze = 2.0

    -- Crisp Magma Bloom
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Parent = Lighting
    end
    bloom.Intensity = 0.75
    bloom.Size = 24
    bloom.Threshold = 1.1

    -- Color Correction for cinematic contrast
    local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if not cc then
        cc = Instance.new("ColorCorrectionEffect")
        cc.Parent = Lighting
    end
    cc.Brightness = 0.02
    cc.Contrast = 0.12
    cc.Saturation = 0.18
    cc.TintColor = Color3.fromRGB(255, 240, 235)
end

--[=[
    Creates a rich holographic 3D billboard for Titan display pedestals.
]=]
local function createTitanHoloCard(parent: Instance, titanName: string, title: string, subtitle: string, stats: { Health: string, Speed: string, Power: string, Reach: string }, abilities: { string }, accentColor: Color3)
    local bg = Instance.new("BillboardGui")
    bg.Name = "TitanHoloCard"
    bg.Size = UDim2.new(0, 420, 0, 260)
    bg.StudsOffset = Vector3.new(0, 16, 0)
    bg.AlwaysOnTop = true
    bg.MaxDistance = 140
    bg.Parent = parent

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 12, 14)
    mainFrame.BackgroundTransparency = 0.25
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = bg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = accentColor
    stroke.Thickness = 2.5
    stroke.Transparency = 0.2
    stroke.Parent = mainFrame

    -- Title
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -20, 0, 40)
    titleLbl.Position = UDim2.new(0, 10, 0, 8)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = string.upper(title)
    titleLbl.TextColor3 = accentColor
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = 26
    titleLbl.TextXAlignment = Enum.TextXAlignment.Center
    titleLbl.Parent = mainFrame

    -- Subtitle Archetype
    local subLbl = Instance.new("TextLabel")
    subLbl.Size = UDim2.new(1, -20, 0, 20)
    subLbl.Position = UDim2.new(0, 10, 0, 46)
    subLbl.BackgroundTransparency = 1
    subLbl.Text = subtitle
    subLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    subLbl.Font = Enum.Font.GothamMedium
    subLbl.TextSize = 14
    subLbl.TextXAlignment = Enum.TextXAlignment.Center
    subLbl.Parent = mainFrame

    -- Divider
    local div = Instance.new("Frame")
    div.Size = UDim2.new(0.85, 0, 0, 1)
    div.Position = UDim2.new(0.075, 0, 0, 72)
    div.BackgroundColor3 = accentColor
    div.BackgroundTransparency = 0.5
    div.BorderSizePixel = 0
    div.Parent = mainFrame

    -- Stat grid
    local statY = 82
    local statRows = {
        { "VITALITY", stats.Health },
        { "MOBILITY", stats.Speed },
        { "MIGHT", stats.Power },
        { "REACH", stats.Reach },
    }

    for i, s in ipairs(statRows) do
        local rowY = statY + ((i - 1) * 22)
        local keyLbl = Instance.new("TextLabel")
        keyLbl.Size = UDim2.new(0.4, 0, 0, 18)
        keyLbl.Position = UDim2.new(0.08, 0, 0, rowY)
        keyLbl.BackgroundTransparency = 1
        keyLbl.Text = s[1]
        keyLbl.TextColor3 = Color3.fromRGB(160, 160, 170)
        keyLbl.Font = Enum.Font.GothamBold
        keyLbl.TextSize = 12
        keyLbl.TextXAlignment = Enum.TextXAlignment.Left
        keyLbl.Parent = mainFrame

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(0.44, 0, 0, 18)
        valLbl.Position = UDim2.new(0.48, 0, 0, rowY)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = s[2]
        valLbl.TextColor3 = Color3.fromRGB(240, 240, 240)
        valLbl.Font = Enum.Font.GothamSemibold
        valLbl.TextSize = 12
        valLbl.TextXAlignment = Enum.TextXAlignment.Right
        valLbl.Parent = mainFrame
    end

    -- Abilities label
    local abTitle = Instance.new("TextLabel")
    abTitle.Size = UDim2.new(1, -20, 0, 16)
    abTitle.Position = UDim2.new(0, 10, 0, 178)
    abTitle.BackgroundTransparency = 1
    abTitle.Text = "SIGNATURE COMBAT KIT"
    abTitle.TextColor3 = accentColor
    abTitle.Font = Enum.Font.GothamBold
    abTitle.TextSize = 11
    abTitle.TextXAlignment = Enum.TextXAlignment.Center
    abTitle.Parent = mainFrame

    local abList = Instance.new("TextLabel")
    abList.Size = UDim2.new(1, -20, 0, 48)
    abList.Position = UDim2.new(0, 10, 0, 196)
    abList.BackgroundTransparency = 1
    abList.Text = table.concat(abilities, "  •  ")
    abList.TextColor3 = Color3.fromRGB(220, 220, 220)
    abList.Font = Enum.Font.Gotham
    abList.TextSize = 12
    abList.TextWrapped = true
    abList.TextXAlignment = Enum.TextXAlignment.Center
    abList.Parent = mainFrame
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

    -- Strip scripts, humanoid animators, and non-visual logic to save physics overhead
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
    if hum then
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end

    statue:PivotTo(statueCFrame)
    statue.Parent = parent

    -- Dual stage lighting
    local underLight = Instance.new("PointLight")
    underLight.Name = "StageUnderglow"
    underLight.Color = accentColor
    underLight.Range = 32
    underLight.Brightness = 4
    underLight.Shadows = false
    underLight.Parent = parent

    local spotPart = Instance.new("Part")
    spotPart.Name = "SpotlightRig"
    spotPart.Size = Vector3.new(2, 2, 2)
    spotPart.CFrame = statueCFrame * CFrame.new(0, 35, 18) * CFrame.Angles(math.rad(-60), 0, 0)
    spotPart.Transparency = 1
    spotPart.Anchored = true
    spotPart.CanCollide = false
    spotPart.CanTouch = false
    spotPart.Parent = parent

    local spot = Instance.new("SpotLight")
    spot.Color = Color3.fromRGB(255, 230, 200)
    spot.Range = 60
    spot.Brightness = 3
    spot.Angle = 45
    spot.Shadows = true
    spot.Parent = spotPart

    return statue
end

--[=[
    Constructs a directional Magma Launch Pad.
]=]
local function createLaunchPad(parent: Instance, name: string, cframe: CFrame, launchVelocity: Vector3, label: string)
    local padModel = Instance.new("Model")
    padModel.Name = name

    -- Outer ring
    local base = createPart(padModel, "PadBase", Vector3.new(18, 1.2, 18), cframe, Enum.Material.SmoothPlastic, Color3.fromRGB(20, 20, 24), true)
    base.CastShadow = false

    -- Glowing inner pad
    local inner = createPart(padModel, "TriggerPad", Vector3.new(14, 1.4, 14), cframe * CFrame.new(0, 0.2, 0), Enum.Material.Neon, Color3.fromRGB(255, 95, 15), false)
    inner.CastShadow = false

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 110, 20)
    light.Range = 24
    light.Brightness = 3
    light.Parent = inner

    -- Overhead holographic billboard
    local bg = Instance.new("BillboardGui")
    bg.Size = UDim2.new(0, 160, 0, 40)
    bg.StudsOffset = Vector3.new(0, 4, 0)
    bg.AlwaysOnTop = true
    bg.MaxDistance = 80
    bg.Parent = inner

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "▲ " .. label .. " ▲"
    lbl.TextColor3 = Color3.fromRGB(255, 180, 50)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = 14
    lbl.Parent = bg

    -- Launch impulse binding
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
            
            -- Spawn fiery launch burst
            local burst = Instance.new("Part")
            burst.Size = Vector3.new(12, 1, 12)
            burst.CFrame = inner.CFrame
            burst.Anchored = true
            burst.CanCollide = false
            burst.CanTouch = false
            burst.Material = Enum.Material.Neon
            burst.Color = Color3.fromRGB(255, 150, 40)
            burst.Transparency = 0.2
            burst.Parent = Workspace

            local tw = TweenService:Create(burst, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = Vector3.new(24, 0.5, 24),
                Transparency = 1,
            })
            tw:Play()
            tw.Completed:Connect(function()
                burst:Destroy()
            end)
        end
    end)

    padModel.Parent = parent
    return padModel
end

--[=[
    Constructs the Bastion Titan DPS dummy with live overhead damage readout.
]=]
local function createBastionDPSDummy(parent: Instance, cframe: CFrame): Model
    local dummyModel = Instance.new("Model")
    dummyModel.Name = "Bastion_Titan_Dummy"

    local core = createPart(dummyModel, "Core", Vector3.new(14, 38, 14), cframe * CFrame.new(0, 19, 0), Enum.Material.Basalt, Color3.fromRGB(30, 28, 32), true)
    dummyModel.PrimaryPart = core

    -- Armor plates
    local chest = createPart(dummyModel, "ChestPlate", Vector3.new(16, 14, 16), cframe * CFrame.new(0, 26, 0), Enum.Material.Slate, Color3.fromRGB(45, 42, 48), true)
    local head = createPart(dummyModel, "HeadCore", Vector3.new(8, 8, 8), cframe * CFrame.new(0, 38, 0), Enum.Material.Basalt, Color3.fromRGB(25, 25, 30), true)
    
    local eye = createPart(dummyModel, "EyeCore", Vector3.new(4, 1.5, 1), cframe * CFrame.new(0, 38, 4.2), Enum.Material.Neon, Color3.fromRGB(255, 60, 20), false)
    eye.CastShadow = false

    -- Dummy attributes
    dummyModel:SetAttribute("BuildingId", "Bastion_DPS_Dummy")
    dummyModel:SetAttribute("BuildingName", "Ancient Bastion Monolith")
    dummyModel:SetAttribute("BuildingType", "TrainingDummy")
    dummyModel:SetAttribute("MaxHealth", 50000)
    dummyModel:SetAttribute("CurrentHealth", 50000)
    dummyModel:SetAttribute("DestructionReward", 0)
    dummyModel:SetAttribute("DestructionPoints", 15)
    dummyModel:SetAttribute("DestructionTier", 3)
    dummyModel:SetAttribute("IsTrainingDummy", true)
    dummyModel:SetAttribute("IsDestroyed", false)

    -- Live DPS Billboard
    local bg = Instance.new("BillboardGui")
    bg.Name = "DPS_Billboard"
    bg.Size = UDim2.new(0, 340, 0, 180)
    bg.StudsOffset = Vector3.new(0, 24, 0)
    bg.AlwaysOnTop = true
    bg.MaxDistance = 150
    bg.Parent = core

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(15, 12, 18)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = bg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 90, 20)
    stroke.Thickness = 2
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "DummyTitle"
    title.Size = UDim2.new(1, 0, 0, 28)
    title.Position = UDim2.new(0, 0, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "ANCIENT BASTION MONOLITH"
    title.TextColor3 = Color3.fromRGB(255, 120, 40)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 16
    title.Parent = frame

    local dpsLbl = Instance.new("TextLabel")
    dpsLbl.Name = "DPSLabel"
    dpsLbl.Size = UDim2.new(1, 0, 0, 40)
    dpsLbl.Position = UDim2.new(0, 0, 0, 36)
    dpsLbl.BackgroundTransparency = 1
    dpsLbl.Text = "0 DPS"
    dpsLbl.TextColor3 = Color3.fromRGB(255, 230, 80)
    dpsLbl.Font = Enum.Font.GothamBlack
    dpsLbl.TextSize = 30
    dpsLbl.Parent = frame

    local streakLbl = Instance.new("TextLabel")
    streakLbl.Name = "StreakLabel"
    streakLbl.Size = UDim2.new(1, 0, 0, 22)
    streakLbl.Position = UDim2.new(0, 0, 0, 80)
    streakLbl.BackgroundTransparency = 1
    streakLbl.Text = "0 HITS  •  1.0x COMBO"
    streakLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    streakLbl.Font = Enum.Font.GothamBold
    streakLbl.TextSize = 13
    streakLbl.Parent = frame

    local dmgLbl = Instance.new("TextLabel")
    dmgLbl.Name = "TotalDamageLabel"
    dmgLbl.Size = UDim2.new(1, 0, 0, 20)
    dmgLbl.Position = UDim2.new(0, 0, 0, 104)
    dmgLbl.BackgroundTransparency = 1
    dmgLbl.Text = "Total Damage: 0  |  Best Hit: 0"
    dmgLbl.TextColor3 = Color3.fromRGB(160, 160, 170)
    dmgLbl.Font = Enum.Font.GothamMedium
    dmgLbl.TextSize = 12
    dmgLbl.Parent = frame

    -- Health bar background
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
    Constructs the entire 4-Tier Volcanic Caldera Sanctuary in Workspace.
]=]
function HubService.ConstructGrandSanctuary()
    print("[HubService] 🌋 Constructing Grand Volcanic Kaiju Sanctuary (450+ studs)...")

    local existing = Workspace:FindFirstChild("KaijuHub")
    if existing then
        existing:Destroy()
    end

    local hub = Instance.new("Folder")
    hub.Name = "KaijuHub"

    local hubOrigin = Vector3.new(0, 520, -5000)

    -- =========================================================================
    -- TIER 1: GRAND CENTRAL PLAZA (Y = 520, 220 studs diameter)
    -- =========================================================================
    local plazaFolder = Instance.new("Folder")
    plazaFolder.Name = "GrandCentralPlaza"
    plazaFolder.Parent = hub

    -- Main Arena Disc
    local mainFloor = createPart(plazaFolder, "PlazaFloor", Vector3.new(220, 6, 220), CFrame.new(hubOrigin.X, hubOrigin.Y - 3, hubOrigin.Z), Enum.Material.Basalt, Color3.fromRGB(32, 30, 35))
    mainFloor.CastShadow = true

    -- Concentric Magma Ley-Line Rings
    local ring1 = createPart(plazaFolder, "MagmaRune_Ring1", Vector3.new(200, 0.4, 200), CFrame.new(hubOrigin.X, hubOrigin.Y + 0.2, hubOrigin.Z), Enum.Material.Neon, Color3.fromRGB(255, 80, 15), false)
    ring1.CastShadow = false

    local ring2 = createPart(plazaFolder, "MagmaRune_Ring2", Vector3.new(140, 0.5, 140), CFrame.new(hubOrigin.X, hubOrigin.Y + 0.25, hubOrigin.Z), Enum.Material.Neon, Color3.fromRGB(255, 110, 25), false)
    ring2.CastShadow = false

    -- Central Elevated Spawn Dais
    local centerDais = createPart(plazaFolder, "CenterDais", Vector3.new(50, 2.5, 50), CFrame.new(hubOrigin.X, hubOrigin.Y + 1.25, hubOrigin.Z), Enum.Material.Slate, Color3.fromRGB(40, 38, 44))
    
    local spawnLoc = Instance.new("SpawnLocation")
    spawnLoc.Name = "HubSpawnLocation"
    spawnLoc.Size = Vector3.new(20, 1.2, 20)
    spawnLoc.CFrame = CFrame.new(hubOrigin.X, hubOrigin.Y + 3.1, hubOrigin.Z)
    spawnLoc.Anchored = true
    spawnLoc.CanCollide = true
    spawnLoc.Material = Enum.Material.Neon
    spawnLoc.Color = Color3.fromRGB(255, 130, 30)
    spawnLoc.Duration = 0
    spawnLoc.Neutral = true
    spawnLoc.Parent = hub

    local spawnLight = Instance.new("PointLight")
    spawnLight.Color = Color3.fromRGB(255, 130, 30)
    spawnLight.Range = 35
    spawnLight.Brightness = 3
    spawnLight.Parent = spawnLoc

    -- Altar of Ascension (Progression Altar)
    local altarModel = Instance.new("Model")
    altarModel.Name = "AltarOfAscension"
    local altarBase = createPart(altarModel, "AltarBase", Vector3.new(18, 3, 18), CFrame.new(hubOrigin.X, hubOrigin.Y + 1.5, hubOrigin.Z + 75), Enum.Material.Basalt, Color3.fromRGB(25, 23, 28))
    local altarMonolith = createPart(altarModel, "Monolith", Vector3.new(10, 24, 6), CFrame.new(hubOrigin.X, hubOrigin.Y + 14, hubOrigin.Z + 75), Enum.Material.Slate, Color3.fromRGB(38, 35, 42))
    local runeCore = createPart(altarModel, "RuneCore", Vector3.new(6, 16, 2), CFrame.new(hubOrigin.X, hubOrigin.Y + 15, hubOrigin.Z + 72.5), Enum.Material.Neon, Color3.fromRGB(255, 120, 20), false)
    runeCore.CastShadow = false

    local altarPrompt = Instance.new("ProximityPrompt")
    altarPrompt.Name = "Prompt"
    altarPrompt.ActionText = "Ascend Titan Stats"
    altarPrompt.ObjectText = "Altar of Ascension"
    altarPrompt.HoldDuration = 0.5
    altarPrompt.MaxActivationDistance = 22
    altarPrompt.RequiresLineOfSight = false
    altarPrompt.Parent = altarMonolith

    altarModel.PrimaryPart = altarMonolith
    altarModel.Parent = plazaFolder

    -- =========================================================================
    -- TIER 2: THE HALL OF TITANS (Y = 535, Elevated North Terrace)
    -- =========================================================================
    local hallFolder = Instance.new("Folder")
    hallFolder.Name = "HallOfTitans"
    hallFolder.Parent = hub

    local terraceOrigin = hubOrigin + Vector3.new(0, 14, -80)

    -- Elevated Terrace Foundation
    local terraceFloor = createPart(hallFolder, "TerraceFloor", Vector3.new(160, 6, 80), CFrame.new(terraceOrigin.X, terraceOrigin.Y - 3, terraceOrigin.Z), Enum.Material.Basalt, Color3.fromRGB(28, 26, 30))
    terraceFloor.CastShadow = true

    -- Grand Steps connecting Plaza to Terrace
    for i = 1, 7 do
        local stepY = hubOrigin.Y + (i * 2)
        local stepZ = hubOrigin.Z - 40 - (i * 5)
        createPart(hallFolder, "Step_" .. i, Vector3.new(60, 2, 6), CFrame.new(hubOrigin.X, stepY - 1, stepZ), Enum.Material.Slate, Color3.fromRGB(35, 33, 38))
    end

    -- Flanking Obsidian Columns
    for _, xOff in ipairs({ -70, -25, 25, 70 }) do
        local col = createPart(hallFolder, "Pillar_" .. xOff, Vector3.new(8, 48, 8), CFrame.new(terraceOrigin.X + xOff, terraceOrigin.Y + 24, terraceOrigin.Z - 30), Enum.Material.Basalt, Color3.fromRGB(20, 18, 22))
        local cap = createPart(hallFolder, "PillarCap_" .. xOff, Vector3.new(12, 4, 12), CFrame.new(terraceOrigin.X + xOff, terraceOrigin.Y + 48, terraceOrigin.Z - 30), Enum.Material.Slate, Color3.fromRGB(35, 32, 38))
    end

    -- Ravager Pedestal (Left)
    local pedRavPos = terraceOrigin + Vector3.new(-42, 1.5, 0)
    local pedRav = createPart(hallFolder, "Pedestal_Ravager", Vector3.new(22, 3, 22), CFrame.new(pedRavPos), Enum.Material.Basalt, Color3.fromRGB(22, 20, 25))
    local pedRavGlow = createPart(hallFolder, "PedRav_GlowRing", Vector3.new(24, 0.4, 24), CFrame.new(pedRavPos + Vector3.new(0, -1.2, 0)), Enum.Material.Neon, Color3.fromRGB(255, 95, 15), false)
    pedRavGlow.CastShadow = false

    local promptRav = Instance.new("ProximityPrompt")
    promptRav.Name = "Prompt"
    promptRav.ObjectText = "Ravager"
    promptRav.ActionText = "Awaken The Ravager"
    promptRav.HoldDuration = 0.5
    promptRav.MaxActivationDistance = 24
    promptRav.RequiresLineOfSight = false
    promptRav.Parent = pedRav

    createTitanHoloCard(pedRav, "Ravager", "The Ravager", "[Colossal Apex Brawler]", {
        Health = "3,000 HP",
        Speed = "28 Studs/s",
        Power = "Extreme Burst",
        Reach = "Close Quarters",
    }, { "Claw Swipe Combo", "Ground Stomp", "Primal Roar" }, Color3.fromRGB(255, 110, 20))

    createDisplayStatue(hallFolder, "Ravager", "Ravager", CFrame.new(pedRavPos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(255, 100, 20))

    -- Brontara Pedestal (Right)
    local pedBronPos = terraceOrigin + Vector3.new(42, 1.5, 0)
    local pedBron = createPart(hallFolder, "Pedestal_Brontara", Vector3.new(26, 3, 26), CFrame.new(pedBronPos), Enum.Material.Basalt, Color3.fromRGB(22, 20, 25))
    local pedBronGlow = createPart(hallFolder, "PedBron_GlowRing", Vector3.new(28, 0.4, 28), CFrame.new(pedBronPos + Vector3.new(0, -1.2, 0)), Enum.Material.Neon, Color3.fromRGB(255, 50, 15), false)
    pedBronGlow.CastShadow = false

    local promptBron = Instance.new("ProximityPrompt")
    promptBron.Name = "Prompt"
    promptBron.ObjectText = "Brontara"
    promptBron.ActionText = "Awaken Brontara"
    promptBron.HoldDuration = 0.5
    promptBron.MaxActivationDistance = 26
    promptBron.RequiresLineOfSight = false
    promptBron.Parent = pedBron

    createTitanHoloCard(pedBron, "Brontara", "Brontara", "[Armored Behemoth Colossus]", {
        Health = "5,500 HP",
        Speed = "18 Studs/s",
        Power = "Crushing Cleave",
        Reach = "Colossal Sweeping Arc",
    }, { "Heavy Tail Sweep", "Seismic Heavy Stomp", "Volcanic Neck Strike", "Magma Roar" }, Color3.fromRGB(255, 55, 20))

    createDisplayStatue(hallFolder, "Brontara", "Brontara", CFrame.new(pedBronPos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(255, 55, 20))

    -- =========================================================================
    -- TIER 3: THE STARGATE PROMONTORY (Y = 550, Elevated South Ridge)
    -- =========================================================================
    local stargateFolder = Instance.new("Folder")
    stargateFolder.Name = "StargatePromontory"
    stargateFolder.Parent = hub

    local promontoryOrigin = hubOrigin + Vector3.new(0, 30, 95)
    local promFloor = createPart(stargateFolder, "PromontoryFloor", Vector3.new(150, 6, 60), CFrame.new(promontoryOrigin.X, promontoryOrigin.Y - 3, promontoryOrigin.Z), Enum.Material.Basalt, Color3.fromRGB(28, 26, 32))
    promFloor.CastShadow = true

    -- Grand Stairs from Plaza to Promontory
    for i = 1, 10 do
        local stepY = hubOrigin.Y + (i * 3)
        local stepZ = hubOrigin.Z + 45 + (i * 5)
        createPart(stargateFolder, "PromStep_" .. i, Vector3.new(50, 3, 6), CFrame.new(hubOrigin.X, stepY - 1.5, stepZ), Enum.Material.Slate, Color3.fromRGB(36, 34, 40))
    end

    -- Portal: SmallTown (Left Arch)
    local portalSTPos = promontoryOrigin + Vector3.new(-45, 0, 0)
    local portalSTModel = Instance.new("Model")
    portalSTModel.Name = "Portal_SmallTown"
    
    local archST_L = createPart(portalSTModel, "ArchPillar_L", Vector3.new(5, 32, 5), CFrame.new(portalSTPos + Vector3.new(-12, 16, 0)), Enum.Material.Basalt, Color3.fromRGB(25, 23, 28))
    local archST_R = createPart(portalSTModel, "ArchPillar_R", Vector3.new(5, 32, 5), CFrame.new(portalSTPos + Vector3.new(12, 16, 0)), Enum.Material.Basalt, Color3.fromRGB(25, 23, 28))
    local archST_Top = createPart(portalSTModel, "ArchBeam", Vector3.new(29, 6, 6), CFrame.new(portalSTPos + Vector3.new(0, 32, 0)), Enum.Material.Slate, Color3.fromRGB(35, 32, 38))
    
    local fieldST = createPart(portalSTModel, "PortalField", Vector3.new(20, 26, 2), CFrame.new(portalSTPos + Vector3.new(0, 14, 0)), Enum.Material.Neon, Color3.fromRGB(0, 210, 255), false)
    fieldST.Transparency = 0.35
    fieldST.CastShadow = false

    local lightST = Instance.new("PointLight")
    lightST.Color = Color3.fromRGB(0, 210, 255)
    lightST.Range = 35
    lightST.Brightness = 4
    lightST.Parent = fieldST

    local promptST = Instance.new("ProximityPrompt")
    promptST.Name = "Prompt"
    promptST.ObjectText = "SmallTown"
    promptST.ActionText = "Deploy to SmallTown"
    promptST.HoldDuration = 0.5
    promptST.MaxActivationDistance = 24
    promptST.RequiresLineOfSight = false
    promptST.Parent = fieldST

    portalSTModel.PrimaryPart = archST_Top
    portalSTModel.Parent = stargateFolder

    -- Portal: Metrovale (Right Arch)
    local portalMVPos = promontoryOrigin + Vector3.new(45, 0, 0)
    local portalMVModel = Instance.new("Model")
    portalMVModel.Name = "Portal_Metrovale"

    local archMV_L = createPart(portalMVModel, "ArchPillar_L", Vector3.new(5, 32, 5), CFrame.new(portalMVPos + Vector3.new(-12, 16, 0)), Enum.Material.Basalt, Color3.fromRGB(25, 23, 28))
    local archMV_R = createPart(portalMVModel, "ArchPillar_R", Vector3.new(5, 32, 5), CFrame.new(portalMVPos + Vector3.new(12, 16, 0)), Enum.Material.Basalt, Color3.fromRGB(25, 23, 28))
    local archMV_Top = createPart(portalMVModel, "ArchBeam", Vector3.new(29, 6, 6), CFrame.new(portalMVPos + Vector3.new(0, 32, 0)), Enum.Material.Slate, Color3.fromRGB(35, 32, 38))

    local fieldMV = createPart(portalMVModel, "PortalField", Vector3.new(20, 26, 2), CFrame.new(portalMVPos + Vector3.new(0, 14, 0)), Enum.Material.Neon, Color3.fromRGB(180, 50, 255), false)
    fieldMV.Transparency = 0.35
    fieldMV.CastShadow = false

    local lightMV = Instance.new("PointLight")
    lightMV.Color = Color3.fromRGB(180, 50, 255)
    lightMV.Range = 35
    lightMV.Brightness = 4
    lightMV.Parent = fieldMV

    local promptMV = Instance.new("ProximityPrompt")
    promptMV.Name = "Prompt"
    promptMV.ObjectText = "Metrovale"
    promptMV.ActionText = "Deploy to Metrovale"
    promptMV.HoldDuration = 0.5
    promptMV.MaxActivationDistance = 24
    promptMV.RequiresLineOfSight = false
    promptMV.Parent = fieldMV

    portalMVModel.PrimaryPart = archMV_Top
    portalMVModel.Parent = stargateFolder

    -- =========================================================================
    -- TIER 4: THE COLOSSEUM PROVING GROUNDS (Y = 492, Sunken South-West Pit)
    -- =========================================================================
    local arenaFolder = Instance.new("Folder")
    arenaFolder.Name = "ColosseumProvingGrounds"
    arenaFolder.Parent = hub

    local arenaOrigin = hubOrigin + Vector3.new(0, -28, -230)

    -- Colosseum Sunken Arena Floor (200 x 200 studs)
    local arenaFloor = createPart(arenaFolder, "ColosseumFloor", Vector3.new(200, 8, 200), CFrame.new(arenaOrigin.X, arenaOrigin.Y - 4, arenaOrigin.Z), Enum.Material.Basalt, Color3.fromRGB(30, 28, 34))
    arenaFloor.CastShadow = true

    -- Perimeter Colosseum Wall
    local wallThickness = 8
    local wallHeight = 24
    createPart(arenaFolder, "Wall_North", Vector3.new(200, wallHeight, wallThickness), CFrame.new(arenaOrigin.X, arenaOrigin.Y + (wallHeight / 2), arenaOrigin.Z - 100), Enum.Material.Slate, Color3.fromRGB(40, 38, 44))
    createPart(arenaFolder, "Wall_South", Vector3.new(200, wallHeight, wallThickness), CFrame.new(arenaOrigin.X, arenaOrigin.Y + (wallHeight / 2), arenaOrigin.Z + 100), Enum.Material.Slate, Color3.fromRGB(40, 38, 44))
    createPart(arenaFolder, "Wall_West", Vector3.new(wallThickness, wallHeight, 200), CFrame.new(arenaOrigin.X - 100, arenaOrigin.Y + (wallHeight / 2), arenaOrigin.Z), Enum.Material.Slate, Color3.fromRGB(40, 38, 44))
    createPart(arenaFolder, "Wall_East", Vector3.new(wallThickness, wallHeight, 200), CFrame.new(arenaOrigin.X + 100, arenaOrigin.Y + (wallHeight / 2), arenaOrigin.Z), Enum.Material.Slate, Color3.fromRGB(40, 38, 44))

    -- Grand Descending Bridge from Plaza to Colosseum
    local bridgeLength = 110
    local bridgeAngle = math.rad(-14)
    local bridgeCFrame = CFrame.new(hubOrigin.X, hubOrigin.Y - 14, hubOrigin.Z - 115) * CFrame.Angles(bridgeAngle, 0, 0)
    createPart(arenaFolder, "ColosseumBridge", Vector3.new(34, 4, bridgeLength), bridgeCFrame, Enum.Material.Slate, Color3.fromRGB(38, 36, 42))

    -- Bastion Titan DPS Dummy (Center)
    createBastionDPSDummy(arenaFolder, CFrame.new(arenaOrigin.X, arenaOrigin.Y, arenaOrigin.Z))

    -- Perimeter Training Pillars
    local pillarPositions = {
        { Name = "Pillar_Alpha", Pos = arenaOrigin + Vector3.new(-45, 0, -35) },
        { Name = "Pillar_Beta", Pos = arenaOrigin + Vector3.new(45, 0, -35) },
        { Name = "Pillar_Gamma", Pos = arenaOrigin + Vector3.new(0, 0, 50) },
    }

    for _, pInfo in ipairs(pillarPositions) do
        local pil = createPart(arenaFolder, pInfo.Name, Vector3.new(8, 32, 8), CFrame.new(pInfo.Pos + Vector3.new(0, 16, 0)), Enum.Material.Basalt, Color3.fromRGB(35, 32, 38))
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

        local core = createPart(pil, pInfo.Name .. "_Core", Vector3.new(4, 26, 4), CFrame.new(pInfo.Pos + Vector3.new(0, 16, 0)), Enum.Material.Neon, Color3.fromRGB(255, 95, 15), false)
        core.CastShadow = false
    end

    -- =========================================================================
    -- TITAN MAGMA LAUNCH PADS (Inter-Tier High Velocity Travel)
    -- =========================================================================
    local launchFolder = Instance.new("Folder")
    launchFolder.Name = "LaunchPads"
    launchFolder.Parent = hub

    -- 1. Plaza -> Colosseum Jump Pad (Launches South down into Arena)
    createLaunchPad(launchFolder, "Pad_PlazaToColosseum", CFrame.new(hubOrigin.X, hubOrigin.Y + 0.6, hubOrigin.Z - 90), Vector3.new(0, 95, -165), "TO PROVING GROUNDS")

    -- 2. Colosseum -> Plaza Jump Pad (Launches North back up to Plaza)
    createLaunchPad(launchFolder, "Pad_ColosseumToPlaza", CFrame.new(arenaOrigin.X, arenaOrigin.Y + 0.6, arenaOrigin.Z + 75), Vector3.new(0, 125, 165), "RETURN TO PLAZA")

    -- 3. Plaza -> Stargate Spire Jump Pad (Launches South up to Promontory)
    createLaunchPad(launchFolder, "Pad_PlazaToStargates", CFrame.new(hubOrigin.X, hubOrigin.Y + 0.6, hubOrigin.Z + 45), Vector3.new(0, 105, 115), "TO STARGATES")

    -- =========================================================================
    -- VOLCANIC CALDERA MONOLITHS & SKYBEAMS (Atmospheric Scale)
    -- =========================================================================
    local vistaFolder = Instance.new("Folder")
    vistaFolder.Name = "CalderaVista"
    vistaFolder.Parent = hub

    -- 12 Towering Jagged Perimeter Basalt Spires
    for i = 1, 12 do
        local angle = math.rad((i - 1) * 30)
        local radius = 220
        local spireX = hubOrigin.X + math.cos(angle) * radius
        local spireZ = hubOrigin.Z + math.sin(angle) * radius
        local spireHeight = 120 + ((i % 4) * 35)

        local spire = createPart(vistaFolder, "Spire_" .. i, Vector3.new(18, spireHeight, 18), CFrame.new(spireX, hubOrigin.Y + (spireHeight / 2) - 40, spireZ) * CFrame.Angles(math.rad((i % 3) * 4), 0, math.rad((i % 2) * -5)), Enum.Material.Basalt, Color3.fromRGB(20, 18, 22), false)
        spire.CastShadow = false
    end

    -- 4 Colossal Skybeams (Cardinal Directions)
    local beamOffsets = {
        Vector3.new(0, 0, -115),
        Vector3.new(0, 0, 115),
        Vector3.new(-115, 0, 0),
        Vector3.new(115, 0, 0),
    }

    for idx, bOff in ipairs(beamOffsets) do
        local beamPos = hubOrigin + bOff
        local beam = createPart(vistaFolder, "SkyBeam_" .. idx, Vector3.new(4, 1200, 4), CFrame.new(beamPos.X, hubOrigin.Y + 600, beamPos.Z), Enum.Material.Neon, if idx % 2 == 0 then Color3.fromRGB(255, 95, 15) else Color3.fromRGB(0, 200, 255), false)
        beam.Transparency = 0.5
        beam.CastShadow = false
    end

    hub.Parent = Workspace
    print(string.format("[HubService] ✅ Grand Kaiju Sanctuary successfully built with %d descendants!", #hub:GetDescendants()))

    return hub
end

--[=[
    Initializes HubService lifecycle and constructs the Grand Sanctuary.
]=]
function HubService.Init()
    print("[HubService] Initializing HubService...")
    setupAtmosphere()
    HubService.ConstructGrandSanctuary()
end

--[=[
    Records incoming damage on the Bastion Titan dummy and updates live overhead DPS GUI.
]=]
function HubService.RecordDummyDamage(building: Model, actualDamage: number, newHp: number, maxHp: number, combo: number)
    if building.Name == "Bastion_Titan_Dummy" then
        local now = os.clock()
        dummyCombatState.TotalDamage += actualDamage
        dummyCombatState.ComboStreak += 1
        if actualDamage > dummyCombatState.HighestHit then
            dummyCombatState.HighestHit = actualDamage
        end
        dummyCombatState.LastHitTime = now

        table.insert(dummyCombatState.DamageWindow, { Time = now, Damage = actualDamage })

        -- Calculate rolling 3s DPS
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

        -- Update Billboard GUI
        local core = building:FindFirstChild("Core")
        local bg = core and core:FindFirstChild("DPS_Billboard")
        local frame = bg and bg:FindFirstChild("Frame")

        if frame then
            local dpsLbl = frame:FindFirstChild("DPSLabel") :: TextLabel?
            if dpsLbl then
                dpsLbl.Text = string.format("%s DPS", tostring(rollingDPS))
            end

            local streakLbl = frame:FindFirstChild("StreakLabel") :: TextLabel?
            if streakLbl then
                streakLbl.Text = string.format("%d HITS  •  %.1fx COMBO", dummyCombatState.ComboStreak, combo)
            end

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
    Starts HubService runtime bindings: DPS dummy calculation and visual feedback.
]=]
function HubService.Start()
    print("[HubService] Starting HubService runtime listeners...")

    -- Inactivity reset loop for DPS dummy (every 1.5s, no polling cost)
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
