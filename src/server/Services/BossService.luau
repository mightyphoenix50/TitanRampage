--!strict
--[[
    BossService.luau
    Boss fights in the Colosseum Proving Grounds (Milestone 15).
    Responsibility:
    - Validates challenges against Titan Power and city-clear requirements (BossConfig).
    - Runs one fight at a time per server: party = titans inside the arena ring at the start,
      boss health scaled by party size, telegraphed attacks, phases at 66% / 33%, enrage timer.
    - The only thing in the game that damages titans. A titan at 0 health is knocked out to the hub.
    - Rewards cash on victory to party members with at least 5% of the damage: a first-clear
      reward plus title, then a smaller repeat reward on a per-player cooldown.
    - Bastion readiness test: a 20-second DPS run compared against each boss's recommended DPS.
    Clients only ask (BossRequest) and render (BossFeedback); every number is decided here.
--]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local BossConfig = require(ConfigFolder:WaitForChild("BossConfig") :: ModuleScript)
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService") :: ModuleScript)
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService") :: ModuleScript)
local CityService = require(script.Parent:WaitForChild("CityService") :: ModuleScript)

-- Remotes live in the place file; create them if this place predates Milestone 15
local function getRemote(name: string): RemoteEvent
    local existing = RemotesFolder:FindFirstChild(name)
    if existing and existing:IsA("RemoteEvent") then return existing end
    local remote = Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = RemotesFolder
    return remote
end

local BossFeedbackRemote = getRemote("BossFeedback")
local BossRequestRemote = getRemote("BossRequest")

local BOSS_TAG = "BossTarget"
local GATE_REACH = 420 -- Challenges must come from in or near the Colosseum
local READINESS_WINDOW = 20 -- Seconds of the Bastion readiness test
local STOMP_SOURCES = { Stomp = true, HeavyStomp = true }

type Fight = {
    Def: BossConfig.BossDef,
    Model: Model,
    Core: BasePart,
    MaxHealth: number,
    Health: number,
    Party: { [Player]: boolean },
    Damage: { [Player]: number },
    StartTime: number,
    Phase: number,
    ShieldUntil: number,
    Ended: boolean,
    Target: Player?,
}

local BossService = {}

local activeFight: Fight? = nil
local parkedProps: { { Instance: Instance, Parent: Instance } } = {}

-- Bastion readiness test, per player: window start and damage so far
local readinessRuns: { [Player]: { Start: number, Damage: number } } = {}

--[=[
    Returns (met, reasons) for a player against a boss's requirements.
]=]
function BossService.CheckRequirements(player: Player, bossId: string): (boolean, { string })
    local def = BossConfig.Get(bossId)
    if not def then return false, { "Unknown boss." } end
    local reasons: { string } = {}
    local profile = PlayerDataService.GetProfile(player)
    if not profile then return false, { "Profile not loaded yet." } end

    local power = ProgressionService.GetTitanPower(player)
    if power < def.RequiredPower then table.insert(reasons, string.format("Titan Power %d / %d", power, def.RequiredPower)) end

    for cityId, needed in pairs(def.RequiredCityClears) do
        local clears = if profile.Cities[cityId] then profile.Cities[cityId].Clears else 0
        if clears < needed then table.insert(reasons, string.format("%s clears %d / %d", cityId, clears, needed)) end
    end

    if def.RequiredTotalClears > 0 then
        local total = 0
        for _, city in pairs(profile.Cities) do
            total += city.Clears
        end
        if total < def.RequiredTotalClears then
            table.insert(reasons, string.format("Total city clears %d / %d", total, def.RequiredTotalClears))
        end
    end

    return #reasons == 0, reasons
end

-- Per-player boss board shown by the gate UI
local function buildBoard(player: Player): { any }
    local profile = PlayerDataService.GetProfile(player)
    local board = {}
    for _, def in ipairs(BossConfig.GetList()) do
        local met, reasons = BossService.CheckRequirements(player, def.Id)
        local rec = profile and profile.BossClears[def.Id]
        local cooldownLeft = 0
        if rec and rec.Clears > 0 then cooldownLeft = math.max(0, def.RepeatCooldown - (os.time() - rec.LastClearAt)) end
        table.insert(board, {
            Id = def.Id,
            DisplayName = def.DisplayName,
            Description = def.Description,
            RequiredPower = def.RequiredPower,
            RecommendedDPS = def.RecommendedDPS,
            Ready = met,
            Missing = reasons,
            Clears = if rec then rec.Clears else 0,
            NextReward = if rec and rec.Clears > 0 then def.RepeatCash else def.FirstClearCash,
            CooldownLeft = cooldownLeft,
            Color = def.Color,
        })
    end
    return board
end

local function sendBoard(player: Player)
    BossFeedbackRemote:FireClient(player, "BossBoard", {
        Bosses = buildBoard(player),
        Power = ProgressionService.GetTitanPower(player),
        ReadinessDPS = player:GetAttribute("ReadinessDPS") or 0,
        FightActive = activeFight ~= nil,
    })
end

local function rootOf(player: Player): BasePart?
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then return root end
    return nil
end

local function horizontalDistance(a: Vector3, b: Vector3): number
    return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function fireParty(fight: Fight, eventType: string, payload: any)
    -- Everyone in the arena or watching from the rim sees the fight
    for _, p in ipairs(Players:GetPlayers()) do
        local root = rootOf(p)
        if fight.Party[p] or (root and horizontalDistance(root.Position, BossConfig.ArenaCenter) < GATE_REACH) then
            BossFeedbackRemote:FireClient(p, eventType, payload)
        end
    end
end

-- Moves the Bastion dummy and practice monoliths out of the arena for the fight
local function parkProvingGroundProps()
    local hub = Workspace:FindFirstChild("KaijuHub")
    local arena = hub and hub:FindFirstChild("ColosseumProvingGrounds")
    if not arena then return end
    local holder = ServerStorage:FindFirstChild("BossFightParked") or Instance.new("Folder")
    holder.Name = "BossFightParked"
    holder.Parent = ServerStorage
    for _, child in ipairs(arena:GetChildren()) do
        if child:GetAttribute("IsTrainingDummy") == true or child.Name == "Bastion_Titan_Dummy" then
            table.insert(parkedProps, { Instance = child, Parent = arena })
            child.Parent = holder
        end
    end
end

local function restoreProvingGroundProps()
    for _, parked in ipairs(parkedProps) do
        if parked.Instance and parked.Parent and parked.Parent.Parent then parked.Instance.Parent = parked.Parent end
    end
    table.clear(parkedProps)
end

-- Part-built stand-in used until the boss's model exists in ReplicatedStorage.Assets.Bosses
local function buildFallbackModel(def: BossConfig.BossDef): Model
    local model = Instance.new("Model")
    model.Name = def.Id
    local s = def.Scale
    local function part(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): BasePart
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.CFrame = offset
        p.Color = color
        p.Material = material
        p.Anchored = true
        p.CanCollide = name == "Core"
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent = model
        return p
    end
    local dark = def.Color:Lerp(Color3.new(0.08, 0.07, 0.08), 0.7)
    local core = part("Core", Vector3.new(s * 0.45, s * 0.6, s * 0.35), CFrame.new(0, s * 0.5, 0), dark, Enum.Material.Basalt)
    part("Head", Vector3.new(s * 0.28, s * 0.22, s * 0.28), CFrame.new(0, s * 0.92, -s * 0.04), dark, Enum.Material.Basalt)
    part("EyeL", Vector3.new(s * 0.05, s * 0.03, s * 0.02), CFrame.new(-s * 0.06, s * 0.95, -s * 0.18), def.Color, Enum.Material.Neon)
    part("EyeR", Vector3.new(s * 0.05, s * 0.03, s * 0.02), CFrame.new(s * 0.06, s * 0.95, -s * 0.18), def.Color, Enum.Material.Neon)
    part(
        "ArmL",
        Vector3.new(s * 0.16, s * 0.55, s * 0.16),
        CFrame.new(-s * 0.32, s * 0.55, 0) * CFrame.Angles(0, 0, math.rad(-8)),
        dark,
        Enum.Material.Slate
    )
    part(
        "ArmR",
        Vector3.new(s * 0.16, s * 0.55, s * 0.16),
        CFrame.new(s * 0.32, s * 0.55, 0) * CFrame.Angles(0, 0, math.rad(8)),
        dark,
        Enum.Material.Slate
    )
    part("LegL", Vector3.new(s * 0.17, s * 0.3, s * 0.2), CFrame.new(-s * 0.13, s * 0.15, 0), dark, Enum.Material.Basalt)
    part("LegR", Vector3.new(s * 0.17, s * 0.3, s * 0.2), CFrame.new(s * 0.13, s * 0.15, 0), dark, Enum.Material.Basalt)
    part("CoreGlow", Vector3.new(s * 0.2, s * 0.2, s * 0.02), CFrame.new(0, s * 0.55, -s * 0.18), def.Color, Enum.Material.Neon)
    model.PrimaryPart = core
    return model
end

local function spawnBossModel(def: BossConfig.BossDef): (Model, BasePart)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local bossesFolder = assets and assets:FindFirstChild("Bosses")
    local template = bossesFolder and bossesFolder:FindFirstChild(def.Id)
    local model: Model
    if template and template:IsA("Model") then
        model = template:Clone()
    else
        model = buildFallbackModel(def)
    end
    if not model.PrimaryPart then model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true) end
    local core = model.PrimaryPart :: BasePart
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then d.Anchored = true end
    end

    -- Stand the model on the arena floor at the centre
    local _, size = model:GetBoundingBox()
    model:PivotTo(CFrame.new(BossConfig.ArenaCenter + Vector3.new(0, size.Y * 0.5, 0)))
    local _, finalSize = model:GetBoundingBox()

    model:SetAttribute("IsBoss", true)
    model:SetAttribute("BossId", def.Id)
    model:SetAttribute("BuildingName", def.DisplayName)
    model:SetAttribute("DestructionTier", 1) -- Abilities apply no tier reduction to bosses
    model:SetAttribute("HitRadius", math.max(finalSize.X, finalSize.Z) * 0.5)
    CollectionService:AddTag(model, BOSS_TAG)
    model.Parent = Workspace
    return model, core
end

-- Titans only ever take damage here. At 0 health they are knocked out to the hub, not killed.
local function damageTitan(fight: Fight, player: Player, amount: number)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    local newHealth = humanoid.Health - amount
    if newHealth > 0 then
        humanoid.Health = newHealth
        BossFeedbackRemote:FireClient(player, "TitanHit", { Damage = amount, Health = newHealth, MaxHealth = humanoid.MaxHealth })
        return
    end

    fight.Party[player] = nil
    humanoid.Health = humanoid.MaxHealth
    CityService.ReturnToHub(player)
    BossFeedbackRemote:FireClient(player, "KnockedOut", { BossName = fight.Def.DisplayName })
    print(string.format("[BossService] 💫 %s was knocked out by %s", player.Name, fight.Def.DisplayName))
end

local function partyList(fight: Fight): { Player }
    local list = {}
    for p in pairs(fight.Party) do
        if p.Parent then table.insert(list, p) end
    end
    return list
end

local function healthPayload(fight: Fight)
    return {
        BossId = fight.Def.Id,
        BossName = fight.Def.DisplayName,
        Health = math.max(0, math.floor(fight.Health)),
        MaxHealth = fight.MaxHealth,
        Phase = fight.Phase,
        Shielded = os.clock() < fight.ShieldUntil,
        EnrageAt = fight.StartTime + fight.Def.EnrageTime,
        ServerClock = os.clock(),
        PartySize = #partyList(fight),
    }
end

local function endFight(fight: Fight, victory: boolean, reason: string)
    if fight.Ended then return end
    fight.Ended = true
    activeFight = nil

    local rewards: { [string]: any } = {}
    if victory then
        local totalDamage = 0
        for _, dealt in pairs(fight.Damage) do
            totalDamage += dealt
        end
        local now = os.time()
        for p, dealt in pairs(fight.Damage) do
            if p.Parent and totalDamage > 0 and dealt / totalDamage >= BossConfig.MinDamageShare then
                local cash = 0
                local firstClear = false
                local title: string? = nil
                PlayerDataService.UpdateProfile(p, function(profile)
                    local rec = profile.BossClears[fight.Def.Id]
                    if not rec then
                        rec = { Clears = 0, LastClearAt = 0 }
                        profile.BossClears[fight.Def.Id] = rec
                    end
                    if rec.Clears == 0 then
                        firstClear = true
                        cash = fight.Def.FirstClearCash
                        rec.LastClearAt = now
                        profile.Titles[fight.Def.Title] = true
                        title = fight.Def.Title
                    elseif now - rec.LastClearAt >= fight.Def.RepeatCooldown then
                        cash = fight.Def.RepeatCash
                        rec.LastClearAt = now
                    end
                    rec.Clears += 1
                end)
                if cash > 0 then ProgressionService.AddRewards(p, cash, 0) end
                if title then p:SetAttribute("BossTitle", title) end
                if firstClear and fight.Def.UnlocksTitan and not PlayerDataService.IsTitanUnlocked(p, fight.Def.UnlocksTitan) then
                    PlayerDataService.UnlockTitan(p, fight.Def.UnlocksTitan)
                    local titanFeedback = RemotesFolder:FindFirstChild("TitanFeedback") :: RemoteEvent?
                    if titanFeedback then
                        titanFeedback:FireClient(p, "TitanListSync", {
                            Titans = PlayerDataService.GetTitansData(p),
                            SelectedTitan = PlayerDataService.GetSelectedTitan(p),
                        })
                    end
                end
                rewards[tostring(p.UserId)] = { Cash = cash, FirstClear = firstClear, Title = title, Share = dealt / totalDamage }
                print(
                    string.format(
                        "[BossService] 🏆 %s rewarded $%d for %s (%.0f%% of damage%s)",
                        p.Name,
                        cash,
                        fight.Def.DisplayName,
                        dealt / totalDamage * 100,
                        if firstClear then ", first clear" else ""
                    )
                )
            end
        end
    end

    fireParty(fight, "FightEnded", {
        BossId = fight.Def.Id,
        BossName = fight.Def.DisplayName,
        Victory = victory,
        Reason = reason,
        Rewards = rewards,
        Duration = math.floor(os.clock() - fight.StartTime),
    })

    -- Heal the surviving party
    for _, p in ipairs(partyList(fight)) do
        local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.Health = humanoid.MaxHealth end
    end

    -- Collapse the boss: debris burst through the destruction feedback, then sink out
    local destructionFeedback = RemotesFolder:FindFirstChild("DestructionFeedback") :: RemoteEvent?
    if victory and destructionFeedback then
        destructionFeedback:FireAllClients("BuildingDestroyed", {
            Building = fight.Model,
            Position = fight.Core.Position,
            Rewards = { Cash = 0, XP = 0, Combo = 1 },
        })
    end
    CollectionService:RemoveTag(fight.Model, BOSS_TAG)
    local sinkTime = if victory then 2.5 else 1.0
    for _, d in ipairs(fight.Model:GetDescendants()) do
        if d:IsA("BasePart") then
            TweenService:Create(d, TweenInfo.new(sinkTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                CFrame = d.CFrame - Vector3.new(0, fight.Def.Scale * 1.2, 0),
                Transparency = 1,
            }):Play()
        end
    end
    task.delay(sinkTime + 0.2, function()
        fight.Model:Destroy()
        restoreProvingGroundProps()
    end)

    print(
        string.format(
            "[BossService] Fight against %s ended: %s (%s)",
            fight.Def.DisplayName,
            if victory then "VICTORY" else "defeat",
            reason
        )
    )
end

-- Picks a living party member for the boss to face
local function pickTarget(fight: Fight): Player?
    local party = partyList(fight)
    if #party == 0 then return nil end
    return party[math.random(1, #party)]
end

local function inCone(origin: Vector3, forward: Vector3, point: Vector3, radius: number, halfAngle: number): boolean
    local offset = Vector3.new(point.X - origin.X, 0, point.Z - origin.Z)
    if offset.Magnitude > radius then return false end
    if offset.Magnitude < 1 then return true end
    local flatForward = Vector3.new(forward.X, 0, forward.Z).Unit
    return math.deg(math.acos(math.clamp(flatForward:Dot(offset.Unit), -1, 1))) <= halfAngle
end

local function runAttack(fight: Fight, attack: BossConfig.BossAttack)
    local center = BossConfig.ArenaCenter
    local bossPos = Vector3.new(fight.Core.Position.X, center.Y, fight.Core.Position.Z)
    local target = fight.Target and rootOf(fight.Target)
    local forward = if target then (Vector3.new(target.Position.X, center.Y, target.Position.Z) - bossPos) else fight.Core.CFrame.LookVector
    if forward.Magnitude < 0.1 then forward = Vector3.new(0, 0, -1) end
    forward = forward.Unit

    if attack.Kind == "Shield" then
        fight.ShieldUntil = os.clock() + (attack.Duration or 8)
        fireParty(fight, "Telegraph", { Kind = "Shield", AttackId = attack.Id, Duration = attack.Duration })
        fireParty(fight, "BossHealth", healthPayload(fight))
        return
    end

    -- Build the hit shapes now so the telegraph and the hit match exactly
    local circles: { { Center: Vector3, Radius: number } } = {}
    local lanes: { { Center: Vector3, Width: number, Length: number } } = {}
    local laneAxis = Vector3.new(1, 0, 0)
    if attack.Kind == "Slam" then
        table.insert(circles, { Center = bossPos, Radius = attack.Radius or 40 })
    elseif attack.Kind == "Circle" then
        for _, p in ipairs(partyList(fight)) do
            local root = rootOf(p)
            if root then
                table.insert(circles, { Center = Vector3.new(root.Position.X, center.Y, root.Position.Z), Radius = attack.Radius or 20 })
            end
        end
    elseif attack.Kind == "Lanes" then
        -- Strips across the arena with equal gaps between them; the axis alternates each cast
        laneAxis = if math.random() < 0.5 then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
        local count = attack.Count or 5
        local width = attack.Width or 30
        local span = BossConfig.ArenaRadius * 2
        local spacing = span / count
        local offset = math.random() * spacing * 0.5
        local across = Vector3.new(laneAxis.Z, 0, laneAxis.X)
        for i = 0, count - 1 do
            local along = -BossConfig.ArenaRadius + offset + spacing * i + width * 0.5
            table.insert(lanes, { Center = center + across * along, Width = width, Length = span })
        end
    end

    fireParty(fight, "Telegraph", {
        Kind = attack.Kind,
        AttackId = attack.Id,
        WindUp = attack.WindUp,
        Origin = bossPos,
        Forward = forward,
        Radius = attack.Radius,
        InnerRadius = attack.InnerRadius,
        Angle = attack.Angle,
        Circles = circles,
        Lanes = lanes,
        LaneAxis = laneAxis,
        Color = fight.Def.Color,
    })

    task.wait(attack.WindUp)
    if fight.Ended then return end

    for _, p in ipairs(partyList(fight)) do
        local root = rootOf(p)
        if root then
            local pos = Vector3.new(root.Position.X, center.Y, root.Position.Z)
            local hit = false
            if attack.Kind == "Slam" or attack.Kind == "Circle" then
                for _, c in ipairs(circles) do
                    if horizontalDistance(pos, c.Center) <= c.Radius then hit = true end
                end
            elseif attack.Kind == "Donut" then
                local d = horizontalDistance(pos, bossPos)
                hit = d >= (attack.InnerRadius or 50) and d <= (attack.Radius or 150)
            elseif attack.Kind == "Cone" then
                hit = inCone(bossPos, forward, pos, attack.Radius or 120, attack.Angle or 35)
            elseif attack.Kind == "Lanes" then
                local across = Vector3.new(laneAxis.Z, 0, laneAxis.X)
                for _, lane in ipairs(lanes) do
                    local rel = pos - lane.Center
                    if math.abs(rel:Dot(across)) <= lane.Width * 0.5 and math.abs(rel:Dot(laneAxis)) <= lane.Length * 0.5 then
                        hit = true
                    end
                end
            end
            if hit then damageTitan(fight, p, attack.Damage) end
        end
    end

    fireParty(fight, "AttackImpact", { Kind = attack.Kind, AttackId = attack.Id, Origin = bossPos })
end

local function runFightLoop(fight: Fight)
    local lastAttackId = ""
    while not fight.Ended do
        local interval = fight.Def.AttackInterval * (BossConfig.PhaseSpeedup ^ (fight.Phase - 1))
        local waited = 0
        while waited < interval and not fight.Ended do
            local dt = task.wait(0.25)
            waited += dt

            -- Drop party members who left the arena (portal, reset); they keep their damage share
            for _, p in ipairs(partyList(fight)) do
                local root = rootOf(p)
                if not root or horizontalDistance(root.Position, BossConfig.ArenaCenter) > BossConfig.ArenaRadius + 60 then
                    fight.Party[p] = nil
                    BossFeedbackRemote:FireClient(p, "LeftFight", { BossName = fight.Def.DisplayName })
                end
            end
            if #partyList(fight) == 0 then
                endFight(fight, false, "Every titan was knocked out or left the arena")
                return
            end
            if os.clock() - fight.StartTime >= fight.Def.EnrageTime then
                for _, p in ipairs(partyList(fight)) do
                    damageTitan(fight, p, math.huge)
                end
                endFight(fight, false, "Enrage timer ran out")
                return
            end

            -- Face the current target
            local targetRoot = fight.Target and rootOf(fight.Target)
            if targetRoot then
                local pivot = fight.Model:GetPivot()
                local look = Vector3.new(targetRoot.Position.X, pivot.Position.Y, targetRoot.Position.Z)
                if (look - pivot.Position).Magnitude > 1 then fight.Model:PivotTo(CFrame.lookAt(pivot.Position, look)) end
            end
        end
        if fight.Ended then return end

        fight.Target = pickTarget(fight)
        local pool = {}
        for _, attack in ipairs(fight.Def.Attacks) do
            if attack.MinPhase <= fight.Phase and attack.Id ~= lastAttackId then table.insert(pool, attack) end
        end
        if #pool > 0 then
            local attack = pool[math.random(1, #pool)]
            lastAttackId = attack.Id
            runAttack(fight, attack)
        end
    end
end

--[=[
    Starts a fight for `challenger` against `bossId` if every rule allows it.
]=]
function BossService.StartFight(challenger: Player, bossId: string): (boolean, string)
    local def = BossConfig.Get(bossId)
    if not def then return false, "Unknown boss." end
    if activeFight then return false, string.format("%s is already being fought. Wait for it to finish.", activeFight.Def.DisplayName) end

    local met, reasons = BossService.CheckRequirements(challenger, bossId)
    if not met then return false, "Not ready: " .. table.concat(reasons, ", ") end

    local challengerRoot = rootOf(challenger)
    if not challengerRoot then return false, "Your titan hasn't spawned yet." end
    if horizontalDistance(challengerRoot.Position, BossConfig.ArenaCenter) > GATE_REACH then
        return false, "Challenge bosses from the Colosseum gate."
    end

    parkProvingGroundProps()
    local model, core = spawnBossModel(def)

    local party: { [Player]: boolean } = { [challenger] = true }
    for _, p in ipairs(Players:GetPlayers()) do
        local root = rootOf(p)
        if root and horizontalDistance(root.Position, BossConfig.ArenaCenter) <= BossConfig.ArenaRadius then party[p] = true end
    end

    -- Bring the challenger into the ring, facing the boss
    local entry = BossConfig.ArenaCenter + Vector3.new(0, 12, BossConfig.ArenaRadius - 25)
    if horizontalDistance(challengerRoot.Position, BossConfig.ArenaCenter) > BossConfig.ArenaRadius - 10 then
        challenger.Character:PivotTo(CFrame.lookAt(entry, Vector3.new(BossConfig.ArenaCenter.X, entry.Y, BossConfig.ArenaCenter.Z)))
    end

    local partySize = 0
    for p in pairs(party) do
        partySize += 1
        local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.Health = humanoid.MaxHealth end
    end
    local maxHealth = math.floor(def.BaseHealth * (1 + def.HealthPerExtraPlayer * (partySize - 1)))

    local fight: Fight = {
        Def = def,
        Model = model,
        Core = core,
        MaxHealth = maxHealth,
        Health = maxHealth,
        Party = party,
        Damage = {},
        StartTime = os.clock(),
        Phase = 1,
        ShieldUntil = 0,
        Ended = false,
        Target = challenger,
    }
    activeFight = fight
    model:SetAttribute("MaxHealth", maxHealth)
    model:SetAttribute("CurrentHealth", maxHealth)

    fireParty(fight, "FightStarted", healthPayload(fight))
    print(
        string.format("[BossService] ⚔️ %s challenged %s (party of %d, %d HP)", challenger.Name, def.DisplayName, partySize, maxHealth)
    )
    task.spawn(runFightLoop, fight)
    return true, "Fight started"
end

--[=[
    Applies ability damage to the active boss. Called by DestructionService after its reach check.
]=]
function BossService.DamageBoss(player: Player, model: Model, damage: number, source: string): (boolean, number)
    local fight = activeFight
    if not fight or fight.Ended or fight.Model ~= model then return false, 0 end
    if not fight.Party[player] then return false, 0 end
    if os.clock() < fight.ShieldUntil and not STOMP_SOURCES[source] then
        BossFeedbackRemote:FireClient(player, "Shielded", { BossName = fight.Def.DisplayName })
        return false, 0
    end

    local applied = math.min(fight.Health, math.max(0, math.floor(damage)))
    if applied <= 0 then return false, 0 end
    fight.Health -= applied
    fight.Damage[player] = (fight.Damage[player] or 0) + applied
    model:SetAttribute("CurrentHealth", math.max(0, fight.Health))

    local fraction = fight.Health / fight.MaxHealth
    local newPhase = 1
    for i, threshold in ipairs(BossConfig.PhaseThresholds) do
        if fraction <= threshold then newPhase = i + 1 end
    end
    if newPhase > fight.Phase then
        fight.Phase = newPhase
        fireParty(fight, "PhaseChanged", { BossName = fight.Def.DisplayName, Phase = newPhase })
    end

    fireParty(fight, "BossHealth", healthPayload(fight))

    if fight.Health <= 0 then endFight(fight, true, "Boss defeated") end
    return true, applied
end

function BossService.GetActiveFight(): Fight?
    return activeFight
end

--[=[
    Bastion readiness test: the first hit on the Bastion dummy starts a 20-second window; the
    result is compared with each boss's recommended DPS on the gate board.
]=]
function BossService.RecordReadinessDamage(player: Player, damage: number)
    local now = os.clock()
    local run = readinessRuns[player]
    if not run then
        run = { Start = now, Damage = 0 }
        readinessRuns[player] = run
        BossFeedbackRemote:FireClient(player, "ReadinessStarted", { Duration = READINESS_WINDOW })
        task.delay(READINESS_WINDOW, function()
            local finished = readinessRuns[player]
            readinessRuns[player] = nil
            if not finished or not player.Parent then return end
            local dps = math.floor(finished.Damage / READINESS_WINDOW)
            local best = math.max(dps, tonumber(player:GetAttribute("ReadinessDPS")) or 0)
            player:SetAttribute("ReadinessDPS", best)
            local verdicts = {}
            for _, def in ipairs(BossConfig.GetList()) do
                table.insert(
                    verdicts,
                    { BossName = def.DisplayName, RecommendedDPS = def.RecommendedDPS, Ready = dps >= def.RecommendedDPS }
                )
            end
            BossFeedbackRemote:FireClient(player, "ReadinessResult", { DPS = dps, Best = best, Verdicts = verdicts })
        end)
    end
    run.Damage += math.max(0, damage)
end

function BossService.Init()
    print("[BossService] Initializing BossService...")

    BossRequestRemote.OnServerEvent:Connect(function(player: Player, action: any, bossId: any)
        if action == "RequestBoard" then
            sendBoard(player)
        elseif action == "DevPrepare" and RunService:IsStudio() then
            -- Studio-only QA shortcut: upgrades and clears for the requested boss. Never live.
            local def = type(bossId) == "string" and BossConfig.Get(bossId)
            if not def then return end
            PlayerDataService.UpdateProfile(player, function(profile)
                for catId in pairs(profile.Upgrades) do
                    profile.Upgrades[catId] = math.max(profile.Upgrades[catId], 4)
                end
                for cityId, needed in pairs(def.RequiredCityClears) do
                    if profile.Cities[cityId] then profile.Cities[cityId].Clears = math.max(profile.Cities[cityId].Clears, needed) end
                end
                if def.RequiredTotalClears > 0 and profile.Cities.SmallTown then
                    profile.Cities.SmallTown.Clears = math.max(profile.Cities.SmallTown.Clears, def.RequiredTotalClears)
                end
            end)
            ProgressionService.RefreshTitanPower(player)
            sendBoard(player)
        elseif action == "Challenge" then
            if type(bossId) ~= "string" or not BossConfig.Get(bossId) then return end
            local ok, message = BossService.StartFight(player, bossId)
            if not ok then BossFeedbackRemote:FireClient(player, "ChallengeRejected", { Reason = message }) end
            sendBoard(player)
        end
    end)

    -- The Colosseum boss gate is any proximity prompt tagged with a BossGate attribute (Studio)
    ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
        if prompt:GetAttribute("BossGate") == true then sendBoard(player) end
    end)

    Players.PlayerRemoving:Connect(function(player)
        readinessRuns[player] = nil
        local fight = activeFight
        if fight then fight.Party[player] = nil end
    end)
end

function BossService.Start()
    print("[BossService] BossService started.")
end

return BossService
