--!strict
--[[
    DropService.luau
    Authoritative physical collectible currency drops for Titan Rampage.
    Features:
    - Spawns floating and bobbing 3D green cash stacks when buildings collapse.
    - Stylized bills with cream straps, glowing green particle auras, and overhead value tags.
    - Centralized 20Hz bobbing, rotation, and magnetic suction loop.
    - Proximity collection (38 studs for standard players).
    - AutoCollect Gamepass Integration: High-velocity magnetic suction (180 studs) that pulls cash stacks through the air into the titan!
    - Clean lifecycle management & automatic 45-second despawn timer.
    - Robust DataModel attribute-driven state (compatible with tests and live gameplay).
--]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local ServicesFolder = script.Parent

local ProgressionService = require(ServicesFolder:WaitForChild("ProgressionService") :: ModuleScript)
local MonetizationService = require(ServicesFolder:WaitForChild("MonetizationService") :: ModuleScript)

local DropService = {}

local dropsFolder: Folder? = nil

local function getDropsFolder(): Folder
    if not dropsFolder or not dropsFolder.Parent then
        local existing = Workspace:FindFirstChild("CashDrops")
        if existing and existing:IsA("Folder") then
            dropsFolder = existing
        else
            local f = Instance.new("Folder")
            f.Name = "CashDrops"
            f.Parent = Workspace
            dropsFolder = f
        end
    end
    return dropsFolder :: Folder
end

-- Remote Event for client feedback (audio, pop particles, HUD floating text)
local DropFeedbackRemote: RemoteEvent? = nil

local function getDropFeedbackRemote(): RemoteEvent?
    if not DropFeedbackRemote then DropFeedbackRemote = RemotesFolder:FindFirstChild("DropFeedback") :: RemoteEvent? end
    return DropFeedbackRemote
end

-- Helper to create a styled static/anchored part
local function createDropPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, material: Enum.Material, color: Color3): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cframe
    p.Material = material
    p.Color = color
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

--[=[
    Initializes DropService containers and remotes.
]=]
function DropService.Init()
    print("[DropService] Initializing DropService...")

    -- Ensure container folder exists in Workspace
    local existingFolder = Workspace:FindFirstChild("CashDrops")
    if existingFolder and existingFolder:IsA("Folder") then
        dropsFolder = existingFolder
        dropsFolder:ClearAllChildren()
    else
        dropsFolder = Instance.new("Folder")
        dropsFolder.Name = "CashDrops"
        dropsFolder.Parent = Workspace
    end

    -- Ensure DropFeedback RemoteEvent exists
    local remote = RemotesFolder:FindFirstChild("DropFeedback") :: RemoteEvent?
    if not remote then
        remote = Instance.new("RemoteEvent")
        remote.Name = "DropFeedback"
        remote.Parent = RemotesFolder
    end
    DropFeedbackRemote = remote
end

--[=[
    Creates a stylized 3D green stack of cash bills at spawnPos.
]=]
local function createCashStackModel(spawnPos: Vector3, cashAmount: number, baseY: number): (Model, BasePart)
    local model = Instance.new("Model")
    model.Name = "CashStack"

    local baseCF = CFrame.new(spawnPos)

    -- 1. Main Dollar Green Stack Base
    local stackBase =
        createDropPart(model, "StackBase", Vector3.new(3.0, 1.2, 4.2), baseCF, Enum.Material.SmoothPlastic, Color3.fromRGB(38, 150, 62))
    model.PrimaryPart = stackBase

    -- 2. Cream/Gold Paper Currency Band
    createDropPart(model, "MoneyBand", Vector3.new(3.06, 1.24, 1.2), baseCF, Enum.Material.SmoothPlastic, Color3.fromRGB(242, 236, 210))

    -- 3. Top Bill Edge Accent Lines
    createDropPart(
        model,
        "TopAccent",
        Vector3.new(2.6, 0.08, 3.8),
        baseCF * CFrame.new(0, 0.61, 0),
        Enum.Material.Neon,
        Color3.fromRGB(65, 205, 95)
    )

    -- 4. Glowing Green PointLight
    local pLight = Instance.new("PointLight")
    pLight.Name = "DropGlow"
    pLight.Color = Color3.fromRGB(55, 255, 110)
    pLight.Range = 14
    pLight.Brightness = 2.4
    pLight.Shadows = false
    pLight.Parent = stackBase

    -- 5. Floating Green Sparkle/Mote Particle Emitter
    local att = Instance.new("Attachment")
    att.Name = "GlowAttachment"
    att.Position = Vector3.new(0, 0, 0)
    att.Parent = stackBase

    local sparks = Instance.new("ParticleEmitter")
    sparks.Name = "CashSparkles"
    sparks.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 255, 120)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 255, 220)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 190, 70)),
    })
    sparks.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(0.6, 0.7),
        NumberSequenceKeypoint.new(1, 0),
    })
    sparks.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.8, 0.4),
        NumberSequenceKeypoint.new(1, 1),
    })
    sparks.Speed = NumberRange.new(1.5, 4.0)
    sparks.SpreadAngle = Vector2.new(180, 180)
    sparks.Lifetime = NumberRange.new(0.6, 1.1)
    sparks.Rate = 5
    sparks.LightEmission = 0.9
    sparks.LightInfluence = 0
    sparks.Parent = att

    -- 6. Holographic Value Tag
    local bg = Instance.new("BillboardGui")
    bg.Name = "ValueTag"
    bg.Size = UDim2.new(0, 110, 0, 36)
    bg.StudsOffset = Vector3.new(0, 2.4, 0)
    bg.AlwaysOnTop = true
    bg.MaxDistance = 90
    bg.Parent = stackBase

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = string.format("💵 +$%d", cashAmount)
    lbl.TextColor3 = Color3.fromRGB(110, 255, 140)
    lbl.TextStrokeColor3 = Color3.fromRGB(10, 45, 15)
    lbl.TextStrokeTransparency = 0.2
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = 16
    lbl.Parent = bg

    -- Set model attributes for state replication and simulation
    local now = os.clock()
    model:SetAttribute("CashAmount", cashAmount)
    model:SetAttribute("BaseY", baseY)
    model:SetAttribute("BobSeed", math.random() * 10)
    model:SetAttribute("SpawnTime", now)
    model:SetAttribute("SuctionSpeed", 35)
    model:SetAttribute("Collected", false)

    model.Parent = getDropsFolder()

    return model, stackBase
end

--[=[
    Collects a drop for a specific player, rewarding cash and playing sound/VFX.
]=]
local function collectDrop(model: Model, player: Player)
    if model:GetAttribute("Collected") == true then return end
    model:SetAttribute("Collected", true)

    local cashAmount = (model:GetAttribute("CashAmount") :: number?) or 10
    local pivot = model:GetPivot()
    local position = pivot.Position

    print(string.format("[DropService] 💰 %s collected +$%d Cash!", player.Name, cashAmount))

    -- 1. Server-authoritative reward
    local ok, err = pcall(function()
        ProgressionService.AddRewards(player, cashAmount, 0, 0)
    end)
    if not ok then
        warn(string.format("[DropService] Error awarding cash to %s: %s", player.Name, tostring(err)))
    else
        print(string.format("[DropService] ✅ Successfully awarded +$%d Cash to %s!", cashAmount, player.Name))
    end

    -- 2. Client feedback remote
    local remote = getDropFeedbackRemote()
    if remote then
        remote:FireClient(player, "CashCollected", {
            Amount = cashAmount,
            Position = position,
        })
        remote:FireAllClients("CashPop", {
            Position = position,
        })
    end

    -- 3. Visual destruction burst
    local stackBase = model.PrimaryPart or model:FindFirstChild("StackBase") :: BasePart?
    if stackBase then
        local pLight = stackBase:FindFirstChild("DropGlow") :: PointLight?
        if pLight then pLight.Brightness = 6.0 end

        local tag = stackBase:FindFirstChild("ValueTag")
        if tag then tag:Destroy() end

        local fadeTween = TweenService:Create(stackBase, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(4.5, 0.2, 5.5),
            Transparency = 1,
        })
        fadeTween:Play()
        fadeTween.Completed:Connect(function()
            model:Destroy()
        end)
    else
        model:Destroy()
    end
end

--[=[
    Spawns physical floating cash stacks at building collapse position.
    @param origin The center Vector3 of the collapsed building.
    @param totalCash Total cash to be distributed into drops.
    @param dropCount Number of physical stacks to spawn (typically 3 to 8).
    @param attackingPlayer The player who destroyed the building (favored for auto-collect).
]=]
function DropService.SpawnCashDrops(origin: Vector3, totalCash: number, dropCount: number, attackingPlayer: Player?)
    if totalCash <= 0 then return end
    local count = math.clamp(dropCount or 4, 2, 10)
    local cashPerDrop = math.max(1, math.floor(totalCash / count))

    for i = 1, count do
        -- Small spread around destruction footprint
        local angle = (i / count) * (math.pi * 2) + math.random(-15, 15) * 0.05
        local dist = math.random(6, 18)
        local targetX = origin.X + math.cos(angle) * dist
        local targetZ = origin.Z + math.sin(angle) * dist
        local baseY = origin.Y + 3.2

        -- Pop upward burst initial position
        local initialPos = Vector3.new(targetX, baseY + math.random(3, 7), targetZ)
        local model, stackBase = createCashStackModel(initialPos, cashPerDrop, baseY)

        if attackingPlayer then model:SetAttribute("TargetPlayerId", attackingPlayer.UserId) end

        -- Pop animation settling down to floating BaseY
        task.spawn(function()
            local settleTween = TweenService:Create(stackBase, TweenInfo.new(0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
                CFrame = CFrame.new(Vector3.new(targetX, baseY, targetZ)),
            })
            settleTween:Play()
        end)
    end

    print(string.format("[DropService] 💵 Spawned %d cash drops ($%d each) at %s", count, cashPerDrop, tostring(origin)))
end

--[=[
    Starts the centralized 20Hz bobbing, AutoCollect suction, and collection loop.
]=]
function DropService.Start()
    print("[DropService] 💵 Starting currency drop simulation and AutoCollect loop...")

    task.spawn(function()
        local lastTick = os.clock()
        while true do
            task.wait(0.05) -- 20 Hz tick
            local now = os.clock()
            local dt = now - lastTick
            lastTick = now

            local success, err = pcall(function()
                local folder = getDropsFolder()
                local children = folder:GetChildren()
                if #children == 0 then return end

                local players = Players:GetPlayers()

                for _, item in ipairs(children) do
                    if not item:IsA("Model") then continue end
                    if item:GetAttribute("Collected") == true then continue end

                    local spawnTime = (item:GetAttribute("SpawnTime") :: number?) or now
                    -- Expiration cleanup (45 seconds)
                    if (now - spawnTime) > 45.0 then
                        item:SetAttribute("Collected", true)
                        item:Destroy()
                        continue
                    end

                    local currentPivot = item:GetPivot()
                    local currentPos = currentPivot.Position
                    local baseY = (item:GetAttribute("BaseY") :: number?) or currentPos.Y
                    local bobSeed = (item:GetAttribute("BobSeed") :: number?) or 0
                    local suctionSpeed = (item:GetAttribute("SuctionSpeed") :: number?) or 35

                    -- Find closest eligible player within suction threshold
                    local closestPlayer: Player? = nil
                    local closestDist = math.huge
                    local closestHrpPos: Vector3? = nil

                    for _, player in ipairs(players) do
                        local char = player.Character
                        local hrp = char and (char:FindFirstChild("HumanoidRootPart") :: BasePart? or char.PrimaryPart)
                        if hrp then
                            local dist = (hrp.Position - currentPos).Magnitude
                            local hasAutoCollect = MonetizationService.HasAutoCollect(player)
                            local suctionThreshold = if hasAutoCollect then 180 else 38

                            if dist < suctionThreshold and dist < closestDist then
                                closestDist = dist
                                closestPlayer = player
                                closestHrpPos = hrp.Position
                            end
                        end
                    end

                    if closestPlayer and closestHrpPos then
                        local targetPos = closestHrpPos + Vector3.new(0, 3, 0)
                        local dir = (targetPos - currentPos)
                        local currentDist = dir.Magnitude

                        if currentDist <= 12.0 then
                            -- Proximity collection reached!
                            collectDrop(item, closestPlayer)
                        else
                            -- Accelerate suction towards player
                            local newSpeed = math.min(220, suctionSpeed + (dt * 180))
                            item:SetAttribute("SuctionSpeed", newSpeed)

                            local moveDist = math.min(currentDist, newSpeed * dt)
                            local stepPos = currentPos + (dir.Unit * moveDist)

                            item:PivotTo(CFrame.lookAt(stepPos, targetPos) * CFrame.Angles(0, now * 8.0, 0))
                        end
                    else
                        -- Reset suction speed if player walks out of range
                        if suctionSpeed > 35 then item:SetAttribute("SuctionSpeed", 35) end

                        -- Gentle floating and bobbing
                        local newY = baseY + (math.sin(now * 3.5 + bobSeed) * 0.65)
                        local rotAngle = now * 1.8 + bobSeed
                        item:PivotTo(CFrame.new(currentPos.X, newY, currentPos.Z) * CFrame.Angles(0, rotAngle, 0))
                    end
                end
            end)

            if not success then warn("[DropService] Error in drop simulation loop:", err) end
        end
    end)
end

--[=[
    Returns the count of active uncollected cash drops.
]=]
function DropService.GetActiveDropCount(): number
    local count = 0
    local folder = getDropsFolder()
    for _, item in ipairs(folder:GetChildren()) do
        if item:IsA("Model") and item:GetAttribute("Collected") ~= true then
            count += 1
        end
    end
    return count
end

return DropService
