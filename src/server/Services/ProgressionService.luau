--!strict
--[[
    ProgressionService.luau
    Responsibility:
    - Server-authoritative player progression (Level, XP curve, Cash, Destruction Points).
    - Server-authoritative Ravager stat upgrades & transaction verification.
    - Powered by PlayerDataService persistent DataStore profiles.
    - Broadcasts progression events and stat updates to clients.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local UpgradeConfig = require(ConfigFolder:WaitForChild("UpgradeConfig") :: ModuleScript)
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService") :: ModuleScript)
local ProgressionUpdateRemote = RemotesFolder:WaitForChild("ProgressionUpdate") :: RemoteEvent
local UpgradeRequestRemote = RemotesFolder:WaitForChild("UpgradeRequest") :: RemoteEvent

-- Reference to MonsterService and MonetizationService (resolved via lazy getters)
local MonsterService = nil
local function getMonsterService()
    if not MonsterService then
        pcall(function()
            MonsterService = require(script.Parent:WaitForChild("MonsterService") :: ModuleScript)
        end)
    end
    return MonsterService
end

local MonetizationService = nil
local function getMonetizationService()
    if not MonetizationService then
        pcall(function()
            MonetizationService = require(script.Parent:WaitForChild("MonetizationService") :: ModuleScript)
        end)
    end
    return MonetizationService
end

export type PlayerProgression = {
    Level: number,
    CurrentXP: number,
    NextLevelXP: number,
    Cash: number,
    DestructionPoints: number,
    Upgrades: { [string]: number },
}

local ProgressionService = {}

--[=[
    Calculates XP required to advance from `level` to `level + 1`.
    Level 1 -> 500 XP (500 cumulative)
    Level 2 -> 850 XP (1,350 cumulative)
    Level 3 -> 1,200 XP (2,550 cumulative)
    Level 4 -> 1,550 XP (4,100 cumulative)
    Level 5 -> 1,900 XP (6,000 cumulative)
    Formula for L >= 1: 500 + (math.max(1, level) - 1) * 350
]=]
function ProgressionService.GetXPRequiredForLevel(level: number): number
    local lvl = math.max(1, level)
    return 500 + (lvl - 1) * 350
end

--[=[
    Initializes default progression data for fallback when profile is not loaded.
]=]
local function createDefaultProgression(): PlayerProgression
    local defaultUpgrades: { [string]: number } = {}
    for catId, _ in pairs(UpgradeConfig.Categories) do
        defaultUpgrades[catId] = 1
    end

    return {
        Level = 1,
        CurrentXP = 0,
        NextLevelXP = ProgressionService.GetXPRequiredForLevel(1),
        Cash = 0,
        DestructionPoints = 0,
        Upgrades = defaultUpgrades,
    }
end

--[=[
    Synchronizes authoritative progression data to the client.
]=]
function ProgressionService.SyncToClient(player: Player)
    local prog = ProgressionService.GetPlayerProgression(player)
    player:SetAttribute("Level", prog.Level)
    player:SetAttribute("CurrentXP", prog.CurrentXP)
    player:SetAttribute("NextLevelXP", prog.NextLevelXP)
    player:SetAttribute("Cash", prog.Cash)
    player:SetAttribute("DestructionPoints", prog.DestructionPoints)

    ProgressionUpdateRemote:FireClient(player, {
        Type = "InitialSync",
        Level = prog.Level,
        CurrentXP = prog.CurrentXP,
        NextLevelXP = prog.NextLevelXP,
        Cash = prog.Cash,
        DestructionPoints = prog.DestructionPoints,
        Upgrades = prog.Upgrades,
    })
end

--[=[
    Initializes service state, connects player lifecycle and remote events.
]=]
function ProgressionService.Init()
    print("[ProgressionService] Initializing ProgressionService...")
    getMonsterService()

    -- Bind upgrade requests from client
    UpgradeRequestRemote.OnServerEvent:Connect(function(player: Player, upgradeId: any)
        if type(upgradeId) ~= "string" then
            warn(string.format("[ProgressionService] Invalid upgrade request from %s (non-string type)", player.Name))
            return
        end
        ProgressionService.HandleUpgradeRequest(player, upgradeId)
    end)

    -- Bind client state sync requests
    ProgressionUpdateRemote.OnServerEvent:Connect(function(player: Player, action: any)
        if action == "RequestSync" then ProgressionService.SyncToClient(player) end
    end)

    -- Player lifecycle: wait for PlayerDataService profile to load, then sync
    Players.PlayerAdded:Connect(function(player)
        task.spawn(function()
            local startTime = os.clock()
            while not PlayerDataService.IsLoaded(player) and player.Parent and (os.clock() - startTime) < 5 do
                task.wait(0.05)
            end
            if player.Parent then ProgressionService.SyncToClient(player) end
        end)
    end)
end

--[=[
    Starts service operations and synchronizes any existing players.
]=]
function ProgressionService.Start()
    print("[ProgressionService] ProgressionService started.")
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            local startTime = os.clock()
            while not PlayerDataService.IsLoaded(player) and player.Parent and (os.clock() - startTime) < 5 do
                task.wait(0.05)
            end
            if player.Parent then ProgressionService.SyncToClient(player) end
        end)
    end
end

--[=[
    Returns the full progression record for a player, reading directly from PlayerDataService.
]=]
function ProgressionService.GetPlayerProgression(player: Player): PlayerProgression
    local profile = PlayerDataService.GetProfile(player)
    if profile then
        return {
            Level = profile.Level,
            CurrentXP = profile.XP,
            NextLevelXP = ProgressionService.GetXPRequiredForLevel(profile.Level),
            Cash = profile.Cash,
            DestructionPoints = profile.DestructionPoints,
            Upgrades = profile.Upgrades,
        }
    end
    return createDefaultProgression()
end

--[=[
    Compatibility method for services querying Cash/Points/XP.
]=]
function ProgressionService.GetPlayerStats(player: Player)
    local prog = ProgressionService.GetPlayerProgression(player)
    return {
        Cash = prog.Cash,
        DestructionPoints = prog.DestructionPoints,
        XP = prog.CurrentXP,
        Level = prog.Level,
        NextLevelXP = prog.NextLevelXP,
    }
end

--[=[
    Queries the active upgraded value for a given upgrade category for a player.
]=]
function ProgressionService.GetUpgradeValue(player: Player, upgradeId: string): number
    local prog = ProgressionService.GetPlayerProgression(player)
    local currentLevel = prog.Upgrades[upgradeId] or 1
    return UpgradeConfig.GetTierValue(upgradeId, currentLevel)
end

--[=[
    Queries the current upgrade level for a category (1-5).
]=]
function ProgressionService.GetUpgradeLevel(player: Player, upgradeId: string): number
    local prog = ProgressionService.GetPlayerProgression(player)
    return prog.Upgrades[upgradeId] or 1
end

--[=[
    Awards currency, points, and XP from building destruction or events.
    Mutates player profile persistently via PlayerDataService.
    Applies scalable XP curve and carries over excess XP upon leveling up.
]=]
function ProgressionService.AddRewards(player: Player, cash: number, points: number, xp: number)
    local monService = getMonetizationService()
    local cashMult = if monService then monService.GetCashMultiplier(player) else 1.0
    local xpMult = if monService then monService.GetXPMultiplier(player) else 1.0

    local addedCash = math.max(0, math.floor(cash * cashMult))
    local addedPoints = math.max(0, math.floor(points))
    local addedXP = math.max(0, math.floor(xp * xpMult))

    local leveledUp = false
    local previousLevel = 1
    local newLevel = 1
    local newXP = 0
    local nextLevelXP = 500
    local newCash = 0
    local newPoints = 0
    local upgrades: { [string]: number } = {}

    -- Safely mutate persistent profile
    local success = PlayerDataService.UpdateProfile(player, function(profile)
        profile.Cash += addedCash
        profile.DestructionPoints += addedPoints
        profile.XP += addedXP

        previousLevel = profile.Level
        nextLevelXP = ProgressionService.GetXPRequiredForLevel(profile.Level)

        while profile.XP >= nextLevelXP do
            profile.XP -= nextLevelXP
            profile.Level += 1
            nextLevelXP = ProgressionService.GetXPRequiredForLevel(profile.Level)
            leveledUp = true
        end

        newLevel = profile.Level
        newXP = profile.XP
        newCash = profile.Cash
        newPoints = profile.DestructionPoints
        upgrades = profile.Upgrades
    end)

    if not success then
        warn(string.format("[ProgressionService] Failed to update profile for %s on AddRewards", player.Name))
        return
    end

    if leveledUp then
        print(
            string.format(
                "[ProgressionService] 🎉 %s leveled up to Level %d! (Next threshold: %d XP)",
                player.Name,
                newLevel,
                nextLevelXP
            )
        )
        local newlyUnlocked = PlayerDataService.CheckTitanUnlocks(player)
        if next(newlyUnlocked) ~= nil then
            local titanFeedback = RemotesFolder:FindFirstChild("TitanFeedback") :: RemoteEvent?
            if titanFeedback then
                titanFeedback:FireClient(player, "TitanListSync", {
                    Titans = PlayerDataService.GetTitansData(player),
                    SelectedTitan = PlayerDataService.GetSelectedTitan(player),
                })
            end
        end
    end

    -- Replicate attributes to player instance
    player:SetAttribute("Level", newLevel)
    player:SetAttribute("CurrentXP", newXP)
    player:SetAttribute("NextLevelXP", nextLevelXP)
    player:SetAttribute("Cash", newCash)
    player:SetAttribute("DestructionPoints", newPoints)

    -- Broadcast update to player
    ProgressionUpdateRemote:FireClient(player, {
        Type = if leveledUp then "LevelUp" else "StatsUpdate",
        Level = newLevel,
        CurrentXP = newXP,
        NextLevelXP = nextLevelXP,
        Cash = newCash,
        DestructionPoints = newPoints,
        Upgrades = upgrades,
        LeveledUp = leveledUp,
        PreviousLevel = if leveledUp then previousLevel else nil,
        AddedCash = addedCash,
        AddedPoints = addedPoints,
        AddedXP = addedXP,
    })
end

--[=[
    Server-authoritative handler for upgrading Ravager attributes.
    Validates category existence, level cap, and affordability before deducting currency.
    Mutates profile persistently via PlayerDataService.
]=]
function ProgressionService.HandleUpgradeRequest(player: Player, upgradeId: string): boolean
    local cat = UpgradeConfig.Categories[upgradeId]
    if not cat then
        warn(string.format("[ProgressionService] %s requested invalid upgrade: '%s'", player.Name, tostring(upgradeId)))
        ProgressionUpdateRemote:FireClient(player, {
            Type = "UpgradeFailed",
            UpgradeId = upgradeId,
            Reason = "Unknown upgrade category.",
        })
        return false
    end

    local profile = PlayerDataService.GetProfile(player)
    if not profile then
        warn(string.format("[ProgressionService] %s cannot upgrade: profile not loaded.", player.Name))
        ProgressionUpdateRemote:FireClient(player, {
            Type = "UpgradeFailed",
            UpgradeId = upgradeId,
            Reason = "Profile not ready. Try again in a moment.",
        })
        return false
    end

    local currentLevel = profile.Upgrades[upgradeId] or 1
    if currentLevel >= cat.MaxLevel then
        print(
            string.format("[ProgressionService] %s upgrade '%s' rejected: Already at Max Level (%d)", player.Name, upgradeId, cat.MaxLevel)
        )
        ProgressionUpdateRemote:FireClient(player, {
            Type = "UpgradeFailed",
            UpgradeId = upgradeId,
            Reason = "Already at maximum level!",
            Level = profile.Level,
            CurrentXP = profile.XP,
            NextLevelXP = ProgressionService.GetXPRequiredForLevel(profile.Level),
            Cash = profile.Cash,
            DestructionPoints = profile.DestructionPoints,
            Upgrades = profile.Upgrades,
        })
        return false
    end

    local nextTier = UpgradeConfig.GetNextTier(upgradeId, currentLevel)
    if not nextTier then return false end

    -- Check affordability
    if profile.Cash < nextTier.CashCost or profile.DestructionPoints < nextTier.PointCost then
        print(
            string.format(
                "[ProgressionService] %s cannot afford '%s' Lvl %d (Requires $%d & %d Pts; Has $%d & %d Pts)",
                player.Name,
                upgradeId,
                nextTier.Level,
                nextTier.CashCost,
                nextTier.PointCost,
                profile.Cash,
                profile.DestructionPoints
            )
        )
        ProgressionUpdateRemote:FireClient(player, {
            Type = "UpgradeFailed",
            UpgradeId = upgradeId,
            Reason = "Insufficient funds!",
            Level = profile.Level,
            CurrentXP = profile.XP,
            NextLevelXP = ProgressionService.GetXPRequiredForLevel(profile.Level),
            Cash = profile.Cash,
            DestructionPoints = profile.DestructionPoints,
            Upgrades = profile.Upgrades,
        })
        return false
    end

    -- Process transaction persistently
    local success = PlayerDataService.UpdateProfile(player, function(prof)
        prof.Cash -= nextTier.CashCost
        prof.DestructionPoints -= nextTier.PointCost
        prof.Upgrades[upgradeId] = nextTier.Level
    end)

    if not success then return false end

    print(
        string.format(
            "[ProgressionService] ✅ %s upgraded '%s' to Level %d (%s) for $%d Cash & %d Points!",
            player.Name,
            cat.DisplayName,
            nextTier.Level,
            tostring(nextTier.Value),
            nextTier.CashCost,
            nextTier.PointCost
        )
    )

    -- Dynamically notify MonsterService of stat upgrade
    local monster = getMonsterService()
    if monster and type(monster.OnUpgradePurchased) == "function" then
        monster.OnUpgradePurchased(player, upgradeId, nextTier.Level, nextTier.Value)
    end

    local updatedProfile = PlayerDataService.GetProfile(player) :: any
    if updatedProfile then
        player:SetAttribute("Cash", updatedProfile.Cash)
        player:SetAttribute("DestructionPoints", updatedProfile.DestructionPoints)
    end

    -- Send confirmation & state update to client
    ProgressionUpdateRemote:FireClient(player, {
        Type = "UpgradeSuccess",
        UpgradeId = upgradeId,
        NewLevel = nextTier.Level,
        NewValue = nextTier.Value,
        Level = updatedProfile.Level,
        CurrentXP = updatedProfile.XP,
        NextLevelXP = ProgressionService.GetXPRequiredForLevel(updatedProfile.Level),
        Cash = updatedProfile.Cash,
        DestructionPoints = updatedProfile.DestructionPoints,
        Upgrades = updatedProfile.Upgrades,
    })

    return true
end

return ProgressionService
