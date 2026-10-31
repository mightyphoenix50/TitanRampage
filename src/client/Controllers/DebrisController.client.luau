--!strict
--[[
    DebrisController.client.luau
    Client-side destruction juice for Titan Rampage (Milestone 14).
    Responsibility:
    - On BuildingDestroyed, breaks the building into tumbling debris chunks thrown outward and up,
      sized and coloured from its MainBody, then fades them out.
    - On BuildingDamaged near the local titan, chips a few small chunks off the wall facing it.
    - Shakes the camera on hits and collapses, scaled by building tier and distance.
    Purely cosmetic: chunks exist only on this client; the server's hide/restore collapse and
    CityService.ResetCity are untouched.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local DestructionFeedback = RemotesFolder:WaitForChild("DestructionFeedback") :: RemoteEvent
local AudioController = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AudioController") :: ModuleScript)

local COLLAPSE_CHUNKS = { [1] = 10, [2] = 14, [3] = 18, [4] = 24 }
local COLLAPSE_SHAKE = { [1] = 0.6, [2] = 0.9, [3] = 1.3, [4] = 1.8 } -- Degrees at point blank
local MAX_ACTIVE_CHUNKS = 140 -- Oldest chunks are removed past this budget
local CHUNK_LIFETIME = 4.0
local CHUNK_FADE_TIME = 0.6
local HIT_CHIP_RANGE = 90 -- Only chip chunks for hits the local titan is close to
local SHAKE_RANGE = 300

local debrisFolder = Instance.new("Folder")
debrisFolder.Name = "ClientDebris"
debrisFolder.Parent = Workspace

local activeChunks: { BasePart } = {}

local rng = Random.new()

-- Camera shake state: decays from `shakeStrength` over `shakeDuration`
local shakeStrength = 0
local shakeDuration = 0
local shakeElapsed = 0

local function addShake(strength: number, duration: number)
    if strength <= 0 then return end
    -- A stronger incoming shake takes over; a weaker one doesn't cut a big one short
    local remaining = if shakeDuration > 0 then shakeStrength * (1 - shakeElapsed / shakeDuration) else 0
    if strength < remaining then return end
    shakeStrength = strength
    shakeDuration = duration
    shakeElapsed = 0
end

local function shakeFromDistance(pos: Vector3, maxStrength: number, duration: number)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local dist = (camera.CFrame.Position - pos).Magnitude
    if dist > SHAKE_RANGE then return end
    local falloff = 1 - (dist / SHAKE_RANGE)
    addShake(maxStrength * falloff * falloff, duration)
end

RunService:BindToRenderStep("DebrisCameraShake", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
    if shakeDuration <= 0 then return end
    shakeElapsed += dt
    if shakeElapsed >= shakeDuration then
        shakeDuration = 0
        return
    end
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local amount = math.rad(shakeStrength * (1 - shakeElapsed / shakeDuration))
    camera.CFrame *= CFrame.Angles(rng:NextNumber(-amount, amount), rng:NextNumber(-amount, amount), rng:NextNumber(-amount, amount) * 0.5)
end)

local function retireChunk(chunk: BasePart)
    local index = table.find(activeChunks, chunk)
    if index then table.remove(activeChunks, index) end
    chunk:Destroy()
end

local function spawnChunk(cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material, velocity: Vector3)
    while #activeChunks >= MAX_ACTIVE_CHUNKS do
        retireChunk(activeChunks[1])
    end

    local chunk = Instance.new("Part")
    chunk.Name = "Debris"
    chunk.Size = size
    chunk.CFrame = cframe
    chunk.Color = color
    chunk.Material = material
    chunk.Anchored = false
    chunk.CanCollide = true
    chunk.CanQuery = false
    chunk.CanTouch = false
    chunk.CastShadow = size.Magnitude > 6
    -- Light chunks so a stray one can't shove the local titan around
    chunk.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.6, 0.1)
    chunk.AssemblyLinearVelocity = velocity
    chunk.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
    chunk.Parent = debrisFolder
    table.insert(activeChunks, chunk)

    task.delay(CHUNK_LIFETIME + rng:NextNumber(0, 0.8), function()
        if not chunk.Parent then return end
        local fade = TweenService:Create(chunk, TweenInfo.new(CHUNK_FADE_TIME), {
            Transparency = 1,
            Size = size * 0.5,
        })
        fade:Play()
        fade.Completed:Connect(function()
            retireChunk(chunk)
        end)
    end)
end

local function getMainBody(building: Instance?): BasePart?
    if not building then return nil end
    local structure = building:FindFirstChild("Structure")
    local mainBody = structure and structure:FindFirstChild("MainBody")
    if mainBody and mainBody:IsA("BasePart") then return mainBody end
    return nil
end

local function burstBuilding(building: Instance?, pos: Vector3, tier: number)
    local mainBody = getMainBody(building)
    local bodySize = if mainBody then mainBody.Size else Vector3.new(20, 30, 20)
    local color = if mainBody then mainBody.Color else Color3.fromRGB(120, 115, 110)
    local material = if mainBody then mainBody.Material else Enum.Material.Concrete
    local roof = mainBody and mainBody.Parent and mainBody.Parent:FindFirstChild("Roof")
    local roofColor = if roof and roof:IsA("BasePart") then roof.Color else color
    local count = COLLAPSE_CHUNKS[tier] or COLLAPSE_CHUNKS[1]

    -- Chunk edge scales with the building's footprint so towers throw bigger slabs
    local footprint = math.max(bodySize.X, bodySize.Z)
    local baseEdge = math.clamp(footprint / 5, 2.5, 9)
    local groundY = pos.Y - bodySize.Y * 0.5

    for i = 1, count do
        local edge = baseEdge * rng:NextNumber(0.55, 1.15)
        local size = Vector3.new(edge, edge * rng:NextNumber(0.4, 0.9), edge * rng:NextNumber(0.6, 1.1))
        local offset = Vector3.new(
            rng:NextNumber(-0.5, 0.5) * bodySize.X,
            rng:NextNumber(0.15, 0.85) * bodySize.Y,
            rng:NextNumber(-0.5, 0.5) * bodySize.Z
        )
        local spawnPos = Vector3.new(pos.X + offset.X, groundY + offset.Y, pos.Z + offset.Z)
        local outward = Vector3.new(offset.X, 0, offset.Z)
        outward = if outward.Magnitude > 0.1 then outward.Unit else Vector3.new(1, 0, 0)
        local speed = rng:NextNumber(18, 38) + tier * 4
        local velocity = outward * speed + Vector3.new(0, rng:NextNumber(20, 45), 0)
        -- Every fourth chunk takes the roof colour, for variety
        local chunkColor = if i % 4 == 0 then roofColor else color
        local rotation = CFrame.Angles(rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi))
        spawnChunk(CFrame.new(spawnPos) * rotation, size, chunkColor, material, velocity)
    end
end

local function chipBuilding(building: Instance?, tier: number)
    local mainBody = getMainBody(building)
    if not mainBody then return end
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    -- Closest point on the MainBody box to the local titan: the face it is hitting
    local localPos = mainBody.CFrame:PointToObjectSpace(root.Position)
    local half = mainBody.Size * 0.5
    local clamped = Vector3.new(
        math.clamp(localPos.X, -half.X, half.X),
        math.clamp(localPos.Y, -half.Y, half.Y),
        math.clamp(localPos.Z, -half.Z, half.Z)
    )
    local hitPos = mainBody.CFrame:PointToWorldSpace(clamped)
    if (hitPos - root.Position).Magnitude > HIT_CHIP_RANGE then return end

    local away = Vector3.new(root.Position.X - hitPos.X, 0, root.Position.Z - hitPos.Z)
    away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
    for _ = 1, 2 + tier do
        local edge = rng:NextNumber(1.2, 2.6)
        local velocity = away * rng:NextNumber(14, 26) + Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(12, 24), rng:NextNumber(-8, 8))
        local spawnPos = hitPos + away * (edge + 0.5) + Vector3.new(0, rng:NextNumber(-2, 4), 0)
        spawnChunk(CFrame.new(spawnPos), Vector3.new(edge, edge * 0.7, edge), mainBody.Color, mainBody.Material, velocity)
    end
    addShake(0.35 + tier * 0.1, 0.18)
end

DestructionFeedback.OnClientEvent:Connect(function(eventType: string, data: any)
    if type(data) ~= "table" then return end
    local building = if typeof(data.Building) == "Instance" then data.Building :: Instance else nil
    local tier = if building then tonumber(building:GetAttribute("DestructionTier")) or 1 else 1

    if eventType == "BuildingDestroyed" then
        local pos = if typeof(data.Position) == "Vector3" then data.Position :: Vector3 else nil
        if not pos then return end
        burstBuilding(building, pos, tier)
        if building and building:FindFirstChild("Windows") then AudioController.PlaySpatial("CollapseGlass", pos) end
        shakeFromDistance(pos, COLLAPSE_SHAKE[tier] or COLLAPSE_SHAKE[1], 0.45 + tier * 0.12)
    elseif eventType == "BuildingDamaged" then
        chipBuilding(building, tier)
    end
end)

print("[DebrisController] Destruction debris and camera shake initialized.")
