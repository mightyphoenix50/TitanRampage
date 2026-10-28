--!strict
--[[
    FootstepController.client.luau
    Client-side titan footsteps for Titan Rampage (Milestone 13).
    Responsibility:
    - Plays stride-synced footsteps for every grounded, moving titan, including other players'.
    - Paces strides by distance travelled (TitanRegistry AudioProfile.FootstepStride), so faster
      titans step more often; walking strides are quiet, sprint strides louder.
    - Adds a light camera dip on the local player's sprint strides.
    Purely cosmetic: driven by replicated velocity, no remotes.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local TitanRegistry = require(SharedFolder:WaitForChild("TitanRegistry") :: ModuleScript)
local AudioController = require(SharedFolder:WaitForChild("AudioController") :: ModuleScript)

local MIN_STEP_SPEED = 4 -- Studs/s below which a titan is treated as standing still
local MAX_HEARING_DISTANCE = 400 -- Skip titans the local camera can't hear anyway
local DEFAULT_STRIDE = 14
local CAMERA_DIP_RATIO = 0.5 -- Sprint ratio above which local strides dip the camera
local CAMERA_DIP_DEPTH = 0.35

-- Distance travelled since each character's last footstep
local strideProgress: { [Model]: number } = {}

local cameraTween: Tween? = nil

local function dipCamera(humanoid: Humanoid, ratio: number)
    if cameraTween then cameraTween:Cancel() end
    humanoid.CameraOffset = Vector3.new(0, -CAMERA_DIP_DEPTH * ratio, 0)
    local tween =
        TweenService:Create(humanoid, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CameraOffset = Vector3.zero })
    cameraTween = tween
    tween:Play()
end

local function stepCharacter(character: Model, dt: number, listenerPos: Vector3)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not humanoid or not root or humanoid.Health <= 0 then
        strideProgress[character] = nil
        return
    end
    if humanoid.FloorMaterial == Enum.Material.Air then return end
    if (root.Position - listenerPos).Magnitude > MAX_HEARING_DISTANCE then return end

    local velocity = root.AssemblyLinearVelocity
    local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
    if speed < MIN_STEP_SPEED then
        strideProgress[character] = 0
        return
    end

    local titanId = (character:GetAttribute("TitanId") :: string?) or "Ravager"
    local def = TitanRegistry.Get(titanId)
    if not def then return end

    local stride = def.AudioProfile.FootstepStride or DEFAULT_STRIDE
    local progress = (strideProgress[character] or 0) + speed * dt
    if progress < stride then
        strideProgress[character] = progress
        return
    end
    strideProgress[character] = progress - stride

    local walkSpeed = def.WalkSpeed
    local sprintSpeed = def.SprintSpeed or walkSpeed * 1.5
    local ratio = math.clamp((speed - walkSpeed) / math.max(sprintSpeed - walkSpeed, 1), 0, 1)

    AudioController.PlayFootstep(titanId, root, ratio)

    if character == LocalPlayer.Character and ratio >= CAMERA_DIP_RATIO then dipCamera(humanoid, ratio) end
end

RunService.Heartbeat:Connect(function(dt: number)
    local camera = workspace.CurrentCamera
    if not camera then return end
    local listenerPos = camera.CFrame.Position

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character and character:GetAttribute("TitanId") ~= nil then stepCharacter(character, dt, listenerPos) end
    end

    -- Drop entries for characters that have despawned
    for character in pairs(strideProgress) do
        if character.Parent == nil then strideProgress[character] = nil end
    end
end)

print("[FootstepController] Titan footstep controller initialized.")
