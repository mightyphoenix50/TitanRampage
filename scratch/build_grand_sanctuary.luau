--!strict
--[[
    build_grand_sanctuary.luau
    Run this script in Roblox Studio Command Bar or via execute_luau to construct
    the Grand Volcanic Kaiju Sanctuary directly in Edit mode.
--]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local ModelsFolder = AssetsFolder:WaitForChild("Models")

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

print("🌋 [Builder] Constructing Grand Volcanic Kaiju Sanctuary (450+ studs)...")

local existing = Workspace:FindFirstChild("KaijuHub")
if existing then
    existing:Destroy()
end

local hub = Instance.new("Folder")
hub.Name = "KaijuHub"

local hubOrigin = Vector3.new(0, 520, -5000)

-- =============================================================================
-- TIER 1: GRAND CENTRAL PLAZA (Y = 520, 220 studs diameter)
-- =============================================================================
local plazaFolder = Instance.new("Folder")
plazaFolder.Name = "GrandCentralPlaza"
plazaFolder.Parent = hub

local mainFloor = createPart(plazaFolder, "PlazaFloor", Vector3.new(220, 6, 220), CFrame.new(hubOrigin.X, hubOrigin.Y - 3, hubOrigin.Z), Enum.Material.Basalt, Color3.fromRGB(32, 30, 35))
mainFloor.CastShadow = true

local ring1 = createPart(plazaFolder, "MagmaRune_Ring1", Vector3.new(200, 0.4, 200), CFrame.new(hubOrigin.X, hubOrigin.Y + 0.2, hubOrigin.Z), Enum.Material.Neon, Color3.fromRGB(255, 80, 15), false)
ring1.CastShadow = false

local ring2 = createPart(plazaFolder, "MagmaRune_Ring2", Vector3.new(140, 0.5, 140), CFrame.new(hubOrigin.X, hubOrigin.Y + 0.25, hubOrigin.Z), Enum.Material.Neon, Color3.fromRGB(255, 110, 25), false)
ring2.CastShadow = false

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

-- Altar of Ascension
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

-- =============================================================================
-- TIER 2: THE HALL OF TITANS (Y = 535, Elevated North Terrace)
-- =============================================================================
local hallFolder = Instance.new("Folder")
hallFolder.Name = "HallOfTitans"
hallFolder.Parent = hub

local terraceOrigin = hubOrigin + Vector3.new(0, 14, -80)
local terraceFloor = createPart(hallFolder, "TerraceFloor", Vector3.new(160, 6, 80), CFrame.new(terraceOrigin.X, terraceOrigin.Y - 3, terraceOrigin.Z), Enum.Material.Basalt, Color3.fromRGB(28, 26, 30))

for i = 1, 7 do
    local stepY = hubOrigin.Y + (i * 2)
    local stepZ = hubOrigin.Z - 40 - (i * 5)
    createPart(hallFolder, "Step_" .. i, Vector3.new(60, 2, 6), CFrame.new(hubOrigin.X, stepY - 1, stepZ), Enum.Material.Slate, Color3.fromRGB(35, 33, 38))
end

for _, xOff in ipairs({ -70, -25, 25, 70 }) do
    createPart(hallFolder, "Pillar_" .. xOff, Vector3.new(8, 48, 8), CFrame.new(terraceOrigin.X + xOff, terraceOrigin.Y + 24, terraceOrigin.Z - 30), Enum.Material.Basalt, Color3.fromRGB(20, 18, 22))
end

-- Helper for Holo Card
local function addHoloCard(parent, title, subtitle, stats, abilities, accent)
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
    stroke.Color = accent
    stroke.Thickness = 2.5
    stroke.Transparency = 0.2
    stroke.Parent = mainFrame

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -20, 0, 40)
    titleLbl.Position = UDim2.new(0, 10, 0, 8)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = string.upper(title)
    titleLbl.TextColor3 = accent
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = 26
    titleLbl.Parent = mainFrame

    local subLbl = Instance.new("TextLabel")
    subLbl.Size = UDim2.new(1, -20, 0, 20)
    subLbl.Position = UDim2.new(0, 10, 0, 46)
    subLbl.BackgroundTransparency = 1
    subLbl.Text = subtitle
    subLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    subLbl.Font = Enum.Font.GothamMedium
    subLbl.TextSize = 14
    subLbl.Parent = mainFrame

    local abList = Instance.new("TextLabel")
    abList.Size = UDim2.new(1, -20, 0, 48)
    abList.Position = UDim2.new(0, 10, 0, 196)
    abList.BackgroundTransparency = 1
    abList.Text = table.concat(abilities, "  •  ")
    abList.TextColor3 = Color3.fromRGB(220, 220, 220)
    abList.Font = Enum.Font.Gotham
    abList.TextSize = 12
    abList.TextWrapped = true
    abList.Parent = mainFrame
end

local function addStatue(parent, name, cframe, accent)
    local tmpl = ModelsFolder:FindFirstChild(name)
    if not tmpl then return end
    local s = tmpl:Clone()
    s.Name = name .. "_DisplayStatue"
    for _, d in ipairs(s:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Animator") then
            d:Destroy()
        elseif d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanTouch = false
            d.CanQuery = false
            d.Massless = true
        end
    end
    local hum = s:FindFirstChildOfClass("Humanoid")
    if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
    s:PivotTo(cframe)
    s.Parent = parent

    local l = Instance.new("PointLight")
    l.Color = accent
    l.Range = 32
    l.Brightness = 4
    l.Parent = parent
end

-- Ravager Pedestal
local pedRavPos = terraceOrigin + Vector3.new(-42, 1.5, 0)
local pedRav = createPart(hallFolder, "Pedestal_Ravager", Vector3.new(22, 3, 22), CFrame.new(pedRavPos), Enum.Material.Basalt, Color3.fromRGB(22, 20, 25))
createPart(hallFolder, "PedRav_GlowRing", Vector3.new(24, 0.4, 24), CFrame.new(pedRavPos + Vector3.new(0, -1.2, 0)), Enum.Material.Neon, Color3.fromRGB(255, 95, 15), false)

local promptRav = Instance.new("ProximityPrompt")
promptRav.Name = "Prompt"
promptRav.ObjectText = "Ravager"
promptRav.ActionText = "Awaken The Ravager"
promptRav.HoldDuration = 0.5
promptRav.MaxActivationDistance = 24
promptRav.RequiresLineOfSight = false
promptRav.Parent = pedRav

addHoloCard(pedRav, "The Ravager", "[Colossal Apex Brawler]", {}, { "Claw Swipe Combo", "Ground Stomp", "Primal Roar" }, Color3.fromRGB(255, 110, 20))
addStatue(hallFolder, "Ravager", CFrame.new(pedRavPos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(255, 100, 20))

-- Brontara Pedestal
local pedBronPos = terraceOrigin + Vector3.new(42, 1.5, 0)
local pedBron = createPart(hallFolder, "Pedestal_Brontara", Vector3.new(26, 3, 26), CFrame.new(pedBronPos), Enum.Material.Basalt, Color3.fromRGB(22, 20, 25))
createPart(hallFolder, "PedBron_GlowRing", Vector3.new(28, 0.4, 28), CFrame.new(pedBronPos + Vector3.new(0, -1.2, 0)), Enum.Material.Neon, Color3.fromRGB(255, 50, 15), false)

local promptBron = Instance.new("ProximityPrompt")
promptBron.Name = "Prompt"
promptBron.ObjectText = "Brontara"
promptBron.ActionText = "Awaken Brontara"
promptBron.HoldDuration = 0.5
promptBron.MaxActivationDistance = 26
promptBron.RequiresLineOfSight = false
promptBron.Parent = pedBron

addHoloCard(pedBron, "Brontara", "[Armored Behemoth Colossus]", {}, { "Heavy Tail Sweep", "Seismic Heavy Stomp", "Volcanic Neck Strike", "Magma Roar" }, Color3.fromRGB(255, 55, 20))
addStatue(hallFolder, "Brontara", CFrame.new(pedBronPos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(255, 55, 20))

-- =============================================================================
-- TIER 3: STARGATE PROMONTORY (Y = 550, South Ridge)
-- =============================================================================
local stargateFolder = Instance.new("Folder")
stargateFolder.Name = "StargatePromontory"
stargateFolder.Parent = hub

local promontoryOrigin = hubOrigin + Vector3.new(0, 30, 95)
createPart(stargateFolder, "PromontoryFloor", Vector3.new(150, 6, 60), CFrame.new(promontoryOrigin.X, promontoryOrigin.Y - 3, promontoryOrigin.Z), Enum.Material.Basalt, Color3.fromRGB(28, 26, 32))

for i = 1, 10 do
    local stepY = hubOrigin.Y + (i * 3)
    local stepZ = hubOrigin.Z + 45 + (i * 5)
    createPart(stargateFolder, "PromStep_" .. i, Vector3.new(50, 3, 6), CFrame.new(hubOrigin.X, stepY - 1.5, stepZ), Enum.Material.Slate, Color3.fromRGB(36, 34, 40))
end

local function addPortal(parent, name, pos, color, objText, actText)
    local m = Instance.new("Model")
    m.Name = name
    createPart(m, "ArchPillar_L", Vector3.new(5, 32, 5), CFrame.new(pos + Vector3.new(-12, 16, 0)), Enum.Material.Basalt, Color3.fromRGB(25, 23, 28))
    createPart(m, "ArchPillar_R", Vector3.new(5, 32, 5), CFrame.new(pos + Vector3.new(12, 16, 0)), Enum.Material.Basalt, Color3.fromRGB(25, 23, 28))
    local top = createPart(m, "ArchBeam", Vector3.new(29, 6, 6), CFrame.new(pos + Vector3.new(0, 32, 0)), Enum.Material.Slate, Color3.fromRGB(35, 32, 38))
    local f = createPart(m, "PortalField", Vector3.new(20, 26, 2), CFrame.new(pos + Vector3.new(0, 14, 0)), Enum.Material.Neon, color, false)
    f.Transparency = 0.35
    local l = Instance.new("PointLight")
    l.Color = color
    l.Range = 35
    l.Brightness = 4
    l.Parent = f
    local p = Instance.new("ProximityPrompt")
    p.Name = "Prompt"
    p.ObjectText = objText
    p.ActionText = actText
    p.HoldDuration = 0.5
    p.MaxActivationDistance = 24
    p.RequiresLineOfSight = false
    p.Parent = f
    m.PrimaryPart = top
    m.Parent = parent
end

addPortal(stargateFolder, "Portal_SmallTown", promontoryOrigin + Vector3.new(-45, 0, 0), Color3.fromRGB(0, 210, 255), "SmallTown", "Deploy to SmallTown")
addPortal(stargateFolder, "Portal_Metrovale", promontoryOrigin + Vector3.new(45, 0, 0), Color3.fromRGB(180, 50, 255), "Metrovale", "Deploy to Metrovale")

-- =============================================================================
-- TIER 4: COLOSSEUM PROVING GROUNDS (Y = 492, Sunken South-West Pit)
-- =============================================================================
local arenaFolder = Instance.new("Folder")
arenaFolder.Name = "ColosseumProvingGrounds"
arenaFolder.Parent = hub

local arenaOrigin = hubOrigin + Vector3.new(0, -28, -230)
createPart(arenaFolder, "ColosseumFloor", Vector3.new(200, 8, 200), CFrame.new(arenaOrigin.X, arenaOrigin.Y - 4, arenaOrigin.Z), Enum.Material.Basalt, Color3.fromRGB(30, 28, 34))

createPart(arenaFolder, "Wall_North", Vector3.new(200, 24, 8), CFrame.new(arenaOrigin.X, arenaOrigin.Y + 12, arenaOrigin.Z - 100), Enum.Material.Slate, Color3.fromRGB(40, 38, 44))
createPart(arenaFolder, "Wall_South", Vector3.new(200, 24, 8), CFrame.new(arenaOrigin.X, arenaOrigin.Y + 12, arenaOrigin.Z + 100), Enum.Material.Slate, Color3.fromRGB(40, 38, 44))
createPart(arenaFolder, "Wall_West", Vector3.new(8, 24, 200), CFrame.new(arenaOrigin.X - 100, arenaOrigin.Y + 12, arenaOrigin.Z), Enum.Material.Slate, Color3.fromRGB(40, 38, 44))
createPart(arenaFolder, "Wall_East", Vector3.new(8, 24, 200), CFrame.new(arenaOrigin.X + 100, arenaOrigin.Y + 12, arenaOrigin.Z), Enum.Material.Slate, Color3.fromRGB(40, 38, 44))

local bridgeCFrame = CFrame.new(hubOrigin.X, hubOrigin.Y - 14, hubOrigin.Z - 115) * CFrame.Angles(math.rad(-14), 0, 0)
createPart(arenaFolder, "ColosseumBridge", Vector3.new(34, 4, 110), bridgeCFrame, Enum.Material.Slate, Color3.fromRGB(38, 36, 42))

-- Bastion Titan DPS Dummy
local dummyModel = Instance.new("Model")
dummyModel.Name = "Bastion_Titan_Dummy"
local core = createPart(dummyModel, "Core", Vector3.new(14, 38, 14), CFrame.new(arenaOrigin.X, arenaOrigin.Y + 19, arenaOrigin.Z), Enum.Material.Basalt, Color3.fromRGB(30, 28, 32), true)
dummyModel.PrimaryPart = core
createPart(dummyModel, "ChestPlate", Vector3.new(16, 14, 16), CFrame.new(arenaOrigin.X, arenaOrigin.Y + 26, arenaOrigin.Z), Enum.Material.Slate, Color3.fromRGB(45, 42, 48), true)
createPart(dummyModel, "HeadCore", Vector3.new(8, 8, 8), CFrame.new(arenaOrigin.X, arenaOrigin.Y + 38, arenaOrigin.Z), Enum.Material.Basalt, Color3.fromRGB(25, 25, 30), true)
createPart(dummyModel, "EyeCore", Vector3.new(4, 1.5, 1), CFrame.new(arenaOrigin.X, arenaOrigin.Y + 38, arenaOrigin.Z + 4.2), Enum.Material.Neon, Color3.fromRGB(255, 60, 20), false)

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

local dpsBg = Instance.new("BillboardGui")
dpsBg.Name = "DPS_Billboard"
dpsBg.Size = UDim2.new(0, 340, 0, 180)
dpsBg.StudsOffset = Vector3.new(0, 24, 0)
dpsBg.AlwaysOnTop = true
dpsBg.MaxDistance = 150
dpsBg.Parent = core

local dpsFrame = Instance.new("Frame")
dpsFrame.Size = UDim2.new(1, 0, 1, 0)
dpsFrame.BackgroundColor3 = Color3.fromRGB(15, 12, 18)
dpsFrame.BackgroundTransparency = 0.2
dpsFrame.BorderSizePixel = 0
dpsFrame.Parent = dpsBg

local dpsTitle = Instance.new("TextLabel")
dpsTitle.Size = UDim2.new(1, 0, 0, 28)
dpsTitle.Text = "ANCIENT BASTION MONOLITH"
dpsTitle.TextColor3 = Color3.fromRGB(255, 120, 40)
dpsTitle.Font = Enum.Font.GothamBlack
dpsTitle.TextSize = 16
dpsTitle.BackgroundTransparency = 1
dpsTitle.Parent = dpsFrame

local dpsLbl = Instance.new("TextLabel")
dpsLbl.Name = "DPSLabel"
dpsLbl.Size = UDim2.new(1, 0, 0, 40)
dpsLbl.Position = UDim2.new(0, 0, 0, 36)
dpsLbl.Text = "0 DPS"
dpsLbl.TextColor3 = Color3.fromRGB(255, 230, 80)
dpsLbl.Font = Enum.Font.GothamBlack
dpsLbl.TextSize = 30
dpsLbl.BackgroundTransparency = 1
dpsLbl.Parent = dpsFrame

local streakLbl = Instance.new("TextLabel")
streakLbl.Name = "StreakLabel"
streakLbl.Size = UDim2.new(1, 0, 0, 22)
streakLbl.Position = UDim2.new(0, 0, 0, 80)
streakLbl.Text = "0 HITS  •  1.0x COMBO"
streakLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
streakLbl.Font = Enum.Font.GothamBold
streakLbl.TextSize = 13
streakLbl.BackgroundTransparency = 1
streakLbl.Parent = dpsFrame

dummyModel.Parent = arenaFolder

for _, pName in ipairs({ "Pillar_Alpha", "Pillar_Beta", "Pillar_Gamma" }) do
    local x = if pName == "Pillar_Alpha" then -45 elseif pName == "Pillar_Beta" then 45 else 0
    local z = if pName == "Pillar_Gamma" then 50 else -35
    local pil = createPart(arenaFolder, pName, Vector3.new(8, 32, 8), CFrame.new(arenaOrigin.X + x, arenaOrigin.Y + 16, arenaOrigin.Z + z), Enum.Material.Basalt, Color3.fromRGB(35, 32, 38))
    pil:SetAttribute("BuildingId", pName)
    pil:SetAttribute("BuildingName", "Practice Monolith")
    pil:SetAttribute("BuildingType", "TrainingPillar")
    pil:SetAttribute("MaxHealth", 10000)
    pil:SetAttribute("CurrentHealth", 10000)
    pil:SetAttribute("IsTrainingDummy", true)
    pil:SetAttribute("IsDestroyed", false)
end

-- =============================================================================
-- LAUNCH PADS (Directional Impulse)
-- =============================================================================
local launchFolder = Instance.new("Folder")
launchFolder.Name = "LaunchPads"
launchFolder.Parent = hub

local function addPad(name, cframe, label)
    local m = Instance.new("Model")
    m.Name = name
    createPart(m, "PadBase", Vector3.new(18, 1.2, 18), cframe, Enum.Material.SmoothPlastic, Color3.fromRGB(20, 20, 24), true)
    local inP = createPart(m, "TriggerPad", Vector3.new(14, 1.4, 14), cframe * CFrame.new(0, 0.2, 0), Enum.Material.Neon, Color3.fromRGB(255, 95, 15), false)
    local bg = Instance.new("BillboardGui")
    bg.Size = UDim2.new(0, 160, 0, 40)
    bg.StudsOffset = Vector3.new(0, 4, 0)
    bg.AlwaysOnTop = true
    bg.Parent = inP
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.Text = "▲ " .. label .. " ▲"
    lbl.TextColor3 = Color3.fromRGB(255, 180, 50)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = 14
    lbl.BackgroundTransparency = 1
    lbl.Parent = bg
    m.Parent = launchFolder
end

addPad("Pad_PlazaToColosseum", CFrame.new(hubOrigin.X, hubOrigin.Y + 0.6, hubOrigin.Z - 90), "TO PROVING GROUNDS")
addPad("Pad_ColosseumToPlaza", CFrame.new(arenaOrigin.X, arenaOrigin.Y + 0.6, arenaOrigin.Z + 75), "RETURN TO PLAZA")
addPad("Pad_PlazaToStargates", CFrame.new(hubOrigin.X, hubOrigin.Y + 0.6, hubOrigin.Z + 45), "TO STARGATES")

-- Perimeter Spires
local vistaFolder = Instance.new("Folder")
vistaFolder.Name = "CalderaVista"
vistaFolder.Parent = hub

for i = 1, 12 do
    local angle = math.rad((i - 1) * 30)
    local spireX = hubOrigin.X + math.cos(angle) * 220
    local spireZ = hubOrigin.Z + math.sin(angle) * 220
    local h = 120 + ((i % 4) * 35)
    createPart(vistaFolder, "Spire_" .. i, Vector3.new(18, h, 18), CFrame.new(spireX, hubOrigin.Y + (h / 2) - 40, spireZ), Enum.Material.Basalt, Color3.fromRGB(20, 18, 22), false)
end

-- Skybeams
for idx, bOff in ipairs({ Vector3.new(0, 0, -115), Vector3.new(0, 0, 115), Vector3.new(-115, 0, 0), Vector3.new(115, 0, 0) }) do
    local bp = hubOrigin + bOff
    local b = createPart(vistaFolder, "SkyBeam_" .. idx, Vector3.new(4, 1200, 4), CFrame.new(bp.X, hubOrigin.Y + 600, bp.Z), Enum.Material.Neon, if idx % 2 == 0 then Color3.fromRGB(255, 95, 15) else Color3.fromRGB(0, 200, 255), false)
    b.Transparency = 0.5
end

hub.Parent = Workspace
print("✅ [Builder] Grand Volcanic Kaiju Sanctuary built! Total descendants: " .. #hub:GetDescendants())
