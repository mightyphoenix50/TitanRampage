--!strict
--[[
    MonetizationService.luau
    Authoritative monetization, receipt processing, and gamepass service for Titan Rampage.
    Responsibility:
    - Handles MarketplaceService.ProcessReceipt idempotently and securely.
    - Caches and validates Gamepass ownership with DataStore fallbacks.
    - Manages Robux purchases (Double Cash, Double XP, Instant Rebuild, VIP Aura, Auto Collect).
    - Processes Developer Products (Cash Surges, XP Blasts, Cooldown Resets, Combo Shields).
    - Provides Studio sandbox simulation mode for zero-cost developer testing.
    - Attaches radiant VIP Titan Auras to eligible players.
--]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local MonetizationConfig = require(ConfigFolder:WaitForChild("MonetizationConfig") :: ModuleScript)
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService") :: ModuleScript)

-- Lazy reference to ProgressionService to prevent circular require
local ProgressionService = nil
local function getProgressionService()
    if not ProgressionService then
        pcall(function()
            ProgressionService = require(script.Parent:WaitForChild("ProgressionService") :: ModuleScript)
        end)
    end
    return ProgressionService
end

-- Ensure remotes exist
local ShopActionRemote = RemotesFolder:FindFirstChild("ShopAction") :: RemoteFunction?
if not ShopActionRemote then
    ShopActionRemote = Instance.new("RemoteFunction")
    ShopActionRemote.Name = "ShopAction"
    ShopActionRemote.Parent = RemotesFolder
end

local ShopFeedbackRemote = RemotesFolder:FindFirstChild("ShopFeedback") :: RemoteEvent?
if not ShopFeedbackRemote then
    ShopFeedbackRemote = Instance.new("RemoteEvent")
    ShopFeedbackRemote.Name = "ShopFeedback"
    ShopFeedbackRemote.Parent = RemotesFolder
end

local MonetizationService = {}

-- Session cached gamepass ownership: [userId] -> { [passId] = true }
local cachedGamepasses: { [number]: { [string]: boolean } } = {}

-- Active Combo Shields: [userId] -> expiration timestamp
local comboShieldExpirations: { [number]: number } = {}

--[=[
    Checks whether a player owns a gamepass, consulting in-memory cache,
    persistent profile, and MarketplaceService API (with error pcall protection).
]=]
function MonetizationService.HasGamepass(player: Player, passId: string): boolean
    local userId = player.UserId
    if not cachedGamepasses[userId] then
        cachedGamepasses[userId] = {}
    end

    -- 1. Check local session cache
    if cachedGamepasses[userId][passId] == true then
        return true
    end

    -- 2. Check persistent DataStore profile (Studio mock or saved state)
    if PlayerDataService.HasGamepass(player, passId) then
        cachedGamepasses[userId][passId] = true
        return true
    end

    -- 3. Check official Roblox Gamepass API if AssetId > 0
    local passDef = MonetizationConfig.GetGamepass(passId)
    if passDef and passDef.AssetId > 0 then
        local success, owns = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(userId, passDef.AssetId)
        end)
        if success and owns == true then
            cachedGamepasses[userId][passId] = true
            PlayerDataService.SetGamepass(player, passId, true)
            return true
        end
    end

    return false
end

--[=[
    Returns the cash multiplier (1.0 default, 2.0 with DoubleCash gamepass).
]=]
function MonetizationService.GetCashMultiplier(player: Player): number
    if MonetizationService.HasGamepass(player, "DoubleCash") then
        return 2.0
    end
    return 1.0
end

--[=[
    Returns the XP multiplier (1.0 default, 2.0 with DoubleXP gamepass).
]=]
function MonetizationService.GetXPMultiplier(player: Player): number
    if MonetizationService.HasGamepass(player, "DoubleXP") then
        return 2.0
    end
    return 1.0
end

function MonetizationService.HasInstantRebuild(player: Player): boolean
    return MonetizationService.HasGamepass(player, "InstantRebuild")
end

function MonetizationService.HasVIPTitanAura(player: Player): boolean
    return MonetizationService.HasGamepass(player, "VIPTitanAura")
end

function MonetizationService.HasAutoCollect(player: Player): boolean
    if player:GetAttribute("HasAutoCollect") == true then
        return true
    end
    local owns = MonetizationService.HasGamepass(player, "AutoCollect")
    if owns then
        player:SetAttribute("HasAutoCollect", true)
    end
    return owns
end

--[=[
    Checks if player has an active Combo Shield.
]=]
function MonetizationService.IsComboShieldActive(player: Player): boolean
    local exp = comboShieldExpirations[player.UserId]
    if exp and os.clock() < exp then
        return true
    end
    return false
end

--[=[
    Applies the VIP Radiant Titan Aura cosmetic to a Titan character model.
]=]
function MonetizationService.ApplyVIPAura(player: Player, character: Model)
    if not MonetizationService.HasVIPTitanAura(player) then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    if not rootPart or not rootPart:IsA("BasePart") then return end

    if rootPart:FindFirstChild("VIPTitanCorona") then return end

    local auraAttachment = Instance.new("Attachment")
    auraAttachment.Name = "VIPTitanCorona"
    auraAttachment.Parent = rootPart

    -- Radiant Golden/Amber Particle Emitter
    local emberEmitter = Instance.new("ParticleEmitter")
    emberEmitter.Name = "VIPEmbers"
    emberEmitter.Texture = "rbxassetid://6017260533" -- Soft star/ember
    emberEmitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 100)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 170, 30)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 20)),
    })
    emberEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 3),
        NumberSequenceKeypoint.new(0.6, 6),
        NumberSequenceKeypoint.new(1, 0),
    })
    emberEmitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.8, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    emberEmitter.Lifetime = NumberRange.new(1.2, 2.0)
    emberEmitter.Rate = 25
    emberEmitter.Speed = NumberRange.new(5, 12)
    emberEmitter.SpreadAngle = Vector2.new(180, 180)
    emberEmitter.LightEmission = 0.85
    emberEmitter.LightInfluence = 0
    emberEmitter.Parent = auraAttachment

    -- Golden corona PointLight
    local vipLight = Instance.new("PointLight")
    vipLight.Name = "VIPLight"
    vipLight.Color = Color3.fromRGB(255, 200, 80)
    vipLight.Brightness = 3.5
    vipLight.Range = 36
    vipLight.Shadows = false
    vipLight.Parent = auraAttachment

    print(string.format("[MonetizationService] ✨ VIP Radiant Aura applied to %s's Titan!", player.Name))
end

--[=[
    Awards developer product rewards to the player.
]=]
local function awardProduct(player: Player, productDef: MonetizationConfig.ProductDef): boolean
    local progService = getProgressionService()

    if productDef.RewardType == "Cash" then
        if progService then
            progService.AddRewards(player, productDef.RewardAmount, 0, 0)
        else
            PlayerDataService.UpdateProfile(player, function(profile)
                profile.Cash += productDef.RewardAmount
            end)
        end
        print(string.format("[MonetizationService] 💰 Awarded +$%d Cash to %s", productDef.RewardAmount, player.Name))
        return true

    elseif productDef.RewardType == "XP" then
        if progService then
            progService.AddRewards(player, 0, 0, productDef.RewardAmount)
        else
            PlayerDataService.UpdateProfile(player, function(profile)
                profile.XP += productDef.RewardAmount
            end)
        end
        print(string.format("[MonetizationService] ⚡ Awarded +%d XP to %s", productDef.RewardAmount, player.Name))
        return true

    elseif productDef.RewardType == "CooldownReset" then
        -- Clear cooldowns on client
        if ShopFeedbackRemote then
            ShopFeedbackRemote:FireClient(player, "CooldownsReset", {
                Message = "All ability cooldowns have been instantly refreshed!",
            })
        end
        print(string.format("[MonetizationService] ⏱️ Reset all ability cooldowns for %s", player.Name))
        return true

    elseif productDef.RewardType == "ComboShield" then
        comboShieldExpirations[player.UserId] = os.clock() + productDef.RewardAmount
        player:SetAttribute("ComboShieldActive", true)
        task.delay(productDef.RewardAmount, function()
            if player.Parent and os.clock() >= (comboShieldExpirations[player.UserId] or 0) then
                player:SetAttribute("ComboShieldActive", false)
            end
        end)
        if ShopFeedbackRemote then
            ShopFeedbackRemote:FireClient(player, "ComboShieldActivated", {
                Duration = productDef.RewardAmount,
                Message = "60-second Combo Shield activated! Combo will not reset!",
            })
        end
        print(string.format("[MonetizationService] 🛡️ Activated 60s Combo Shield for %s", player.Name))
        return true
    end

    return false
end

--[=[
    Server-authoritative Developer Product receipt handler (Roblox standard).
]=]
local function processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        -- Player left or not in server; ask Roblox to retry later
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- Idempotency check: has this receipt already been fulfilled?
    local purchaseId = tostring(receiptInfo.PurchaseId)
    if PlayerDataService.IsReceiptProcessed(player, purchaseId) then
        print(string.format("[MonetizationService] ⚠️ Receipt %s already processed for %s. Skipping duplicate.", purchaseId, player.Name))
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    -- Locate ProductDef by AssetId
    local productDef = MonetizationConfig.GetProductByAssetId(receiptInfo.ProductId)
    if not productDef then
        warn(string.format("[MonetizationService] ❌ Unknown ProductId %s purchased by %s", tostring(receiptInfo.ProductId), player.Name))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- Grant product rewards
    local success = awardProduct(player, productDef)
    if not success then
        warn(string.format("[MonetizationService] ❌ Failed to award product %s to %s", productDef.Id, player.Name))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- Persist idempotency record
    PlayerDataService.MarkReceiptProcessed(player, purchaseId)

    -- Notify client
    if ShopFeedbackRemote then
        ShopFeedbackRemote:FireClient(player, "PurchaseSuccess", {
            ItemType = "Product",
            Id = productDef.Id,
            DisplayName = productDef.DisplayName,
            Message = string.format("Purchased %s successfully!", productDef.DisplayName),
        })
    end

    print(string.format("[MonetizationService] ✅ Successfully processed receipt %s for %s (%s)", purchaseId, player.Name, productDef.DisplayName))
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

--[=[
    Initializes monetization services and remote callbacks.
]=]
function MonetizationService.Init()
    print("[MonetizationService] Initializing MonetizationService...")

    -- Bind Roblox authoritative receipt processor
    MarketplaceService.ProcessReceipt = processReceipt

    -- Listen to gamepass purchase completion
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passAssetId: number, wasPurchased: boolean)
        if not wasPurchased then return end
        local passDef = MonetizationConfig.GetGamepassByAssetId(passAssetId)
        if not passDef then return end

        if not cachedGamepasses[player.UserId] then
            cachedGamepasses[player.UserId] = {}
        end
        cachedGamepasses[player.UserId][passDef.Id] = true
        PlayerDataService.SetGamepass(player, passDef.Id, true)

        -- If VIP Aura bought, apply immediately
        if passDef.Id == "VIPTitanAura" and player.Character then
            MonetizationService.ApplyVIPAura(player, player.Character)
        end

        if ShopFeedbackRemote then
            ShopFeedbackRemote:FireClient(player, "PurchaseSuccess", {
                ItemType = "Gamepass",
                Id = passDef.Id,
                DisplayName = passDef.DisplayName,
                Message = string.format("Unlocked %s permanently!", passDef.DisplayName),
            })
        end

        print(string.format("[MonetizationService] 🎉 %s purchased Gamepass: %s!", player.Name, passDef.DisplayName))
    end)

    -- Handle Shop Action invocations from client
    if ShopActionRemote then
        ShopActionRemote.OnServerInvoke = function(player: Player, action: string, itemId: any): any
            if action == "GetShopData" then
                local ownedPasses: { [string]: boolean } = {}
                for passId, _ in pairs(MonetizationConfig.Gamepasses) do
                    ownedPasses[passId] = MonetizationService.HasGamepass(player, passId)
                end

                return {
                    Gamepasses = MonetizationConfig.GetGamepassesList(),
                    Products = MonetizationConfig.GetProductsList(),
                    OwnedGamepasses = ownedPasses,
                    IsStudio = RunService:IsStudio(),
                }

            elseif action == "PromptPurchase" then
                local itemType = itemId and itemId.Type
                local id = itemId and itemId.Id

                if itemType == "Gamepass" then
                    local passDef = MonetizationConfig.GetGamepass(id)
                    if not passDef then return { Success = false, Reason = "Invalid gamepass" } end

                    if MonetizationService.HasGamepass(player, id) then
                        return { Success = false, Reason = "Already owned!" }
                    end

                    if passDef.AssetId > 0 and not RunService:IsStudio() then
                        MarketplaceService:PromptGamePassPurchase(player, passDef.AssetId)
                        return { Success = true, Action = "Prompted" }
                    else
                        -- In Studio or placeholder AssetId: Use Sandbox mock purchase
                        return MonetizationService.HandleSandboxBuy(player, "Gamepass", id)
                    end

                elseif itemType == "Product" then
                    local prodDef = MonetizationConfig.GetProduct(id)
                    if not prodDef then return { Success = false, Reason = "Invalid product" } end

                    if prodDef.AssetId > 0 and not RunService:IsStudio() then
                        MarketplaceService:PromptProductPurchase(player, prodDef.AssetId)
                        return { Success = true, Action = "Prompted" }
                    else
                        -- In Studio or placeholder AssetId: Use Sandbox mock purchase
                        return MonetizationService.HandleSandboxBuy(player, "Product", id)
                    end
                end

                return { Success = false, Reason = "Unknown action" }

            elseif action == "SandboxBuy" then
                local itemType = itemId and itemId.Type
                local id = itemId and itemId.Id
                return MonetizationService.HandleSandboxBuy(player, itemType, id)
            end

            return { Success = false, Reason = "Unknown shop request" }
        end
    end

    -- Cleanup on player leave
    Players.PlayerRemoving:Connect(function(player)
        cachedGamepasses[player.UserId] = nil
        comboShieldExpirations[player.UserId] = nil
    end)
end

--[=[
    Safe sandbox testing method for Studio / local test runs without real Robux.
]=]
function MonetizationService.HandleSandboxBuy(player: Player, itemType: string?, itemId: string?): any
    if not itemType or not itemId then
        return { Success = false, Reason = "Missing item information" }
    end

    if itemType == "Gamepass" then
        local passDef = MonetizationConfig.GetGamepass(itemId)
        if not passDef then
            return { Success = false, Reason = "Gamepass not found" }
        end

        if not cachedGamepasses[player.UserId] then
            cachedGamepasses[player.UserId] = {}
        end
        cachedGamepasses[player.UserId][itemId] = true
        PlayerDataService.SetGamepass(player, itemId, true)

        if itemId == "VIPTitanAura" and player.Character then
            MonetizationService.ApplyVIPAura(player, player.Character)
        end

        if ShopFeedbackRemote then
            ShopFeedbackRemote:FireClient(player, "PurchaseSuccess", {
                ItemType = "Gamepass",
                Id = passDef.Id,
                DisplayName = passDef.DisplayName,
                Message = string.format("[TEST SANDBOX] Unlocked %s!", passDef.DisplayName),
            })
        end

        print(string.format("[MonetizationService] 🧪 [SANDBOX] %s unlocked gamepass: %s", player.Name, passDef.DisplayName))
        return { Success = true, Message = "Unlocked via Studio Sandbox" }

    elseif itemType == "Product" then
        local prodDef = MonetizationConfig.GetProduct(itemId)
        if not prodDef then
            return { Success = false, Reason = "Product not found" }
        end

        awardProduct(player, prodDef)

        if ShopFeedbackRemote then
            ShopFeedbackRemote:FireClient(player, "PurchaseSuccess", {
                ItemType = "Product",
                Id = prodDef.Id,
                DisplayName = prodDef.DisplayName,
                Message = string.format("[TEST SANDBOX] Purchased %s!", prodDef.DisplayName),
            })
        end

        print(string.format("[MonetizationService] 🧪 [SANDBOX] %s granted product: %s", player.Name, prodDef.DisplayName))
        return { Success = true, Message = "Granted via Studio Sandbox" }
    end

    return { Success = false, Reason = "Invalid item type" }
end

--[=[
    Starts Monetization operations and hooks player character spawns.
]=]
function MonetizationService.Start()
    print("[MonetizationService] MonetizationService started.")

    local function onCharacterAdded(player: Player, character: Model)
        task.wait(0.2)
        player:SetAttribute("HasAutoCollect", MonetizationService.HasAutoCollect(player))
        if MonetizationService.HasVIPTitanAura(player) then
            MonetizationService.ApplyVIPAura(player, character)
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            onCharacterAdded(player, player.Character)
        end
        player.CharacterAdded:Connect(function(char)
            onCharacterAdded(player, char)
        end)
    end

    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(char)
            onCharacterAdded(player, char)
        end)
    end)
end

return MonetizationService
