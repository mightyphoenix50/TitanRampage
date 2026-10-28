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

export type AtmosphereSettings = {
    Density: number,
    Offset: number,
    Color: Color3,
    Decay: Color3,
    Glare: number,
    Haze: number,
}

export type BloomSettings = {
    Intensity: number,
    Size: number,
    Threshold: number,
}

export type ColorCorrectionSettings = {
    Brightness: number,
    Contrast: number,
    Saturation: number,
    TintColor: Color3,
}

export type LightingProfile = {
    ClockTime: number,
    Brightness: number,
    OutdoorAmbient: Color3,
    Ambient: Color3,
    ShadowSoftness: number,
    Atmosphere: AtmosphereSettings,
    Bloom: BloomSettings,
    ColorCorrection: ColorCorrectionSettings,
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
    LightingProfile: LightingProfile,
}

export type CityConfigType = {
    Cities: { [string]: CityDefinition },
    DisplayOrder: { string },
    GetCity: (cityId: string) -> CityDefinition?,
    GetCityList: () -> { CityDefinition },
    GetLightingProfile: (zoneId: string) -> LightingProfile?,
}

local HubLightingProfile: LightingProfile = {
    ClockTime = 18.25,
    Brightness = 2.2, -- Enhanced illumination for massive sanctuary vista
    OutdoorAmbient = Color3.fromRGB(110, 75, 70), -- Clear ambient shadow illumination
    Ambient = Color3.fromRGB(85, 60, 58),
    ShadowSoftness = 0.2,
    Atmosphere = {
        Density = 0.28,
        Offset = 0.25,
        Color = Color3.fromRGB(195, 95, 55),
        Decay = Color3.fromRGB(65, 30, 25),
        Glare = 0.45,
        Haze = 1.6,
    },
    Bloom = {
        Intensity = 0.70,
        Size = 24,
        Threshold = 1.1,
    },
    ColorCorrection = {
        Brightness = 0.03,
        Contrast = 0.14,
        Saturation = 0.20,
        TintColor = Color3.fromRGB(255, 245, 238),
    },
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
        LightingProfile = {
            ClockTime = 14.2, -- Bright, clear sunny afternoon
            Brightness = 2.4,
            OutdoorAmbient = Color3.fromRGB(125, 130, 135), -- Clear, bright shadows
            Ambient = Color3.fromRGB(80, 80, 85),
            ShadowSoftness = 0.2,
            Atmosphere = {
                Density = 0.26,
                Offset = 0.2,
                Color = Color3.fromRGB(195, 220, 255), -- Coastal sky blue
                Decay = Color3.fromRGB(100, 140, 190),
                Glare = 0.3,
                Haze = 0.8,
            },
            Bloom = {
                Intensity = 0.5,
                Size = 18,
                Threshold = 1.2,
            },
            ColorCorrection = {
                Brightness = 0.0,
                Contrast = 0.08,
                Saturation = 0.12,
                TintColor = Color3.fromRGB(255, 255, 255),
            },
        },
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
        LightingProfile = {
            ClockTime = 16.5, -- High-stakes metropolitan golden hour
            Brightness = 2.2,
            OutdoorAmbient = Color3.fromRGB(115, 110, 120),
            Ambient = Color3.fromRGB(75, 70, 80),
            ShadowSoftness = 0.2,
            Atmosphere = {
                Density = 0.34,
                Offset = 0.25,
                Color = Color3.fromRGB(220, 170, 130), -- Warm amber city haze
                Decay = Color3.fromRGB(120, 70, 50),
                Glare = 0.5,
                Haze = 1.4,
            },
            Bloom = {
                Intensity = 0.6,
                Size = 22,
                Threshold = 1.15,
            },
            ColorCorrection = {
                Brightness = 0.02,
                Contrast = 0.12,
                Saturation = 0.15,
                TintColor = Color3.fromRGB(255, 245, 240),
            },
        },
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
            if def then table.insert(list, def) end
        end
        return list
    end,

    GetLightingProfile = function(zoneId: string): LightingProfile?
        if zoneId == "KaijuHub" then return HubLightingProfile end
        local city = Cities[zoneId]
        return if city then city.LightingProfile else nil
    end,
}

-- Support table indexing syntax: CityConfig["SmallTown"] or CityConfig.SmallTown
setmetatable(CityConfig, {
    __index = function(tbl, key)
        if Cities[key] then return Cities[key] end
        return rawget(tbl, key)
    end,
})

return CityConfig
