--!strict
--[[
    CityService.luau
    Responsibility:
    - Server-authoritative management of cities, zones, and destructible building infrastructure.
    - Registers every city once at startup and indexes all destructible buildings and their original states.
    - Each city keeps its own state (buildings, run statistics, completion), so players can destroy
      SmallTown and Metrovale at the same time; a portal trip only moves the player who took it.
    - Server-authoritative Run Statistics per city (Timer, Cash/XP accounting, Highest Combo, Damage).
    - Detects 100% city completion, triggers CityCompleted event, and awards completion rewards to the
      city's participants via ProgressionService.
    - Full city rebuild engine (CityService.ResetCity) restoring all original building instances without duplication.
--]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local CityConfig = require(ConfigFolder:WaitForChild("CityConfig") :: ModuleScript)
local DestructionConfig = require(ConfigFolder:WaitForChild("DestructionConfig") :: ModuleScript)
local CityFeedbackRemote = RemotesFolder:WaitForChild("CityFeedback") :: RemoteEvent
local RebuildCityRequestRemote = RemotesFolder:WaitForChild("RebuildCityRequest") :: RemoteEvent
local CitySelectRequestRemote = RemotesFolder:WaitForChild("CitySelectRequest") :: RemoteEvent

-- Services
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService") :: ModuleScript)
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService") :: ModuleScript)
local DestructionService = nil
local MonetizationService = nil

local function getDestructionService()
    if not DestructionService then DestructionService = require(script.Parent:WaitForChild("DestructionService") :: ModuleScript) end
    return DestructionService
end

local function getMonetizationService()
    if not MonetizationService then
        pcall(function()
            MonetizationService = require(script.Parent:WaitForChild("MonetizationService") :: ModuleScript)
        end)
    end
    return MonetizationService
end

export type BuildingVisualBackup = {
    MainBody: BasePart?,
    MainBodyCFrame: CFrame?,
    MainBodySize: Vector3?,
    MainBodyColor: Color3?,
    Roof: BasePart?,
    RoofCFrame: CFrame?,
    RoofSize: Vector3?,
    RoofColor: Color3?,
    WindowParts: { BasePart },
    PropParts: { BasePart },
    -- Window/prop parts' authored Transparency and CanCollide (shared map), restored on rebuild
    PartTransparency: { [BasePart]: number },
    PartCanCollide: { [BasePart]: boolean },
}

export type BuildingEntry = {
    Model: Model,
    CityId: string,
    Id: string,
    Name: string,
    Type: string,
    MaxHealth: number,
    CurrentHealth: number,
    Reward: number,
    Tier: number,
    Position: Vector3,
    PrimaryPart: BasePart?,
    IsDestroyed: boolean,
    VisualBackup: BuildingVisualBackup,
}

export type CityStats = {
    CityName: string,
    TotalBuildings: number,
    ActiveBuildings: number,
    DestroyedBuildings: number,
    TotalHealth: number,
    CurrentHealth: number,
    DestructionPercentage: number,
    CityCompletionPercentage: number,
    RunStartTime: number,
    RunEndTime: number,
    HighestCombo: number,
    CityCompleted: boolean,
}

export type CityRunStats = {
    CityId: string,
    RunStartTime: number,
    RunEndTime: number,
    Duration: number,
    BuildingsDestroyed: number,
    BuildingsDamaged: number,
    TotalDamage: number,
    BasicAttacks: number,
    Stomps: number,
    Roars: number,
    HighestCombo: number,
    BuildingsCash: number,
    BuildingsXP: number,
    CompletionCash: number,
    CompletionXP: number,
    TotalCash: number,
    TotalXP: number,
    DestructionScore: number,
    BuildingsPerMinute: number,
    CityCompleted: boolean,
    CompletionAwarded: boolean,
}

type CityState = {
    Id: string,
    BuildingsById: { [string]: BuildingEntry },
    BuildingList: { BuildingEntry },
    Run: CityRunStats,
    DamagedBuildingIds: { [string]: boolean },
    -- Players who damaged this city during the current run; they share its completion reward
    Participants: { [Player]: boolean },
}

local DEFAULT_CITY = "SmallTown"

local CityService = {}

local cityStates: { [string]: CityState } = {}
local entriesByModel: { [Instance]: BuildingEntry } = {}

-- Which city each player is standing in (nil = Kaiju Hub)
local playerCity: { [Player]: string } = {}

-- Authored Transparency/CanCollide of building window and prop parts, captured the first time
-- a part is registered (cities are intact at server start).
local authoredTransparency: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any
local authoredCanCollide: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Session unlock and completion tracking
local playerCityCompletions: { [number]: { [string]: number } } = {}
local cityBestRecords: { [string]: { BestTime: number, BestCombo: number, BestScore: number, BestBPM: number } } = {
    SmallTown = { BestTime = 0, BestCombo = 1, BestScore = 0, BestBPM = 0 },
    Metrovale = { BestTime = 0, BestCombo = 1, BestScore = 0, BestBPM = 0 },
}

local function newRun(cityId: string): CityRunStats
    return {
        CityId = cityId,
        RunStartTime = 0, -- Set on the run's first damage
        RunEndTime = 0,
        Duration = 0,
        BuildingsDestroyed = 0,
        BuildingsDamaged = 0,
        TotalDamage = 0,
        BasicAttacks = 0,
        Stomps = 0,
        Roars = 0,
        HighestCombo = 1,
        BuildingsCash = 0,
        BuildingsXP = 0,
        CompletionCash = 0,
        CompletionXP = 0,
        TotalCash = 0,
        TotalXP = 0,
        DestructionScore = 0,
        BuildingsPerMinute = 0,
        CityCompleted = false,
        CompletionAwarded = false,
    }
end

local function resetRun(state: CityState)
    state.Run = newRun(state.Id)
    table.clear(state.DamagedBuildingIds)
    table.clear(state.Participants)
end

-- Registers every city on first use if Init hasn't (e.g. a module required before Init)
local function ensureInitialized()
    if next(cityStates) == nil then
        for _, def in ipairs(CityConfig.GetCityList()) do
            CityService.RegisterCity(def.CityId)
        end
    end
end

local function getState(cityId: string?): CityState?
    ensureInitialized()
    if not cityId then return nil end
    return cityStates[cityId]
end

-- Players currently standing in a city
local function playersInCity(cityId: string): { Player }
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if playerCity[p] == cityId then table.insert(list, p) end
    end
    return list
end

local function fireCity(cityId: string, eventType: string, payload: any)
    for _, p in ipairs(playersInCity(cityId)) do
        CityFeedbackRemote:FireClient(p, eventType, payload)
    end
end

--[=[
    Initializes CityService, binds rebuild and city selection events, and registers every city.
]=]
function CityService.Init()
    print("[CityService] Initializing CityService with simultaneous multi-city support...")
    getDestructionService()
    for _, def in ipairs(CityConfig.GetCityList()) do
        CityService.RegisterCity(def.CityId)
    end

    -- Bind client rebuild requests (rebuilds the city the player is in, or the one they name)
    RebuildCityRequestRemote.OnServerEvent:Connect(function(player: Player, requestedCity: any)
        print(string.format("[CityService] Rebuild request received from %s for '%s'", player.Name, tostring(requestedCity)))
        local cityId = playerCity[player]
        if type(requestedCity) == "string" and cityStates[requestedCity] then cityId = requestedCity end
        CityService.ResetCity(player, cityId)
    end)

    -- Bind client city selection requests
    CitySelectRequestRemote.OnServerEvent:Connect(function(player: Player, requestedCity: any)
        if type(requestedCity) ~= "string" then
            warn(string.format("[CityService] Invalid CitySelectRequest from %s (non-string type)", player.Name))
            return
        end

        local unlocked, reason = CityService.IsCityUnlocked(player, requestedCity)
        if not unlocked then
            warn(
                string.format(
                    "[CityService] Rejected CitySelectRequest from %s for '%s': %s",
                    player.Name,
                    requestedCity,
                    reason or "Locked"
                )
            )
            CityFeedbackRemote:FireClient(player, "CitySelectRejected", {
                CityId = requestedCity,
                Reason = reason or "City is locked!",
            })
            return
        end

        local success, loadMsg = CityService.LoadCity(requestedCity, player)
        if not success then
            warn(string.format("[CityService] Failed to load city '%s' for %s: %s", requestedCity, player.Name, loadMsg))
            CityFeedbackRemote:FireClient(player, "CitySelectRejected", {
                CityId = requestedCity,
                Reason = loadMsg,
            })
            return
        end

        print(string.format("[CityService] ✅ %s travelled to '%s'!", player.Name, requestedCity))
    end)

    -- Player lifecycle
    Players.PlayerAdded:Connect(function(player)
        playerCityCompletions[player.UserId] = {
            SmallTown = 0,
            Metrovale = 0,
        }

        player.CharacterAdded:Connect(function(character)
            -- A respawn always lands in the Kaiju Hub lobby, so the player is no longer in a city
            playerCity[player] = nil
            local hub = Workspace:FindFirstChild("KaijuHub")
            if hub then
                -- KaijuHub is the master lobby spawn. Do not override spawn location.
                return
            end
            local cityDef = CityConfig.GetCity(DEFAULT_CITY)
            if cityDef then
                playerCity[player] = DEFAULT_CITY
                task.wait(0.1)
                if character and character.Parent and character.PrimaryPart then
                    character:PivotTo(CFrame.new(cityDef.SpawnPosition + Vector3.new(0, 4, 0)))
                end
            end
        end)

        task.defer(function()
            if player.Parent then
                CityFeedbackRemote:FireClient(player, "CityProgressUpdate", CityService.GetCityStats(DEFAULT_CITY))
                CityFeedbackRemote:FireClient(player, "CityListSync", CityService.GetAvailableCities(player))
                local hubLighting = CityConfig.GetLightingProfile("KaijuHub")
                if hubLighting then CityFeedbackRemote:FireClient(player, "CityLightingChanged", hubLighting) end
            end
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        playerCityCompletions[player.UserId] = nil
        playerCity[player] = nil
        for _, state in pairs(cityStates) do
            state.Participants[player] = nil
        end
    end)
end

--[=[
    Starts city service operations.
]=]
function CityService.Start()
    print("[CityService] CityService started.")
    for cityId in pairs(cityStates) do
        local stats = CityService.GetCityStats(cityId)
        print(
            string.format(
                "[CityService] City '%s' ready: %d buildings (Total HP: %d)",
                stats.CityName,
                stats.TotalBuildings,
                stats.TotalHealth
            )
        )
    end
end

--[=[
    Indexes all buildings of a city once and backs up their initial visual states for rebuild restoration.
]=]
function CityService.RegisterCity(cityName: string)
    local citiesFolder = Workspace:FindFirstChild("Cities")
    if not citiesFolder then
        warn("[CityService] Workspace.Cities folder not found!")
        return
    end

    local cityFolder = citiesFolder:FindFirstChild(cityName)
    if not cityFolder then
        warn(string.format("[CityService] City folder '%s' not found!", cityName))
        return
    end

    local buildingsFolder = cityFolder:FindFirstChild("Buildings")
    if not buildingsFolder then
        warn(string.format("[CityService] Buildings folder in '%s' not found!", cityName))
        return
    end

    local state: CityState = {
        Id = cityName,
        BuildingsById = {},
        BuildingList = {},
        Run = newRun(cityName),
        DamagedBuildingIds = {},
        Participants = {},
    }

    local totalHP = 0

    for _, child in ipairs(buildingsFolder:GetChildren()) do
        if child:IsA("Model") then
            local bId = child:GetAttribute("BuildingId") or child.Name
            local bName = child:GetAttribute("BuildingName") or child.Name
            local bType = child:GetAttribute("BuildingType") or "Small"
            local tier = tonumber(child:GetAttribute("DestructionTier")) or 1

            -- Scale the authored HP once per building; AuthoredMaxHealth keeps re-registration idempotent
            local authoredHp = tonumber(child:GetAttribute("AuthoredMaxHealth"))
            if not authoredHp then
                authoredHp = tonumber(child:GetAttribute("MaxHealth")) or 500
                child:SetAttribute("AuthoredMaxHealth", authoredHp)
            end
            local healthScale = DestructionConfig.TierHealthScale[tier] or 1
            local maxHp = math.max(1, math.floor(authoredHp * healthScale))
            local curHp = math.min(tonumber(child:GetAttribute("CurrentHealth")) or maxHp, maxHp)
            child:SetAttribute("MaxHealth", maxHp)
            child:SetAttribute("CurrentHealth", curHp)
            local reward = child:GetAttribute("DestructionReward") or child:GetAttribute("DestructonReward") or 100
            local attrDestroyed = child:GetAttribute("IsDestroyed")
            local isDestroyed = if attrDestroyed ~= nil then (attrDestroyed == true) else false

            local structure = child:FindFirstChild("Structure")
            local mainBody = structure and structure:FindFirstChild("MainBody") :: BasePart?
            local roof = structure and structure:FindFirstChild("Roof") :: BasePart?

            local windowsFolder = child:FindFirstChild("Windows")
            local windowParts: { BasePart } = {}
            if windowsFolder then
                for _, part in ipairs(windowsFolder:GetChildren()) do
                    if part:IsA("BasePart") then table.insert(windowParts, part) end
                end
            end

            local propsFolder = child:FindFirstChild("Props")
            local propParts: { BasePart } = {}
            if propsFolder then
                for _, part in ipairs(propsFolder:GetChildren()) do
                    if part:IsA("BasePart") then table.insert(propParts, part) end
                end
            end

            for _, list in { windowParts, propParts } do
                for _, part in ipairs(list) do
                    if authoredTransparency[part] == nil then
                        authoredTransparency[part] = part.Transparency
                        authoredCanCollide[part] = part.CanCollide
                    end
                end
            end

            local primaryPart = child.PrimaryPart or mainBody or child:FindFirstChildWhichIsA("BasePart")
            local pos = if primaryPart then primaryPart.Position else child:GetPivot().Position

            local visualBackup: BuildingVisualBackup = {
                MainBody = mainBody,
                MainBodyCFrame = if mainBody then mainBody.CFrame else nil,
                MainBodySize = if mainBody then mainBody.Size else nil,
                MainBodyColor = if mainBody then mainBody.Color else nil,
                Roof = roof,
                RoofCFrame = if roof then roof.CFrame else nil,
                RoofSize = if roof then roof.Size else nil,
                RoofColor = if roof then roof.Color else nil,
                WindowParts = windowParts,
                PropParts = propParts,
                PartTransparency = authoredTransparency,
                PartCanCollide = authoredCanCollide,
            }

            local entry: BuildingEntry = {
                Model = child,
                CityId = cityName,
                Id = tostring(bId),
                Name = tostring(bName),
                Type = tostring(bType),
                MaxHealth = tonumber(maxHp) or 500,
                CurrentHealth = tonumber(curHp) or 500,
                Reward = tonumber(reward) or 100,
                Tier = tonumber(tier) or 1,
                Position = pos,
                PrimaryPart = primaryPart,
                IsDestroyed = isDestroyed,
                VisualBackup = visualBackup,
            }

            state.BuildingsById[entry.Id] = entry
            table.insert(state.BuildingList, entry)
            entriesByModel[child] = entry
            totalHP += entry.MaxHealth
        end
    end

    cityStates[cityName] = state

    print(
        string.format(
            "[CityService] Successfully registered city '%s' with %d destructible buildings. Total HP: %d",
            cityName,
            #state.BuildingList,
            totalHP
        )
    )
end

--[=[
    Returns the city a player is standing in, or nil when they are in the Kaiju Hub.
]=]
function CityService.GetPlayerCity(player: Player): string?
    return playerCity[player]
end

-- Compatibility: the city a player is in, defaulting to SmallTown
function CityService.GetActiveCity(player: Player?): string
    return (player and playerCity[player]) or DEFAULT_CITY
end

function CityService.GetCityName(player: Player?): string
    return CityService.GetActiveCity(player)
end

function CityService.GetCityConfig(cityId: string)
    return CityConfig.GetCity(cityId)
end

function CityService.GetPlayerCityCompletions(player: Player, cityId: string): number
    local profile = PlayerDataService.GetProfile(player)
    if profile and profile.Cities and profile.Cities[cityId] then return profile.Cities[cityId].Clears end
    local comps = playerCityCompletions[player.UserId]
    if not comps then return 0 end
    return comps[cityId] or 0
end

function CityService.IsCityUnlocked(player: Player, cityId: string): (boolean, string?)
    local cityDef = CityConfig.GetCity(cityId)
    if not cityDef then return false, "City does not exist" end

    local req = cityDef.UnlockRequirements
    if req.UnlockedByDefault then return true, nil end

    -- Check persistent profile unlock state
    local profile = PlayerDataService.GetProfile(player)
    if profile and profile.Cities and profile.Cities[cityId] and profile.Cities[cityId].Unlocked then return true, nil end

    -- Check required level
    if req.RequiredLevel then
        local prog = ProgressionService.GetPlayerProgression(player)
        if prog.Level < req.RequiredLevel then
            return false, string.format("Requires Level %d (Current: Level %d)", req.RequiredLevel, prog.Level)
        end
    end

    -- Check required SmallTown clears
    if req.RequiredSmallTownClears then
        local clears = CityService.GetPlayerCityCompletions(player, "SmallTown")
        if clears < req.RequiredSmallTownClears then
            return false, string.format("Requires %d SmallTown Clears (Current: %d)", req.RequiredSmallTownClears, clears)
        end
    end

    -- If requirements are met, record unlock in persistent profile
    if profile and profile.Cities and profile.Cities[cityId] then
        PlayerDataService.UpdateProfile(player, function(prof)
            if prof.Cities[cityId] then prof.Cities[cityId].Unlocked = true end
        end)
    end

    return true, nil
end

function CityService.GetAvailableCities(player: Player): { any }
    local result = {}
    local profile = PlayerDataService.GetProfile(player)
    for _, def in ipairs(CityConfig.GetCityList()) do
        local unlocked, reason = CityService.IsCityUnlocked(player, def.CityId)
        local cityRecord = if profile and profile.Cities then profile.Cities[def.CityId] else nil
        local bestTime = if cityRecord and cityRecord.BestTime
            then cityRecord.BestTime
            else (cityBestRecords[def.CityId] and cityBestRecords[def.CityId].BestTime or 0)
        local bestCombo = if cityRecord and cityRecord.BestCombo
            then cityRecord.BestCombo
            else (cityBestRecords[def.CityId] and cityBestRecords[def.CityId].BestCombo or 1)
        local clears = if cityRecord then cityRecord.Clears else CityService.GetPlayerCityCompletions(player, def.CityId)

        local bestScore = if cityRecord and cityRecord.BestScore
            then cityRecord.BestScore
            else (cityBestRecords[def.CityId] and cityBestRecords[def.CityId].BestScore or 0)
        local bestBpm = if cityRecord and cityRecord.BestBuildingsPerMinute
            then cityRecord.BestBuildingsPerMinute
            else (cityBestRecords[def.CityId] and cityBestRecords[def.CityId].BestBPM or 0)

        table.insert(result, {
            CityId = def.CityId,
            DisplayName = def.DisplayName,
            Description = def.Description,
            Difficulty = def.Difficulty,
            RecommendedLevel = def.RecommendedLevel,
            Unlocked = unlocked,
            LockReason = reason,
            BestTime = bestTime,
            BestCombo = bestCombo,
            BestScore = bestScore,
            BestBuildingsPerMinute = bestBpm,
            Completions = clears,
            IsActive = (def.CityId == playerCity[player]),
        })
    end
    return result
end

--[=[
    Sends a player (or, with no player, everyone) to a city. Other cities keep running untouched.
]=]
function CityService.LoadCity(cityId: string, player: Player?): (boolean, string)
    local cityDef = CityConfig.GetCity(cityId)
    if not cityDef then return false, "Invalid city ID: " .. tostring(cityId) end
    local state = getState(cityId)
    if not state then return false, "City is not available: " .. cityId end

    if player then
        local unlocked, reason = CityService.IsCityUnlocked(player, cityId)
        if not unlocked then return false, reason or "City is locked!" end
    end

    local travellers = if player then { player } else Players:GetPlayers()
    local spawnPos = cityDef.SpawnPosition
    local stats = CityService.GetCityStats(cityId)

    for _, p in ipairs(travellers) do
        playerCity[p] = cityId
        if p.Character and p.Character.PrimaryPart then p.Character:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 4, 0))) end

        CityFeedbackRemote:FireClient(p, "CityLoaded", {
            CityId = cityId,
            CityName = cityDef.DisplayName,
            SpawnPosition = spawnPos,
            Stats = stats,
        })
        CityFeedbackRemote:FireClient(p, "CityProgressUpdate", stats)
        if cityDef.LightingProfile then CityFeedbackRemote:FireClient(p, "CityLightingChanged", cityDef.LightingProfile) end
        CityFeedbackRemote:FireClient(p, "CityListSync", CityService.GetAvailableCities(p))
    end

    print(
        string.format(
            "[CityService] ✅ %d player(s) entered '%s' (%d/%d buildings standing)",
            #travellers,
            cityId,
            stats.ActiveBuildings,
            stats.TotalBuildings
        )
    )

    return true, "City Loaded"
end

function CityService.ReturnToHub(player: Player): (boolean, string)
    local hub = Workspace:FindFirstChild("KaijuHub")
    local hubSpawn = hub and hub:FindFirstChild("HubSpawnLocation", true)
    if not hubSpawn or not hubSpawn:IsA("BasePart") then return false, "Kaiju Hub spawn not found!" end

    if player.Character and player.Character.PrimaryPart then
        playerCity[player] = nil
        player.Character:PivotTo(hubSpawn.CFrame + Vector3.new(0, 8, 0))
        local hubLighting = CityConfig.GetLightingProfile("KaijuHub")
        if hubLighting then CityFeedbackRemote:FireClient(player, "CityLightingChanged", hubLighting) end
        CityFeedbackRemote:FireClient(player, "CityListSync", CityService.GetAvailableCities(player))
        return true, "Returned to Kaiju Hub"
    end
    return false, "Player character not found"
end

function CityService.GetAllBuildings(cityId: string?): { Model }
    local models: { Model } = {}
    for id, state in pairs(cityStates) do
        if cityId == nil or id == cityId then
            for _, entry in ipairs(state.BuildingList) do
                table.insert(models, entry.Model)
            end
        end
    end
    return models
end

function CityService.GetBuildingById(buildingId: string, cityId: string?): Model?
    for id, state in pairs(cityStates) do
        if cityId == nil or id == cityId then
            local entry = state.BuildingsById[buildingId]
            if entry then return entry.Model end
        end
    end
    return nil
end

function CityService.GetBuildingEntry(building: Model): BuildingEntry?
    ensureInitialized()
    return entriesByModel[building]
end

-- Horizontal distance from `origin` to the building's footprint (its authored MainBody box), so a
-- titan pressed against a wide tower is in range; falls back to the building's centre point
local function footprintDistanceSq(entry: BuildingEntry, origin: Vector3): number
    local backup = entry.VisualBackup
    local bodyCFrame = backup and backup.MainBodyCFrame
    local bodySize = backup and backup.MainBodySize
    if not bodyCFrame or not bodySize then return (entry.Position.X - origin.X) ^ 2 + (entry.Position.Z - origin.Z) ^ 2 end

    local localPos = bodyCFrame:PointToObjectSpace(Vector3.new(origin.X, bodyCFrame.Position.Y, origin.Z))
    local dx = math.max(math.abs(localPos.X) - bodySize.X * 0.5, 0)
    local dz = math.max(math.abs(localPos.Z) - bodySize.Z * 0.5, 0)
    return dx * dx + dz * dz
end

function CityService.GetBuildingsInRadius(origin: Vector3, radius: number): { { Building: Model, Entry: BuildingEntry, Distance: number } }
    ensureInitialized()
    local results = {}
    local rSq = radius * radius

    -- Cities are far apart, so scanning every city's buildings only ever matches the one the titan is in
    for _, state in pairs(cityStates) do
        for _, entry in ipairs(state.BuildingList) do
            if not entry.IsDestroyed and entry.PrimaryPart then
                local distSq = footprintDistanceSq(entry, origin)
                if distSq <= rSq then
                    local actualDist = math.sqrt(distSq)
                    table.insert(results, {
                        Building = entry.Model,
                        Entry = entry,
                        Distance = actualDist,
                    })
                end
            end
        end
    end

    -- Include active bosses (BossService tags them), measured to their body's edge
    for _, boss in ipairs(CollectionService:GetTagged("BossTarget")) do
        if boss:IsA("Model") and boss.PrimaryPart then
            local part = boss.PrimaryPart
            local hitRadius = tonumber(boss:GetAttribute("HitRadius")) or 10
            local dist = math.max(0, Vector3.new(part.Position.X - origin.X, 0, part.Position.Z - origin.Z).Magnitude - hitRadius)
            if dist <= radius then
                local bossEntry: BuildingEntry = {
                    Model = boss,
                    CityId = "KaijuHub",
                    Id = boss.Name,
                    Name = tostring(boss:GetAttribute("BuildingName") or boss.Name),
                    Type = "Boss",
                    MaxHealth = 1,
                    CurrentHealth = 1,
                    Reward = 0,
                    Tier = 1,
                    Position = part.Position,
                    PrimaryPart = part,
                    IsDestroyed = false,
                    VisualBackup = nil :: any,
                }
                table.insert(results, { Building = boss, Entry = bossEntry, Distance = dist })
            end
        end
    end

    -- Include KaijuHub training pillars if within radius
    local hub = Workspace:FindFirstChild("KaijuHub")
    if hub then
        for _, child in ipairs(hub:GetDescendants()) do
            if child:GetAttribute("IsTrainingDummy") == true and child:GetAttribute("IsDestroyed") ~= true then
                local part = if child:IsA("BasePart") then child else child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
                if part then
                    local distSq = (part.Position.X - origin.X) ^ 2 + (part.Position.Z - origin.Z) ^ 2
                    if distSq <= rSq then
                        local curHp = child:GetAttribute("CurrentHealth") or 10000
                        local maxHp = child:GetAttribute("MaxHealth") or 10000
                        local dummyEntry: BuildingEntry = {
                            Model = child :: any,
                            CityId = "KaijuHub",
                            Id = child.Name,
                            Name = tostring(child:GetAttribute("BuildingName") or child.Name),
                            Type = "TrainingPillar",
                            MaxHealth = maxHp,
                            CurrentHealth = curHp,
                            Reward = 0,
                            Tier = 1,
                            Position = part.Position,
                            PrimaryPart = part,
                            IsDestroyed = false,
                            VisualBackup = nil :: any,
                        }
                        table.insert(results, {
                            Building = child :: any,
                            Entry = dummyEntry,
                            Distance = math.sqrt(distSq),
                        })
                    end
                end
            end
        end
    end

    table.sort(results, function(a, b)
        return a.Distance < b.Distance
    end)

    return results
end

--[=[
    Returns live statistics for a city (default SmallTown), computed directly from its building state.
]=]
function CityService.GetCityStats(cityId: string?): CityStats
    local id = cityId or DEFAULT_CITY
    local state = getState(id)
    local totalHP = 0
    local curHP = 0
    local activeCount = 0
    local destroyedCount = 0
    local list = if state then state.BuildingList else {}

    for _, entry in ipairs(list) do
        local maxHp = entry.Model:GetAttribute("MaxHealth")
        if maxHp == nil then maxHp = entry.MaxHealth end

        local health = entry.Model:GetAttribute("CurrentHealth")
        if health == nil then health = entry.CurrentHealth end

        local attrDestroyed = entry.Model:GetAttribute("IsDestroyed")
        local destroyed = if attrDestroyed ~= nil then (attrDestroyed == true) else entry.IsDestroyed

        entry.MaxHealth = tonumber(maxHp) or 500
        entry.CurrentHealth = tonumber(health) or 0
        entry.IsDestroyed = destroyed

        totalHP += entry.MaxHealth
        curHP += entry.CurrentHealth

        if destroyed then
            destroyedCount += 1
        else
            activeCount += 1
        end
    end

    local totalBuildings = #list
    local destructionPct = if totalHP > 0 then math.clamp(math.floor((1 - (curHP / totalHP)) * 100), 0, 100) else 0
    local completionPct = if totalBuildings > 0 then math.clamp(math.floor((destroyedCount / totalBuildings) * 100), 0, 100) else 0
    local run = if state then state.Run else newRun(id)

    return {
        CityName = id,
        TotalBuildings = totalBuildings,
        ActiveBuildings = activeCount,
        DestroyedBuildings = destroyedCount,
        TotalHealth = totalHP,
        CurrentHealth = curHP,
        DestructionPercentage = destructionPct,
        CityCompletionPercentage = completionPct,
        RunStartTime = if run.RunStartTime > 0 then run.RunStartTime else os.clock(),
        RunEndTime = run.RunEndTime,
        HighestCombo = run.HighestCombo,
        CityCompleted = run.CityCompleted,
    }
end

function CityService.GetRunStats(cityId: string?): CityRunStats
    local state = getState(cityId or DEFAULT_CITY)
    return if state then state.Run else newRun(cityId or DEFAULT_CITY)
end

--[=[
    Records incoming structural damage to a city building during its run.
]=]
function CityService.RecordDamage(building: Model, amount: number, player: Player?)
    local entry = entriesByModel[building]
    local state = entry and getState(entry.CityId)
    if not entry or not state then return end
    local run = state.Run
    if run.RunStartTime == 0 then run.RunStartTime = os.clock() end
    run.TotalDamage += math.max(0, amount)
    if not state.DamagedBuildingIds[entry.Id] then
        state.DamagedBuildingIds[entry.Id] = true
        run.BuildingsDamaged += 1
    end
    if player then state.Participants[player] = true end
end

--[=[
    Records ability usage in the run of the city the player is in.
]=]
function CityService.RecordAbilityUsed(player: Player?, abilityName: string)
    local state = player and getState(playerCity[player])
    if not state or state.Run.CityCompleted then return end
    local run = state.Run
    if abilityName == "BasicAttack" or abilityName == "TailSweep" or abilityName == "NeckStrike" then
        run.BasicAttacks += 1
    elseif abilityName == "Stomp" or abilityName == "HeavyStomp" then
        run.Stomps += 1
    elseif abilityName == "Roar" then
        run.Roars += 1
    end
end

--[=[
    Calculates destruction run score using the formal scoring model:
    Base (Cash + 10% Damage) + Combo Bonus + Speed Bonus + Completion Bonus.
]=]
function CityService.CalculateDestructionScore(cityId: string, run: CityRunStats): (number, number, number, number, number)
    local targetTime = if cityId == "Metrovale" then 240 else 120
    local completionBonus = if cityId == "Metrovale" then 15000 else 5000

    local baseScore = run.BuildingsCash + math.floor(run.TotalDamage * 0.1)
    local comboBonus = math.floor(run.HighestCombo * 1500)
    local speedBonus = math.max(0, math.floor((targetTime - run.Duration) * 50))
    local totalScore = math.max(0, math.floor(baseScore + comboBonus + speedBonus + completionBonus))

    return totalScore, baseScore, comboBonus, speedBonus, completionBonus
end

--[=[
    Records a building destruction event, updates its city's run statistics, and checks completion.
]=]
function CityService.RecordDestruction(player: Player?, building: Model, cash: number, xp: number, combo: number)
    local entry = entriesByModel[building]
    local state = entry and getState(entry.CityId)
    if not entry or not state then return end
    local run = state.Run
    run.BuildingsDestroyed += 1
    run.BuildingsCash += math.max(0, cash)
    run.BuildingsXP += math.max(0, xp)

    if combo > run.HighestCombo then run.HighestCombo = combo end

    local stats = CityService.GetCityStats(state.Id)

    -- Broadcast live city progress to everyone in this city
    fireCity(state.Id, "CityProgressUpdate", stats)

    -- Check for city completion transition
    if stats.DestroyedBuildings >= stats.TotalBuildings and not run.CityCompleted then
        CityService.TriggerCityCompletion(state.Id, player)
    end
end

--[=[
    Triggers server-authoritative city completion when all of a city's buildings are destroyed.
    The completion reward goes to the run's participants (players who damaged the city) and anyone
    standing in the city at the moment it falls.
]=]
function CityService.TriggerCityCompletion(cityId: string, triggeringPlayer: Player?)
    local state = getState(cityId)
    if not state then return end
    local run = state.Run
    if run.CityCompleted then return end
    run.CityCompleted = true
    run.RunEndTime = os.clock()
    if run.RunStartTime == 0 then run.RunStartTime = run.RunEndTime end

    local cityDef = CityConfig.GetCity(cityId)
    local completionReward = if cityDef then cityDef.CompletionReward else { Cash = 5000, XP = 2000 }

    local recipients: { Player } = {}
    local seen: { [Player]: boolean } = {}
    for p in pairs(state.Participants) do
        if p.Parent and not seen[p] then
            seen[p] = true
            table.insert(recipients, p)
        end
    end
    for _, p in ipairs(playersInCity(cityId)) do
        if not seen[p] then
            seen[p] = true
            table.insert(recipients, p)
        end
    end

    print(
        string.format(
            "[CityService] 🏆 CITY DESTROYED! All %d buildings in '%s' flattened! Rewarding %d player(s)...",
            #state.BuildingList,
            cityId,
            #recipients
        )
    )

    -- Award completion reward exactly once via ProgressionService
    if not run.CompletionAwarded then
        run.CompletionAwarded = true
        for _, player in ipairs(recipients) do
            ProgressionService.AddRewards(player, completionReward.Cash, completionReward.XP)
            print(
                string.format(
                    "[CityService] Awarded City Completion Bonus to %s: +$%d Cash, +%d XP",
                    player.Name,
                    completionReward.Cash,
                    completionReward.XP
                )
            )
        end
    end

    local duration = math.max(1, math.floor(run.RunEndTime - run.RunStartTime))
    run.Duration = duration
    local bpm = math.floor((run.BuildingsDestroyed / (duration / 60)) * 10) / 10
    run.BuildingsPerMinute = bpm

    local totalScore, baseScore, comboBonus, speedBonus, completionScoreBonus = CityService.CalculateDestructionScore(cityId, run)
    run.DestructionScore = totalScore

    local totalCash = run.BuildingsCash + completionReward.Cash
    local totalXP = run.BuildingsXP + completionReward.XP

    run.CompletionCash = completionReward.Cash
    run.CompletionXP = completionReward.XP
    run.TotalCash = totalCash
    run.TotalXP = totalXP

    -- Record completion count per player & update persistent profile
    local isNewBestTimeMap: { [number]: boolean } = {}
    local isNewBestComboMap: { [number]: boolean } = {}
    local isNewBestScoreMap: { [number]: boolean } = {}
    local isNewBestBpmMap: { [number]: boolean } = {}

    for _, p in ipairs(recipients) do
        local comps = playerCityCompletions[p.UserId]
        if not comps then
            comps = { SmallTown = 0, Metrovale = 0 }
            playerCityCompletions[p.UserId] = comps
        end
        comps[cityId] = (comps[cityId] or 0) + 1

        PlayerDataService.UpdateProfile(p, function(prof)
            if not prof.Cities[cityId] then
                prof.Cities[cityId] = {
                    Unlocked = true,
                    Clears = 0,
                    BestTime = nil,
                    BestCombo = 0,
                    BestScore = 0,
                    BestBuildingsPerMinute = 0,
                }
            end
            local cityData = prof.Cities[cityId]
            cityData.Clears += 1

            local isNewTime = not cityData.BestTime or duration < cityData.BestTime
            local isNewCombo = run.HighestCombo > (cityData.BestCombo or 0)
            local isNewScore = totalScore > (cityData.BestScore or 0)
            local isNewBpm = bpm > (cityData.BestBuildingsPerMinute or 0)

            isNewBestTimeMap[p.UserId] = isNewTime
            isNewBestComboMap[p.UserId] = isNewCombo
            isNewBestScoreMap[p.UserId] = isNewScore
            isNewBestBpmMap[p.UserId] = isNewBpm

            if isNewTime then cityData.BestTime = duration end
            if isNewCombo then cityData.BestCombo = run.HighestCombo end
            if isNewScore then cityData.BestScore = totalScore end
            if isNewBpm then cityData.BestBuildingsPerMinute = bpm end

            -- Update persistent lifetime statistics
            if prof.Statistics then
                local stats = prof.Statistics
                stats.TotalBuildingsDestroyed += run.BuildingsDestroyed
                stats.TotalDamageDealt += run.TotalDamage
                stats.TotalCitiesCompleted += 1
                stats.TotalRunsCompleted += 1
                stats.TotalCashEarned += totalCash
                stats.TotalXPEarned += totalXP
                if run.HighestCombo > stats.HighestCombo then stats.HighestCombo = run.HighestCombo end
                stats.TotalPlayTime += duration
            end

            -- Automatically unlock Metrovale if player meets requirements
            if prof.Cities.Metrovale and not prof.Cities.Metrovale.Unlocked then
                if prof.Level >= 4 and prof.Cities.SmallTown.Clears >= 1 then prof.Cities.Metrovale.Unlocked = true end
            end
        end)
    end

    if triggeringPlayer then
        local comps = playerCityCompletions[triggeringPlayer.UserId]
        print(
            string.format("[CityService] %s now has %d completions for '%s'", triggeringPlayer.Name, comps and comps[cityId] or 1, cityId)
        )
    end

    -- Update session best records
    local rec = cityBestRecords[cityId]
    if not rec then
        rec = { BestTime = 0, BestCombo = 1, BestScore = 0, BestBPM = 0 }
        cityBestRecords[cityId] = rec
    end
    if rec.BestTime == 0 or duration < rec.BestTime then
        rec.BestTime = duration
        print(string.format("[CityService] ⏱️ New Best Time for '%s': %ds!", cityId, duration))
    end
    if run.HighestCombo > rec.BestCombo then
        rec.BestCombo = run.HighestCombo
        print(string.format("[CityService] 🔥 New Best Combo for '%s': %dx!", cityId, rec.BestCombo))
    end
    if totalScore > rec.BestScore then
        rec.BestScore = totalScore
        print(string.format("[CityService] 🌟 New Best Destruction Score for '%s': %d!", cityId, totalScore))
    end
    if bpm > rec.BestBPM then
        rec.BestBPM = bpm
        print(string.format("[CityService] ⚡ New Best BPM for '%s': %.1f!", cityId, bpm))
    end

    -- Check if Metrovale unlocked, and titan unlocks, for each rewarded player
    for _, p in ipairs(recipients) do
        local unlocked, _ = CityService.IsCityUnlocked(p, "Metrovale")
        if unlocked then
            CityFeedbackRemote:FireClient(p, "CityUnlocked", {
                CityId = "Metrovale",
                CityName = "Metrovale",
            })
        end
        CityFeedbackRemote:FireClient(p, "CityListSync", CityService.GetAvailableCities(p))

        local newlyUnlockedTitans = PlayerDataService.CheckTitanUnlocks(p)
        if next(newlyUnlockedTitans) ~= nil then
            local titanFeedback = RemotesFolder:FindFirstChild("TitanFeedback") :: RemoteEvent?
            if titanFeedback then
                titanFeedback:FireClient(p, "TitanListSync", {
                    Titans = PlayerDataService.GetTitansData(p),
                    SelectedTitan = PlayerDataService.GetSelectedTitan(p),
                })
            end
        end
    end

    -- Construct and broadcast personalized completion payload per rewarded player
    for _, p in ipairs(recipients) do
        local prof = PlayerDataService.GetProfile(p)
        local cityData = if prof and prof.Cities then prof.Cities[cityId] else nil

        local completionPayload = {
            CityName = cityId,
            TotalBuildings = #state.BuildingList,
            DestroyedBuildings = #state.BuildingList,
            CityCompletionPercentage = 100,
            Duration = duration,
            HighestCombo = run.HighestCombo,
            TotalDamage = run.TotalDamage,
            BuildingsDestroyed = run.BuildingsDestroyed,
            BuildingsDamaged = run.BuildingsDamaged,
            BasicAttacks = run.BasicAttacks,
            Stomps = run.Stomps,
            Roars = run.Roars,
            BuildingsPerMinute = bpm,
            DestructionScore = totalScore,
            ScoreBreakdown = {
                BaseScore = baseScore,
                ComboBonus = comboBonus,
                SpeedBonus = speedBonus,
                CompletionBonus = completionScoreBonus,
            },
            BestTime = if cityData and cityData.BestTime then cityData.BestTime else rec.BestTime,
            BestCombo = if cityData and cityData.BestCombo then cityData.BestCombo else rec.BestCombo,
            BestScore = if cityData and cityData.BestScore then cityData.BestScore else rec.BestScore,
            BestBPM = if cityData and cityData.BestBuildingsPerMinute then cityData.BestBuildingsPerMinute else rec.BestBPM,
            IsNewBestTime = isNewBestTimeMap[p.UserId] == true,
            IsNewBestCombo = isNewBestComboMap[p.UserId] == true,
            IsNewBestScore = isNewBestScoreMap[p.UserId] == true,
            IsNewBestBpm = isNewBestBpmMap[p.UserId] == true,
            BuildingsCash = run.BuildingsCash,
            BuildingsXP = run.BuildingsXP,
            CompletionCash = completionReward.Cash,
            CompletionXP = completionReward.XP,
            TotalCash = totalCash,
            TotalXP = totalXP,
        }

        CityFeedbackRemote:FireClient(p, "CityCompleted", completionPayload)
    end
end

--[=[
    Restores a city's buildings to full health and pristine visual state, resets its run statistics,
    and starts a new run. A player may rebuild a city once it is fully cleared; the InstantRebuild
    gamepass skips that wait only when nobody else is mid-run there.
]=]
function CityService.ResetCity(requestingPlayer: Player?, cityId: string?): (boolean, string)
    local id = cityId or (requestingPlayer and playerCity[requestingPlayer]) or DEFAULT_CITY
    local state = getState(id)
    if not state then return false, "Unknown city" end

    local stats = CityService.GetCityStats(id)
    local isCompleted = state.Run.CityCompleted or (stats.DestroyedBuildings >= stats.TotalBuildings and stats.TotalBuildings > 0)
    local monService = getMonetizationService()
    local hasInstantRebuild = if requestingPlayer and monService then monService.HasInstantRebuild(requestingPlayer) else false

    if requestingPlayer and not isCompleted then
        -- Don't let one player's instant rebuild wipe someone else's progress in a shared city
        local othersMidRun = false
        for p in pairs(state.Participants) do
            if p ~= requestingPlayer and p.Parent then othersMidRun = true end
        end
        if not hasInstantRebuild then
            warn(string.format("[CityService] Rejected rebuild request from %s: '%s' is not yet completed!", requestingPlayer.Name, id))
            return false, "City is not completed"
        elseif othersMidRun then
            warn(string.format("[CityService] Rejected instant rebuild from %s: others are mid-run in '%s'", requestingPlayer.Name, id))
            CityFeedbackRemote:FireClient(requestingPlayer, "CitySelectRejected", {
                CityId = id,
                Reason = "Other titans are still destroying this city!",
            })
            return false, "Other players are mid-run"
        end
    end

    print(string.format("[CityService] Rebuilding '%s'... Restoring %d buildings.", id, #state.BuildingList))

    -- 1. Restore all buildings
    local models: { Model } = {}
    for _, entry in ipairs(state.BuildingList) do
        local bld = entry.Model
        local backup = entry.VisualBackup
        table.insert(models, bld)

        -- Remove any rubble parts
        local rubble = bld:FindFirstChild("Rubble")
        if rubble then rubble:Destroy() end

        -- Restore MainBody
        if backup.MainBody and backup.MainBodyCFrame then
            backup.MainBody.CFrame = backup.MainBodyCFrame
            backup.MainBody.Size = backup.MainBodySize or backup.MainBody.Size
            backup.MainBody.Color = backup.MainBodyColor or backup.MainBody.Color
            backup.MainBody.Transparency = 0
            backup.MainBody.CanCollide = true
        end

        -- Restore Roof
        if backup.Roof and backup.RoofCFrame then
            backup.Roof.CFrame = backup.RoofCFrame
            backup.Roof.Size = backup.RoofSize or backup.Roof.Size
            backup.Roof.Color = backup.RoofColor or backup.RoofColor
            backup.Roof.Transparency = 0
            backup.Roof.CanCollide = true
        end

        -- Restore Windows and Props to their authored look (cities differ: SmallTown glass is opaque)
        for _, list in { backup.WindowParts, backup.PropParts } do
            for _, part in ipairs(list) do
                if part and part.Parent then
                    part.Transparency = backup.PartTransparency[part] or 0
                    part.CanCollide = if backup.PartCanCollide[part] ~= nil then backup.PartCanCollide[part] else true
                end
            end
        end

        -- Reset attributes and entry health
        entry.CurrentHealth = entry.MaxHealth
        entry.IsDestroyed = false
        bld:SetAttribute("CurrentHealth", entry.MaxHealth)
        bld:SetAttribute("IsDestroyed", false)
    end

    -- 2. Reset DestructionService state for this city's buildings only
    local dest = getDestructionService()
    if dest and type(dest.ClearCollapsingBuildings) == "function" then dest.ClearCollapsingBuildings(models) end

    -- 3. Reset run statistics
    resetRun(state)

    local newStats = CityService.GetCityStats(id)

    -- 4. Broadcast city reset to everyone in this city
    fireCity(id, "CityReset", newStats)

    local cityDef = CityConfig.GetCity(id)
    if requestingPlayer and requestingPlayer.Character and requestingPlayer.Character.PrimaryPart and cityDef then
        playerCity[requestingPlayer] = id
        requestingPlayer.Character:PivotTo(CFrame.new(cityDef.SpawnPosition + Vector3.new(0, 4, 0)))
    end

    print(string.format("[CityService] ✅ City '%s' completely reconstructed! New run timer starts on first hit.", id))

    return true, "City Rebuilt"
end

--[=[
    Applies health reduction to the indexed building entry and updates building attributes.
]=]
function CityService.ApplyDamage(buildingModel: Model, damage: number, attacker: Player?): (boolean, number)
    -- Special handling for KaijuHub Training Pillars
    if buildingModel:GetAttribute("IsTrainingDummy") == true then
        local maxHp = tonumber(buildingModel:GetAttribute("MaxHealth")) or 10000
        local curHp = tonumber(buildingModel:GetAttribute("CurrentHealth")) or maxHp
        local actualDamage = math.min(curHp, math.max(1, damage))
        local newHp = curHp - actualDamage
        if buildingModel.Name == "Bastion_Titan_Dummy" and newHp <= 1000 then
            newHp = maxHp -- The Bastion never breaks: it hosts the readiness DPS test
        end
        buildingModel:SetAttribute("CurrentHealth", math.max(0, newHp))
        return true, actualDamage
    end

    local entry = CityService.GetBuildingEntry(buildingModel)
    if not entry or entry.IsDestroyed then return false, 0 end

    local curHp = tonumber(buildingModel:GetAttribute("CurrentHealth")) or entry.CurrentHealth
    if curHp <= 0 then
        entry.IsDestroyed = true
        buildingModel:SetAttribute("IsDestroyed", true)
        return false, 0
    end

    local actualDamage = math.min(curHp, math.max(1, damage))
    local newHp = math.max(0, curHp - actualDamage)

    entry.CurrentHealth = newHp
    buildingModel:SetAttribute("CurrentHealth", newHp)

    if newHp <= 0 then
        entry.IsDestroyed = true
        buildingModel:SetAttribute("IsDestroyed", true)
    end

    return true, actualDamage
end

function CityService.RepairCity(cityId: string?)
    CityService.ResetCity(nil, cityId)
end

return CityService
