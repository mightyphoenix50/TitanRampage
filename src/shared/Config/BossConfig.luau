--!strict
--[[
    BossConfig.luau
    Boss fight definitions for the Colosseum Proving Grounds (Milestone 15).
    Pure data: requirements, health, attack patterns and rewards. BossService runs the fights.

    Attack kinds (all telegraphed with a ground marker for WindUp seconds, then hit once):
    - "Slam":   circle centred on the boss
    - "Circle": a circle under every party member's current position
    - "Cone":   frontal cone from the boss toward its current target
    - "Lanes":  parallel strips across the arena, with gaps to stand in
    - "Donut":  ring between InnerRadius and Radius around the boss (stand close to dodge)
    - "Shield": boss ignores everything except stomps for Duration seconds (no damage, no marker)
--]]

export type BossAttack = {
    Id: string,
    Kind: string,
    Damage: number,
    WindUp: number,
    Radius: number?,
    InnerRadius: number?,
    Angle: number?, -- Cone half-angle in degrees
    Width: number?, -- Lane width
    Count: number?, -- Lane count
    Duration: number?, -- Shield duration
    MinPhase: number, -- 1, 2 or 3: the attack joins the rotation from this phase on
}

export type BossDef = {
    Id: string,
    Order: number,
    DisplayName: string,
    Title: string, -- Title granted on first clear
    Description: string,
    RequiredPower: number,
    RequiredCityClears: { [string]: number }, -- Per-city clear requirements
    RequiredTotalClears: number, -- Total clears across all cities
    BaseHealth: number, -- Solo health; +HealthPerExtraPlayer per extra party member
    HealthPerExtraPlayer: number,
    EnrageTime: number, -- Seconds before the fight is lost
    AttackInterval: number, -- Seconds between attacks in phase 1 (phases 2/3 speed up)
    RecommendedDPS: number, -- Compared against the Bastion readiness test
    FirstClearCash: number,
    RepeatCash: number,
    RepeatCooldown: number, -- Seconds between rewarded repeat clears, per player
    UnlocksTitan: string?,
    Color: Color3,
    Scale: number, -- Rough height in studs for the fallback model and the health bar anchor
    Attacks: { BossAttack },
}

local BossConfig = {}

BossConfig.ArenaCenter = Vector3.new(0, 480, -5425) -- Top of ColosseumFloor, centred between its walls
BossConfig.ArenaRadius = 140 -- Players inside this ring when a fight starts join the party (walls sit ~145-160 out)
BossConfig.MinDamageShare = 0.05 -- Party members below this share of boss damage get no reward
BossConfig.PhaseThresholds = { 0.66, 0.33 } -- Health fractions where phases 2 and 3 begin
BossConfig.PhaseSpeedup = 0.8 -- Attack interval multiplier per phase after the first

local Bosses: { [string]: BossDef } = {
    CinderWarden = {
        Id = "CinderWarden",
        Order = 1,
        DisplayName = "Cinder Warden",
        Title = "Cinder Breaker",
        Description = "A lava golem that guards the Colosseum. Slams the ground and leaves magma pools under its challengers.",
        RequiredPower = 300,
        RequiredCityClears = { SmallTown = 1 },
        RequiredTotalClears = 0,
        BaseHealth = 25000,
        HealthPerExtraPlayer = 0.6,
        EnrageTime = 180,
        AttackInterval = 3.2,
        RecommendedDPS = 180,
        FirstClearCash = 5000,
        RepeatCash = 1250,
        RepeatCooldown = 600,
        UnlocksTitan = "Brontara",
        Color = Color3.fromRGB(255, 96, 24),
        Scale = 60,
        Attacks = {
            { Id = "MagmaSlam", Kind = "Slam", Damage = 450, WindUp = 1.4, Radius = 45, MinPhase = 1 },
            { Id = "MagmaPools", Kind = "Circle", Damage = 350, WindUp = 1.2, Radius = 22, MinPhase = 1 },
            { Id = "EruptionRing", Kind = "Donut", Damage = 600, WindUp = 1.6, Radius = 135, InnerRadius = 55, MinPhase = 2 },
            { Id = "LavaBreath", Kind = "Cone", Damage = 550, WindUp = 1.3, Radius = 120, Angle = 35, MinPhase = 3 },
        },
    },

    StormcoilSerpent = {
        Id = "StormcoilSerpent",
        Order = 2,
        DisplayName = "Stormcoil Serpent",
        Title = "Storm Breaker",
        Description = "A lightning eel that splits the arena into lanes of lightning and sweeps its coils across the floor.",
        RequiredPower = 550,
        RequiredCityClears = { Metrovale = 1 },
        RequiredTotalClears = 0,
        BaseHealth = 60000,
        HealthPerExtraPlayer = 0.6,
        EnrageTime = 180,
        AttackInterval = 2.8,
        RecommendedDPS = 380,
        FirstClearCash = 12000,
        RepeatCash = 3000,
        RepeatCooldown = 600,
        Color = Color3.fromRGB(90, 200, 255),
        Scale = 70,
        Attacks = {
            { Id = "LightningLanes", Kind = "Lanes", Damage = 650, WindUp = 1.3, Width = 30, Count = 5, MinPhase = 1 },
            { Id = "StaticStrikes", Kind = "Circle", Damage = 500, WindUp = 1.1, Radius = 24, MinPhase = 1 },
            { Id = "CoilSweep", Kind = "Cone", Damage = 700, WindUp = 1.2, Radius = 140, Angle = 60, MinPhase = 2 },
            { Id = "StormNova", Kind = "Donut", Damage = 800, WindUp = 1.5, Radius = 135, InnerRadius = 50, MinPhase = 3 },
        },
    },

    ObsidianColossus = {
        Id = "ObsidianColossus",
        Order = 3,
        DisplayName = "Obsidian Colossus",
        Title = "Colossus Breaker",
        Description = "An armoured giant. Raises an obsidian shield that only stomps can crack, and sends quake waves through the arena.",
        RequiredPower = 850,
        RequiredCityClears = {},
        RequiredTotalClears = 5,
        BaseHealth = 140000,
        HealthPerExtraPlayer = 0.6,
        EnrageTime = 210,
        AttackInterval = 2.6,
        RecommendedDPS = 750,
        FirstClearCash = 25000,
        RepeatCash = 6000,
        RepeatCooldown = 600,
        Color = Color3.fromRGB(150, 110, 255),
        Scale = 85,
        Attacks = {
            { Id = "ObsidianSlam", Kind = "Slam", Damage = 900, WindUp = 1.3, Radius = 55, MinPhase = 1 },
            { Id = "QuakeWave", Kind = "Donut", Damage = 900, WindUp = 1.4, Radius = 140, InnerRadius = 60, MinPhase = 1 },
            { Id = "ShardRain", Kind = "Circle", Damage = 700, WindUp = 1.1, Radius = 26, MinPhase = 2 },
            { Id = "ObsidianShield", Kind = "Shield", Damage = 0, WindUp = 0.6, Duration = 8, MinPhase = 2 },
            { Id = "RiftLanes", Kind = "Lanes", Damage = 900, WindUp = 1.2, Width = 32, Count = 5, MinPhase = 3 },
        },
    },
}

BossConfig.Bosses = Bosses

function BossConfig.Get(bossId: string): BossDef?
    return Bosses[bossId]
end

function BossConfig.GetList(): { BossDef }
    local list = {}
    for _, def in pairs(Bosses) do
        table.insert(list, def)
    end
    table.sort(list, function(a, b)
        return a.Order < b.Order
    end)
    return list
end

return BossConfig
