--!strict
--[[
    ServerBootstrap.server.luau
    Master entry point for the Titan Rampage server.
    Initializes core services in deterministic order: Data -> City -> Destruction -> Progression -> Monster.
--]]

local ServerScriptService = game:GetService("ServerScriptService")
local ServicesFolder = ServerScriptService:WaitForChild("Services")

local PlayerDataService = require(ServicesFolder:WaitForChild("PlayerDataService") :: ModuleScript)
local MonetizationService = require(ServicesFolder:WaitForChild("MonetizationService") :: ModuleScript)
local CityService = require(ServicesFolder:WaitForChild("CityService") :: ModuleScript)
local DestructionService = require(ServicesFolder:WaitForChild("DestructionService") :: ModuleScript)
local ProgressionService = require(ServicesFolder:WaitForChild("ProgressionService") :: ModuleScript)
local DropService = require(ServicesFolder:WaitForChild("DropService") :: ModuleScript)
local HubService = require(ServicesFolder:WaitForChild("HubService") :: ModuleScript)
local MonsterService = require(ServicesFolder:WaitForChild("MonsterService") :: ModuleScript)

local services = {
    PlayerDataService,
    MonetizationService,
    CityService,
    DestructionService,
    ProgressionService,
    DropService,
    HubService,
    MonsterService,
}

print("[Titan Rampage] Initializing server services...")
for _, service in ipairs(services) do
    if type(service.Init) == "function" then service.Init() end
end

print("[Titan Rampage] Starting server services...")
for _, service in ipairs(services) do
    if type(service.Start) == "function" then service.Start() end
end

print("[Titan Rampage] Server successfully initialized!")
