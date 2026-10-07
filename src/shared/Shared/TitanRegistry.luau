--!strict
--[[
    TitanRegistry.luau
    Central registry and configuration for all playable Titans in Titan Rampage.
    Supports extensible data-driven multi-Titan architecture.
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
}

export type UnlockRequirement = {
    Level: number,
    Clears: number,
}

export type TitanDef = {
    Id: string,
    Name: string,
    DisplayName: string,
    Title: string,
    Description: string,
    CreatureType: string,
    BaseHealth: number,
    WalkSpeed: number,
    JumpPower: number,
    HipHeight: number,
    CameraZoom: {
        Min: number,
        Max: number,
        Default: number,
        CameraOffset: Vector3,
    },
    UnlockRequirement: UnlockRequirement,
    Abilities: { [string]: AbilityDef },
    AbilityOrder: { string },
}

local Registry: { [string]: TitanDef } = {
    Ravager = {
        Id = "Ravager",
        Name = "Ravager",
        DisplayName = "The Ravager",
        Title = "Ancient Volcanic Behemoth",
        Description = "An original ancient bipedal titan forged of hardened basalt stone and volcanic fury. Excels in rapid melee claw strikes and aggressive area ground slams.",
        CreatureType = "Bipedal Basalt Titan",
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
                Radius = 12,
                AnimationDuration = 0.42,
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
                Damage = 300,
                Radius = 30,
                WindUp = 0.35,
                AnimationDuration = 0.75,
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
                AnimationIds = {
                    Roar = "rbxassetid://0",
                },
            },
        },
        AbilityOrder = { "BasicAttack", "Stomp", "Roar" },
    },

    Brontara = {
        Id = "Brontara",
        Name = "Brontara",
        DisplayName = "Brontara",
        Title = "The Earthshaker",
        Description = "A colossal quadrupedal ancient behemoth of dense bedrock and surging magma veins. Shakes the earth with seismic footsteps and sweeping siege strikes.",
        CreatureType = "Quadrupedal Colossal Behemoth",
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
                AnimationIds = {
                    Roar = "rbxassetid://0",
                },
            },
        },
        AbilityOrder = { "TailSweep", "HeavyStomp", "NeckStrike", "Roar" },
    },
}

local TitanRegistry = {}

function TitanRegistry.Get(titanId: string): TitanDef?
    return Registry[titanId]
end

function TitanRegistry.GetAll(): { [string]: TitanDef }
    return Registry
end

function TitanRegistry.GetList(): { TitanDef }
    return { Registry.Ravager, Registry.Brontara }
end

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

-- Allow direct table indexing: TitanRegistry["Ravager"]
setmetatable(TitanRegistry, {
    __index = function(_, key)
        return Registry[key]
    end,
})

return TitanRegistry
