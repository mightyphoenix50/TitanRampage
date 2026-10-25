--!strict
--[[
    CityService.luau
    Responsibility:
    - Server-authoritative management of cities, zones, and destructible building infrastructure.
    - Registers active cities (SmallTown) and indexes all destructible buildings and their original states.
    - Live tracking of city completion: TotalBuildings, DestroyedBuildings, ActiveBuildings, HP, and percentages.
    - Server-authoritative Run Statistics (Timer, Cash/Points/XP accounting, Highest Combo, Damage).
    - Detects 100% city completion, triggers CityCompleted event, and awards completion rewards via ProgressionService.
    - Full city rebuild engine (CityService.ResetCity) restoring all original building instances without duplication.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local CityConfig = require(ConfigFolder:WaitForChild("CityConfig") :: ModuleScript)
local CityFeedbackRemote = RemotesFolder:WaitForChild("CityFeedback") :: RemoteEvent
local RebuildCityRequestRemote = RemotesFolder:WaitForChild("RebuildCityRequest") :: RemoteEvent
local CitySelectRequestRemote = RemotesFolder:WaitForChild("CitySelectRequest") :: RemoteEvent

-- Services
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService") :: ModuleScript)
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService") :: ModuleScript)
local DestructionService = nil
local MonetizationService = nil

local function getDestructionService()
    if not DestructionService then
        DestructionService = require(script.Parent:WaitForChild("DestructionService") :: ModuleScript)
    end
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
}

export type BuildingEntry = {
    Model: Model,
    Id: string,
    Name: string,
    Type: string,
    MaxHealth: number,
    CurrentHealth: number,
    Reward: number,
    Points: number,
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
    BuildingsPoints: number,
    BuildingsXP: number,
    CompletionCash: number,
    CompletionPoints: number,
    CompletionXP: number,
    TotalCash: number,
    TotalPoints: number,
    TotalXP: number,
    DestructionScore: number,
    BuildingsPerMinute: number,
    CityCompleted: boolean,
    CompletionAwarded: boolean,
}

local CityService = {}

local activeCityName = "SmallTown"
local buildingsById: { [string]: BuildingEntry } = {}
local buildingList: { BuildingEntry } = {}

-- Session unlock and completion tracking
local playerCityCompletions: { [number]: { [string]: number } } = {}
local cityBestRecords: { [string]: { BestTime: number, BestCombo: number, BestScore: number, BestBPM: number } } = {
    SmallTown = { BestTime = 0, BestCombo = 1, BestScore = 0, BestBPM = 0 },
    Metrovale = { BestTime = 0, BestCombo = 1, BestScore = 0, BestBPM = 0 },
}

local runDamagedBuildingIds: { [string]: boolean } = {}

-- Run statistics for current session
local currentRun: CityRunStats = {
    CityId = "SmallTown",
    RunStartTime = os.clock(),
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
    BuildingsPoints = 0,
    BuildingsXP = 0,
    CompletionCash = 0,
    CompletionPoints = 0,
    CompletionXP = 0,
    TotalCash = 0,
    TotalPoints = 0,
    TotalXP = 0,
    DestructionScore = 0,
    BuildingsPerMinute = 0,
    CityCompleted = false,
    CompletionAwarded = false,
}

local function resetRun(cityId: string)
    table.clear(runDamagedBuildingIds)
    currentRun.CityId = cityId
    currentRun.RunStartTime = os.clock()
    currentRun.RunEndTime = 0
    currentRun.Duration = 0
    currentRun.BuildingsDestroyed = 0
    currentRun.BuildingsDamaged = 0
    currentRun.TotalDamage = 0
    currentRun.BasicAttacks = 0
    currentRun.Stomps = 0
    currentRun.Roars = 0
    currentRun.HighestCombo = 1
    currentRun.BuildingsCash = 0
    currentRun.BuildingsPoints = 0
    currentRun.BuildingsXP = 0
    currentRun.CompletionCash = 0
    currentRun.CompletionPoints = 0
    currentRun.CompletionXP = 0
    currentRun.TotalCash = 0
    currentRun.TotalPoints = 0
    currentRun.TotalXP = 0
    currentRun.DestructionScore = 0
    currentRun.BuildingsPerMinute = 0
    currentRun.CityCompleted = false
    currentRun.CompletionAwarded = false
end

local function ensureInitialized()
    if #buildingList == 0 then
        CityService.RegisterCity(activeCityName)
    end
end

--[=[
    Initializes CityService, binds rebuild and city selection events, and registers SmallTown.
]=]
function CityService.Init()
    print("[CityService] Initializing CityService with multi-city support...")
    getDestructionService()
    CityService.RegisterCity(activeCityName)
    currentRun.RunStartTime = os.clock()

    -- Bind client rebuild requests
    RebuildCityRequestRemote.OnServerEvent:Connect(function(player: Player, requestedCity: any)
        print(string.format("[CityService] Rebuild request received from %s for '%s'", player.Name, tostring(requestedCity)))
        CityService.ResetCity(player)
    end)

    -- Bind client city selection requests
    CitySelectRequestRemote.OnServerEvent:Connect(function(player: Player, requestedCity: any)
        if type(requestedCity) ~= "string" then
            warn(string.format("[CityService] Invalid CitySelectRequest from %s (non-string type)", player.Name))
            return
        end

        local unlocked, reason = CityService.IsCityUnlocked(player, requestedCity)
        if not unlocked then
            warn(string.format("[CityService] Rejected CitySelectRequest from %s for '%s': %s", player.Name, requestedCity, reason or "Locked"))
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

        print(string.format("[CityService] ✅ %s successfully switched active city to '%s'!", player.Name, requestedCity))
    end)

    -- Player lifecycle
    Players.PlayerAdded:Connect(function(player)
        playerCityCompletions[player.UserId] = {
            SmallTown = 0,
            Metrovale = 0,
        }

        player.CharacterAdded:Connect(function(character)
            local hub = Workspace:FindFirstChild("KaijuHub")
            if hub then
                -- KaijuHub is the master lobby spawn. Do not override spawn location.
                return
            end
            local cityDef = CityConfig.GetCity(activeCityName)
            if cityDef then
                task.wait(0.1)
                if character and character.Parent and character.PrimaryPart then
                    character:PivotTo(CFrame.new(cityDef.SpawnPosition + Vector3.new(0, 4, 0)))
                end
            end
        end)

        task.defer(function()
            if player.Parent then
                CityFeedbackRemote:FireClient(player, "CityProgressUpdate", CityService.GetCityStats())
                CityFeedbackRemote:FireClient(player, "CityListSync", CityService.GetAvailableCities(player))
                local hubLighting = CityConfig.GetLightingProfile("KaijuHub")
                if hubLighting then
                    CityFeedbackRemote:FireClient(player, "CityLightingChanged", hubLighting)
                end
            end
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        playerCityCompletions[player.UserId] = nil
    end)
end

--[=[
    Starts city service operations.
]=]
function CityService.Start()
    print("[CityService] CityService started.")
    local stats = CityService.GetCityStats()
    print(string.format("[CityService] City '%s' active: %d buildings (Total HP: %d)", stats.CityName, stats.TotalBuildings, stats.TotalHealth))
end

--[=[
    Indexes all buildings and backs up their initial visual states for instant rebuild restoration.
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

    activeCityName = cityName
    buildingsById = {}
    buildingList = {}

    local buildingsFolder = cityFolder:FindFirstChild("Buildings")
    if not buildingsFolder then
        warn(string.format("[CityService] Buildings folder in '%s' not found!", cityName))
        return
    end

    local totalHP = 0

    for _, child in ipairs(buildingsFolder:GetChildren()) do
        if child:IsA("Model") then
            local bId = child:GetAttribute("BuildingId") or child.Name
            local bName = child:GetAttribute("BuildingName") or child.Name
            local bType = child:GetAttribute("BuildingType") or "Small"
            local maxHp = child:GetAttribute("MaxHealth") or 500
            local curHp = child:GetAttribute("CurrentHealth") or maxHp
            local reward = child:GetAttribute("DestructionReward") or child:GetAttribute("DestructonReward") or 100
            local points = child:GetAttribute("DestructionPoints") or 50
            local tier = child:GetAttribute("DestructionTier") or 1
            local attrDestroyed = child:GetAttribute("IsDestroyed")
            local isDestroyed = if attrDestroyed ~= nil then (attrDestroyed == true) else false

            local structure = child:FindFirstChild("Structure")
            local mainBody = structure and structure:FindFirstChild("MainBody") :: BasePart?
            local roof = structure and structure:FindFirstChild("Roof") :: BasePart?

            local windowsFolder = child:FindFirstChild("Windows")
            local windowParts: { BasePart } = {}
            if windowsFolder then
                for _, part in ipairs(windowsFolder:GetChildren()) do
                    if part:IsA("BasePart") then
                        table.insert(windowParts, part)
                    end
                end
            end

            local propsFolder = child:FindFirstChild("Props")
            local propParts: { BasePart } = {}
            if propsFolder then
                for _, part in ipairs(propsFolder:GetChildren()) do
                    if part:IsA("BasePart") then
                        table.insert(propParts, part)
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
            }

            local entry: BuildingEntry = {
                Model = child,
                Id = tostring(bId),
                Name = tostring(bName),
                Type = tostring(bType),
                MaxHealth = tonumber(maxHp) or 500,
                CurrentHealth = tonumber(curHp) or 500,
                Reward = tonumber(reward) or 100,
                Points = tonumber(points) or 50,
                Tier = tonumber(tier) or 1,
                Position = pos,
                PrimaryPart = primaryPart,
                IsDestroyed = isDestroyed,
                VisualBackup = visualBackup,
            }

            buildingsById[entry.Id] = entry
            table.insert(buildingList, entry)
            totalHP += entry.MaxHealth
        end
    end

    print(string.format("[CityService] Successfully registered city '%s' with %d destructible buildings. Total HP: %d", cityName, #buildingList, totalHP))
end

function CityService.GetCityName(): string
    return activeCityName
end

function CityService.GetActiveCity(): string
    return activeCityName
end

function CityService.GetCityConfig(cityId: string)
    return CityConfig.GetCity(cityId)
end

function CityService.GetPlayerCityCompletions(player: Player, cityId: string): number
    local profile = PlayerDataService.GetProfile(player)
    if profile and profile.Cities and profile.Cities[cityId] then
        return profile.Cities[cityId].Clears
    end
    local comps = playerCityCompletions[player.UserId]
    if not comps then return 0 end
    return comps[cityId] or 0
end

function CityService.IsCityUnlocked(player: Player, cityId: string): (boolean, string?)
    local cityDef = CityConfig.GetCity(cityId)
    if not cityDef then
        return false, "City does not exist"
    end

    local req = cityDef.UnlockRequirements
    if req.UnlockedByDefault then
        return true, nil
    end

    -- Check persistent profile unlock state
    local profile = PlayerDataService.GetProfile(player)
    if profile and profile.Cities and profile.Cities[cityId] and profile.Cities[cityId].Unlocked then
        return true, nil
    end

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
            if prof.Cities[cityId] then
                prof.Cities[cityId].Unlocked = true
            end
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
        local bestTime = if cityRecord and cityRecord.BestTime then cityRecord.BestTime else (cityBestRecords[def.CityId] and cityBestRecords[def.CityId].BestTime or 0)
        local bestCombo = if cityRecord and cityRecord.BestCombo then cityRecord.BestCombo else (cityBestRecords[def.CityId] and cityBestRecords[def.CityId].BestCombo or 1)
        local clears = if cityRecord then cityRecord.Clears else CityService.GetPlayerCityCompletions(player, def.CityId)

        local bestScore = if cityRecord and cityRecord.BestScore then cityRecord.BestScore else (cityBestRecords[def.CityId] and cityBestRecords[def.CityId].BestScore or 0)
        local bestBpm = if cityRecord and cityRecord.BestBuildingsPerMinute then cityRecord.BestBuildingsPerMinute else (cityBestRecords[def.CityId] and cityBestRecords[def.CityId].BestBPM or 0)

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
            IsActive = (def.CityId == activeCityName),
        })
    end
    return result
end

function CityService.LoadCity(cityId: string, player: Player?): (boolean, string)
    local cityDef = CityConfig.GetCity(cityId)
    if not cityDef then
        return false, "Invalid city ID: " .. tostring(cityId)
    end

    if player then
        local unlocked, reason = CityService.IsCityUnlocked(player, cityId)
        if not unlocked then
            return false, reason or "City is locked!"
        end
    end

    -- Security check: do not switch if current city has active incomplete run with damage
    if cityId ~= activeCityName and not currentRun.CityCompleted and currentRun.TotalDamage > 0 then
        return false, "Cannot switch cities during an active destruction run! Rebuild or finish first."
    end

    activeCityName = cityId
    CityService.RegisterCity(cityId)

    -- Reset DestructionService state
    local dest = getDestructionService()
    if dest and type(dest.ClearCollapsingBuildings) == "function" then
        dest.ClearCollapsingBuildings()
    end

    -- Reset run statistics
    resetRun(cityId)

    -- Teleport player(s) to new city spawn
    local spawnPos = cityDef.SpawnPosition
    if player and player.Character and player.Character.PrimaryPart then
        player.Character:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 4, 0)))
    else
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character and p.Character.PrimaryPart then
                p.Character:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 4, 0)))
            end
        end
    end

    local stats = CityService.GetCityStats()
    print(string.format("[CityService] ✅ Successfully loaded city '%s' (%d buildings, Total HP: %d)",
        cityId, stats.TotalBuildings, stats.TotalHealth))

    -- Broadcast to clients
    CityFeedbackRemote:FireAllClients("CityLoaded", {
        CityId = cityId,
        CityName = cityDef.DisplayName,
        SpawnPosition = spawnPos,
        Stats = stats,
    })
    CityFeedbackRemote:FireAllClients("CityProgressUpdate", stats)
    if cityDef.LightingProfile then
        CityFeedbackRemote:FireAllClients("CityLightingChanged", cityDef.LightingProfile)
    end

    for _, p in ipairs(Players:GetPlayers()) do
        CityFeedbackRemote:FireClient(p, "CityListSync", CityService.GetAvailableCities(p))
    end

    return true, "City Loaded"
end

function CityService.ReturnToHub(player: Player): (boolean, string)
    local hub = Workspace:FindFirstChild("KaijuHub")
    local hubSpawn = hub and hub:FindFirstChild("HubSpawnLocation", true)
    if not hubSpawn or not hubSpawn:IsA("BasePart") then
        return false, "Kaiju Hub spawn not found!"
    end

    if player.Character and player.Character.PrimaryPart then
        player.Character:PivotTo(hubSpawn.CFrame + Vector3.new(0, 8, 0))
        local hubLighting = CityConfig.GetLightingProfile("KaijuHub")
        if hubLighting then
            CityFeedbackRemote:FireClient(player, "CityLightingChanged", hubLighting)
        end
        return true, "Returned to Kaiju Hub"
    end
    return false, "Player character not found"
end

function CityService.GetAllBuildings(): { Model }
    ensureInitialized()
    local models: { Model } = {}
    for _, entry in ipairs(buildingList) do
        table.insert(models, entry.Model)
    end
    return models
end

function CityService.GetBuildingById(buildingId: string): Model?
    ensureInitialized()
    local entry = buildingsById[buildingId]
    return if entry then entry.Model else nil
end

function CityService.GetBuildingEntry(building: Model): BuildingEntry?
    ensureInitialized()
    local bId = building:GetAttribute("BuildingId") or building.Name
    return buildingsById[tostring(bId)]
end

function CityService.GetBuildingsInRadius(origin: Vector3, radius: number): { { Building: Model, Entry: BuildingEntry, Distance: number } }
    ensureInitialized()
    local results = {}
    local rSq = radius * radius

    for _, entry in ipairs(buildingList) do
        if not entry.IsDestroyed and entry.PrimaryPart then
            local distSq = (entry.Position.X - origin.X) ^ 2 + (entry.Position.Z - origin.Z) ^ 2
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

    -- Include KaijuHub training pillars if within radius
    local hub = Workspace:FindFirstChild("KaijuHub")
    if hub then
        for _, child in ipairs(hub:GetDescendants()) do
            if child:GetAttribute("IsTrainingDummy") == true then
                local part = if child:IsA("BasePart") then child else child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
                if part then
                    local distSq = (part.Position.X - origin.X) ^ 2 + (part.Position.Z - origin.Z) ^ 2
                    if distSq <= rSq then
                        local curHp = child:GetAttribute("CurrentHealth") or 10000
                        local maxHp = child:GetAttribute("MaxHealth") or 10000
                        local dummyEntry: BuildingEntry = {
                            Model = child :: any,
                            Id = child.Name,
                            Name = tostring(child:GetAttribute("BuildingName") or child.Name),
                            Type = "TrainingPillar",
                            MaxHealth = maxHp,
                            CurrentHealth = curHp,
                            Reward = 0,
                            Points = 10,
                            Tier = 1,
                            Position = part.Position,
                            PrimaryPart = part,
                            Structure = nil,
                            MainBody = part,
                            Roof = nil,
                            WindowParts = {},
                            PropParts = {},
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
    Returns live statistics computed directly from the active building state.
]=]
function CityService.GetCityStats(): CityStats
    ensureInitialized()
    local totalHP = 0
    local curHP = 0
    local activeCount = 0
    local destroyedCount = 0

    for _, entry in ipairs(buildingList) do
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

    local totalBuildings = #buildingList
    local destructionPct = if totalHP > 0 then math.clamp(math.floor((1 - (curHP / totalHP)) * 100), 0, 100) else 0
    local completionPct = if totalBuildings > 0 then math.clamp(math.floor((destroyedCount / totalBuildings) * 100), 0, 100) else 0

    return {
        CityName = activeCityName,
        TotalBuildings = totalBuildings,
        ActiveBuildings = activeCount,
        DestroyedBuildings = destroyedCount,
        TotalHealth = totalHP,
        CurrentHealth = curHP,
        DestructionPercentage = destructionPct,
        CityCompletionPercentage = completionPct,
        RunStartTime = currentRun.RunStartTime,
        RunEndTime = currentRun.RunEndTime,
        HighestCombo = currentRun.HighestCombo,
        CityCompleted = currentRun.CityCompleted,
    }
end

function CityService.GetRunStats(): CityRunStats
    return currentRun
end

--[=[
    Records incoming structural damage during the active run.
]=]
function CityService.RecordDamage(amount: number, buildingId: string?)
    currentRun.TotalDamage += math.max(0, amount)
    if buildingId and not runDamagedBuildingIds[buildingId] then
        runDamagedBuildingIds[buildingId] = true
        currentRun.BuildingsDamaged += 1
    end
end

--[=[
    Records ability usage during the active run.
]=]
function CityService.RecordAbilityUsed(player: Player?, abilityName: string)
    if currentRun.CityCompleted then return end
    if abilityName == "BasicAttack" or abilityName == "TailSweep" or abilityName == "NeckStrike" then
        currentRun.BasicAttacks += 1
    elseif abilityName == "Stomp" or abilityName == "HeavyStomp" then
        currentRun.Stomps += 1
    elseif abilityName == "Roar" then
        currentRun.Roars += 1
    end
end

--[=[
    Calculates destruction run score using the formal scoring model:
    Base (Points + 10% Damage) + Combo Bonus + Speed Bonus + Completion Bonus.
]=]
function CityService.CalculateDestructionScore(cityId: string, run: CityRunStats): (number, number, number, number, number)
    local targetTime = if cityId == "Metrovale" then 240 else 120
    local completionBonus = if cityId == "Metrovale" then 15000 else 5000

    local baseScore = run.BuildingsPoints + math.floor(run.TotalDamage * 0.1)
    local comboBonus = math.floor(run.HighestCombo * 1500)
    local speedBonus = math.max(0, math.floor((targetTime - run.Duration) * 50))
    local totalScore = math.max(0, math.floor(baseScore + comboBonus + speedBonus + completionBonus))

    return totalScore, baseScore, comboBonus, speedBonus, completionBonus
end

--[=[
    Records a building destruction event, updates run statistics, and checks completion.
]=]
function CityService.RecordDestruction(player: Player?, building: Model, cash: number, points: number, xp: number, combo: number)
    currentRun.BuildingsDestroyed += 1
    currentRun.BuildingsCash += math.max(0, cash)
    currentRun.BuildingsPoints += math.max(0, points)
    currentRun.BuildingsXP += math.max(0, xp)

    if combo > currentRun.HighestCombo then
        currentRun.HighestCombo = combo
    end

    local stats = CityService.GetCityStats()

    -- Broadcast live city progress update to all clients
    CityFeedbackRemote:FireAllClients("CityProgressUpdate", stats)

    -- Check for city completion transition
    if stats.DestroyedBuildings >= stats.TotalBuildings and not currentRun.CityCompleted then
        CityService.TriggerCityCompletion(player)
    end
end

--[=[
    Triggers server-authoritative city completion when all buildings are destroyed.
]=]
function CityService.TriggerCityCompletion(triggeringPlayer: Player?)
    if currentRun.CityCompleted then return end
    currentRun.CityCompleted = true
    currentRun.RunEndTime = os.clock()

    local cityDef = CityConfig[activeCityName]
    local completionReward = if cityDef then cityDef.CompletionReward else { Cash = 5000, DestructionPoints = 2500, XP = 2000 }

    print(string.format("[CityService] 🏆 CITY DESTROYED! All %d buildings in '%s' flattened! Awarding completion bonuses...", #buildingList, activeCityName))

    -- Award completion reward exactly once via ProgressionService
    if not currentRun.CompletionAwarded then
        currentRun.CompletionAwarded = true
        if ProgressionService then
            for _, player in ipairs(Players:GetPlayers()) do
                ProgressionService.AddRewards(player, completionReward.Cash, completionReward.DestructionPoints, completionReward.XP)
                print(string.format("[CityService] Awarded City Completion Bonus to %s: +$%d Cash, +%d Pts, +%d XP",
                    player.Name, completionReward.Cash, completionReward.DestructionPoints, completionReward.XP))
            end
        end
    end

    local duration = math.max(1, math.floor(currentRun.RunEndTime - currentRun.RunStartTime))
    currentRun.Duration = duration
    local bpm = math.floor((currentRun.BuildingsDestroyed / (duration / 60)) * 10) / 10
    currentRun.BuildingsPerMinute = bpm

    local totalScore, baseScore, comboBonus, speedBonus, completionScoreBonus = CityService.CalculateDestructionScore(activeCityName, currentRun)
    currentRun.DestructionScore = totalScore

    local totalCash = currentRun.BuildingsCash + completionReward.Cash
    local totalPoints = currentRun.BuildingsPoints + completionReward.DestructionPoints
    local totalXP = currentRun.BuildingsXP + completionReward.XP

    currentRun.CompletionCash = completionReward.Cash
    currentRun.CompletionPoints = completionReward.DestructionPoints
    currentRun.CompletionXP = completionReward.XP
    currentRun.TotalCash = totalCash
    currentRun.TotalPoints = totalPoints
    currentRun.TotalXP = totalXP

    -- Record completion count per player & update persistent profile
    local isNewBestTimeMap: { [number]: boolean } = {}
    local isNewBestComboMap: { [number]: boolean } = {}
    local isNewBestScoreMap: { [number]: boolean } = {}
    local isNewBestBpmMap: { [number]: boolean } = {}

    for _, p in ipairs(Players:GetPlayers()) do
        local comps = playerCityCompletions[p.UserId]
        if not comps then
            comps = { SmallTown = 0, Metrovale = 0 }
            playerCityCompletions[p.UserId] = comps
        end
        comps[activeCityName] = (comps[activeCityName] or 0) + 1

        PlayerDataService.UpdateProfile(p, function(prof)
            if not prof.Cities[activeCityName] then
                prof.Cities[activeCityName] = {
                    Unlocked = true,
                    Clears = 0,
                    BestTime = nil,
                    BestCombo = 0,
                    BestScore = 0,
                    BestBuildingsPerMinute = 0,
                }
            end
            local cityData = prof.Cities[activeCityName]
            cityData.Clears += 1

            local isNewTime = not cityData.BestTime or duration < cityData.BestTime
            local isNewCombo = currentRun.HighestCombo > (cityData.BestCombo or 0)
            local isNewScore = totalScore > (cityData.BestScore or 0)
            local isNewBpm = bpm > (cityData.BestBuildingsPerMinute or 0)

            isNewBestTimeMap[p.UserId] = isNewTime
            isNewBestComboMap[p.UserId] = isNewCombo
            isNewBestScoreMap[p.UserId] = isNewScore
            isNewBestBpmMap[p.UserId] = isNewBpm

            if isNewTime then
                cityData.BestTime = duration
            end
            if isNewCombo then
                cityData.BestCombo = currentRun.HighestCombo
            end
            if isNewScore then
                cityData.BestScore = totalScore
            end
            if isNewBpm then
                cityData.BestBuildingsPerMinute = bpm
            end

            -- Update persistent lifetime statistics
            if prof.Statistics then
                local stats = prof.Statistics
                stats.TotalBuildingsDestroyed += currentRun.BuildingsDestroyed
                stats.TotalDamageDealt += currentRun.TotalDamage
                stats.TotalCitiesCompleted += 1
                stats.TotalRunsCompleted += 1
                stats.TotalCashEarned += totalCash
                stats.TotalPointsEarned += totalPoints
                stats.TotalXPEarned += totalXP
                if currentRun.HighestCombo > stats.HighestCombo then
                    stats.HighestCombo = currentRun.HighestCombo
                end
                stats.TotalPlayTime += duration
            end

            -- Automatically unlock Metrovale if player meets requirements
            if prof.Cities.Metrovale and not prof.Cities.Metrovale.Unlocked then
                if prof.Level >= 4 and prof.Cities.SmallTown.Clears >= 1 then
                    prof.Cities.Metrovale.Unlocked = true
                end
            end
        end)
    end

    if triggeringPlayer then
        local comps = playerCityCompletions[triggeringPlayer.UserId]
        print(string.format("[CityService] %s now has %d completions for '%s'",
            triggeringPlayer.Name, comps and comps[activeCityName] or 1, activeCityName))
    end

    -- Update session best records
    local rec = cityBestRecords[activeCityName]
    if not rec then
        rec = { BestTime = 0, BestCombo = 1, BestScore = 0, BestBPM = 0 }
        cityBestRecords[activeCityName] = rec
    end
    if rec.BestTime == 0 or duration < rec.BestTime then
        rec.BestTime = duration
        print(string.format("[CityService] ⏱️ New Best Time for '%s': %ds!", activeCityName, duration))
    end
    if currentRun.HighestCombo > rec.BestCombo then
        rec.BestCombo = currentRun.HighestCombo
        print(string.format("[CityService] 🔥 New Best Combo for '%s': %dx!", activeCityName, rec.BestCombo))
    end
    if totalScore > rec.BestScore then
        rec.BestScore = totalScore
        print(string.format("[CityService] 🌟 New Best Destruction Score for '%s': %d pts!", activeCityName, totalScore))
    end
    if bpm > rec.BestBPM then
        rec.BestBPM = bpm
        print(string.format("[CityService] ⚡ New Best BPM for '%s': %.1f!", activeCityName, bpm))
    end

    -- Check if Metrovale unlocked for any player
    for _, p in ipairs(Players:GetPlayers()) do
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

    -- Construct and broadcast personalized completion payload per client
    for _, p in ipairs(Players:GetPlayers()) do
        local prof = PlayerDataService.GetProfile(p)
        local cityData = if prof and prof.Cities then prof.Cities[activeCityName] else nil

        local completionPayload = {
            CityName = activeCityName,
            TotalBuildings = #buildingList,
            DestroyedBuildings = #buildingList,
            CityCompletionPercentage = 100,
            Duration = duration,
            HighestCombo = currentRun.HighestCombo,
            TotalDamage = currentRun.TotalDamage,
            BuildingsDestroyed = currentRun.BuildingsDestroyed,
            BuildingsDamaged = currentRun.BuildingsDamaged,
            BasicAttacks = currentRun.BasicAttacks,
            Stomps = currentRun.Stomps,
            Roars = currentRun.Roars,
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
            BuildingsCash = currentRun.BuildingsCash,
            BuildingsPoints = currentRun.BuildingsPoints,
            BuildingsXP = currentRun.BuildingsXP,
            CompletionCash = completionReward.Cash,
            CompletionPoints = completionReward.DestructionPoints,
            CompletionXP = completionReward.XP,
            TotalCash = totalCash,
            TotalPoints = totalPoints,
            TotalXP = totalXP,
        }

        CityFeedbackRemote:FireClient(p, "CityCompleted", completionPayload)
    end
end

--[=[
    Restores all original 15 buildings to full health and pristine visual state, resets run statistics, and starts a new run.
]=]
function CityService.ResetCity(requestingPlayer: Player?): (boolean, string)
    ensureInitialized()

    local stats = CityService.GetCityStats()
    local isCompleted = currentRun.CityCompleted or (stats.DestroyedBuildings >= stats.TotalBuildings and stats.TotalBuildings > 0)
    local monService = getMonetizationService()
    local hasInstantRebuild = if requestingPlayer and monService then monService.HasInstantRebuild(requestingPlayer) else false

    -- Security validation: only allow rebuilding if city is completed (or player has InstantRebuild gamepass)
    if requestingPlayer and not isCompleted and not hasInstantRebuild then
        warn(string.format("[CityService] Rejected rebuild request from %s: City is not yet completed!", requestingPlayer.Name))
        return false, "City is not completed"
    end

    print(string.format("[CityService] Rebuilding '%s'... Restoring %d buildings.", activeCityName, #buildingList))

    -- 1. Restore all buildings
    for _, entry in ipairs(buildingList) do
        local bld = entry.Model
        local backup = entry.VisualBackup

        -- Remove any rubble parts
        local rubble = bld:FindFirstChild("Rubble")
        if rubble then
            rubble:Destroy()
        end

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

        -- Restore Windows
        for _, winPart in ipairs(backup.WindowParts) do
            if winPart and winPart.Parent then
                winPart.Transparency = 0.4
                winPart.CanCollide = true
            end
        end

        -- Restore Props
        for _, propPart in ipairs(backup.PropParts) do
            if propPart and propPart.Parent then
                propPart.Transparency = 0
                propPart.CanCollide = true
            end
        end

        -- Reset attributes and entry health
        entry.CurrentHealth = entry.MaxHealth
        entry.IsDestroyed = false
        bld:SetAttribute("CurrentHealth", entry.MaxHealth)
        bld:SetAttribute("IsDestroyed", false)
    end

    -- 2. Reset DestructionService state
    local dest = getDestructionService()
    if dest and type(dest.ClearCollapsingBuildings) == "function" then
        dest.ClearCollapsingBuildings()
    end

    -- 3. Reset run statistics
    resetRun(activeCityName)

    local newStats = CityService.GetCityStats()

    -- 4. Broadcast city reset to all clients
    CityFeedbackRemote:FireAllClients("CityReset", newStats)

    local cityDef = CityConfig.GetCity(activeCityName)
    if requestingPlayer and requestingPlayer.Character and requestingPlayer.Character.PrimaryPart and cityDef then
        requestingPlayer.Character:PivotTo(CFrame.new(cityDef.SpawnPosition + Vector3.new(0, 4, 0)))
    end

    print(string.format("[CityService] ✅ City '%s' completely reconstructed! New run timer started.", activeCityName))

    return true, "City Rebuilt"
end

--[=[
    Applies health reduction to the indexed building entry and updates building attributes.
]=]
function CityService.ApplyDamage(buildingModel: Model, damage: number, attacker: Player?): (boolean, number)
    ensureInitialized()

    -- Special handling for KaijuHub Training Pillars
    if buildingModel:GetAttribute("IsTrainingDummy") == true then
        local maxHp = tonumber(buildingModel:GetAttribute("MaxHealth")) or 10000
        local curHp = tonumber(buildingModel:GetAttribute("CurrentHealth")) or maxHp
        local actualDamage = math.min(curHp, math.max(1, damage))
        local newHp = curHp - actualDamage
        if newHp <= 1000 then
            newHp = maxHp -- Instantly refresh practice pillar health
        end
        buildingModel:SetAttribute("CurrentHealth", newHp)
        return true, actualDamage
    end

    local entry = CityService.GetBuildingEntry(buildingModel)
    if not entry or entry.IsDestroyed then
        return false, 0
    end

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

function CityService.RepairCity()
    CityService.ResetCity(nil)
end

return CityService
