--!strict
--[[
    MonetizationConfig.luau
    Authoritative monetization configuration for Titan Rampage.
    Responsibility:
    - Defines all official Gamepasses (multipliers, features, cosmetics).
    - Defines all Developer Products (currency packs, instant cooldown resets, combo freeze).
    - Configures Robux pricing, display metadata, icons, and reward parameters.
    - Provides production-safe fallbacks and Studio sandbox test modes.
--]]

export type PerkType = "Multiplier" | "Feature" | "Cosmetic"
export type ProductCategory = "Currency" | "XP" | "Combat"
export type ProductRewardType = "Cash" | "XP" | "CooldownReset" | "ComboShield"

export type GamepassDef = {
    Id: string,
    Name: string,
    DisplayName: string,
    Description: string,
    RobuxPrice: number,
    Icon: string,
    AssetId: number,
    PerkType: PerkType,
    MultiplierValue: number?,
}

export type ProductDef = {
    Id: string,
    Name: string,
    DisplayName: string,
    Description: string,
    RobuxPrice: number,
    Icon: string,
    AssetId: number,
    Category: ProductCategory,
    RewardType: ProductRewardType,
    RewardAmount: number,
}

local MonetizationConfig = {}

MonetizationConfig.Gamepasses = {
    DoubleCash = {
        Id = "DoubleCash",
        Name = "DoubleCash",
        DisplayName = "2x Cash Multiplier",
        Description = "Permanently doubles all Cash earned from smashing buildings, maintaining combos, and completing cities!",
        RobuxPrice = 249,
        Icon = "💵",
        AssetId = 0, -- Set to official Roblox GamePassId upon publication
        PerkType = "Multiplier",
        MultiplierValue = 2.0,
    },
    DoubleXP = {
        Id = "DoubleXP",
        Name = "DoubleXP",
        DisplayName = "2x XP Multiplier",
        Description = "Permanently doubles all XP earned, unlocking colossal Titan stat upgrades twice as fast!",
        RobuxPrice = 199,
        Icon = "⭐",
        AssetId = 0,
        PerkType = "Multiplier",
        MultiplierValue = 2.0,
    },
    InstantRebuild = {
        Id = "InstantRebuild",
        Name = "InstantRebuild",
        DisplayName = "Instant City Rebuild",
        Description = "Instantly restore destroyed cities to pristine condition at will with 0 cooldown timer!",
        RobuxPrice = 149,
        Icon = "🏛️",
        AssetId = 0,
        PerkType = "Feature",
    },
    VIPTitanAura = {
        Id = "VIPTitanAura",
        Name = "VIPTitanAura",
        DisplayName = "VIP Radiant Titan Aura",
        Description = "Envelops your Titan in an awe-inspiring corona of glowing golden embers and pulsing cosmic lightning!",
        RobuxPrice = 299,
        Icon = "✨",
        AssetId = 0,
        PerkType = "Cosmetic",
    },
    AutoCollect = {
        Id = "AutoCollect",
        Name = "AutoCollect",
        DisplayName = "Auto-Collector Magnet",
        Description = "Magnetically pulls all debris currency and destruction rewards across the entire district straight to you!",
        RobuxPrice = 99,
        Icon = "🧲",
        AssetId = 0,
        PerkType = "Feature",
    },
} :: { [string]: GamepassDef }

MonetizationConfig.Products = {
    CashSurge_Small = {
        Id = "CashSurge_Small",
        Name = "CashSurge_Small",
        DisplayName = "+$25,000 Cash Surge",
        Description = "Instant injection of $25,000 Cash to spend immediately on Titan stat upgrades.",
        RobuxPrice = 49,
        Icon = "💰",
        AssetId = 0, -- Set to official Roblox ProductId upon publication
        Category = "Currency",
        RewardType = "Cash",
        RewardAmount = 25000,
    },
    CashSurge_Large = {
        Id = "CashSurge_Large",
        Name = "CashSurge_Large",
        DisplayName = "+$150,000 Cash Vault",
        Description = "Colossal fortune of $150,000 Cash to max out multiple upgrade tiers in an instant!",
        RobuxPrice = 199,
        Icon = "🏦",
        AssetId = 0,
        Category = "Currency",
        RewardType = "Cash",
        RewardAmount = 150000,
    },
    XPBlast_Small = {
        Id = "XPBlast_Small",
        Name = "XPBlast_Small",
        DisplayName = "+5,000 XP Blast",
        Description = "Instant 5,000 XP boost to accelerate through Titan progression tiers and unlock new Kaiju.",
        RobuxPrice = 79,
        Icon = "⚡",
        AssetId = 0,
        Category = "XP",
        RewardType = "XP",
        RewardAmount = 5000,
    },
    InstantCooldownReset = {
        Id = "InstantCooldownReset",
        Name = "InstantCooldownReset",
        DisplayName = "Instant Cooldown Reset",
        Description = "Instantly clears all active cooldowns on your Stomp, Heavy Stomp, Neck Strike, and Roar!",
        RobuxPrice = 25,
        Icon = "⏱️",
        AssetId = 0,
        Category = "Combat",
        RewardType = "CooldownReset",
        RewardAmount = 1,
    },
    ComboShield = {
        Id = "ComboShield",
        Name = "ComboShield",
        DisplayName = "60s Combo Freeze Shield",
        Description = "Freezes your destruction combo multiplier timer for 60 seconds — your combo cannot decay!",
        RobuxPrice = 39,
        Icon = "🛡️",
        AssetId = 0,
        Category = "Combat",
        RewardType = "ComboShield",
        RewardAmount = 60,
    },
} :: { [string]: ProductDef }

MonetizationConfig.GamepassOrder = {
    "DoubleCash",
    "DoubleXP",
    "InstantRebuild",
    "VIPTitanAura",
    "AutoCollect",
}

MonetizationConfig.ProductOrder = {
    "CashSurge_Small",
    "CashSurge_Large",
    "XPBlast_Small",
    "InstantCooldownReset",
    "ComboShield",
}

function MonetizationConfig.GetGamepass(id: string): GamepassDef?
    return MonetizationConfig.Gamepasses[id]
end

function MonetizationConfig.GetGamepassByAssetId(assetId: number): GamepassDef?
    if assetId == 0 then return nil end
    for _, def in pairs(MonetizationConfig.Gamepasses) do
        if def.AssetId == assetId then
            return def
        end
    end
    return nil
end

function MonetizationConfig.GetProduct(id: string): ProductDef?
    return MonetizationConfig.Products[id]
end

function MonetizationConfig.GetProductByAssetId(assetId: number): ProductDef?
    if assetId == 0 then return nil end
    for _, def in pairs(MonetizationConfig.Products) do
        if def.AssetId == assetId then
            return def
        end
    end
    return nil
end

function MonetizationConfig.GetGamepassesList(): { GamepassDef }
    local list = {}
    for _, id in ipairs(MonetizationConfig.GamepassOrder) do
        local def = MonetizationConfig.Gamepasses[id]
        if def then
            table.insert(list, def)
        end
    end
    return list
end

function MonetizationConfig.GetProductsList(): { ProductDef }
    local list = {}
    for _, id in ipairs(MonetizationConfig.ProductOrder) do
        local def = MonetizationConfig.Products[id]
        if def then
            table.insert(list, def)
        end
    end
    return list
end

return MonetizationConfig
