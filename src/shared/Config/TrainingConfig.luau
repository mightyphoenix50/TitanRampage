--!strict
--[[
    TrainingConfig.luau
    Titan Punching Bags (Milestone 15): light Training Power from hitting bags in the hub.
    Tuned so destroying cities always grows Power faster (see the balance check in the M15 changelog):
    - Grants are throttled to one per GrantInterval, so faster attacks don't train faster.
    - Each grant shrinks as Training Power nears the cap: gain = TPPerGrant * (1 - TP / cap).
    - The cap only rises with city clears: CapBase + CapPerClear * total clears, up to CapMax.
    - Pounding one bag for FatigueAfter seconds without hitting anything else cuts gains to FatigueFactor.
    - Bags never give cash or XP.
--]]

export type BagDef = {
    Id: string,
    DisplayName: string,
    RequiredPower: number, -- Power from upgrades and levels (Training Power excluded)
    TPPerGrant: number,
    Color: Color3,
}

local TrainingConfig = {}

TrainingConfig.GrantInterval = 1.0
TrainingConfig.CapBase = 40
TrainingConfig.CapPerClear = 15
TrainingConfig.CapMax = 160
TrainingConfig.FatigueAfter = 60
TrainingConfig.FatigueFactor = 0.25
TrainingConfig.FatigueResetIdle = 20 -- Seconds away from bags that also clear fatigue

TrainingConfig.Bags = {
    Basic = {
        Id = "Basic",
        DisplayName = "Basic Punching Bag",
        RequiredPower = 0,
        TPPerGrant = 0.04, -- ~2.4 TP/min at 0 TP
        Color = Color3.fromRGB(150, 110, 80),
    },
    Reinforced = {
        Id = "Reinforced",
        DisplayName = "Reinforced Punching Bag",
        RequiredPower = 250,
        TPPerGrant = 0.05, -- ~3 TP/min at 0 TP
        Color = Color3.fromRGB(110, 120, 140),
    },
    Magma = {
        Id = "Magma",
        DisplayName = "Magma Punching Bag",
        RequiredPower = 500,
        TPPerGrant = 0.06, -- ~3.6 TP/min at 0 TP
        Color = Color3.fromRGB(255, 96, 24),
    },
} :: { [string]: BagDef }

function TrainingConfig.GetCap(totalClears: number): number
    return math.min(TrainingConfig.CapMax, TrainingConfig.CapBase + TrainingConfig.CapPerClear * math.max(0, totalClears))
end

-- Pure gain formula shared by TrainingService and the balance simulation
function TrainingConfig.GetGain(bag: BagDef, trainingPower: number, cap: number, fatigued: boolean): number
    local room = math.max(0, 1 - trainingPower / math.max(cap, 1))
    return bag.TPPerGrant * room * (if fatigued then TrainingConfig.FatigueFactor else 1)
end

return TrainingConfig
