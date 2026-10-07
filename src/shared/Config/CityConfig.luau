--!strict
--[[
    CityConfig.luau
    Central configuration for cities, progression unlock requirements, and completion rewards in Titan Rampage.
--]]

export type CityReward = {
    Cash: number,
    DestructionPoints: number,
    XP: number,
}

export type UnlockRequirements = {
    UnlockedByDefault: boolean,
    RequiredLevel: number?,
    RequiredSmallTownClears: number?,
}

export type CityBounds = {
    Center: Vector3,
    Size: Vector3,
}

export type CityDefinition = {
    CityId: string,
    DisplayName: string,
    Description: string,
    Difficulty: number,
    RecommendedLevel: number,
    UnlockRequirements: UnlockRequirements,
    CompletionReward: CityReward,
    TotalBuildings: number,
    TargetTotalHP: number,
    CityBounds: CityBounds,
    SpawnPosition: Vector3,
}

export type CityConfigType = {
    Cities: { [string]: CityDefinition },
    DisplayOrder: { string },
    GetCity: (cityId: string) -> CityDefinition?,
    GetCityList: () -> { CityDefinition },
}

local Cities: { [string]: CityDefinition } = {
    SmallTown = {
        CityId = "SmallTown",
        DisplayName = "SmallTown",
        Description = "A quiet coastal municipality now facing colossal titan devastation.",
        Difficulty = 1,
        RecommendedLevel = 1,
        UnlockRequirements = {
            UnlockedByDefault = true,
            RequiredLevel = 1,
            RequiredSmallTownClears = 0,
        },
        CompletionReward = {
            Cash = 1000,
            DestructionPoints = 500,
            XP = 500,
        },
        TotalBuildings = 15,
        TargetTotalHP = 16410,
        CityBounds = {
            Center = Vector3.new(0, 15, 140),
            Size = Vector3.new(270, 80, 252),
        },
        SpawnPosition = Vector3.new(0, 5, 0),
    },

    Metrovale = {
        CityId = "Metrovale",
        DisplayName = "Metrovale",
        Description = "A dense modern metropolis of towering corporate skyscrapers, transit boulevards, and civic landmarks.",
        Difficulty = 2,
        RecommendedLevel = 5,
        UnlockRequirements = {
            UnlockedByDefault = false,
            RequiredLevel = 5,
            RequiredSmallTownClears = 2,
        },
        CompletionReward = {
            Cash = 2500,
            DestructionPoints = 1250,
            XP = 1500,
        },
        TotalBuildings = 27,
        TargetTotalHP = 53380,
        CityBounds = {
            Center = Vector3.new(1200, 40, 200),
            Size = Vector3.new(360, 160, 380),
        },
        SpawnPosition = Vector3.new(1200, 5, -20),
    },
}

local DisplayOrder: { string } = {
    "SmallTown",
    "Metrovale",
}

local CityConfig = {
    Cities = Cities,
    DisplayOrder = DisplayOrder,

    GetCity = function(cityId: string): CityDefinition?
        return Cities[cityId]
    end,

    GetCityList = function(): { CityDefinition }
        local list: { CityDefinition } = {}
        for _, id in ipairs(DisplayOrder) do
            local def = Cities[id]
            if def then
                table.insert(list, def)
            end
        end
        return list
    end,
}

-- Support table indexing syntax: CityConfig["SmallTown"] or CityConfig.SmallTown
setmetatable(CityConfig, {
    __index = function(tbl, key)
        if Cities[key] then
            return Cities[key]
        end
        return rawget(tbl, key)
    end,
})

return CityConfig

