--!strict
--[[
    TitanConfig.luau
    Central configuration and backward-compatible entry point for Titans in Titan Rampage.
    Delegates to ReplicatedStorage.Shared.TitanRegistry.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TitanRegistry = require(ReplicatedStorage.Shared:WaitForChild("TitanRegistry") :: ModuleScript)

export type AbilitySlot = TitanRegistry.AbilitySlot
export type AbilityDef = TitanRegistry.AbilityDef
export type TitanDef = TitanRegistry.TitanDef

return TitanRegistry
