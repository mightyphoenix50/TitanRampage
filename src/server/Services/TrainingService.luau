--!strict
--[[
    TrainingService.luau
    Titan Punching Bags (Milestone 15).
    Responsibility:
    - Grants Training Power when a titan's ability lands on a punching bag (bags are hub training
      dummies with a BagId attribute; DestructionService reports the hits after its reach check).
    - Enforces the TrainingConfig rules: one grant per second, diminishing gains toward a cap that
      only city clears raise, bag Power requirements, and fatigue on one bag without other hits.
    - Training Power adds Titan Power and +0.25% ability damage (TitanRegistry / DestructionService).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local TrainingConfig = require(ConfigFolder:WaitForChild("TrainingConfig") :: ModuleScript)
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService") :: ModuleScript)
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService") :: ModuleScript)

local function getRemote(name: string): RemoteEvent
    local existing = RemotesFolder:FindFirstChild(name)
    if existing and existing:IsA("RemoteEvent") then return existing end
    local remote = Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = RemotesFolder
    return remote
end

local TrainingFeedbackRemote = getRemote("TrainingFeedback")

type Session = {
    BagId: string,
    Since: number, -- When the player started pounding this bag without hitting anything else
    LastHit: number,
    LastGrant: number,
}

local TrainingService = {}

local sessions: { [Player]: Session } = {}

local function totalClears(profile: any): number
    local total = 0
    for _, city in pairs(profile.Cities) do
        total += city.Clears
    end
    return total
end

function TrainingService.GetCap(player: Player): number
    local profile = PlayerDataService.GetProfile(player)
    return if profile then TrainingConfig.GetCap(totalClears(profile)) else TrainingConfig.CapBase
end

--[=[
    Called by DestructionService when a player's ability hits a punching bag.
]=]
function TrainingService.RecordBagHit(player: Player, bag: Instance)
    local bagId = bag:GetAttribute("BagId")
    local def = type(bagId) == "string" and TrainingConfig.Bags[bagId]
    if not def then return end
    local profile = PlayerDataService.GetProfile(player)
    if not profile then return end

    -- Bag requirement uses Power from upgrades and levels only, so training can't unlock bags
    local untrainedPower = ProgressionService.GetTitanPower(player) - math.floor(profile.TrainingPower or 0)
    if untrainedPower < def.RequiredPower then
        TrainingFeedbackRemote:FireClient(player, "BagLocked", { BagName = def.DisplayName, RequiredPower = def.RequiredPower })
        return
    end

    local now = os.clock()
    local session = sessions[player]
    if not session or session.BagId ~= def.Id or now - session.LastHit > TrainingConfig.FatigueResetIdle then
        session = { BagId = def.Id, Since = now, LastHit = now, LastGrant = 0 }
        sessions[player] = session
    end
    session.LastHit = now

    -- Everyone nearby sees the bag swing; only one grant per interval however fast the titan attacks
    TrainingFeedbackRemote:FireAllClients("BagSwing", { Bag = bag, Attacker = player })
    if now - session.LastGrant < TrainingConfig.GrantInterval then return end
    session.LastGrant = now

    local cap = TrainingConfig.GetCap(totalClears(profile))
    local fatigued = now - session.Since >= TrainingConfig.FatigueAfter
    local gain = TrainingConfig.GetGain(def, profile.TrainingPower or 0, cap, fatigued)
    if gain <= 0 then
        TrainingFeedbackRemote:FireClient(player, "BagCapped", { Cap = cap })
        return
    end

    local newTP = 0
    PlayerDataService.UpdateProfile(player, function(prof)
        prof.TrainingPower = math.min(cap, (prof.TrainingPower or 0) + gain)
        newTP = prof.TrainingPower
    end)
    ProgressionService.RefreshTitanPower(player)
    TrainingFeedbackRemote:FireClient(player, "BagGain", {
        Bag = bag,
        Gain = gain,
        TrainingPower = newTP,
        Cap = cap,
        Fatigued = fatigued,
    })
end

--[=[
    Any non-bag hit (a city building or a boss) clears bag fatigue.
]=]
function TrainingService.NoteOtherHit(player: Player)
    sessions[player] = nil
end

function TrainingService.Init()
    print("[TrainingService] Initializing TrainingService...")
    Players.PlayerRemoving:Connect(function(player)
        sessions[player] = nil
    end)
end

function TrainingService.Start()
    print("[TrainingService] TrainingService started.")
end

return TrainingService
