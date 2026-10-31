--!strict
--[[
    DestructionConfig.luau
    Central configuration for the destruction system in Titan Rampage.
    Balances damage scaling by building tier, area falloff, and combo multiplier rules.
--]]

export type TierDamageMap = { [number]: number }

export type DestructionConfigType = {
    BasicAttackDamage: TierDamageMap,
    BasicAttackRange: number,
    BasicAttackRadius: number,

    StompDamage: TierDamageMap,
    StompRadius: number,
    StompMinDamageFactor: number,

    TierHealthScale: TierDamageMap,

    Combo: {
        Timeout: number,
        MaxMultiplier: number,
        MultiplierPerHit: number,
    },

    Tiers: {
        [number]: {
            Name: string,
            BaseXP: number,
        },
    },
}

local DestructionConfig: DestructionConfigType = {
    -- Target damage based on building DestructionTier
    BasicAttackDamage = {
        [1] = 150, -- Tier 1 (Small buildings: ~450-650 HP, ~3-4 hits)
        [2] = 100, -- Tier 2 (Medium buildings: ~1400-1800 HP)
        [3] = 75, -- Tier 3 (Large skyscrapers: ~3500-3800 HP)
        [4] = 60, -- Tier 4 (Landmarks: ~6000-7500 HP)
    },
    BasicAttackRange = 22,
    BasicAttackRadius = 18,

    -- Stomp maximum epicenter damage by Tier
    StompDamage = {
        [1] = 400, -- Tier 1 (Small buildings)
        [2] = 300, -- Tier 2 (Medium buildings)
        [3] = 200, -- Tier 3 (Large buildings)
        [4] = 150, -- Tier 4 (Landmarks)
    },
    StompRadius = 30,
    StompMinDamageFactor = 0.35, -- Outer edge damage is 35% of epicenter max

    -- Scales each building's authored MaxHealth when its city registers (CityService), so a
    -- base-level Ravager (150 dmg x tier multiplier) drops buildings in about 2 / 4 / 7 / 15 hits
    TierHealthScale = {
        [1] = 0.50, -- Small: 450-800 authored -> 225-400
        [2] = 0.22, -- Medium: 1400-2400 -> 308-528
        [3] = 0.22, -- Large: 2100-2700 -> 462-594
        [4] = 0.13, -- Landmark: 6500-7500 -> 845-975
    },

    -- Combo mechanics
    Combo = {
        Timeout = 5.0, -- Seconds before combo resets
        MaxMultiplier = 5, -- Prototype combo cap (1x -> 2x -> 3x -> 4x -> 5x)
        MultiplierPerHit = 1, -- Increment per destruction/damage event
    },

    -- Tier definitions
    Tiers = {
        [1] = { Name = "Small", BaseXP = 10 },
        [2] = { Name = "Medium", BaseXP = 25 },
        [3] = { Name = "Large", BaseXP = 50 },
        [4] = { Name = "Landmark", BaseXP = 100 },
    },
}

return DestructionConfig
