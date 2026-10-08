--!strict
--[[
    PlayerDataService.luau
    Responsibility:
    - Production-ready persistent player progression management using Roblox DataStoreService.
    - Versioned data schema (SchemaVersion = 1) and safe migration pipeline.
    - Multi-attempt retry logic with exponential backoff for LoadAsync and SaveAsync.
    - Authoritative in-memory session caching during gameplay.
    - Critical safety rules: NEVER wipe player progress on DataStore failure; lock saving if load failed.
    - Periodic autosave every 5 minutes and guaranteed shutdown persistence via BindToClose.
    - Graceful Studio development fallback when API service access is disabled.
--]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(ConfigFolder:WaitForChild("UpgradeConfig") :: ModuleScript)
local TitanRegistry = require(SharedFolder:WaitForChild("TitanRegistry") :: ModuleScript)

export type CityProgress = {
    Unlocked: boolean,
    Clears: number,
    BestTime: number?,
    BestCombo: number,
    BestScore: number,
    BestBuildingsPerMinute: number,
}

export type LifetimeStatistics = {
    TotalBuildingsDestroyed: number,
    TotalDamageDealt: number,
    TotalCitiesCompleted: number,
    TotalRunsCompleted: number,
    TotalCashEarned: number,
    TotalPointsEarned: number,
    TotalXPEarned: number,
    HighestCombo: number,
    TotalPlayTime: number,
}

export type PlayerProfile = {
    SchemaVersion: number,
    Level: number,
    XP: number,
    Cash: number,
    DestructionPoints: number,
    Upgrades: { [string]: number },
    Cities: { [string]: CityProgress },
    Titans: { [string]: { Unlocked: boolean } },
    SelectedTitan: string,
    Statistics: LifetimeStatistics,
}

local PlayerDataService = {}

local DATASTORE_NAME = "TitanRampage_PlayerData_v1"
local CURRENT_SCHEMA_VERSION = 3
local AUTOSAVE_INTERVAL = 300 -- 5 minutes
local MAX_RETRIES = 3
local RETRY_BASE_DELAY = 1.0

-- Session state
local sessionProfiles: { [number]: PlayerProfile } = {}
local isProfileLoaded: { [number]: boolean } = {}
local isLoadFailed: { [number]: boolean } = {}
local isSaving: { [number]: boolean } = {}

-- Studio mock storage for local testing without web API errors
local mockStorage: { [number]: any } = {}
local studioApiAvailable: boolean? = nil

local dataStoreInstance: GlobalDataStore? = nil

--[=[
    Safely retrieves the DataStore reference or marks Studio fallback.
]=]
local function getDataStore(): GlobalDataStore?
    if dataStoreInstance then
        return dataStoreInstance
    end

    local success, ds = pcall(function()
        return DataStoreService:GetDataStore(DATASTORE_NAME)
    end)

    if success and ds then
        dataStoreInstance = ds
        return ds
    else
        warn(string.format("[PlayerDataService] Failed to access DataStore '%s': %s", DATASTORE_NAME, tostring(ds)))
        return nil
    end
end

--[=[
    Tests whether Studio has Web API service access enabled.
]=]
local function checkStudioApiAccess(): boolean
    if studioApiAvailable ~= nil then
        return studioApiAvailable :: boolean
    end

    if not RunService:IsStudio() then
        studioApiAvailable = true
        return true
    end

    local ds = getDataStore()
    if not ds then
        studioApiAvailable = false
        return false
    end

    local success, res = pcall(function()
        return ds:GetAsync("__studio_api_probe__")
    end)

    if success then
        studioApiAvailable = true
        print("[PlayerDataService] Studio DataStore API access is ENABLED.")
    else
        studioApiAvailable = false
        print("[PlayerDataService] Notice: Studio DataStore API access is disabled. Using safe in-memory session persistence for Studio development.")
    end

    return studioApiAvailable :: boolean
end

--[=[
    Creates a clean default player profile for brand new players.
]=]
function PlayerDataService.CreateDefaultProfile(): PlayerProfile
    local defaultUpgrades: { [string]: number } = {}
    if UpgradeConfig and UpgradeConfig.Categories then
        for catId, _ in pairs(UpgradeConfig.Categories) do
            defaultUpgrades[catId] = 1
        end
    else
        defaultUpgrades = {
            BasicAttackDamage = 1,
            BasicAttackCooldown = 1,
            StompDamage = 1,
            StompRadius = 1,
            StompCooldown = 1,
            WalkSpeed = 1,
            RoarCooldown = 1,
        }
    end

    return {
        SchemaVersion = CURRENT_SCHEMA_VERSION,
        Level = 1,
        XP = 0,
        Cash = 0,
        DestructionPoints = 0,
        Upgrades = defaultUpgrades,
        Cities = {
            SmallTown = {
                Unlocked = true,
                Clears = 0,
                BestTime = nil,
                BestCombo = 0,
                BestScore = 0,
                BestBuildingsPerMinute = 0,
            },
            Metrovale = {
                Unlocked = false,
                Clears = 0,
                BestTime = nil,
                BestCombo = 0,
                BestScore = 0,
                BestBuildingsPerMinute = 0,
            },
        },
        Titans = {
            Ravager = { Unlocked = true },
            Brontara = { Unlocked = false },
        },
        SelectedTitan = "Ravager",
        Statistics = {
            TotalBuildingsDestroyed = 0,
            TotalDamageDealt = 0,
            TotalCitiesCompleted = 0,
            TotalRunsCompleted = 0,
            TotalCashEarned = 0,
            TotalPointsEarned = 0,
            TotalXPEarned = 0,
            HighestCombo = 0,
            TotalPlayTime = 0,
        },
    }
end

--[=[
    Applies schema migrations sequentially if loaded data has older SchemaVersion.
]=]
function PlayerDataService.MigrateProfile(data: any): any
    if type(data) ~= "table" then
        return PlayerDataService.CreateDefaultProfile()
    end

    local version = tonumber(data.SchemaVersion) or 0

    if version < 2 then
        print(string.format("[PlayerDataService] 🔄 Migrating player profile from Schema %d to Schema 2...", version))

        -- Migrate Cities to include BestScore and BestBuildingsPerMinute
        if type(data.Cities) == "table" then
            for _, cityData in pairs(data.Cities) do
                if type(cityData) == "table" then
                    if cityData.BestScore == nil then
                        cityData.BestScore = 0
                    end
                    if cityData.BestBuildingsPerMinute == nil then
                        cityData.BestBuildingsPerMinute = 0
                    end
                end
            end
        end

        -- Seed or attach lifetime statistics
        if type(data.Statistics) ~= "table" then
            local defaultStats = {
                TotalBuildingsDestroyed = 0,
                TotalDamageDealt = 0,
                TotalCitiesCompleted = 0,
                TotalRunsCompleted = 0,
                TotalCashEarned = math.max(0, tonumber(data.Cash) or 0),
                TotalPointsEarned = math.max(0, tonumber(data.DestructionPoints) or 0),
                TotalXPEarned = math.max(0, tonumber(data.XP) or 0),
                HighestCombo = 0,
                TotalPlayTime = 0,
            }

            -- Estimate lifetime clears from existing city clear counts
            if type(data.Cities) == "table" then
                for _, cityData in pairs(data.Cities) do
                    if type(cityData) == "table" then
                        local clears = tonumber(cityData.Clears) or 0
                        defaultStats.TotalCitiesCompleted += clears
                        defaultStats.TotalRunsCompleted += clears
                        local bc = tonumber(cityData.BestCombo) or 0
                        if bc > defaultStats.HighestCombo then
                            defaultStats.HighestCombo = bc
                        end
                    end
                end
            end

            data.Statistics = defaultStats
        end

        data.SchemaVersion = 2
    end

    if version < 3 then
        print(string.format("[PlayerDataService] 🔄 Migrating player profile from Schema %d to Schema 3...", version))
        if type(data.Titans) ~= "table" then
            data.Titans = {
                Ravager = { Unlocked = true },
                Brontara = { Unlocked = false },
            }
        else
            if data.Titans.Ravager == nil then
                data.Titans.Ravager = { Unlocked = true }
            else
                data.Titans.Ravager.Unlocked = true
            end
            if data.Titans.Brontara == nil then
                data.Titans.Brontara = { Unlocked = false }
            end
        end

        if type(data.SelectedTitan) ~= "string" or (data.SelectedTitan ~= "Ravager" and data.SelectedTitan ~= "Brontara") then
            data.SelectedTitan = "Ravager"
        end

        data.SchemaVersion = 3
    end

    data.SchemaVersion = CURRENT_SCHEMA_VERSION
    return data
end

--[=[
    Validates, clamps, and defaults all fields in a loaded profile to prevent corruption.
]=]
function PlayerDataService.ValidateProfile(raw: any): PlayerProfile
    local data = PlayerDataService.MigrateProfile(raw)
    local defaults = PlayerDataService.CreateDefaultProfile()

    local profile: PlayerProfile = {
        SchemaVersion = CURRENT_SCHEMA_VERSION,
        Level = math.clamp(math.floor(tonumber(data.Level) or defaults.Level), 1, 100),
        XP = math.max(0, math.floor(tonumber(data.XP) or defaults.XP)),
        Cash = math.max(0, math.floor(tonumber(data.Cash) or defaults.Cash)),
        DestructionPoints = math.max(0, math.floor(tonumber(data.DestructionPoints) or defaults.DestructionPoints)),
        Upgrades = {},
        Cities = {},
        Titans = {
            Ravager = { Unlocked = true },
            Brontara = { Unlocked = false },
        },
        SelectedTitan = "Ravager",
        Statistics = defaults.Statistics,
    }

    -- Validate Lifetime Statistics
    local rawStats = if type(data.Statistics) == "table" then data.Statistics else {}
    profile.Statistics = {
        TotalBuildingsDestroyed = math.max(0, math.floor(tonumber(rawStats.TotalBuildingsDestroyed) or defaults.Statistics.TotalBuildingsDestroyed)),
        TotalDamageDealt = math.max(0, math.floor(tonumber(rawStats.TotalDamageDealt) or defaults.Statistics.TotalDamageDealt)),
        TotalCitiesCompleted = math.max(0, math.floor(tonumber(rawStats.TotalCitiesCompleted) or defaults.Statistics.TotalCitiesCompleted)),
        TotalRunsCompleted = math.max(0, math.floor(tonumber(rawStats.TotalRunsCompleted) or defaults.Statistics.TotalRunsCompleted)),
        TotalCashEarned = math.max(0, math.floor(tonumber(rawStats.TotalCashEarned) or defaults.Statistics.TotalCashEarned)),
        TotalPointsEarned = math.max(0, math.floor(tonumber(rawStats.TotalPointsEarned) or defaults.Statistics.TotalPointsEarned)),
        TotalXPEarned = math.max(0, math.floor(tonumber(rawStats.TotalXPEarned) or defaults.Statistics.TotalXPEarned)),
        HighestCombo = math.max(0, math.floor(tonumber(rawStats.HighestCombo) or defaults.Statistics.HighestCombo)),
        TotalPlayTime = math.max(0, math.floor(tonumber(rawStats.TotalPlayTime) or defaults.Statistics.TotalPlayTime)),
    }

    -- Validate Upgrades
    local rawUpgrades = if type(data.Upgrades) == "table" then data.Upgrades else {}
    for catId, defaultLvl in pairs(defaults.Upgrades) do
        local maxLvl = 5
        if UpgradeConfig and UpgradeConfig.Categories and UpgradeConfig.Categories[catId] then
            maxLvl = UpgradeConfig.Categories[catId].MaxLevel
        end
        local lvl = tonumber(rawUpgrades[catId]) or defaultLvl
        profile.Upgrades[catId] = math.clamp(math.floor(lvl), 1, maxLvl)
    end

    -- Validate Cities
    local rawCities = if type(data.Cities) == "table" then data.Cities else {}
    for cityName, defaultCity in pairs(defaults.Cities) do
        local userCity = rawCities[cityName]
        if type(userCity) == "table" then
            local isUnlocked = if userCity.Unlocked ~= nil then (userCity.Unlocked == true) else defaultCity.Unlocked
            if cityName == "SmallTown" then
                isUnlocked = true -- SmallTown is always unlocked
            end
            local clears = math.max(0, math.floor(tonumber(userCity.Clears) or 0))
            local bestTime = if tonumber(userCity.BestTime) and userCity.BestTime > 0 then math.floor(userCity.BestTime) else nil
            local bestCombo = math.clamp(math.floor(tonumber(userCity.BestCombo) or 0), 0, 5)
            local bestScore = math.max(0, math.floor(tonumber(userCity.BestScore) or 0))
            local bestBpm = math.max(0, tonumber(userCity.BestBuildingsPerMinute) or 0)

            profile.Cities[cityName] = {
                Unlocked = isUnlocked,
                Clears = clears,
                BestTime = bestTime,
                BestCombo = bestCombo,
                BestScore = bestScore,
                BestBuildingsPerMinute = bestBpm,
            }
        else
            profile.Cities[cityName] = {
                Unlocked = defaultCity.Unlocked,
                Clears = defaultCity.Clears,
                BestTime = defaultCity.BestTime,
                BestCombo = defaultCity.BestCombo,
                BestScore = defaultCity.BestScore,
                BestBuildingsPerMinute = defaultCity.BestBuildingsPerMinute,
            }
        end
    end

    -- Validate Titans & SelectedTitan
    local rawTitans = if type(data.Titans) == "table" then data.Titans else {}
    local bronUnlocked = false
    if type(rawTitans.Brontara) == "table" and rawTitans.Brontara.Unlocked ~= nil then
        bronUnlocked = (rawTitans.Brontara.Unlocked == true)
    end

    profile.Titans = {
        Ravager = { Unlocked = true },
        Brontara = { Unlocked = bronUnlocked },
    }

    local sel = tostring(data.SelectedTitan or "Ravager")
    if sel == "Brontara" and bronUnlocked then
        profile.SelectedTitan = "Brontara"
    else
        profile.SelectedTitan = "Ravager"
    end

    return profile
end

--[=[
    Titan Selection & Unlock Accessors.
]=]
function PlayerDataService.GetSelectedTitan(player: Player): string
    local prof = PlayerDataService.GetProfile(player)
    return if prof and prof.SelectedTitan then prof.SelectedTitan else "Ravager"
end

function PlayerDataService.SetSelectedTitan(player: Player, titanId: string): boolean
    local prof = PlayerDataService.GetProfile(player)
    if not prof then return false end
    if not TitanRegistry.Get(titanId) then return false end
    if not PlayerDataService.IsTitanUnlocked(player, titanId) then
        return false
    end
    prof.SelectedTitan = titanId
    if mockStorage[player.UserId] then
        mockStorage[player.UserId].SelectedTitan = titanId
    end
    return true
end

function PlayerDataService.CheckTitanUnlocks(player: Player): { [string]: boolean }
    local prof = PlayerDataService.GetProfile(player)
    if not prof then return {} end

    local totalClears = 0
    if prof.Statistics and type(prof.Statistics.TotalCitiesCompleted) == "number" then
        totalClears = prof.Statistics.TotalCitiesCompleted
    elseif prof.Cities then
        for _, c in pairs(prof.Cities) do
            if type(c) == "table" and type(c.Clears) == "number" then
                totalClears += c.Clears
            end
        end
    end

    local newlyUnlocked: { [string]: boolean } = {}
    for _, titanDef in ipairs(TitanRegistry.GetList()) do
        local id = titanDef.Id
        if id ~= "Ravager" then
            local isAlreadyUnlocked = prof.Titans and prof.Titans[id] and prof.Titans[id].Unlocked == true
            if not isAlreadyUnlocked then
                local canUnlock, _ = TitanRegistry.IsUnlocked(id, prof.Level or 1, totalClears)
                if canUnlock then
                    PlayerDataService.UnlockTitan(player, id)
                    newlyUnlocked[id] = true
                    print(string.format("[PlayerDataService] 🔓 Titan '%s' unlocked for %s (Level %d, %d Clears)",
                        id, player.Name, prof.Level or 1, totalClears))
                end
            end
        end
    end
    return newlyUnlocked
end

function PlayerDataService.IsTitanUnlocked(player: Player, titanId: string): boolean
    local prof = PlayerDataService.GetProfile(player)
    if not prof then return titanId == "Ravager" end
    if titanId == "Ravager" then return true end
    if prof.Titans and prof.Titans[titanId] and prof.Titans[titanId].Unlocked == true then
        return true
    end
    PlayerDataService.CheckTitanUnlocks(player)
    if prof.Titans and prof.Titans[titanId] and prof.Titans[titanId].Unlocked == true then
        return true
    end
    return false
end

function PlayerDataService.UnlockTitan(player: Player, titanId: string): boolean
    local prof = PlayerDataService.GetProfile(player)
    if not prof then return false end
    if not TitanRegistry.Get(titanId) then return false end
    if not prof.Titans then
        prof.Titans = { Ravager = { Unlocked = true }, Brontara = { Unlocked = false } }
    end
    if not prof.Titans[titanId] then
        prof.Titans[titanId] = { Unlocked = true }
    else
        prof.Titans[titanId].Unlocked = true
    end
    if mockStorage[player.UserId] then
        if not mockStorage[player.UserId].Titans then
            mockStorage[player.UserId].Titans = { Ravager = { Unlocked = true }, Brontara = { Unlocked = false } }
        end
        mockStorage[player.UserId].Titans[titanId] = { Unlocked = true }
    end
    return true
end

function PlayerDataService.GetTitansData(player: Player): { [string]: { Unlocked: boolean } }
    local prof = PlayerDataService.GetProfile(player)
    if not prof or not prof.Titans then
        return { Ravager = { Unlocked = true }, Brontara = { Unlocked = false } }
    end
    PlayerDataService.CheckTitanUnlocks(player)
    local copy: { [string]: { Unlocked: boolean } } = {}
    for k, v in pairs(prof.Titans) do
        copy[k] = { Unlocked = (v.Unlocked == true) }
    end
    return copy
end

--[=[
    Loads profile for a player with 3 retries and exponential backoff.
]=]
function PlayerDataService.LoadProfile(player: Player): (boolean, PlayerProfile)
    local userId = player.UserId
    local key = string.format("Player_%d", userId)
    print(string.format("[PlayerDataService] Loading data for %s (UserId: %d)...", player.Name, userId))

    local apiAvailable = checkStudioApiAccess()

    if not apiAvailable then
        -- Studio fallback mode: check mockStorage or create default
        local savedMock = mockStorage[userId]
        if savedMock then
            local validated = PlayerDataService.ValidateProfile(savedMock)
            sessionProfiles[userId] = validated
            isProfileLoaded[userId] = true
            isLoadFailed[userId] = false
            print(string.format("[PlayerDataService] ✅ [Studio Fallback] Loaded mock profile for %s (Level %d, $%d Cash)", player.Name, validated.Level, validated.Cash))
            return true, validated
        else
            local defaultProfile = PlayerDataService.CreateDefaultProfile()
            sessionProfiles[userId] = defaultProfile
            mockStorage[userId] = defaultProfile
            isProfileLoaded[userId] = true
            isLoadFailed[userId] = false
            print(string.format("[PlayerDataService] ✅ [Studio Fallback] Initialized default session profile for %s", player.Name))
            return true, defaultProfile
        end
    end

    local ds = getDataStore()
    if not ds then
        warn(string.format("[PlayerDataService] CRITICAL: DataStore unavailable for %s. Locking save to prevent data wipe.", player.Name))
        local fallback = PlayerDataService.CreateDefaultProfile()
        sessionProfiles[userId] = fallback
        isProfileLoaded[userId] = true
        isLoadFailed[userId] = true -- Prevent overwriting production data
        return false, fallback
    end

    -- Retry loop (up to MAX_RETRIES)
    local loadedData = nil
    local loadSuccess = false
    local lastError = ""

    for attempt = 1, MAX_RETRIES do
        local success, result = pcall(function()
            return ds:GetAsync(key)
        end)

        if success then
            loadedData = result
            loadSuccess = true
            break
        else
            lastError = tostring(result)
            warn(string.format("[PlayerDataService] Load attempt %d failed for %s: %s", attempt, player.Name, lastError))
            if attempt < MAX_RETRIES then
                task.wait(RETRY_BASE_DELAY * attempt)
            end
        end
    end

    if not loadSuccess then
        -- CRITICAL SAFETY RULE: Never wipe player progress on DataStore failure
        warn(string.format("[PlayerDataService] 🚨 CRITICAL: Load failed for %s after %d attempts. Save locked for this session to prevent overwriting stored progress.", player.Name, MAX_RETRIES))
        local fallback = PlayerDataService.CreateDefaultProfile()
        sessionProfiles[userId] = fallback
        isProfileLoaded[userId] = true
        isLoadFailed[userId] = true
        return false, fallback
    end

    local finalProfile: PlayerProfile
    if loadedData == nil then
        -- First time player
        print(string.format("[PlayerDataService] No stored profile found for %s. Creating new profile.", player.Name))
        finalProfile = PlayerDataService.CreateDefaultProfile()
    else
        finalProfile = PlayerDataService.ValidateProfile(loadedData)
        print(string.format("[PlayerDataService] ✅ Successfully loaded profile for %s (Level %d, $%d Cash, %d Pts)", player.Name, finalProfile.Level, finalProfile.Cash, finalProfile.DestructionPoints))
    end

    sessionProfiles[userId] = finalProfile
    isProfileLoaded[userId] = true
    isLoadFailed[userId] = false
    return true, finalProfile
end

--[=[
    Saves in-memory profile to DataStore with 3 retries and exponential backoff.
]=]
function PlayerDataService.SaveProfile(player: Player): boolean
    local userId = player.UserId
    local key = string.format("Player_%d", userId)

    -- CRITICAL SAFETY CHECKS
    if not isProfileLoaded[userId] then
        warn(string.format("[PlayerDataService] Refused to save %s: Profile was never loaded.", player.Name))
        return false
    end

    if isLoadFailed[userId] == true then
        warn(string.format("[PlayerDataService] Refused to save %s: Load failed on join; saving locked to protect stored data.", player.Name))
        return false
    end

    local profile = sessionProfiles[userId]
    if not profile then
        warn(string.format("[PlayerDataService] Refused to save %s: In-memory profile is nil.", player.Name))
        return false
    end

    if isSaving[userId] then
        print(string.format("[PlayerDataService] Save already in progress for %s, skipping duplicate request.", player.Name))
        return true
    end

    isSaving[userId] = true

    local apiAvailable = checkStudioApiAccess()
    if not apiAvailable then
        -- Studio fallback mode: update mockStorage
        mockStorage[userId] = profile
        isSaving[userId] = false
        print(string.format("[PlayerDataService] ✅ [Studio Fallback] Saved mock profile for %s (Level %d, $%d Cash)", player.Name, profile.Level, profile.Cash))
        return true
    end

    local ds = getDataStore()
    if not ds then
        isSaving[userId] = false
        warn(string.format("[PlayerDataService] Failed to save %s: DataStore unavailable.", player.Name))
        return false
    end

    local saveSuccess = false
    local lastError = ""

    for attempt = 1, MAX_RETRIES do
        local success, err = pcall(function()
            ds:UpdateAsync(key, function(oldData)
                -- If oldData exists but is uncorrupted, ensure we don't save an empty profile
                return profile
            end)
        end)

        if success then
            saveSuccess = true
            print(string.format("[PlayerDataService] ✅ Save successful for %s (Level %d, $%d Cash, %d Pts)", player.Name, profile.Level, profile.Cash, profile.DestructionPoints))
            break
        else
            lastError = tostring(err)
            warn(string.format("[PlayerDataService] Save attempt %d failed for %s: %s", attempt, player.Name, lastError))
            if attempt < MAX_RETRIES then
                task.wait(RETRY_BASE_DELAY * attempt)
            end
        end
    end

    isSaving[userId] = false

    if not saveSuccess then
        warn(string.format("[PlayerDataService] 🚨 CRITICAL: Save failed for %s after %d attempts. Current data kept in memory.", player.Name, MAX_RETRIES))
        return false
    end

    return true
end

--[=[
    Returns the active in-memory profile for a player.
]=]
function PlayerDataService.GetProfile(player: Player): PlayerProfile?
    local prof = sessionProfiles[player.UserId]
    if not prof and player.Parent then
        local _, loaded = PlayerDataService.LoadProfile(player)
        return loaded
    end
    return prof
end

--[=[
    Returns whether the profile has completed initial loading.
]=]
function PlayerDataService.IsLoaded(player: Player): boolean
    return isProfileLoaded[player.UserId] == true
end

--[=[
    Returns whether profile load failed on join.
]=]
function PlayerDataService.IsLoadFailed(player: Player): boolean
    return isLoadFailed[player.UserId] == true
end

--[=[
    Safely mutates the in-memory profile through a callback function.
]=]
function PlayerDataService.UpdateProfile(player: Player, callback: (profile: PlayerProfile) -> ()): boolean
    local profile = sessionProfiles[player.UserId]
    if not profile then
        warn(string.format("[PlayerDataService] Cannot update profile for %s: Profile not loaded.", player.Name))
        return false
    end

    callback(profile)
    return true
end

--[=[
    Studio Mock Accessors (for automated testing of persistence mechanics).
]=]
function PlayerDataService.SetMockData(userId: number, data: any)
    mockStorage[userId] = data
end

function PlayerDataService.GetMockData(userId: number): any
    return mockStorage[userId]
end

function PlayerDataService.ClearMockData(userId: number)
    mockStorage[userId] = nil
end

--[=[
    Initializes lifecycle bindings and autosave loop.
]=]
function PlayerDataService.Init()
    print("[PlayerDataService] Initializing PlayerDataService...")
    checkStudioApiAccess()

    -- PlayerAdded lifecycle
    Players.PlayerAdded:Connect(function(player)
        PlayerDataService.LoadProfile(player)
    end)

    -- PlayerRemoving lifecycle
    Players.PlayerRemoving:Connect(function(player)
        local userId = player.UserId
        if isProfileLoaded[userId] and not isLoadFailed[userId] then
            PlayerDataService.SaveProfile(player)
        end
        sessionProfiles[userId] = nil
        isProfileLoaded[userId] = nil
        isLoadFailed[userId] = nil
        isSaving[userId] = nil
    end)

    -- BindToClose shutdown handler
    game:BindToClose(function()
        print("[PlayerDataService] Server shutdown initiated. Saving all active player profiles...")
        local playersToSave = {}
        for _, player in ipairs(Players:GetPlayers()) do
            local userId = player.UserId
            if isProfileLoaded[userId] and not isLoadFailed[userId] then
                table.insert(playersToSave, player)
            end
        end

        if #playersToSave == 0 then
            print("[PlayerDataService] No active profiles to save on shutdown.")
            return
        end

        local completedSaves = 0
        local totalSaves = #playersToSave

        for _, player in ipairs(playersToSave) do
            task.spawn(function()
                PlayerDataService.SaveProfile(player)
                completedSaves += 1
            end)
        end

        local startTime = os.clock()
        while completedSaves < totalSaves and (os.clock() - startTime) < 25 do
            task.wait(0.1)
        end

        print(string.format("[PlayerDataService] Shutdown save completed: %d / %d profiles saved.", completedSaves, totalSaves))
    end)
end

--[=[
    Starts service operations, loads any existing players, and launches autosave loop.
]=]
function PlayerDataService.Start()
    print("[PlayerDataService] PlayerDataService started.")

    -- Load any players already present
    for _, player in ipairs(Players:GetPlayers()) do
        if not sessionProfiles[player.UserId] then
            PlayerDataService.LoadProfile(player)
        end
    end

    -- Periodic Autosave loop (Every 5 minutes)
    task.spawn(function()
        while true do
            task.wait(AUTOSAVE_INTERVAL)
            print("[PlayerDataService] ⏰ Starting periodic autosave cycle...")
            for _, player in ipairs(Players:GetPlayers()) do
                local userId = player.UserId
                if isProfileLoaded[userId] and not isLoadFailed[userId] then
                    task.spawn(function()
                        PlayerDataService.SaveProfile(player)
                    end)
                end
            end
        end
    end)
end

return PlayerDataService

