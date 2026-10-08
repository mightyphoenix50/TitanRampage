--!strict
--[[
    TitanRegistry.luau
    Central authoritative registry and configuration for all playable Titans in Titan Rampage.
    Milestone 9A: Multi-Titan Architecture.
    Provides scalable data-driven Titan definitions, upgrade mappings, camera configs,
    and ability resolution without hardcoding Titan-specific conditionals.
--]]

export type AbilitySlot = "Primary" | "Stomp" | "Signature" | "Utility"

export type AbilityDef = {
    Name: string,
    DisplayName: string,
    Description: string,
    Slot: AbilitySlot,
    KeybindDisplay: string,
    Cooldown: number,
    Damage: number?,
    Range: number?,
    Radius: number?,
    WindUp: number?,
    AnimationDuration: number?,
    AnimationIds: { [string]: string }?,
    CooldownUpgradeCategory: string?,
    DamageUpgradeCategory: string?,
    RadiusUpgradeCategory: string?,
}

export type UnlockRequirement = {
    Level: number,
    Clears: number,
    Description: string?,
}

export type CameraConfig = {
    Min: number,
    Max: number,
    Default: number,
    CameraOffset: Vector3,
}

export type BaseMovementConfig = {
    WalkSpeed: number,
    JumpPower: number,
    HipHeight: number,
}

export type UpgradeMapping = {
    Category: string,
    TargetType: "AbilityStat" | "CharacterStat",
    AbilityName: string?,
    StatName: string,
    BaseValue: number,
}

export type AudioProfile = {
    AttackWhoosh: { [string]: string }?,
    StompAnticipation: string?,
    StompImpact: string?,
    Roar: string?,
    [string]: any,
}

export type TitanDef = {
    Id: string,
    Name: string,
    DisplayName: string,
    Title: string,
    Description: string,
    CreatureType: string,
    ModelName: string,
    BaseHealth: number,
    WalkSpeed: number,
    JumpPower: number,
    HipHeight: number,
    CameraZoom: CameraConfig,
    UnlockRequirement: UnlockRequirement,
    Abilities: { [string]: AbilityDef },
    AbilityOrder: { string },
    UpgradeMappings: { [string]: UpgradeMapping },
    AudioProfile: AudioProfile,
    AnimationProfile: string,
}

local Registry: { [string]: TitanDef } = {
    Ravager = {
        Id = "Ravager",
        Name = "Ravager",
        DisplayName = "The Ravager",
        Title = "Ancient Volcanic Behemoth",
        Description = "An original ancient bipedal titan forged of hardened basalt stone and volcanic fury. Excels in rapid melee claw strikes and aggressive area ground slams.",
        CreatureType = "Bipedal Basalt Titan",
        ModelName = "Ravager",
        BaseHealth = 3000,
        WalkSpeed = 24,
        JumpPower = 65,
        HipHeight = 0.15,
        CameraZoom = {
            Min = 15,
            Max = 120,
            Default = 45,
            CameraOffset = Vector3.new(0, 5, 0),
        },
        UnlockRequirement = {
            Level = 1,
            Clears = 0,
            Description = "Starter Titan • Always Available",
        },
        Abilities = {
            BasicAttack = {
                Name = "BasicAttack",
                DisplayName = "Claw Strike",
                Description = "Rapid sweeping claw slash devastating buildings in a tight forward cone.",
                Slot = "Primary",
                KeybindDisplay = "LMB / 1",
                Cooldown = 0.78,
                Damage = 120,
                Range = 22,
                Radius = 18,
                AnimationDuration = 0.42,
                CooldownUpgradeCategory = "BasicAttackCooldown",
                DamageUpgradeCategory = "BasicAttackDamage",
                AnimationIds = {
                    LeftSwipe = "rbxassetid://0",
                    RightSwipe = "rbxassetid://0",
                    DownwardSmash = "rbxassetid://0",
                },
            },
            Stomp = {
                Name = "Stomp",
                DisplayName = "Ground Stomp",
                Description = "Heavy leg stomp sending a localized kinetic shockwave through nearby structures.",
                Slot = "Stomp",
                KeybindDisplay = "E / 2",
                Cooldown = 5.0,
                Damage = 400,
                Radius = 30,
                WindUp = 0.35,
                AnimationDuration = 0.75,
                CooldownUpgradeCategory = "StompCooldown",
                DamageUpgradeCategory = "StompDamage",
                RadiusUpgradeCategory = "StompRadius",
                AnimationIds = {
                    Stomp = "rbxassetid://0",
                },
            },
            Roar = {
                Name = "Roar",
                DisplayName = "Volcanic Roar",
                Description = "Intimidating roar that releases a concussive soundwave across the district.",
                Slot = "Utility",
                KeybindDisplay = "R / 3",
                Cooldown = 8.0,
                Radius = 45,
                AnimationDuration = 1.00,
                CooldownUpgradeCategory = "RoarCooldown",
                AnimationIds = {
                    Roar = "rbxassetid://0",
                },
            },
        },
        AbilityOrder = { "BasicAttack", "Stomp", "Roar" },
        UpgradeMappings = {
            BasicAttackDamage = {
                Category = "BasicAttackDamage",
                TargetType = "AbilityStat",
                AbilityName = "BasicAttack",
                StatName = "Damage",
                BaseValue = 150,
            },
            BasicAttackCooldown = {
                Category = "BasicAttackCooldown",
                TargetType = "AbilityStat",
                AbilityName = "BasicAttack",
                StatName = "Cooldown",
                BaseValue = 0.78,
            },
            StompDamage = {
                Category = "StompDamage",
                TargetType = "AbilityStat",
                AbilityName = "Stomp",
                StatName = "Damage",
                BaseValue = 400,
            },
            StompRadius = {
                Category = "StompRadius",
                TargetType = "AbilityStat",
                AbilityName = "Stomp",
                StatName = "Radius",
                BaseValue = 30,
            },
            StompCooldown = {
                Category = "StompCooldown",
                TargetType = "AbilityStat",
                AbilityName = "Stomp",
                StatName = "Cooldown",
                BaseValue = 5.0,
            },
            WalkSpeed = {
                Category = "WalkSpeed",
                TargetType = "CharacterStat",
                StatName = "WalkSpeed",
                BaseValue = 24,
            },
            RoarCooldown = {
                Category = "RoarCooldown",
                TargetType = "AbilityStat",
                AbilityName = "Roar",
                StatName = "Cooldown",
                BaseValue = 8.0,
            },
        },
        AudioProfile = {
            AttackWhoosh = {
                LeftSwipe = "LeftSwipe",
                RightSwipe = "RightSwipe",
                DownwardSmash = "DownwardSmash",
            },
            StompAnticipation = "StompAnticipation",
            StompImpact = "StompImpact",
            Roar = "Roar",
        },
        AnimationProfile = "Ravager",
    },

    Brontara = {
        Id = "Brontara",
        Name = "Brontara",
        DisplayName = "Brontara",
        Title = "The Earthshaker",
        Description = "A colossal quadrupedal ancient behemoth of dense bedrock and surging magma veins. Shakes the earth with seismic footsteps and sweeping siege strikes.",
        CreatureType = "Quadrupedal Colossal Behemoth",
        ModelName = "Brontara",
        BaseHealth = 4500,
        WalkSpeed = 20,
        JumpPower = 40,
        HipHeight = 0.15,
        CameraZoom = {
            Min = 25,
            Max = 160,
            Default = 65,
            CameraOffset = Vector3.new(0, 10, 0),
        },
        UnlockRequirement = {
            Level = 5,
            Clears = 2,
            Description = "Requires Level 5 and 2 City Clears",
        },
        Abilities = {
            TailSweep = {
                Name = "TailSweep",
                DisplayName = "Tail Sweep",
                Description = "Sweeps its massive spiked tail horizontally across the street, devastating multiple buildings in a wide arc.",
                Slot = "Primary",
                KeybindDisplay = "LMB / 1",
                Cooldown = 1.10,
                Damage = 200,
                Range = 26,
                Radius = 16,
                AnimationDuration = 0.65,
                CooldownUpgradeCategory = "BasicAttackCooldown",
                DamageUpgradeCategory = "BasicAttackDamage",
                AnimationIds = {
                    TailSweep = "rbxassetid://0",
                },
            },
            HeavyStomp = {
                Name = "HeavyStomp",
                DisplayName = "Heavy Stomp",
                Description = "Rears up onto hind legs and crashes massive front pillars down, unleashing a devastating 45-stud seismic shockwave.",
                Slot = "Stomp",
                KeybindDisplay = "E / 2",
                Cooldown = 6.0,
                Damage = 600,
                Radius = 45,
                WindUp = 0.50,
                AnimationDuration = 1.00,
                CooldownUpgradeCategory = "StompCooldown",
                DamageUpgradeCategory = "StompDamage",
                RadiusUpgradeCategory = "StompRadius",
                AnimationIds = {
                    HeavyStomp = "rbxassetid://0",
                },
            },
            NeckStrike = {
                Name = "NeckStrike",
                DisplayName = "Neck Strike",
                Description = "Arches its colossal neck and plunges its armored crest downward, obliterating distant structures from high above.",
                Slot = "Signature",
                KeybindDisplay = "Q",
                Cooldown = 4.0,
                Damage = 350,
                Range = 52,
                Radius = 14,
                AnimationDuration = 0.70,
                CooldownUpgradeCategory = "BasicAttackCooldown",
                DamageUpgradeCategory = "BasicAttackDamage",
                AnimationIds = {
                    NeckStrike = "rbxassetid://0",
                },
            },
            Roar = {
                Name = "Roar",
                DisplayName = "Seismic Bellow",
                Description = "Releases an ultra-low infrasound bellow that rattles the foundations of the entire city district.",
                Slot = "Utility",
                KeybindDisplay = "R / 3",
                Cooldown = 8.0,
                Radius = 55,
                AnimationDuration = 1.10,
                CooldownUpgradeCategory = "RoarCooldown",
                AnimationIds = {
                    Roar = "rbxassetid://0",
                },
            },
        },
        AbilityOrder = { "TailSweep", "HeavyStomp", "NeckStrike", "Roar" },
        UpgradeMappings = {
            BasicAttackDamage = {
                Category = "BasicAttackDamage",
                TargetType = "AbilityStat",
                AbilityName = "TailSweep",
                StatName = "Damage",
                BaseValue = 200,
            },
            BasicAttackCooldown = {
                Category = "BasicAttackCooldown",
                TargetType = "AbilityStat",
                AbilityName = "TailSweep",
                StatName = "Cooldown",
                BaseValue = 1.10,
            },
            StompDamage = {
                Category = "StompDamage",
                TargetType = "AbilityStat",
                AbilityName = "HeavyStomp",
                StatName = "Damage",
                BaseValue = 600,
            },
            StompRadius = {
                Category = "StompRadius",
                TargetType = "AbilityStat",
                AbilityName = "HeavyStomp",
                StatName = "Radius",
                BaseValue = 45,
            },
            StompCooldown = {
                Category = "StompCooldown",
                TargetType = "AbilityStat",
                AbilityName = "HeavyStomp",
                StatName = "Cooldown",
                BaseValue = 6.0,
            },
            WalkSpeed = {
                Category = "WalkSpeed",
                TargetType = "CharacterStat",
                StatName = "WalkSpeed",
                BaseValue = 20,
            },
            RoarCooldown = {
                Category = "RoarCooldown",
                TargetType = "AbilityStat",
                AbilityName = "Roar",
                StatName = "Cooldown",
                BaseValue = 8.0,
            },
        },
        AudioProfile = {
            AttackWhoosh = {
                LeftSwipe = "LeftSwipe",
                RightSwipe = "RightSwipe",
                DownwardSmash = "DownwardSmash",
            },
            StompAnticipation = "StompAnticipation",
            StompImpact = "StompImpact",
            Roar = "Roar",
        },
        AnimationProfile = "Brontara",
    },
}

local TitanRegistry = {}

--[=[
    Retrieves the authoritative definition for a Titan by Id.
]=]
function TitanRegistry.Get(titanId: string): TitanDef?
    return Registry[titanId]
end

--[=[
    Returns the dictionary of all registered Titans.
]=]
function TitanRegistry.GetAll(): { [string]: TitanDef }
    return Registry
end

--[=[
    Returns a deterministic ordered list of all registered Titans.
]=]
function TitanRegistry.GetList(): { TitanDef }
    return { Registry.Ravager, Registry.Brontara }
end

--[=[
    Checks whether a TitanId is registered.
]=]
function TitanRegistry.IsRegistered(titanId: string): boolean
    return Registry[titanId] ~= nil
end

--[=[
    Retrieves an ability definition by TitanId and ability name.
]=]
function TitanRegistry.GetAbility(titanId: string, abilityName: string): AbilityDef?
    local def = Registry[titanId]
    if not def then return nil end
    return def.Abilities[abilityName]
end

--[=[
    Retrieves the primary ability assigned to a specific AbilitySlot.
]=]
function TitanRegistry.GetAbilityForSlot(titanId: string, slot: AbilitySlot): AbilityDef?
    local def = Registry[titanId]
    if not def then return nil end
    for _, ability in pairs(def.Abilities) do
        if ability.Slot == slot then
            return ability
        end
    end
    return nil
end

--[=[
    Retrieves the upgrade mapping definition for a Titan and upgrade category.
]=]
function TitanRegistry.GetUpgradeMapping(titanId: string, categoryId: string): UpgradeMapping?
    local def = Registry[titanId]
    if not def or not def.UpgradeMappings then return nil end
    return def.UpgradeMappings[categoryId]
end

--[=[
    Calculates effective ability cooldown considering player upgrade values.
    For Ravager: perfectly scales cooldown with UpgradeConfig values.
]=]
function TitanRegistry.CalculateAbilityCooldown(titanId: string, abilityName: string, upgradeValue: number?): number
    local def = Registry[titanId]
    if not def then return 1.0 end
    local ab = def.Abilities[abilityName]
    if not ab then return 1.0 end

    if not upgradeValue then
        return ab.Cooldown
    end

    if titanId == "Ravager" then
        -- For Ravager, upgradeValue directly represents the target cooldown
        return upgradeValue
    end

    -- Generic formula for future Titans: scale base cooldown by ratio
    local mapping = def.UpgradeMappings and ab.CooldownUpgradeCategory and def.UpgradeMappings[ab.CooldownUpgradeCategory]
    if mapping and mapping.BaseValue > 0 then
        return ab.Cooldown * (upgradeValue / mapping.BaseValue)
    end

    return ab.Cooldown
end

--[=[
    Calculates effective ability damage considering player upgrade values.
    For Ravager: perfectly scales damage with UpgradeConfig values.
]=]
function TitanRegistry.CalculateAbilityDamage(titanId: string, abilityName: string, upgradeValue: number?): number
    local def = Registry[titanId]
    if not def then return 100 end
    local ab = def.Abilities[abilityName]
    if not ab then return 100 end

    if not upgradeValue then
        return ab.Damage or 100
    end

    if titanId == "Ravager" then
        -- For Ravager, upgradeValue directly represents the base damage before tier multipliers
        return upgradeValue
    end

    -- Generic formula for future Titans: scale base damage by upgrade ratio
    local baseDmg = ab.Damage or 100
    local mapping = def.UpgradeMappings and ab.DamageUpgradeCategory and def.UpgradeMappings[ab.DamageUpgradeCategory]
    if mapping and mapping.BaseValue > 0 then
        return math.floor(baseDmg * (upgradeValue / mapping.BaseValue))
    end

    return baseDmg
end

--[=[
    Calculates effective ability radius considering player upgrade values.
    For Ravager: perfectly scales Stomp radius with UpgradeConfig values.
]=]
function TitanRegistry.CalculateAbilityRadius(titanId: string, abilityName: string, upgradeValue: number?): number
    local def = Registry[titanId]
    if not def then return 30 end
    local ab = def.Abilities[abilityName]
    if not ab then return 30 end

    if not upgradeValue then
        return ab.Radius or 30
    end

    if titanId == "Ravager" then
        return upgradeValue
    end

    local baseRad = ab.Radius or 30
    local mapping = def.UpgradeMappings and ab.RadiusUpgradeCategory and def.UpgradeMappings[ab.RadiusUpgradeCategory]
    if mapping and mapping.BaseValue > 0 then
        return math.floor(baseRad * (upgradeValue / mapping.BaseValue))
    end

    return baseRad
end

--[=[
    Calculates effective walk speed considering player upgrade values.
    For Ravager: BaseSpeed (24) + (upgradeSpeed - 24) = upgradeSpeed (28 to 40).
]=]
function TitanRegistry.CalculateWalkSpeed(titanId: string, upgradeSpeed: number?): number
    local def = Registry[titanId]
    local baseSpeed = if def then def.WalkSpeed else 24

    if not upgradeSpeed then
        return baseSpeed
    end

    if titanId == "Ravager" then
        local bonus = math.max(0, upgradeSpeed - 24)
        return baseSpeed + bonus
    end

    -- For future Titans: maintain speed delta relative to standard upgrade curve
    local bonus = math.max(0, upgradeSpeed - 28)
    return baseSpeed + bonus
end

--[=[
    Evaluates whether player meets level & clear requirements to unlock a Titan.
]=]
function TitanRegistry.IsUnlocked(titanId: string, level: number, clears: number): (boolean, string?)
    local def = Registry[titanId]
    if not def then
        return false, "Titan does not exist"
    end

    local req = def.UnlockRequirement
    if not req then
        return true, nil
    end

    if level < req.Level then
        return false, string.format("Requires Level %d (Current: %d)", req.Level, level)
    end

    if clears < req.Clears then
        return false, string.format("Requires %d City Clears (Current: %d)", req.Clears, clears)
    end

    return true, nil
end

-- Allow backward-compatible table indexing: TitanRegistry["Ravager"]
setmetatable(TitanRegistry, {
    __index = function(_, key)
        return Registry[key]
    end,
})

return TitanRegistry
