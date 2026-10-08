--!strict
--[[
    AudioConfig.luau
    Central sound definitions, spatial profiles, and volume parameters for Titan Rampage.
    Organized by category: Combat, Destruction, Progression, UI, City.
    Supports built-in engine fallbacks (rbxasset://sounds/...) and production asset IDs (rbxassetid://...).
--]]

export type SoundDef = {
    SoundId: string,
    PlaceholderAssetId: string?,
    Volume: number,
    BasePitch: number,
    PitchVariation: number?,
    SoundGroup: string,
    RollOffMinDistance: number?,
    RollOffMaxDistance: number?,
    RollOffMode: Enum.RollOffMode?,
    ThrottleTime: number?,
    SecondarySoundId: string?,
}

export type AudioConfigType = {
    SoundGroups: { [string]: { Volume: number, Parent: string? } },
    Sounds: { [string]: SoundDef },
    GetBuildingImpactKey: (tier: number) -> string,
    GetCollapseRumbleTierMultiplier: (tier: number) -> (number, number),
}

local AudioConfig: AudioConfigType = {
    SoundGroups = {
        Master = { Volume = 1.0, Parent = nil },
        Combat = { Volume = 0.9, Parent = "Master" },
        Destruction = { Volume = 0.9, Parent = "Master" },
        UI = { Volume = 0.5, Parent = "Master" },       -- Quieter per specifications
        Music = { Volume = 0.6, Parent = "Master" },
    },

    Sounds = {
        -- ====================================================================
        -- 1. COMBAT
        -- ====================================================================
        LeftSwipe = {
            SoundId = "rbxasset://sounds/action_jump.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Heavy monster claw swipe left
            Volume = 0.85,
            BasePitch = 1.25, -- Fast crisp whoosh
            PitchVariation = 0.06,
            SoundGroup = "Combat",
            RollOffMinDistance = 15,
            RollOffMaxDistance = 250,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        RightSwipe = {
            SoundId = "rbxasset://sounds/action_jump.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Heavy monster claw swipe right
            Volume = 0.85,
            BasePitch = 1.45, -- Pitch-varied counter whoosh
            PitchVariation = 0.06,
            SoundGroup = "Combat",
            RollOffMinDistance = 15,
            RollOffMaxDistance = 250,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        DownwardSmash = {
            SoundId = "rbxasset://sounds/action_jump.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Deep overhead cleave whoosh
            Volume = 1.05,
            BasePitch = 0.80, -- Deep low-frequency resonance
            PitchVariation = 0.04,
            SoundGroup = "Combat",
            RollOffMinDistance = 20,
            RollOffMaxDistance = 300,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        TailSweepWhoosh = {
            SoundId = "rbxasset://sounds/action_jump.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Colossal tail whip whoosh
            Volume = 1.05,
            BasePitch = 0.85, -- Heavy, deep low-frequency whoosh
            PitchVariation = 0.05,
            SoundGroup = "Combat",
            RollOffMinDistance = 20,
            RollOffMaxDistance = 320,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        Impact_Small = {
            SoundId = "rbxasset://sounds/action_jump_land.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Crisp concrete wall impact
            Volume = 0.85,
            BasePitch = 1.30,
            PitchVariation = 0.08,
            SoundGroup = "Combat",
            RollOffMinDistance = 20,
            RollOffMaxDistance = 280,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            ThrottleTime = 0.06,
        },

        Impact_Medium = {
            SoundId = "rbxasset://sounds/action_jump_land.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Heavier concrete/brick thud
            Volume = 0.95,
            BasePitch = 1.05,
            PitchVariation = 0.06,
            SoundGroup = "Combat",
            RollOffMinDistance = 25,
            RollOffMaxDistance = 320,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            ThrottleTime = 0.06,
        },

        Impact_Large = {
            SoundId = "rbxasset://sounds/action_jump_land.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Deep structural bass shock impact
            Volume = 1.15,
            BasePitch = 0.80,
            PitchVariation = 0.05,
            SoundGroup = "Combat",
            RollOffMinDistance = 30,
            RollOffMaxDistance = 380,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            ThrottleTime = 0.08,
            SecondarySoundId = "rbxasset://sounds/impact_explosion_03.mp3",
        },

        Impact_Landmark = {
            SoundId = "rbxasset://sounds/impact_explosion_03.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Colossal reverberating landmark slam
            Volume = 1.35,
            BasePitch = 0.85,
            PitchVariation = 0.03,
            SoundGroup = "Combat",
            RollOffMinDistance = 40,
            RollOffMaxDistance = 480,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            ThrottleTime = 0.08,
            SecondarySoundId = "rbxasset://sounds/action_jump_land.mp3",
        },

        StompAnticipation = {
            SoundId = "rbxasset://sounds/action_falling.ogg",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Sub-bass seismic charging rumble
            Volume = 0.55,
            BasePitch = 0.50,
            PitchVariation = 0.03,
            SoundGroup = "Combat",
            RollOffMinDistance = 25,
            RollOffMaxDistance = 320,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        StompImpact = {
            SoundId = "rbxasset://sounds/impact_explosion_03.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Massive seismic ground slam & shockwave
            Volume = 1.40,
            BasePitch = 0.95,
            PitchVariation = 0.04,
            SoundGroup = "Combat",
            RollOffMinDistance = 35,
            RollOffMaxDistance = 450,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            SecondarySoundId = "rbxasset://sounds/action_jump_land.mp3",
        },

        StompDebris = {
            SoundId = "rbxasset://sounds/action_jump_land.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Ground rubble & rock settling rumble
            Volume = 0.75,
            BasePitch = 0.70,
            PitchVariation = 0.08,
            SoundGroup = "Combat",
            RollOffMinDistance = 25,
            RollOffMaxDistance = 350,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        HeavyStompImpact = {
            SoundId = "rbxasset://sounds/impact_explosion_03.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Massive seismic ground slam & shockwave
            Volume = 1.55,
            BasePitch = 0.75, -- Deeper, massive seismic impact
            PitchVariation = 0.04,
            SoundGroup = "Combat",
            RollOffMinDistance = 45,
            RollOffMaxDistance = 550,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            SecondarySoundId = "rbxasset://sounds/action_jump_land.mp3",
        },

        NeckStrikeImpact = {
            SoundId = "rbxasset://sounds/action_jump_land.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Deep hammer plunge structural thud
            Volume = 1.25,
            BasePitch = 0.70,
            PitchVariation = 0.05,
            SoundGroup = "Combat",
            RollOffMinDistance = 25,
            RollOffMaxDistance = 380,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            SecondarySoundId = "rbxasset://sounds/impact_explosion_03.mp3",
        },

        Roar = {
            SoundId = "rbxasset://sounds/impact_explosion_03.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Original colossal ancient beast roar
            Volume = 1.45,
            BasePitch = 0.45, -- Sub-bass monstrous rumble
            PitchVariation = 0.04,
            SoundGroup = "Combat",
            RollOffMinDistance = 40,
            RollOffMaxDistance = 550,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        -- ====================================================================
        -- 2. DESTRUCTION
        -- ====================================================================
        WindowBreak = {
            SoundId = "rbxasset://sounds/action_jump.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Cascading glass shatter & falling shards
            Volume = 0.70,
            BasePitch = 2.00,
            PitchVariation = 0.12,
            SoundGroup = "Destruction",
            RollOffMinDistance = 15,
            RollOffMaxDistance = 260,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            ThrottleTime = 0.15, -- Prevents glass cacophony on Stomp AoE
        },

        StructuralGroan = {
            SoundId = "rbxasset://sounds/action_jump_land.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Heavy concrete rebar creak & groaning
            Volume = 0.70,
            BasePitch = 0.55,
            PitchVariation = 0.05,
            SoundGroup = "Destruction",
            RollOffMinDistance = 20,
            RollOffMaxDistance = 300,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            ThrottleTime = 0.20,
        },

        CriticalStrain = {
            SoundId = "rbxasset://sounds/impact_explosion_03.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Severe structural fracture & groan
            Volume = 0.85,
            BasePitch = 0.40,
            PitchVariation = 0.04,
            SoundGroup = "Destruction",
            RollOffMinDistance = 25,
            RollOffMaxDistance = 340,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            ThrottleTime = 0.25,
        },

        CollapseInitiate = {
            SoundId = "rbxasset://sounds/action_jump_land.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Primary foundation shear & loud crack
            Volume = 1.10,
            BasePitch = 0.75,
            PitchVariation = 0.05,
            SoundGroup = "Destruction",
            RollOffMinDistance = 25,
            RollOffMaxDistance = 360,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        CollapseRumble = {
            SoundId = "rbxasset://sounds/impact_explosion_03.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Heavy building descent & collapsing masonry
            Volume = 1.25,
            BasePitch = 0.65,
            PitchVariation = 0.05,
            SoundGroup = "Destruction",
            RollOffMinDistance = 30,
            RollOffMaxDistance = 420,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        RubbleImpact = {
            SoundId = "rbxasset://sounds/action_jump_land.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Rubble settling onto foundation
            Volume = 0.80,
            BasePitch = 0.85,
            PitchVariation = 0.08,
            SoundGroup = "Destruction",
            RollOffMinDistance = 20,
            RollOffMaxDistance = 300,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        -- ====================================================================
        -- 3. PROGRESSION
        -- ====================================================================
        RewardEarned = {
            SoundId = "rbxasset://sounds/volume_slider.ogg",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Crisp arcade collection ping
            Volume = 0.50,
            BasePitch = 1.40,
            PitchVariation = 0.04,
            SoundGroup = "UI",
            ThrottleTime = 0.08,
        },

        LevelUp = {
            SoundId = "rbxasset://sounds/action_jump.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Triumphant brass fanfare & level chime
            Volume = 0.90,
            BasePitch = 1.80,
            PitchVariation = 0.00,
            SoundGroup = "UI",
        },

        Combo_2 = {
            SoundId = "rbxasset://sounds/volume_slider.ogg",
            PlaceholderAssetId = "rbxassetid://0",
            Volume = 0.55,
            BasePitch = 1.20,
            SoundGroup = "UI",
        },

        Combo_3 = {
            SoundId = "rbxasset://sounds/volume_slider.ogg",
            PlaceholderAssetId = "rbxassetid://0",
            Volume = 0.65,
            BasePitch = 1.40,
            SoundGroup = "UI",
        },

        Combo_4 = {
            SoundId = "rbxasset://sounds/volume_slider.ogg",
            PlaceholderAssetId = "rbxassetid://0",
            Volume = 0.75,
            BasePitch = 1.65,
            SoundGroup = "UI",
        },

        Combo_5 = {
            SoundId = "rbxasset://sounds/impact_explosion_03.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: MAX INFERNO celebratory blazing cue
            Volume = 0.95,
            BasePitch = 1.50,
            SoundGroup = "UI",
            SecondarySoundId = "rbxasset://sounds/volume_slider.ogg",
        },

        -- ====================================================================
        -- 4. UI
        -- ====================================================================
        ButtonClick = {
            SoundId = "rbxasset://sounds/volume_slider.ogg",
            PlaceholderAssetId = "rbxassetid://0",
            Volume = 0.40,
            BasePitch = 1.00,
            PitchVariation = 0.04,
            SoundGroup = "UI",
        },

        CitySelect = {
            SoundId = "rbxasset://sounds/volume_slider.ogg",
            PlaceholderAssetId = "rbxassetid://0",
            Volume = 0.45,
            BasePitch = 1.15,
            SoundGroup = "UI",
        },

        CityPlay = {
            SoundId = "rbxasset://sounds/action_jump.mp3",
            PlaceholderAssetId = "rbxassetid://0",
            Volume = 0.60,
            BasePitch = 1.10,
            SoundGroup = "UI",
        },

        Rebuild = {
            SoundId = "rbxasset://sounds/action_jump_land.mp3",
            PlaceholderAssetId = "rbxassetid://0",
            Volume = 0.70,
            BasePitch = 1.20,
            SoundGroup = "UI",
        },

        UpgradeSuccess = {
            SoundId = "rbxasset://sounds/volume_slider.ogg",
            PlaceholderAssetId = "rbxassetid://0",
            Volume = 0.60,
            BasePitch = 1.50,
            SoundGroup = "UI",
        },

        UpgradeError = {
            SoundId = "rbxasset://sounds/action_jump_land.mp3",
            PlaceholderAssetId = "rbxassetid://0",
            Volume = 0.40,
            BasePitch = 0.50,
            SoundGroup = "UI",
        },

        PanelToggle = {
            SoundId = "rbxasset://sounds/volume_slider.ogg",
            PlaceholderAssetId = "rbxassetid://0",
            Volume = 0.35,
            BasePitch = 0.90,
            SoundGroup = "UI",
        },

        -- ====================================================================
        -- 5. CITY
        -- ====================================================================
        CityComplete = {
            SoundId = "rbxasset://sounds/impact_explosion_03.mp3",
            PlaceholderAssetId = "rbxassetid://0", -- Production: Orchestral victory fanfare
            Volume = 1.00,
            BasePitch = 1.20,
            SoundGroup = "UI",
            SecondarySoundId = "rbxasset://sounds/volume_slider.ogg",
        },
    },

    GetBuildingImpactKey = function(tier: number): string
        if tier == 1 then
            return "Impact_Small"
        elseif tier == 2 then
            return "Impact_Medium"
        elseif tier == 3 then
            return "Impact_Large"
        else
            return "Impact_Landmark"
        end
    end,

    GetCollapseRumbleTierMultiplier = function(tier: number): (number, number)
        -- Returns (volumeMult, pitchMult)
        if tier == 1 then
            return 0.85, 1.10
        elseif tier == 2 then
            return 1.00, 0.95
        elseif tier == 3 then
            return 1.25, 0.80
        else
            -- Landmark
            return 1.50, 0.65
        end
    end,
}

return AudioConfig
