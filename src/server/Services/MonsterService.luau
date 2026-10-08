--!strict
--[[
    MonsterService.luau
    Responsibility:
    - Server-authoritative management of active Titan characters/monsters.
    - Spawning, character setup, camera boundaries, and Titan state tracking.
    - Server-authoritative ability execution & cooldown validation with Progression upgrades.
    - Resolves Titan definitions, stats, and upgrade mappings authoritatively through TitanRegistry.
    - Integrates Basic Attack and Stomp with DestructionService using upgraded stats.
    - Broadcasts visual/audio effect events to clients.
    - Milestone 9A: Multi-Titan Architecture.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local ModelsFolder = AssetsFolder:WaitForChild("Models")

local TitanRegistry = require(SharedFolder:WaitForChild("TitanRegistry") :: ModuleScript)
local DestructionConfig = require(ConfigFolder:WaitForChild("DestructionConfig") :: ModuleScript)

local TitanActionRemote = RemotesFolder:WaitForChild("TitanAction") :: RemoteEvent
local TitanEffectRemote = RemotesFolder:WaitForChild("TitanEffect") :: RemoteEvent
local TitanSelectRequest = RemotesFolder:WaitForChild("TitanSelectRequest") :: RemoteEvent
local TitanFeedbackRemote = RemotesFolder:WaitForChild("TitanFeedback") :: RemoteEvent

-- Services
local CityService = require(script.Parent:WaitForChild("CityService") :: ModuleScript)
local DestructionService = require(script.Parent:WaitForChild("DestructionService") :: ModuleScript)
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService") :: ModuleScript)
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService") :: ModuleScript)

local MonsterService = {}

-- State tracking per player UserId
type CooldownMap = { [string]: number }
local playerCooldowns: { [number]: CooldownMap } = {}
local activeTitans: { [number]: string } = {}
local playerAttackVariantIndex: { [number]: number } = {}
local ATTACK_VARIANTS = { "LeftSwipe", "RightSwipe", "DownwardSmash" }
local isSpawning: { [number]: boolean } = {}

--[=[
    Initializes service data structures and binds remote events.
]=]
function MonsterService.Init()
    print("[MonsterService] Initializing MonsterService...")

    -- Bind client action requests
    TitanActionRemote.OnServerEvent:Connect(function(player: Player, actionName: any)
        if type(actionName) ~= "string" then return end
        MonsterService.ProcessAbilityRequest(player, actionName)
    end)

    -- Bind Titan selection / sync requests
    TitanSelectRequest.OnServerEvent:Connect(function(player: Player, action: any, titanId: any)
        if action == "Select" and type(titanId) == "string" then
            MonsterService.SelectTitan(player, titanId)
        elseif action == "RequestSync" then
            local titans = PlayerDataService.GetTitansData(player)
            local selected = PlayerDataService.GetSelectedTitan(player)
            TitanFeedbackRemote:FireClient(player, "TitanListSync", {
                Titans = titans,
                SelectedTitan = selected,
            })
        end
    end)

    -- Bind player lifecycle
    Players.PlayerAdded:Connect(function(player)
        playerCooldowns[player.UserId] = {}
        local initialTitan = PlayerDataService.GetSelectedTitan(player) or "Ravager"
        activeTitans[player.UserId] = initialTitan
        playerAttackVariantIndex[player.UserId] = 0

        player.CharacterAdded:Connect(function(character)
            if isSpawning[player.UserId] then return end

            local selected = activeTitans[player.UserId] or PlayerDataService.GetSelectedTitan(player)
            local charTitan = character:GetAttribute("TitanId") or "Ravager"

            if selected ~= charTitan then
                task.spawn(function()
                    MonsterService.SpawnPlayerTitan(player, selected)
                end)
            else
                MonsterService.SetupTitanCharacter(player, character)
            end
        end)

        if player.Character then
            local selected = activeTitans[player.UserId] or PlayerDataService.GetSelectedTitan(player)
            local charTitan = player.Character:GetAttribute("TitanId") or "Ravager"
            if selected ~= charTitan then
                MonsterService.SpawnPlayerTitan(player, selected)
            else
                MonsterService.SetupTitanCharacter(player, player.Character)
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        playerCooldowns[player.UserId] = nil
        activeTitans[player.UserId] = nil
        playerAttackVariantIndex[player.UserId] = nil
        isSpawning[player.UserId] = nil
    end)
end

--[=[
    Starts service loops and handles any players already present.
]=]
function MonsterService.Start()
    print("[MonsterService] MonsterService started.")
    for _, player in ipairs(Players:GetPlayers()) do
        if not playerCooldowns[player.UserId] then
            playerCooldowns[player.UserId] = {}
            local sel = PlayerDataService.GetSelectedTitan(player) or "Ravager"
            activeTitans[player.UserId] = sel
            playerAttackVariantIndex[player.UserId] = 0
        end
        if player.Character then
            local selected = activeTitans[player.UserId] or PlayerDataService.GetSelectedTitan(player)
            local charTitan = player.Character:GetAttribute("TitanId") or "Ravager"
            if selected ~= charTitan then
                MonsterService.SpawnPlayerTitan(player, selected)
            else
                MonsterService.SetupTitanCharacter(player, player.Character)
            end
        end
    end
end

--[=[
    Selects and validates a Titan for the player server-side.
    Enforces registered Titan, model availability, and authoritative unlock status.
]=]
function MonsterService.SelectTitan(player: Player, titanId: string)
    if type(titanId) ~= "string" then
        return
    end

    local titanDef = TitanRegistry.Get(titanId)
    if not titanDef then
        warn(string.format("[MonsterService] Unknown titan selection: '%s' from %s", tostring(titanId), player.Name))
        TitanFeedbackRemote:FireClient(player, "TitanSelectRejected", {
            TitanId = titanId,
            Reason = "Unknown Titan.",
        })
        return
    end

    local modelTemplate = ModelsFolder:FindFirstChild(titanDef.ModelName)
    if not modelTemplate then
        warn(string.format("[MonsterService] Model template not found in Assets.Models for %s", titanId))
        TitanFeedbackRemote:FireClient(player, "TitanSelectRejected", {
            TitanId = titanId,
            Reason = "Titan model not found in Assets.",
        })
        return
    end

    local unlocked = PlayerDataService.IsTitanUnlocked(player, titanId)
    if not unlocked then
        TitanFeedbackRemote:FireClient(player, "TitanSelectRejected", {
            TitanId = titanId,
            Reason = "Titan is locked.",
        })
        print(string.format("[MonsterService] ❌ Rejected Titan %s selection for %s: Locked", titanId, player.Name))
        return
    end

    if isSpawning[player.UserId] then
        TitanFeedbackRemote:FireClient(player, "TitanSelectRejected", {
            TitanId = titanId,
            Reason = "Spawn in progress.",
        })
        return
    end

    PlayerDataService.SetSelectedTitan(player, titanId)
    activeTitans[player.UserId] = titanId
    MonsterService.SpawnPlayerTitan(player, titanId)
    TitanFeedbackRemote:FireClient(player, "TitanSelected", {
        TitanId = titanId,
        SelectedTitan = titanId,
        Titans = PlayerDataService.GetTitansData(player),
    })
    print(string.format("[MonsterService] ✅ %s successfully selected Titan %s", player.Name, titanId))
end

--[=[
    Spawns the requested Titan model for the player.
]=]
function MonsterService.SpawnPlayerTitan(player: Player, titanId: string)
    local titanDef = TitanRegistry.Get(titanId)
    if not titanDef then return end

    local modelTemplate = ModelsFolder:FindFirstChild(titanDef.ModelName)
    if not modelTemplate then
        warn(string.format("[MonsterService] Model template not found in Assets.Models for %s", titanId))
        return
    end

    isSpawning[player.UserId] = true

    local oldChar = player.Character
    local spawnCFrame: CFrame? = nil

    if oldChar and oldChar.PrimaryPart then
        spawnCFrame = oldChar.PrimaryPart.CFrame + Vector3.new(0, 2, 0)
    else
        local cityFolder = Workspace:FindFirstChild("Cities")
        local smallTown = cityFolder and cityFolder:FindFirstChild("SmallTown")
        local spawnPart = smallTown and smallTown:FindFirstChild("SpawnLocation")
        if spawnPart and spawnPart:IsA("BasePart") then
            spawnCFrame = spawnPart.CFrame + Vector3.new(0, 8, 0)
        else
            spawnCFrame = CFrame.new(0, 15, 0)
        end
    end

    local newChar = modelTemplate:Clone()
    newChar.Name = player.Name
    newChar:SetAttribute("TitanId", titanId)

    if spawnCFrame then
        newChar:PivotTo(spawnCFrame)
    end

    newChar.Parent = Workspace
    player.Character = newChar

    if oldChar and oldChar ~= newChar then
        oldChar:Destroy()
    end

    activeTitans[player.UserId] = titanId
    playerAttackVariantIndex[player.UserId] = 0

    MonsterService.SetupTitanCharacter(player, newChar)

    TitanFeedbackRemote:FireClient(player, "TitanSpawned", { TitanId = titanId })
    task.wait(0.1)
    isSpawning[player.UserId] = false
end

--[=[
    Called by ProgressionService whenever a player purchases a stat upgrade.
    Instantly updates active character properties through TitanRegistry calculation.
]=]
function MonsterService.OnUpgradePurchased(player: Player, upgradeId: string, newLevel: number, newValue: number)
    if upgradeId == "WalkSpeed" then
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                local titanId = activeTitans[player.UserId] or "Ravager"
                local finalSpeed = TitanRegistry.CalculateWalkSpeed(titanId, newValue)
                humanoid.WalkSpeed = finalSpeed
                print(string.format("[MonsterService] Dynamically updated %s WalkSpeed to %d (Upgrade Level %d)", player.Name, humanoid.WalkSpeed, newLevel))
            end
        end
    end
end

--[=[
    Configures character properties, Humanoid values, and camera parameters for the Titan.
    Resolves base values and upgrade formulas authoritatively via TitanRegistry.
]=]
function MonsterService.SetupTitanCharacter(player: Player, character: Model)
    local titanId = character:GetAttribute("TitanId") or activeTitans[player.UserId] or PlayerDataService.GetSelectedTitan(player) or "Ravager"
    activeTitans[player.UserId] = titanId
    character:SetAttribute("TitanId", titanId)

    local titanDef = TitanRegistry.Get(titanId) or TitanRegistry.Get("Ravager")
    if not titanDef then return end

    local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
    if not humanoid then return end

    local upgradeSpeed = ProgressionService.GetUpgradeValue(player, "WalkSpeed")
    local finalSpeed = TitanRegistry.CalculateWalkSpeed(titanId, upgradeSpeed)

    humanoid.MaxHealth = titanDef.BaseHealth
    humanoid.Health = titanDef.BaseHealth
    humanoid.WalkSpeed = finalSpeed
    humanoid.JumpPower = titanDef.JumpPower
    humanoid.HipHeight = titanDef.HipHeight
    humanoid.DisplayName = string.format("%s (%s)", player.DisplayName, titanDef.DisplayName)

    player.CameraMinZoomDistance = titanDef.CameraZoom.Min
    player.CameraMaxZoomDistance = titanDef.CameraZoom.Max
    humanoid.CameraOffset = titanDef.CameraZoom.CameraOffset

    print(string.format("[MonsterService] Configured %s as Titan: %s (HP: %d, WalkSpeed: %d, HipHeight: %.2f)",
        player.Name, titanDef.DisplayName, titanDef.BaseHealth, finalSpeed, titanDef.HipHeight))
end

--[=[
    Executes Basic Melee Attack using player's upgraded damage against valid target buildings.
]=]
function MonsterService.ExecuteBasicAttack(player: Player, character: Model, hrp: BasePart, abilityDef: any, titanDef: any)
    local range = abilityDef.Range or DestructionConfig.BasicAttackRange or 22
    local radius = abilityDef.Radius or DestructionConfig.BasicAttackRadius or 18
    local strikePosition = hrp.Position + (hrp.CFrame.LookVector * (range * 0.5))

    -- Cycle through attack variants for rhythmic combat choreography
    local nextIdx = ((playerAttackVariantIndex[player.UserId] or 0) % #ATTACK_VARIANTS) + 1
    playerAttackVariantIndex[player.UserId] = nextIdx
    local currentVariant = ATTACK_VARIANTS[nextIdx]

    -- 1. Broadcast visual swing effect to clients with variant tag
    TitanEffectRemote:FireAllClients("BasicAttack", character, {
        Position = strikePosition,
        LookVector = hrp.CFrame.LookVector,
        Variant = currentVariant,
    })

    -- 2. Query nearby buildings via CityService
    if CityService and DestructionService then
        local nearbyBuildings = CityService.GetBuildingsInRadius(strikePosition, radius)
        local targetBuilding = nil
        local targetDist = 9999

        for _, item in ipairs(nearbyBuildings) do
            local bld = item.Building
            if not bld:GetAttribute("IsDestroyed") then
                -- Verify building is in front of Titan (dot product > -0.1)
                local bldPos = item.Entry.Position
                local toBld = (Vector3.new(bldPos.X, 0, bldPos.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Unit
                local dot = hrp.CFrame.LookVector:Dot(toBld)

                if dot > -0.1 and item.Distance < targetDist then
                    targetDist = item.Distance
                    targetBuilding = bld
                end
            end
        end

        if targetBuilding then
            local tier = tonumber(targetBuilding:GetAttribute("DestructionTier")) or 1
            local upgradePower = ProgressionService.GetUpgradeValue(player, "BasicAttackDamage")
            local baseDmg = TitanRegistry.CalculateAbilityDamage(titanDef.Id, "BasicAttack", upgradePower)
            local tierMult = if tier == 1 then 1.0 elseif tier == 2 then 0.67 elseif tier == 3 then 0.50 else 0.40
            local calculatedDamage = math.max(1, math.floor(baseDmg * tierMult))

            local success, damageApplied = DestructionService.DamageBuilding(targetBuilding, calculatedDamage, player, "BasicAttack")
            if success then
                print(string.format("[MonsterService] [Basic Attack - %s] %s (%s) struck '%s' for %d damage! (Remaining HP: %s)",
                    currentVariant, player.Name, titanDef.DisplayName, targetBuilding.Name, damageApplied, tostring(targetBuilding:GetAttribute("CurrentHealth"))))
            end
        else
            print(string.format("[MonsterService] [Basic Attack - %s] %s (%s) attacked air. No buildings in melee arc.", currentVariant, player.Name, titanDef.DisplayName))
        end
    end
end

--[=[
    Executes Stomp Ability with wind-up and upgraded area-of-effect radius & damage.
]=]
function MonsterService.ExecuteStomp(player: Player, character: Model, hrp: BasePart, abilityDef: any, titanDef: any)
    local windUp = abilityDef.WindUp or 0.35
    local upgradeRadius = ProgressionService.GetUpgradeValue(player, "StompRadius")
    local radius = TitanRegistry.CalculateAbilityRadius(titanDef.Id, "Stomp", upgradeRadius)
    local groundPos = hrp.Position - Vector3.new(0, hrp.Size.Y * 0.5, 0)

    print(string.format("[MonsterService] [Stomp Wind-up] %s (%s) preparing Stomp (%.2fs windup, %d radius)...",
        player.Name, titanDef.DisplayName, windUp, radius))

    -- Broadcast windup visual anticipation event
    TitanEffectRemote:FireAllClients("StompWindup", character, {
        Position = groundPos,
        Radius = radius,
        WindUp = windUp,
    })

    task.delay(windUp, function()
        if not character.Parent then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end

        local impactGroundPos = hrp.Position - Vector3.new(0, hrp.Size.Y * 0.5, 0)

        -- 1. Broadcast ground shockwave effect with upgraded radius
        TitanEffectRemote:FireAllClients("Stomp", character, {
            Position = impactGroundPos,
            Radius = radius,
        })

        -- 2. Area destruction via DestructionService with distance falloff & upgraded damage
        if CityService and DestructionService then
            local buildingsInRadius = CityService.GetBuildingsInRadius(impactGroundPos, radius)
            local buildingsDamaged = 0

            local upgradeStomp = ProgressionService.GetUpgradeValue(player, "StompDamage")
            local baseStomp = TitanRegistry.CalculateAbilityDamage(titanDef.Id, "Stomp", upgradeStomp)

            for _, item in ipairs(buildingsInRadius) do
                local bld = item.Building
                if not bld:GetAttribute("IsDestroyed") then
                    local tier = tonumber(bld:GetAttribute("DestructionTier")) or 1
                    local tierMult = if tier == 1 then 1.0 elseif tier == 2 then 0.75 elseif tier == 3 then 0.50 else 0.40
                    local maxStomp = math.max(1, math.floor(baseStomp * tierMult))
                    local minFactor = DestructionConfig.StompMinDamageFactor or 0.35

                    -- Distance falloff calculation: 1.0 at epicenter down to minFactor at perimeter
                    local dist = item.Distance
                    local falloff = math.clamp(1 - (dist / radius), 0, 1)
                    local multiplier = minFactor + ((1 - minFactor) * falloff)
                    local calculatedDamage = math.floor(maxStomp * multiplier)

                    local success, applied = DestructionService.DamageBuilding(bld, calculatedDamage, player, "Stomp")
                    if success then
                        buildingsDamaged += 1
                        print(string.format("[MonsterService] [Stomp AoE] Hit '%s' (Tier %d) for %d damage (dist: %.1f studs, falloff: %.2f)",
                            bld.Name, tier, applied, dist, multiplier))
                    end
                end
            end

            print(string.format("[MonsterService] [Stomp IMPACT] %s (%s) ground slam finished. Buildings affected: %d (Radius: %d studs)",
                player.Name, titanDef.DisplayName, buildingsDamaged, radius))
        end
    end)
end

--[=[
    Executes Tail Sweep (Brontara primary sweep attack).
]=]
function MonsterService.ExecuteTailSweep(player: Player, character: Model, hrp: BasePart, abilityDef: any, titanDef: any)
    local range = abilityDef.Range or 26
    local strikePosition = hrp.Position - (hrp.CFrame.LookVector * (range * 0.4))

    TitanEffectRemote:FireAllClients("TailSweep", character, {
        Position = strikePosition,
        LookVector = hrp.CFrame.LookVector,
    })

    if CityService and DestructionService then
        local nearbyBuildings = CityService.GetBuildingsInRadius(hrp.Position, range + 8)
        local upgradePower = ProgressionService.GetUpgradeValue(player, "BasicAttackDamage")
        local scaledDmg = TitanRegistry.CalculateAbilityDamage(titanDef.Id, "TailSweep", upgradePower)
        local hitCount = 0

        for _, item in ipairs(nearbyBuildings) do
            local bld = item.Building
            if not bld:GetAttribute("IsDestroyed") then
                local tier = tonumber(bld:GetAttribute("DestructionTier")) or 1
                local tierMult = if tier == 1 then 1.0 elseif tier == 2 then 0.70 elseif tier == 3 then 0.50 else 0.40
                local calculatedDamage = math.max(1, math.floor(scaledDmg * tierMult))

                local success, _ = DestructionService.DamageBuilding(bld, calculatedDamage, player, "TailSweep")
                if success then
                    hitCount += 1
                end
            end
        end

        print(string.format("[MonsterService] [TailSweep] %s (%s) swept! Hit %d buildings for %d dmg", player.Name, titanDef.DisplayName, hitCount, scaledDmg))
    end
end

--[=[
    Executes Heavy Stomp Ability (Brontara heavy seismic slam).
]=]
function MonsterService.ExecuteHeavyStomp(player: Player, character: Model, hrp: BasePart, abilityDef: any, titanDef: any)
    local windUp = abilityDef.WindUp or 0.50
    local upgradeRadius = ProgressionService.GetUpgradeValue(player, "StompRadius")
    local radius = TitanRegistry.CalculateAbilityRadius(titanDef.Id, "HeavyStomp", upgradeRadius)
    local groundPos = hrp.Position - Vector3.new(0, hrp.Size.Y * 0.5, 0)

    print(string.format("[MonsterService] [Heavy Stomp Wind-up] %s (%s) rearing up (%.2fs windup, %d radius)...", player.Name, titanDef.DisplayName, windUp, radius))

    TitanEffectRemote:FireAllClients("HeavyStompWindup", character, {
        Position = groundPos,
        Radius = radius,
        WindUp = windUp,
    })

    task.delay(windUp, function()
        if not character.Parent then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end

        local impactGroundPos = hrp.Position - Vector3.new(0, hrp.Size.Y * 0.5, 0)

        TitanEffectRemote:FireAllClients("HeavyStomp", character, {
            Position = impactGroundPos,
            Radius = radius,
        })

        if CityService and DestructionService then
            local buildingsInRadius = CityService.GetBuildingsInRadius(impactGroundPos, radius)
            local upgradeStomp = ProgressionService.GetUpgradeValue(player, "StompDamage")
            local scaledStomp = TitanRegistry.CalculateAbilityDamage(titanDef.Id, "HeavyStomp", upgradeStomp)
            local count = 0

            for _, item in ipairs(buildingsInRadius) do
                local bld = item.Building
                if not bld:GetAttribute("IsDestroyed") then
                    local tier = tonumber(bld:GetAttribute("DestructionTier")) or 1
                    local tierMult = if tier == 1 then 1.0 elseif tier == 2 then 0.75 elseif tier == 3 then 0.50 else 0.40
                    local maxStomp = math.max(1, math.floor(scaledStomp * tierMult))
                    local minFactor = 0.40

                    local dist = item.Distance
                    local falloff = math.clamp(1 - (dist / radius), 0, 1)
                    local multiplier = minFactor + ((1 - minFactor) * falloff)
                    local calculatedDamage = math.floor(maxStomp * multiplier)

                    local success = DestructionService.DamageBuilding(bld, calculatedDamage, player, "HeavyStomp")
                    if success then count += 1 end
                end
            end

            print(string.format("[MonsterService] [Heavy Stomp IMPACT] %s (%s) seismic shock hit %d buildings!", player.Name, titanDef.DisplayName, count))
        end
    end)
end

--[=[
    Executes Neck Strike Ability (Brontara signature long-range overhead smash).
]=]
function MonsterService.ExecuteNeckStrike(player: Player, character: Model, hrp: BasePart, abilityDef: any, titanDef: any)
    local range = abilityDef.Range or 52
    local radius = abilityDef.Radius or 14
    local strikePosition = hrp.Position + (hrp.CFrame.LookVector * (range * 0.85))

    TitanEffectRemote:FireAllClients("NeckStrike", character, {
        Position = strikePosition,
        LookVector = hrp.CFrame.LookVector,
    })

    if CityService and DestructionService then
        local nearbyBuildings = CityService.GetBuildingsInRadius(strikePosition, radius)
        local upgradePower = ProgressionService.GetUpgradeValue(player, "BasicAttackDamage")
        local scaledDmg = TitanRegistry.CalculateAbilityDamage(titanDef.Id, "NeckStrike", upgradePower)
        local countHit = 0

        for _, item in ipairs(nearbyBuildings) do
            local bld = item.Building
            if not bld:GetAttribute("IsDestroyed") then
                local tier = tonumber(bld:GetAttribute("DestructionTier")) or 1
                local tierMult = if tier == 1 then 1.0 elseif tier == 2 then 0.75 elseif tier == 3 then 0.55 else 0.45
                local calculatedDamage = math.max(1, math.floor(scaledDmg * tierMult))

                local success = DestructionService.DamageBuilding(bld, calculatedDamage, player, "NeckStrike")
                if success then countHit += 1 end
            end
        end

        print(string.format("[MonsterService] [NeckStrike] %s (%s) plunge hit %d buildings for %d dmg!", player.Name, titanDef.DisplayName, countHit, scaledDmg))
    end
end

--[=[
    Executes Roar Ability (utility intimidation effect).
]=]
function MonsterService.ExecuteRoar(player: Player, character: Model, hrp: BasePart, abilityDef: any, titanDef: any)
    local head = character:FindFirstChild("Head") :: BasePart?
    local roarOrigin = if head then head.Position else (hrp.Position + Vector3.new(0, 5, 0))
    local radius = abilityDef.Radius or 45
    local titanId = titanDef.Id

    print(string.format("[MonsterService] [Roar EVENT] %s (%s) unleashed a thunderous Roar! Radius: %d studs.", player.Name, titanDef.DisplayName, radius))

    TitanEffectRemote:FireAllClients("Roar", character, {
        Position = roarOrigin,
        Radius = radius,
        Titan = titanId,
    })
end

-- Ability executor map for clean polymorphic dispatch
local AbilityExecutors = {
    BasicAttack = MonsterService.ExecuteBasicAttack,
    Stomp = MonsterService.ExecuteStomp,
    Roar = MonsterService.ExecuteRoar,
    TailSweep = MonsterService.ExecuteTailSweep,
    HeavyStomp = MonsterService.ExecuteHeavyStomp,
    NeckStrike = MonsterService.ExecuteNeckStrike,
}

--[=[
    Validates and executes an ability request server-side, enforcing upgraded cooldowns via TitanRegistry.
]=]
function MonsterService.ProcessAbilityRequest(player: Player, actionName: string)
    local character = player.Character
    if not character or not character.Parent then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return end

    local titanId = activeTitans[player.UserId] or PlayerDataService.GetSelectedTitan(player) or "Ravager"
    local titanDef = TitanRegistry.Get(titanId)
    if not titanDef then return end

    local abilityDef = titanDef.Abilities[actionName]
    if not abilityDef then
        warn(string.format("[MonsterService] %s requested unknown ability: %s", player.Name, tostring(actionName)))
        return
    end

    -- Determine cooldown time based on active upgrades through TitanRegistry
    local cdCategory = abilityDef.CooldownUpgradeCategory
    local cdUpgradeValue = if cdCategory then ProgressionService.GetUpgradeValue(player, cdCategory) else nil
    local cooldownTime = TitanRegistry.CalculateAbilityCooldown(titanId, actionName, cdUpgradeValue)

    -- Cooldown validation
    local cooldowns = playerCooldowns[player.UserId]
    if not cooldowns then
        cooldowns = {}
        playerCooldowns[player.UserId] = cooldowns
    end

    local now = os.clock()
    local lastUsed = cooldowns[actionName] or 0

    if (now - lastUsed) < cooldownTime then
        local remaining = cooldownTime - (now - lastUsed)
        print(string.format("[MonsterService] Ability %s on cooldown for %s (%.2fs remaining)", actionName, player.Name, remaining))
        return
    end

    cooldowns[actionName] = now

    -- Execute server-authoritative ability
    if CityService and type(CityService.RecordAbilityUsed) == "function" then
        CityService.RecordAbilityUsed(player, actionName)
    end

    local executor = AbilityExecutors[actionName]
    if executor then
        executor(player, character, hrp, abilityDef, titanDef)
    else
        warn(string.format("[MonsterService] No ability executor registered for '%s'", actionName))
    end
end

return MonsterService
