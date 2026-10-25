--!strict
--[[
    DestructionService.luau
    Responsibility:
    - Server-authoritative building destruction engine for Titan Rampage.
    - Validates hit legality, range, and target building viability.
    - Applies tiered damage, non-destructive visual degradation, and controlled structural collapses.
    - Manages destruction combo multipliers and forwards rewards to ProgressionService.
    - Notifies CityService of damage and destruction events for live city progress and completion tracking.
    - Broadcasts client destruction feedback (damage numbers, debris, rubble).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local DestructionConfig = require(ConfigFolder:WaitForChild("DestructionConfig") :: ModuleScript)
local DestructionFeedbackRemote = RemotesFolder:WaitForChild("DestructionFeedback") :: RemoteEvent

-- Services
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService") :: ModuleScript)
local CityService = require(script.Parent:WaitForChild("CityService") :: ModuleScript)
local HubService = nil

local function getHubService()
    if not HubService then
        pcall(function()
            HubService = require(script.Parent:WaitForChild("HubService") :: ModuleScript)
        end)
    end
    return HubService
end

export type ComboData = {
    Multiplier: number,
    Hits: number,
    LastHitTime: number,
}

local DestructionService = {}

-- In-memory session tracking
local playerCombos: { [number]: ComboData } = {}
local collapsingBuildings: { [Instance]: boolean } = {}

--[=[
    Initializes service state and connects player lifecycle.
]=]
function DestructionService.Init()
    print("[DestructionService] Initializing DestructionService...")

    Players.PlayerAdded:Connect(function(player)
        playerCombos[player.UserId] = {
            Multiplier = 1,
            Hits = 0,
            LastHitTime = 0,
        }
    end)

    Players.PlayerRemoving:Connect(function(player)
        playerCombos[player.UserId] = nil
    end)
end

--[=[
    Starts background combo monitoring loops.
]=]
function DestructionService.Start()
    print("[DestructionService] DestructionService started.")
    for _, player in ipairs(Players:GetPlayers()) do
        if not playerCombos[player.UserId] then
            playerCombos[player.UserId] = { Multiplier = 1, Hits = 0, LastHitTime = 0 }
        end
    end
end

--[=[
    Clears collapsing buildings table upon city rebuild.
]=]
function DestructionService.ClearCollapsingBuildings()
    table.clear(collapsingBuildings)
    print("[DestructionService] Cleared collapsing buildings cache for city rebuild.")
end

--[=[
    Returns session stats for a player from ProgressionService.
]=]
function DestructionService.GetPlayerStats(player: Player): any
    return ProgressionService.GetPlayerStats(player)
end

--[=[
    Returns the active combo multiplier for a player.
]=]
function DestructionService.GetPlayerCombo(player: Player): number
    local combo = playerCombos[player.UserId]
    if not combo then return 1 end

    local now = os.clock()
    if (now - combo.LastHitTime) > DestructionConfig.Combo.Timeout then
        combo.Multiplier = 1
        combo.Hits = 0
    end
    return combo.Multiplier
end

--[=[
    Updates the combo counter when player damages/destroys a building.
]=]
local function registerComboActivity(player: Player): number
    local combo = playerCombos[player.UserId]
    if not combo then
        combo = { Multiplier = 1, Hits = 0, LastHitTime = 0 }
        playerCombos[player.UserId] = combo
    end

    local now = os.clock()
    if (now - combo.LastHitTime) <= DestructionConfig.Combo.Timeout then
        combo.Hits += 1
        combo.Multiplier = math.clamp(combo.Multiplier + DestructionConfig.Combo.MultiplierPerHit, 1, DestructionConfig.Combo.MaxMultiplier)
    else
        combo.Hits = 1
        combo.Multiplier = 1
    end

    combo.LastHitTime = now
    local activeMult = combo.Multiplier

    -- Send combo update to client
    DestructionFeedbackRemote:FireClient(player, "ComboUpdate", {
        Multiplier = activeMult,
        Hits = combo.Hits,
        Timeout = DestructionConfig.Combo.Timeout,
    })

    -- Schedule combo expiration reset check
    task.delay(DestructionConfig.Combo.Timeout + 0.1, function()
        local current = playerCombos[player.UserId]
        if current and (os.clock() - current.LastHitTime) >= DestructionConfig.Combo.Timeout then
            if current.Multiplier > 1 then
                current.Multiplier = 1
                current.Hits = 0
                DestructionFeedbackRemote:FireClient(player, "ComboReset", { Multiplier = 1 })
            end
        end
    end)

    return activeMult
end

--[=[
    Applies visual damage state modifications non-destructively based on remaining health ratio.
    Phases:
    - 100-75%: Normal
    - 75-50%: Light Damage (Hide ~half windows, slight weathered tint)
    - 50-25%: Heavy Damage (Hide all windows, hide awnings/props, structural degradation)
    - 25-0%: Critical Damage (Darkened scorched basalt structure, roof scorched)
]=]
local function updateBuildingVisualDamage(building: Model, currentHealth: number, maxHealth: number)
    local ratio = if maxHealth > 0 then currentHealth / maxHealth else 0
    local windowsFolder = building:FindFirstChild("Windows")
    local propsFolder = building:FindFirstChild("Props")
    local structure = building:FindFirstChild("Structure")
    local mainBody = structure and structure:FindFirstChild("MainBody") :: BasePart?
    local roof = structure and structure:FindFirstChild("Roof") :: BasePart?

    if ratio <= 0.75 and ratio > 0.50 then
        -- Light Damage: Hide ~half of windows
        if windowsFolder then
            local wins = windowsFolder:GetChildren()
            for i = 1, math.floor(#wins / 2) do
                if wins[i]:IsA("BasePart") then
                    wins[i].Transparency = 1
                    wins[i].CanCollide = false
                end
            end
        end
    elseif ratio <= 0.50 and ratio > 0.25 then
        -- Heavy Damage: Hide all windows, hide entrance awning and props
        if windowsFolder then
            for _, win in ipairs(windowsFolder:GetChildren()) do
                if win:IsA("BasePart") then
                    win.Transparency = 1
                    win.CanCollide = false
                end
            end
        end
        if propsFolder then
            for _, prop in ipairs(propsFolder:GetChildren()) do
                if prop:IsA("BasePart") then
                    prop.Transparency = 1
                    prop.CanCollide = false
                end
            end
        end
        if mainBody then
            mainBody.Color = Color3.fromRGB(110, 105, 100)
        end
    elseif ratio <= 0.25 and ratio > 0 then
        -- Critical Damage: Hide all windows/props, scorch structure & roof
        if windowsFolder then
            for _, win in ipairs(windowsFolder:GetChildren()) do
                if win:IsA("BasePart") then
                    win.Transparency = 1
                    win.CanCollide = false
                end
            end
        end
        if propsFolder then
            for _, prop in ipairs(propsFolder:GetChildren()) do
                if prop:IsA("BasePart") then
                    prop.Transparency = 1
                    prop.CanCollide = false
                end
            end
        end
        if mainBody then
            mainBody.Color = Color3.fromRGB(45, 42, 42)
        end
        if roof then
            roof.Color = Color3.fromRGB(35, 33, 33)
        end
    end
end

--[=[
    Executes a controlled structural collapse on building destruction non-destructively.
]=]
local function executeControlledCollapse(building: Model, player: Player?, rewards: { Cash: number, Points: number, XP: number, Combo: number })
    if collapsingBuildings[building] then return end
    collapsingBuildings[building] = true

    local structure = building:FindFirstChild("Structure")
    local windows = building:FindFirstChild("Windows")
    local props = building:FindFirstChild("Props")

    -- Hide exterior window and prop clutter
    if windows then
        for _, p in ipairs(windows:GetChildren()) do
            if p:IsA("BasePart") then
                p.Transparency = 1
                p.CanCollide = false
            end
        end
    end
    if props then
        for _, p in ipairs(props:GetChildren()) do
            if p:IsA("BasePart") then
                p.Transparency = 1
                p.CanCollide = false
            end
        end
    end

    local primaryPart = building.PrimaryPart or (structure and structure:FindFirstChild("MainBody") :: BasePart?)
    local collapsePos = if primaryPart then primaryPart.Position else building:GetPivot().Position

    -- Create Rubble Remnant
    local foundation = structure and structure:FindFirstChild("Foundation") :: BasePart?
    local fSize = if foundation then foundation.Size else Vector3.new(20, 1, 20)
    local fCFrame = if foundation then foundation.CFrame else CFrame.new(collapsePos.X, 0.5, collapsePos.Z)

    local rubble = Instance.new("Part")
    rubble.Name = "Rubble"
    rubble.Size = Vector3.new(fSize.X, 1.8, fSize.Z)
    rubble.CFrame = fCFrame * CFrame.new(0, 0.4, 0)
    rubble.Color = Color3.fromRGB(65, 68, 72)
    rubble.Material = Enum.Material.Concrete
    rubble.Anchored = true
    rubble.CanCollide = true
    rubble.TopSurface = Enum.SurfaceType.Smooth
    rubble.Parent = building

    -- Structural shudder / rumble before descent
    local mainBody = structure and structure:FindFirstChild("MainBody") :: BasePart?
    local roof = structure and structure:FindFirstChild("Roof") :: BasePart?
    if mainBody then
        local origCFrame = mainBody.CFrame
        task.spawn(function()
            for _ = 1, 3 do
                mainBody.CFrame = origCFrame * CFrame.new(math.random(-1, 1) * 0.35, 0, math.random(-1, 1) * 0.35)
                task.wait(0.04)
            end
            mainBody.CFrame = origCFrame
        end)
    end

    -- Smooth structural descent without permanently destroying parts
    if structure then
        local mainBody = structure:FindFirstChild("MainBody") :: BasePart?
        local roof = structure:FindFirstChild("Roof") :: BasePart?

        if mainBody then
            local tweenInfo = TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            local targetCFrame = mainBody.CFrame * CFrame.new(0, -mainBody.Size.Y * 0.85, 0)
            local t = TweenService:Create(mainBody, tweenInfo, {
                CFrame = targetCFrame,
                Transparency = 0.8,
            })
            t:Play()
            t.Completed:Connect(function()
                mainBody.Transparency = 1
                mainBody.CanCollide = false
            end)
        end

        if roof then
            local tweenInfo = TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            local targetCFrame = roof.CFrame * CFrame.new(0, -roof.Position.Y + 1.5, 0)
            local t = TweenService:Create(roof, tweenInfo, {
                CFrame = targetCFrame,
                Transparency = 0.5,
            })
            t:Play()
            t.Completed:Connect(function()
                roof.Transparency = 1
                roof.CanCollide = false
            end)
        end
    end

    -- Broadcast destruction effects to all clients (dust cloud, camera shake, sound)
    DestructionFeedbackRemote:FireAllClients("BuildingDestroyed", {
        Building = building,
        Player = player,
        Position = collapsePos,
        RubbleCFrame = rubble.CFrame,
        Rewards = rewards,
    })

    print(string.format("[DestructionService] Building '%s' completely collapsed. Remains converted to rubble.", building.Name))
end

--[=[
    Primary Server-Authoritative API for damaging a building.
    @param building The target building Model
    @param damage Raw incoming damage amount
    @param player Attacking Player (optional)
    @param source Action source name ("BasicAttack", "Stomp", etc.)
    @return (success: boolean, actualDamageApplied: number)
]=]
function DestructionService.DamageBuilding(building: Model, damage: number, player: Player?, source: string): (boolean, number)
    if not building or not building.Parent then
        warn("[DestructionService] Rejected damage: Invalid building instance.")
        return false, 0
    end

    -- If building was reset and IsDestroyed is false, clear any stale collapsing flag
    if building:GetAttribute("IsDestroyed") == false and collapsingBuildings[building] then
        collapsingBuildings[building] = nil
    end

    -- Verify building is not already destroyed
    if building:GetAttribute("IsDestroyed") == true or collapsingBuildings[building] then
        return false, 0
    end

    local maxHp = tonumber(building:GetAttribute("MaxHealth")) or 500
    local curHp = tonumber(building:GetAttribute("CurrentHealth")) or maxHp

    if curHp <= 0 then
        return false, 0
    end

    -- Distance & reach validation if player is specified
    if player and player.Character and player.Character.PrimaryPart then
        local hrp = player.Character.PrimaryPart
        local buildingPos = building:GetPivot().Position
        local dist = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(buildingPos.X, 0, buildingPos.Z)).Magnitude

        local maxAllowedReach = 85 -- Generous boundary check
        if source == "BasicAttack" then
            maxAllowedReach = DestructionConfig.BasicAttackRange + 20
        elseif source == "TailSweep" then
            maxAllowedReach = 55
        elseif source == "NeckStrike" then
            maxAllowedReach = 75
        elseif source == "Stomp" then
            local stompRad = ProgressionService.GetUpgradeValue(player, "StompRadius")
            maxAllowedReach = stompRad + 25
        elseif source == "HeavyStomp" then
            local stompRad = ProgressionService.GetUpgradeValue(player, "StompRadius") * 1.5
            maxAllowedReach = stompRad + 35
        end

        if dist > maxAllowedReach then
            warn(string.format("[DestructionService] Security: Rejected %s from %s on %s - distance (%.1f) exceeds max reach (%.1f)",
                source, player.Name, building.Name, dist, maxAllowedReach))
            return false, 0
        end
    end

    -- Apply damage single-sourced through CityService
    local success, actualDamage = CityService.ApplyDamage(building, damage, player)
    if not success then
        return false, 0
    end

    -- Special handling for KaijuHub Training Pillars
    if building:GetAttribute("IsTrainingDummy") == true then
        local maxHp = tonumber(building:GetAttribute("MaxHealth")) or 10000
        local newHp = tonumber(building:GetAttribute("CurrentHealth")) or maxHp
        local playerCombo = 1
        if player then
            playerCombo = registerComboActivity(player)
        end

        local hub = getHubService()
        if hub and type(hub.RecordDummyDamage) == "function" then
            hub.RecordDummyDamage(building, actualDamage, newHp, maxHp, playerCombo)
        end

        DestructionFeedbackRemote:FireAllClients("BuildingDamaged", {
            Building = building,
            Damage = actualDamage,
            CurrentHealth = newHp,
            MaxHealth = maxHp,
            Position = building:GetPivot().Position,
            Source = source,
            Combo = playerCombo,
            IsTrainingDummy = true,
        })
        return true, actualDamage
    end

    -- Record damage in run statistics
    local bId = building:GetAttribute("BuildingId") or building.Name
    CityService.RecordDamage(actualDamage, tostring(bId))

    local newHp = tonumber(building:GetAttribute("CurrentHealth")) or 0
    local buildingPos = building:GetPivot().Position

    -- Process rewards and state transition
    if newHp <= 0 then
        -- Building Destroyed!
        local comboMult = 1
        if player then
            comboMult = registerComboActivity(player)
        end

        local baseReward = tonumber(building:GetAttribute("DestructionReward")) or tonumber(building:GetAttribute("DestructonReward")) or 100
        local basePoints = tonumber(building:GetAttribute("DestructionPoints")) or 50
        local tier = tonumber(building:GetAttribute("DestructionTier")) or 1
        local baseXP = tonumber(building:GetAttribute("DestructionXP")) or (DestructionConfig.Tiers[tier] and DestructionConfig.Tiers[tier].BaseXP) or 50

        local finalCash = math.floor(baseReward * comboMult)
        local finalPoints = math.floor(basePoints * comboMult)
        local finalXP = math.floor(baseXP * comboMult)

        local rewards = {
            Cash = finalCash,
            Points = finalPoints,
            XP = finalXP,
            Combo = comboMult,
        }

        if player then
            -- Award via server-authoritative ProgressionService
            ProgressionService.AddRewards(player, finalCash, finalPoints, finalXP)

            print(string.format("[DestructionService] %s destroyed '%s' (%s, Tier %d)! Awarded +$%d Cash, +%d Pts, +%d XP [Combo %dx]",
                player.Name, building.Name, tostring(building:GetAttribute("BuildingName")), tier, finalCash, finalPoints, finalXP, comboMult))
        end

        -- Record destruction in CityService for live city completion tracking
        CityService.RecordDestruction(player, building, finalCash, finalPoints, finalXP, comboMult)

        executeControlledCollapse(building, player, rewards)
    else
        -- Building Damaged (Survives)
        updateBuildingVisualDamage(building, newHp, maxHp)

        if player then
            registerComboActivity(player)
        end

        -- Broadcast damage feedback for floating damage numbers and impact effects
        local playerCombo = if player then DestructionService.GetPlayerCombo(player) else 1
        DestructionFeedbackRemote:FireAllClients("BuildingDamaged", {
            Building = building,
            Damage = actualDamage,
            CurrentHealth = newHp,
            MaxHealth = maxHp,
            Position = buildingPos,
            Source = source,
            Combo = playerCombo,
        })
    end

    return true, actualDamage
end

return DestructionService
