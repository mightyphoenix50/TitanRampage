--!strict
--[[
    UpgradeConfig.luau
    Central configuration for Titan Rampage Ravager upgrades.
    Defines 7 upgrade categories across 5 progressive levels, stat values, and currency costs.
--]]

export type UpgradeTier = {
    Level: number,
    Value: number,
    CashCost: number,
    PointCost: number,
}

export type UpgradeCategory = {
    Id: string,
    DisplayName: string,
    Description: string,
    Unit: string,
    Format: string,
    MaxLevel: number,
    Tiers: { [number]: UpgradeTier },
}

export type UpgradeConfigType = {
    Categories: { [string]: UpgradeCategory },
    DisplayOrder: { string },
    GetTier: (categoryId: string, level: number) -> UpgradeTier?,
    GetTierValue: (categoryId: string, level: number) -> number,
    GetNextTier: (categoryId: string, currentLevel: number) -> UpgradeTier?,
}

local Categories: { [string]: UpgradeCategory } = {
    BasicAttackDamage = {
        Id = "BasicAttackDamage",
        DisplayName = "Basic Attack Damage",
        Description = "Increases primary melee strike damage against structures.",
        Unit = "DMG",
        Format = "%d DMG",
        MaxLevel = 5,
        Tiers = {
            [1] = { Level = 1, Value = 150, CashCost = 0, PointCost = 0 },
            [2] = { Level = 2, Value = 190, CashCost = 400, PointCost = 200 },
            [3] = { Level = 3, Value = 240, CashCost = 1400, PointCost = 700 },
            [4] = { Level = 4, Value = 300, CashCost = 3800, PointCost = 2000 },
            [5] = { Level = 5, Value = 380, CashCost = 9500, PointCost = 5000 },
        },
    },

    BasicAttackCooldown = {
        Id = "BasicAttackCooldown",
        DisplayName = "Attack Speed",
        Description = "Reduces recovery delay between primary attacks.",
        Unit = "s",
        Format = "%.2fs cd",
        MaxLevel = 5,
        Tiers = {
            [1] = { Level = 1, Value = 0.78, CashCost = 0, PointCost = 0 },
            [2] = { Level = 2, Value = 0.68, CashCost = 400, PointCost = 200 },
            [3] = { Level = 3, Value = 0.58, CashCost = 1400, PointCost = 700 },
            [4] = { Level = 4, Value = 0.50, CashCost = 3800, PointCost = 2000 },
            [5] = { Level = 5, Value = 0.42, CashCost = 9500, PointCost = 5000 },
        },
    },

    StompDamage = {
        Id = "StompDamage",
        DisplayName = "Stomp Damage",
        Description = "Increases epicenter shockwave destruction from ground slams.",
        Unit = "DMG",
        Format = "%d DMG",
        MaxLevel = 5,
        Tiers = {
            [1] = { Level = 1, Value = 400, CashCost = 0, PointCost = 0 },
            [2] = { Level = 2, Value = 520, CashCost = 450, PointCost = 220 },
            [3] = { Level = 3, Value = 670, CashCost = 1500, PointCost = 750 },
            [4] = { Level = 4, Value = 850, CashCost = 4000, PointCost = 2100 },
            [5] = { Level = 5, Value = 1100, CashCost = 10000, PointCost = 5200 },
        },
    },

    StompRadius = {
        Id = "StompRadius",
        DisplayName = "Stomp Radius",
        Description = "Expands the devastation perimeter of the ground stomp.",
        Unit = "Studs",
        Format = "%d Studs",
        MaxLevel = 5,
        Tiers = {
            [1] = { Level = 1, Value = 30, CashCost = 0, PointCost = 0 },
            [2] = { Level = 2, Value = 35, CashCost = 400, PointCost = 200 },
            [3] = { Level = 3, Value = 42, CashCost = 1400, PointCost = 700 },
            [4] = { Level = 4, Value = 50, CashCost = 3800, PointCost = 2000 },
            [5] = { Level = 5, Value = 60, CashCost = 9500, PointCost = 5000 },
        },
    },

    StompCooldown = {
        Id = "StompCooldown",
        DisplayName = "Stomp Recharge",
        Description = "Reduces the cooldown delay between ground stomps.",
        Unit = "s",
        Format = "%.2fs cd",
        MaxLevel = 5,
        Tiers = {
            [1] = { Level = 1, Value = 5.00, CashCost = 0, PointCost = 0 },
            [2] = { Level = 2, Value = 4.50, CashCost = 450, PointCost = 220 },
            [3] = { Level = 3, Value = 4.00, CashCost = 1500, PointCost = 750 },
            [4] = { Level = 4, Value = 3.50, CashCost = 4000, PointCost = 2100 },
            [5] = { Level = 5, Value = 3.00, CashCost = 10000, PointCost = 5200 },
        },
    },

    WalkSpeed = {
        Id = "WalkSpeed",
        DisplayName = "Movement Speed",
        Description = "Accelerates your Titan's colossal stride pacing across the city.",
        Unit = "Speed",
        Format = "%d Speed",
        MaxLevel = 5,
        Tiers = {
            [1] = { Level = 1, Value = 28, CashCost = 0, PointCost = 0 },
            [2] = { Level = 2, Value = 31, CashCost = 350, PointCost = 180 },
            [3] = { Level = 3, Value = 34, CashCost = 1200, PointCost = 600 },
            [4] = { Level = 4, Value = 37, CashCost = 3200, PointCost = 1700 },
            [5] = { Level = 5, Value = 40, CashCost = 8500, PointCost = 4500 },
        },
    },

    RoarCooldown = {
        Id = "RoarCooldown",
        DisplayName = "Roar Recharge",
        Description = "Reduces the cooldown delay between thunderous roars.",
        Unit = "s",
        Format = "%.2fs cd",
        MaxLevel = 5,
        Tiers = {
            [1] = { Level = 1, Value = 8.00, CashCost = 0, PointCost = 0 },
            [2] = { Level = 2, Value = 7.00, CashCost = 350, PointCost = 180 },
            [3] = { Level = 3, Value = 6.00, CashCost = 1200, PointCost = 600 },
            [4] = { Level = 4, Value = 5.00, CashCost = 3200, PointCost = 1700 },
            [5] = { Level = 5, Value = 4.00, CashCost = 8500, PointCost = 4500 },
        },
    },
}

local DisplayOrder: { string } = {
    "BasicAttackDamage",
    "BasicAttackCooldown",
    "StompDamage",
    "StompRadius",
    "StompCooldown",
    "WalkSpeed",
    "RoarCooldown",
}

local UpgradeConfig: UpgradeConfigType = {
    Categories = Categories,
    DisplayOrder = DisplayOrder,

    GetTier = function(categoryId: string, level: number): UpgradeTier?
        local cat = Categories[categoryId]
        if not cat then return nil end
        local clamped = math.clamp(level, 1, cat.MaxLevel)
        return cat.Tiers[clamped]
    end,

    GetTierValue = function(categoryId: string, level: number): number
        local cat = Categories[categoryId]
        if not cat then return 0 end
        local clamped = math.clamp(level, 1, cat.MaxLevel)
        local tier = cat.Tiers[clamped]
        return if tier then tier.Value else 0
    end,

    GetNextTier = function(categoryId: string, currentLevel: number): UpgradeTier?
        local cat = Categories[categoryId]
        if not cat then return nil end
        if currentLevel >= cat.MaxLevel then return nil end
        return cat.Tiers[currentLevel + 1]
    end,
}

return UpgradeConfig
