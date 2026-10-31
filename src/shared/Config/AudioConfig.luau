--!strict
--[[
    AudioConfig.luau
    Central sound definitions, spatial profiles, and volume parameters for Titan Rampage.
    Organized by category: Combat, Destruction, Progression, UI, City, Footsteps, Shop, Ambience.
    Library sounds (rbxassetid://...) come from Roblox's free, licensed ProSoundEffects catalogue.
    FallbackSoundId is a built-in engine sound (rbxasset://sounds/...) that AudioController uses
    if the library sound fails to load. Entries with only an engine SoundId still need a real sound.
--]]

export type SoundDef = {
    SoundId: string,
    FallbackSoundId: string?,
    MaxDuration: number?, -- Fades the sound out after this many seconds (for long library clips)
    Looped: boolean?,
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
        UI = { Volume = 0.5, Parent = "Master" }, -- Quieter per specifications
        Music = { Volume = 0.6, Parent = "Master" },
        Ambience = { Volume = 0.45, Parent = "Master" },
    },

    Sounds = {
        -- ====================================================================
        -- 1. COMBAT
        -- ====================================================================
        LeftSwipe = {
            SoundId = "rbxassetid://9120711836", -- ProSoundEffects: Whoosh Fast Swish By 4
            FallbackSoundId = "rbxasset://sounds/action_jump.mp3",
            Volume = 0.85,
            BasePitch = 1.00,
            PitchVariation = 0.06,
            SoundGroup = "Combat",
            RollOffMinDistance = 15,
            RollOffMaxDistance = 250,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        RightSwipe = {
            SoundId = "rbxassetid://9120714219", -- ProSoundEffects: Whoosh Fast Swish By 3
            FallbackSoundId = "rbxasset://sounds/action_jump.mp3",
            Volume = 0.85,
            BasePitch = 1.08,
            PitchVariation = 0.06,
            SoundGroup = "Combat",
            RollOffMinDistance = 15,
            RollOffMaxDistance = 250,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        DownwardSmash = {
            SoundId = "rbxassetid://9120716870", -- ProSoundEffects: Whoosh Fast Swish By 4 (light rumble)
            FallbackSoundId = "rbxasset://sounds/action_jump.mp3",
            Volume = 1.05,
            BasePitch = 0.85,
            PitchVariation = 0.04,
            SoundGroup = "Combat",
            RollOffMinDistance = 20,
            RollOffMaxDistance = 300,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        TailSweepWhoosh = {
            SoundId = "rbxassetid://9114373663", -- ProSoundEffects: Fast Pass By Airy Whooshes Windy 2
            FallbackSoundId = "rbxasset://sounds/action_jump.mp3",
            Volume = 1.05,
            BasePitch = 0.80,
            PitchVariation = 0.05,
            SoundGroup = "Combat",
            RollOffMinDistance = 20,
            RollOffMaxDistance = 320,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        Impact_Small = {
            SoundId = "rbxassetid://9125869505", -- ProSoundEffects: Rock Drops Smashes Impacts Hits 1
            FallbackSoundId = "rbxasset://sounds/action_jump_land.mp3",
            Volume = 0.85,
            BasePitch = 1.15,
            PitchVariation = 0.08,
            SoundGroup = "Combat",
            RollOffMinDistance = 20,
            RollOffMaxDistance = 280,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            ThrottleTime = 0.06,
        },

        Impact_Medium = {
            SoundId = "rbxassetid://9125869505", -- ProSoundEffects: Rock Drops Smashes Impacts Hits 1
            FallbackSoundId = "rbxasset://sounds/action_jump_land.mp3",
            Volume = 0.95,
            BasePitch = 0.95,
            PitchVariation = 0.06,
            SoundGroup = "Combat",
            RollOffMinDistance = 25,
            RollOffMaxDistance = 320,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            ThrottleTime = 0.06,
        },

        Impact_Large = {
            SoundId = "rbxassetid://9118585250", -- ProSoundEffects: Rock Cracks Big Boulder Hits 4
            FallbackSoundId = "rbxasset://sounds/action_jump_land.mp3",
            Volume = 1.15,
            BasePitch = 1.00,
            PitchVariation = 0.05,
            SoundGroup = "Combat",
            RollOffMinDistance = 30,
            RollOffMaxDistance = 380,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            ThrottleTime = 0.08,
        },

        Impact_Landmark = {
            SoundId = "rbxassetid://9125484526", -- ProSoundEffects: Deep Hits Big Reverberant Booms 1
            FallbackSoundId = "rbxasset://sounds/impact_explosion_03.mp3",
            Volume = 1.35,
            BasePitch = 0.90,
            PitchVariation = 0.03,
            SoundGroup = "Combat",
            RollOffMinDistance = 40,
            RollOffMaxDistance = 480,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            ThrottleTime = 0.08,
        },

        StompAnticipation = {
            SoundId = "rbxassetid://9118667573", -- ProSoundEffects: Rock Scrape Deep Grinding Impacts 26
            FallbackSoundId = "rbxasset://sounds/action_falling.ogg",
            Volume = 0.55,
            BasePitch = 0.80,
            PitchVariation = 0.03,
            SoundGroup = "Combat",
            RollOffMinDistance = 25,
            RollOffMaxDistance = 320,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        StompImpact = {
            SoundId = "rbxassetid://9125484367", -- ProSoundEffects: Deep Hits Big Reverberant Booms 2
            FallbackSoundId = "rbxasset://sounds/impact_explosion_03.mp3",
            Volume = 1.40,
            BasePitch = 1.00,
            PitchVariation = 0.04,
            SoundGroup = "Combat",
            RollOffMinDistance = 35,
            RollOffMaxDistance = 450,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        StompDebris = {
            SoundId = "rbxassetid://9125883906", -- ProSoundEffects: Rocks Tumble Falling Down Cliff 1
            FallbackSoundId = "rbxasset://sounds/action_jump_land.mp3",
            Volume = 0.75,
            BasePitch = 1.00,
            PitchVariation = 0.08,
            SoundGroup = "Combat",
            RollOffMinDistance = 25,
            RollOffMaxDistance = 350,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        HeavyStompImpact = {
            SoundId = "rbxassetid://9125484743", -- ProSoundEffects: Deep Hits Big Reverberant Booms 3
            FallbackSoundId = "rbxasset://sounds/impact_explosion_03.mp3",
            Volume = 1.55,
            BasePitch = 0.85,
            PitchVariation = 0.04,
            SoundGroup = "Combat",
            RollOffMinDistance = 45,
            RollOffMaxDistance = 550,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        NeckStrikeImpact = {
            SoundId = "rbxassetid://9118585250", -- ProSoundEffects: Rock Cracks Big Boulder Hits 4
            FallbackSoundId = "rbxasset://sounds/action_jump_land.mp3",
            Volume = 1.25,
            BasePitch = 0.85,
            PitchVariation = 0.05,
            SoundGroup = "Combat",
            RollOffMinDistance = 25,
            RollOffMaxDistance = 380,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        Roar = {
            SoundId = "rbxassetid://9113980319", -- ProSoundEffects: Creature Mix Giant Crab Monster Roar Growl 1
            FallbackSoundId = "rbxasset://sounds/impact_explosion_03.mp3",
            Volume = 1.45,
            BasePitch = 0.90,
            PitchVariation = 0.04,
            SoundGroup = "Combat",
            RollOffMinDistance = 40,
            RollOffMaxDistance = 550,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        BrontaraRoar = {
            SoundId = "rbxassetid://9113980319", -- ProSoundEffects: same roar, pitched down for the bigger titan
            FallbackSoundId = "rbxasset://sounds/impact_explosion_03.mp3",
            Volume = 1.55,
            BasePitch = 0.70,
            PitchVariation = 0.03,
            SoundGroup = "Combat",
            RollOffMinDistance = 45,
            RollOffMaxDistance = 600,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        -- ====================================================================
        -- 2. DESTRUCTION
        -- ====================================================================
        WindowBreak = {
            SoundId = "rbxassetid://9118763694", -- ProSoundEffects: Safety Glass 2
            FallbackSoundId = "rbxasset://sounds/action_jump.mp3",
            MaxDuration = 2.5,
            Volume = 0.70,
            BasePitch = 1.00,
            PitchVariation = 0.12,
            SoundGroup = "Destruction",
            RollOffMinDistance = 15,
            RollOffMaxDistance = 260,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            ThrottleTime = 0.15, -- Prevents glass cacophony on Stomp AoE
        },

        StructuralGroan = {
            SoundId = "rbxassetid://9120826020", -- ProSoundEffects: Wood Crack Slow Splintering Crackling 6
            FallbackSoundId = "rbxasset://sounds/action_jump_land.mp3",
            MaxDuration = 3.0,
            Volume = 0.70,
            BasePitch = 0.80,
            PitchVariation = 0.05,
            SoundGroup = "Destruction",
            RollOffMinDistance = 20,
            RollOffMaxDistance = 300,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            ThrottleTime = 0.20,
        },

        CriticalStrain = {
            SoundId = "rbxassetid://9118667573", -- ProSoundEffects: Rock Scrape Deep Grinding Impacts 26
            FallbackSoundId = "rbxasset://sounds/impact_explosion_03.mp3",
            Volume = 0.85,
            BasePitch = 0.70,
            PitchVariation = 0.04,
            SoundGroup = "Destruction",
            RollOffMinDistance = 25,
            RollOffMaxDistance = 340,
            RollOffMode = Enum.RollOffMode.InverseTapered,
            ThrottleTime = 0.25,
        },

        CollapseGlass = {
            SoundId = "rbxassetid://9114590269", -- ProSoundEffects: Glass Break 1 (crash, shatter, debris)
            FallbackSoundId = "rbxasset://sounds/action_jump_land.mp3",
            Volume = 0.70,
            BasePitch = 0.95,
            PitchVariation = 0.08,
            SoundGroup = "Destruction",
            RollOffMinDistance = 20,
            RollOffMaxDistance = 280,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        CollapseInitiate = {
            SoundId = "rbxassetid://9118585250", -- ProSoundEffects: Rock Cracks Big Boulder Hits 4
            FallbackSoundId = "rbxasset://sounds/action_jump_land.mp3",
            Volume = 1.10,
            BasePitch = 0.90,
            PitchVariation = 0.05,
            SoundGroup = "Destruction",
            RollOffMinDistance = 25,
            RollOffMaxDistance = 360,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        CollapseRumble = {
            SoundId = "rbxassetid://9125883906", -- ProSoundEffects: Rocks Tumble Falling Down Cliff 1
            FallbackSoundId = "rbxasset://sounds/impact_explosion_03.mp3",
            Volume = 1.25,
            BasePitch = 0.90,
            PitchVariation = 0.05,
            SoundGroup = "Destruction",
            RollOffMinDistance = 30,
            RollOffMaxDistance = 420,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        RubbleImpact = {
            SoundId = "rbxassetid://9125869505", -- ProSoundEffects: Rock Drops Smashes Impacts Hits 1
            FallbackSoundId = "rbxasset://sounds/action_jump_land.mp3",
            Volume = 0.80,
            BasePitch = 0.90,
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
            Volume = 0.50,
            BasePitch = 1.40,
            PitchVariation = 0.04,
            SoundGroup = "UI",
            ThrottleTime = 0.08,
        },

        LevelUp = {
            SoundId = "rbxasset://sounds/action_jump.mp3",
            Volume = 0.90,
            BasePitch = 1.80,
            PitchVariation = 0.00,
            SoundGroup = "UI",
        },

        Combo_2 = {
            SoundId = "rbxasset://sounds/volume_slider.ogg",
            Volume = 0.55,
            BasePitch = 1.20,
            SoundGroup = "UI",
        },

        Combo_3 = {
            SoundId = "rbxasset://sounds/volume_slider.ogg",
            Volume = 0.65,
            BasePitch = 1.40,
            SoundGroup = "UI",
        },

        Combo_4 = {
            SoundId = "rbxasset://sounds/volume_slider.ogg",
            Volume = 0.75,
            BasePitch = 1.65,
            SoundGroup = "UI",
        },

        Combo_5 = {
            SoundId = "rbxasset://sounds/impact_explosion_03.mp3",
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
            Volume = 0.40,
            BasePitch = 1.00,
            PitchVariation = 0.04,
            SoundGroup = "UI",
        },

        CitySelect = {
            SoundId = "rbxasset://sounds/volume_slider.ogg",
            Volume = 0.45,
            BasePitch = 1.15,
            SoundGroup = "UI",
        },

        CityPlay = {
            SoundId = "rbxasset://sounds/action_jump.mp3",
            Volume = 0.60,
            BasePitch = 1.10,
            SoundGroup = "UI",
        },

        Rebuild = {
            SoundId = "rbxasset://sounds/action_jump_land.mp3",
            Volume = 0.70,
            BasePitch = 1.20,
            SoundGroup = "UI",
        },

        UpgradeSuccess = {
            SoundId = "rbxasset://sounds/volume_slider.ogg",
            Volume = 0.60,
            BasePitch = 1.50,
            SoundGroup = "UI",
        },

        UpgradeError = {
            SoundId = "rbxasset://sounds/action_jump_land.mp3",
            Volume = 0.40,
            BasePitch = 0.50,
            SoundGroup = "UI",
        },

        PanelToggle = {
            SoundId = "rbxasset://sounds/volume_slider.ogg",
            Volume = 0.35,
            BasePitch = 0.90,
            SoundGroup = "UI",
        },

        -- ====================================================================
        -- 5. CITY
        -- ====================================================================
        CityComplete = {
            SoundId = "rbxasset://sounds/impact_explosion_03.mp3",
            Volume = 1.00,
            BasePitch = 1.20,
            SoundGroup = "UI",
            SecondarySoundId = "rbxasset://sounds/volume_slider.ogg",
        },

        -- ====================================================================
        -- 6. FOOTSTEPS (sprint strides, see AudioController.PlayFootstep)
        -- ====================================================================
        Footstep_Ravager = {
            SoundId = "rbxassetid://9125404769", -- ProSoundEffects: Boomy Footsteps Giant Thumpy Dinosaur 1
            FallbackSoundId = "rbxasset://sounds/action_jump_land.mp3",
            MaxDuration = 0.9, -- Clip holds several steps; keep only the first
            Volume = 0.30, -- Halved in M14: steps were too loud over combat
            BasePitch = 1.15, -- Lighter, quicker basalt stride
            PitchVariation = 0.05,
            SoundGroup = "Combat",
            RollOffMinDistance = 20,
            RollOffMaxDistance = 260,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        Footstep_Brontara = {
            SoundId = "rbxassetid://9125404774", -- ProSoundEffects: Boomy Footsteps Giant Thumpy Dinosaur 2
            FallbackSoundId = "rbxasset://sounds/action_jump_land.mp3",
            MaxDuration = 1.1,
            Volume = 0.40,
            BasePitch = 0.85, -- Heavier, slower quadruped stride
            PitchVariation = 0.04,
            SoundGroup = "Combat",
            RollOffMinDistance = 25,
            RollOffMaxDistance = 320,
            RollOffMode = Enum.RollOffMode.InverseTapered,
        },

        -- ====================================================================
        -- 7. SHOP (engine stand-ins: no licensed cash/power sounds found yet)
        -- ====================================================================
        ShopPurchase = {
            SoundId = "rbxasset://sounds/electronicpingshort.wav", -- Stand-in for a cash-register chime
            Volume = 0.65,
            BasePitch = 1.10,
            SoundGroup = "UI",
            SecondarySoundId = "rbxasset://sounds/snap.mp3",
        },

        ShopPowerSurge = {
            SoundId = "rbxasset://sounds/bass.mp3", -- Stand-in for a power-surge hum (gamepass unlock)
            Volume = 0.80,
            BasePitch = 0.60,
            SoundGroup = "UI",
            SecondarySoundId = "rbxasset://sounds/electronicpingshort.wav",
        },

        -- ====================================================================
        -- 8. AMBIENCE (looped beds, keyed by CityConfig LightingProfile.AmbientLoop)
        -- ====================================================================
        Ambience_KaijuHub = {
            SoundId = "rbxassetid://9112775624", -- ProSoundEffects: Eerie Presence 3 (rumble loop)
            Looped = true,
            Volume = 0.50,
            BasePitch = 0.80, -- Deeper volcanic rumble
            SoundGroup = "Ambience",
        },

        Ambience_SmallTown = {
            SoundId = "rbxassetid://9119679596", -- ProSoundEffects: Surf Waves Crash On Shore 4
            Looped = true,
            Volume = 0.55,
            BasePitch = 1.00,
            SoundGroup = "Ambience",
        },

        Ambience_Metrovale = {
            SoundId = "rbxassetid://9112772296", -- ProSoundEffects: Distant Traffic 3 (loop)
            Looped = true,
            Volume = 0.60,
            BasePitch = 1.00,
            SoundGroup = "Ambience",
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
