--!strict
--[[
    ShopHUD.client.luau
    Client UI controller for the Titan Rampage Marketplace.
    Responsibility:
    - Renders the tabbed modal Shop GUI (Gamepasses, Currency Packs, Combat Boosts).
    - Queries server-authoritative shop data via ShopAction RemoteFunction.
    - Prompts Robux purchases in production and seamless mock purchases in Studio sandbox mode.
    - Listens to ShopFeedback for immediate reward notifications and ownership updates.
    - Binds to keybind (B), HUD Shop button, and Hub Market Pavilion ProximityPrompt.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local MainUI = (script.Parent :: any):IsA("ScreenGui") and script.Parent or PlayerGui:WaitForChild("MainUI") :: ScreenGui

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local SharedFolder = ReplicatedStorage:WaitForChild("Shared")

local MonetizationConfig = require(ConfigFolder:WaitForChild("MonetizationConfig") :: ModuleScript)
local AudioController = require(SharedFolder:WaitForChild("AudioController") :: ModuleScript)

local ShopActionRemote = RemotesFolder:WaitForChild("ShopAction") :: RemoteFunction
local ShopFeedbackRemote = RemotesFolder:WaitForChild("ShopFeedback") :: RemoteEvent
local SprintToggleBindable = RemotesFolder:FindFirstChild("SprintToggle") :: BindableEvent?

-- Check or create ShopToggle BindableEvent
local ShopToggleBindable = RemotesFolder:FindFirstChild("ShopToggle") :: BindableEvent?
if not ShopToggleBindable then
    ShopToggleBindable = Instance.new("BindableEvent")
    ShopToggleBindable.Name = "ShopToggle"
    ShopToggleBindable.Parent = RemotesFolder
end

-- UI Construction: ShopPanel
local ShopPanel = MainUI:FindFirstChild("ShopPanel") :: Frame?
if not ShopPanel then
    ShopPanel = Instance.new("Frame")
    ShopPanel.Name = "ShopPanel"
    ShopPanel.Size = UDim2.new(0, 680, 0, 490)
    ShopPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
    ShopPanel.AnchorPoint = Vector2.new(0.5, 0.5)
    ShopPanel.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
    ShopPanel.BorderSizePixel = 0
    ShopPanel.Visible = false
    ShopPanel.ZIndex = 30
    ShopPanel.Parent = MainUI

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = ShopPanel

    local stroke = Instance.new("UIStroke")
    stroke.Name = "PanelStroke"
    stroke.Color = Color3.fromRGB(255, 140, 20)
    stroke.Thickness = 2
    stroke.Parent = ShopPanel
end

-- Header
local Header = ShopPanel:FindFirstChild("Header") :: Frame?
if not Header then
    Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 56)
    Header.BackgroundColor3 = Color3.fromRGB(26, 32, 44)
    Header.BorderSizePixel = 0
    Header.ZIndex = 31
    Header.Parent = ShopPanel

    local hCorner = Instance.new("UICorner")
    hCorner.CornerRadius = UDim.new(0, 10)
    hCorner.Parent = Header

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -60, 0, 28)
    title.Position = UDim2.new(0, 18, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "🛒 TITAN MARKETPLACE"
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 20
    title.TextColor3 = Color3.fromRGB(255, 200, 40)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 32
    title.Parent = Header

    local subTitle = Instance.new("TextLabel")
    subTitle.Name = "SubTitle"
    subTitle.Size = UDim2.new(1, -60, 0, 18)
    subTitle.Position = UDim2.new(0, 18, 0, 32)
    subTitle.BackgroundTransparency = 1
    subTitle.Text = "Unlock Permanent Multipliers • Currency Packs • Combat Boosts"
    subTitle.Font = Enum.Font.Gotham
    subTitle.TextSize = 11
    subTitle.TextColor3 = Color3.fromRGB(160, 180, 200)
    subTitle.TextXAlignment = Enum.TextXAlignment.Left
    subTitle.ZIndex = 32
    subTitle.Parent = Header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 36, 0, 36)
    closeBtn.Position = UDim2.new(1, -44, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(45, 52, 68)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.ZIndex = 32
    closeBtn.Parent = Header

    local cbCorner = Instance.new("UICorner")
    cbCorner.CornerRadius = UDim.new(0, 6)
    cbCorner.Parent = closeBtn
end

local CloseButton = Header:WaitForChild("CloseButton") :: TextButton

-- Tabs Bar
local TabsBar = ShopPanel:FindFirstChild("TabsBar") :: Frame?
if not TabsBar then
    TabsBar = Instance.new("Frame")
    TabsBar.Name = "TabsBar"
    TabsBar.Size = UDim2.new(1, -28, 0, 36)
    TabsBar.Position = UDim2.new(0, 14, 0, 64)
    TabsBar.BackgroundTransparency = 1
    TabsBar.ZIndex = 31
    TabsBar.Parent = ShopPanel

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 8)
    layout.Parent = TabsBar
end

-- Items Container
local ItemsScroll = ShopPanel:FindFirstChild("ItemsScroll") :: ScrollingFrame?
if not ItemsScroll then
    ItemsScroll = Instance.new("ScrollingFrame")
    ItemsScroll.Name = "ItemsScroll"
    ItemsScroll.Size = UDim2.new(1, -28, 1, -145)
    ItemsScroll.Position = UDim2.new(0, 14, 0, 106)
    ItemsScroll.BackgroundColor3 = Color3.fromRGB(14, 17, 24)
    ItemsScroll.BackgroundTransparency = 0.5
    ItemsScroll.BorderSizePixel = 0
    ItemsScroll.ScrollBarThickness = 6
    ItemsScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 140, 20)
    ItemsScroll.ZIndex = 31
    ItemsScroll.Parent = ShopPanel

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 8)
    sCorner.Parent = ItemsScroll

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 8)
    listLayout.Parent = ItemsScroll
end

-- Footer Info Bar
local FooterBar = ShopPanel:FindFirstChild("FooterBar") :: Frame?
if not FooterBar then
    FooterBar = Instance.new("Frame")
    FooterBar.Name = "FooterBar"
    FooterBar.Size = UDim2.new(1, -28, 0, 28)
    FooterBar.Position = UDim2.new(0, 14, 1, -34)
    FooterBar.BackgroundColor3 = Color3.fromRGB(22, 28, 38)
    FooterBar.BorderSizePixel = 0
    FooterBar.ZIndex = 31
    FooterBar.Parent = ShopPanel

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 6)
    fCorner.Parent = FooterBar

    local footerText = Instance.new("TextLabel")
    footerText.Name = "FooterText"
    footerText.Size = UDim2.new(1, -16, 1, 0)
    footerText.Position = UDim2.new(0, 8, 0, 0)
    footerText.BackgroundTransparency = 1
    footerText.Font = Enum.Font.Gotham
    footerText.TextSize = 11
    footerText.TextColor3 = Color3.fromRGB(140, 210, 160)
    footerText.TextXAlignment = Enum.TextXAlignment.Left
    footerText.Text = "⚡ Safe Sandbox Mode Active • Purchases in Studio do not consume Robux"
    footerText.ZIndex = 32
    footerText.Parent = FooterBar
end

-- Local State
local currentTab = "Gamepasses"
local cachedShopData: any = nil
local isStudioMode = true

-- Tab Buttons
type TabDef = { Id: string, DisplayName: string, Icon: string }
local TAB_DEFINITIONS: { TabDef } = {
    { Id = "Gamepasses", DisplayName = "GAMEPASSES", Icon = "⭐" },
    { Id = "Currency", DisplayName = "CURRENCY & XP", Icon = "💰" },
    { Id = "Combat", DisplayName = "COMBAT BOOSTS", Icon = "⚔️" },
}

local tabButtons: { [string]: TextButton } = {}

local function createTabButton(tabDef: TabDef): TextButton
    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. tabDef.Id
    btn.Size = UDim2.new(0, 170, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(28, 35, 48)
    btn.Text = string.format("%s %s", tabDef.Icon, tabDef.DisplayName)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(180, 195, 215)
    btn.ZIndex = 32
    btn.Parent = TabsBar

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = btn

    local bStroke = Instance.new("UIStroke")
    bStroke.Name = "Stroke"
    bStroke.Color = Color3.fromRGB(45, 55, 75)
    bStroke.Thickness = 1
    bStroke.Parent = btn

    return btn
end

--[=[
    Populates item cards for the active tab.
]=]
local function renderTabItems()
    ItemsScroll:ClearAllChildren()

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 8)
    listLayout.Parent = ItemsScroll

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 6)
    padding.PaddingBottom = UDim.new(0, 6)
    padding.PaddingLeft = UDim.new(0, 6)
    padding.PaddingRight = UDim.new(0, 6)
    padding.Parent = ItemsScroll

    local totalHeight = 0
    local owned = (cachedShopData and cachedShopData.OwnedGamepasses) or {}

    if currentTab == "Gamepasses" then
        local passes = MonetizationConfig.GetGamepassesList()
        for _, pass in ipairs(passes) do
            local isOwned = owned[pass.Id] == true

            local card = Instance.new("Frame")
            card.Name = "Card_" .. pass.Id
            card.Size = UDim2.new(1, 0, 0, 64)
            card.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
            card.BorderSizePixel = 0
            card.ZIndex = 32
            card.Parent = ItemsScroll

            local cCorner = Instance.new("UICorner")
            cCorner.CornerRadius = UDim.new(0, 8)
            cCorner.Parent = card

            local cStroke = Instance.new("UIStroke")
            cStroke.Color = if isOwned then Color3.fromRGB(40, 80, 50) else Color3.fromRGB(50, 62, 85)
            cStroke.Thickness = 1
            cStroke.Parent = card

            -- Icon
            local iconLbl = Instance.new("TextLabel")
            iconLbl.Size = UDim2.new(0, 48, 1, 0)
            iconLbl.Position = UDim2.new(0, 8, 0, 0)
            iconLbl.BackgroundTransparency = 1
            iconLbl.Font = Enum.Font.GothamBlack
            iconLbl.TextSize = 26
            iconLbl.Text = pass.Icon
            iconLbl.ZIndex = 33
            iconLbl.Parent = card

            -- Name
            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(0.6, -70, 0, 20)
            nameLbl.Position = UDim2.new(0, 64, 0, 8)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.TextSize = 13
            nameLbl.TextColor3 = if isOwned then Color3.fromRGB(140, 230, 160) else Color3.fromRGB(255, 255, 255)
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Text = pass.DisplayName
            nameLbl.ZIndex = 33
            nameLbl.Parent = card

            -- Description
            local descLbl = Instance.new("TextLabel")
            descLbl.Size = UDim2.new(0.65, -70, 0, 30)
            descLbl.Position = UDim2.new(0, 64, 0, 28)
            descLbl.BackgroundTransparency = 1
            descLbl.Font = Enum.Font.Gotham
            descLbl.TextSize = 10
            descLbl.TextColor3 = Color3.fromRGB(150, 165, 185)
            descLbl.TextXAlignment = Enum.TextXAlignment.Left
            descLbl.TextWrapped = true
            descLbl.Text = pass.Description
            descLbl.ZIndex = 33
            descLbl.Parent = card

            -- Action Button
            local buyBtn = Instance.new("TextButton")
            buyBtn.Name = "BuyButton"
            buyBtn.Size = UDim2.new(0, 140, 0, 42)
            buyBtn.Position = UDim2.new(1, -148, 0.5, 0)
            buyBtn.AnchorPoint = Vector2.new(0, 0.5)
            buyBtn.ZIndex = 33
            buyBtn.Parent = card

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = buyBtn

            if isOwned then
                buyBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 40)
                buyBtn.TextColor3 = Color3.fromRGB(120, 220, 140)
                buyBtn.Font = Enum.Font.GothamBold
                buyBtn.TextSize = 12
                buyBtn.Text = "✓ OWNED"
                buyBtn.AutoButtonColor = false
            else
                buyBtn.BackgroundColor3 = Color3.fromRGB(255, 130, 20)
                buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                buyBtn.Font = Enum.Font.GothamBlack
                buyBtn.TextSize = 11
                buyBtn.Text = if isStudioMode
                    then string.format("TEST UNLOCK\n(R$ %d)", pass.RobuxPrice)
                    else string.format("BUY PASS\nR$ %d", pass.RobuxPrice)
                buyBtn.AutoButtonColor = true

                buyBtn.MouseButton1Click:Connect(function()
                    AudioController.PlayUI("ButtonClick")
                    local res = ShopActionRemote:InvokeServer("PromptPurchase", { Type = "Gamepass", Id = pass.Id })
                    if res and res.Success then AudioController.PlayUI("UpgradeSuccess") end
                end)
            end

            totalHeight += 72
        end
    else
        -- Products (Currency or Combat)
        local targetCat = if currentTab == "Currency" then { Currency = true, XP = true } else { Combat = true }
        local products = MonetizationConfig.GetProductsList()
        for _, prod in ipairs(products) do
            if targetCat[prod.Category] then
                local card = Instance.new("Frame")
                card.Name = "Card_" .. prod.Id
                card.Size = UDim2.new(1, 0, 0, 64)
                card.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
                card.BorderSizePixel = 0
                card.ZIndex = 32
                card.Parent = ItemsScroll

                local cCorner = Instance.new("UICorner")
                cCorner.CornerRadius = UDim.new(0, 8)
                cCorner.Parent = card

                local cStroke = Instance.new("UIStroke")
                cStroke.Color = Color3.fromRGB(50, 62, 85)
                cStroke.Thickness = 1
                cStroke.Parent = card

                -- Icon
                local iconLbl = Instance.new("TextLabel")
                iconLbl.Size = UDim2.new(0, 48, 1, 0)
                iconLbl.Position = UDim2.new(0, 8, 0, 0)
                iconLbl.BackgroundTransparency = 1
                iconLbl.Font = Enum.Font.GothamBlack
                iconLbl.TextSize = 26
                iconLbl.Text = prod.Icon
                iconLbl.ZIndex = 33
                iconLbl.Parent = card

                -- Name
                local nameLbl = Instance.new("TextLabel")
                nameLbl.Size = UDim2.new(0.6, -70, 0, 20)
                nameLbl.Position = UDim2.new(0, 64, 0, 8)
                nameLbl.BackgroundTransparency = 1
                nameLbl.Font = Enum.Font.GothamBold
                nameLbl.TextSize = 13
                nameLbl.TextColor3 = Color3.fromRGB(255, 230, 80)
                nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                nameLbl.Text = prod.DisplayName
                nameLbl.ZIndex = 33
                nameLbl.Parent = card

                -- Description
                local descLbl = Instance.new("TextLabel")
                descLbl.Size = UDim2.new(0.65, -70, 0, 30)
                descLbl.Position = UDim2.new(0, 64, 0, 28)
                descLbl.BackgroundTransparency = 1
                descLbl.Font = Enum.Font.Gotham
                descLbl.TextSize = 10
                descLbl.TextColor3 = Color3.fromRGB(150, 165, 185)
                descLbl.TextXAlignment = Enum.TextXAlignment.Left
                descLbl.TextWrapped = true
                descLbl.Text = prod.Description
                descLbl.ZIndex = 33
                descLbl.Parent = card

                -- Buy Button
                local buyBtn = Instance.new("TextButton")
                buyBtn.Name = "BuyButton"
                buyBtn.Size = UDim2.new(0, 140, 0, 42)
                buyBtn.Position = UDim2.new(1, -148, 0.5, 0)
                buyBtn.AnchorPoint = Vector2.new(0, 0.5)
                buyBtn.BackgroundColor3 = Color3.fromRGB(255, 130, 20)
                buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                buyBtn.Font = Enum.Font.GothamBlack
                buyBtn.TextSize = 11
                buyBtn.Text = if isStudioMode
                    then string.format("TEST BUY\n(R$ %d)", prod.RobuxPrice)
                    else string.format("BUY\nR$ %d", prod.RobuxPrice)
                buyBtn.ZIndex = 33
                buyBtn.Parent = card

                local btnCorner = Instance.new("UICorner")
                btnCorner.CornerRadius = UDim.new(0, 6)
                btnCorner.Parent = buyBtn

                buyBtn.MouseButton1Click:Connect(function()
                    AudioController.PlayUI("ButtonClick")
                    local res = ShopActionRemote:InvokeServer("PromptPurchase", { Type = "Product", Id = prod.Id })
                    if res and res.Success then AudioController.PlayUI("UpgradeSuccess") end
                end)

                totalHeight += 72
            end
        end
    end

    ItemsScroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
end

local function selectTab(tabId: string)
    currentTab = tabId
    for id, btn in pairs(tabButtons) do
        local isActive = (id == tabId)
        btn.BackgroundColor3 = if isActive then Color3.fromRGB(48, 62, 85) else Color3.fromRGB(28, 35, 48)
        btn.TextColor3 = if isActive then Color3.fromRGB(255, 220, 60) else Color3.fromRGB(160, 175, 195)
        local stroke = btn:FindFirstChild("Stroke") :: UIStroke?
        if stroke then
            stroke.Color = if isActive then Color3.fromRGB(255, 160, 30) else Color3.fromRGB(45, 55, 75)
            stroke.Thickness = if isActive then 2 else 1
        end
    end
    renderTabItems()
end

for _, tabDef in ipairs(TAB_DEFINITIONS) do
    local btn = createTabButton(tabDef)
    tabButtons[tabDef.Id] = btn
    btn.MouseButton1Click:Connect(function()
        AudioController.PlayUI("ButtonClick")
        selectTab(tabDef.Id)
    end)
end

local function refreshShopData()
    task.spawn(function()
        local data = ShopActionRemote:InvokeServer("GetShopData")
        if data then
            cachedShopData = data
            isStudioMode = (data.IsStudio == true)
            renderTabItems()
        end
    end)
end

local function toggleShop(forceState: boolean?)
    local target = if forceState ~= nil then forceState else not ShopPanel.Visible
    ShopPanel.Visible = target
    if target then
        AudioController.PlayUI("PanelToggle")
        refreshShopData()
        selectTab(currentTab)
    else
        AudioController.PlayUI("PanelToggle")
    end
end

CloseButton.MouseButton1Click:Connect(function()
    toggleShop(false)
end)

ShopToggleBindable.Event:Connect(function(forceState: boolean?)
    toggleShop(forceState)
end)

-- Hook ProximityPrompt for Hub Market Pavilion
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
    if player == LocalPlayer and prompt.Name == "MarketPavilionPrompt" then toggleShop(true) end
end)

-- Keybinds: B toggles shop
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.B then toggleShop() end
end)

-- ShopFeedback listener
ShopFeedbackRemote.OnClientEvent:Connect(function(eventType: string, data: any)
    if eventType == "PurchaseSuccess" then
        AudioController.PlayReward(3)
        refreshShopData()
    elseif eventType == "CooldownsReset" then
        AudioController.PlayReward(4)
    elseif eventType == "ComboShieldActivated" then
        AudioController.PlayReward(5)
    end
end)

-- Add Shop Button to StatsFrame
local StatsFrame = MainUI:WaitForChild("StatsFrame", 10) :: Frame?
if StatsFrame then
    local ShopBtn = StatsFrame:FindFirstChild("ShopButton") :: TextButton?
    if not ShopBtn then
        ShopBtn = Instance.new("TextButton")
        ShopBtn.Name = "ShopButton"
        ShopBtn.Size = UDim2.new(0, 95, 0, 32)
        ShopBtn.Position = UDim2.new(1.915, 5, -0.053, 12)
        ShopBtn.BackgroundColor3 = Color3.fromRGB(240, 130, 20)
        ShopBtn.Text = "🛒 SHOP"
        ShopBtn.Font = Enum.Font.GothamBlack
        ShopBtn.TextSize = 12
        ShopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        ShopBtn.ZIndex = 14
        ShopBtn.Parent = StatsFrame

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = ShopBtn

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 215, 60)
        stroke.Thickness = 1.5
        stroke.Parent = ShopBtn

        ShopBtn.MouseButton1Click:Connect(function()
            toggleShop()
        end)
    end
end

-- Initial render
selectTab("Gamepasses")
print("[ShopHUD] Marketplace HUD initialized.")
