--!strict
--[[
    DestructionHUD.client.luau
    Client UI controller for Titan Rampage.
    Responsibility:
    - Real-time HUD updates for Level, XP progress bar, Cash, Points, and Combo.
    - Full Ravager Upgrade Matrix UI panel with live affordability tracking.
    - Floating damage numbers, destruction billboards, and level-up banners.
    - City Progress HUD tracker (Buildings count, percentage, progress bar, live timer).
    - City Completion Screen with run statistics, rewards accounting, and Rebuild City button.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local MainUI = script.Parent :: ScreenGui

local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local SharedFolder = ReplicatedStorage:WaitForChild("Shared")

local UpgradeConfig = require(ConfigFolder:WaitForChild("UpgradeConfig") :: ModuleScript)
local AudioController = require(SharedFolder:WaitForChild("AudioController") :: ModuleScript)
local TitanRegistry = require(SharedFolder:WaitForChild("TitanRegistry") :: ModuleScript)
local DestructionFeedback = RemotesFolder:WaitForChild("DestructionFeedback") :: RemoteEvent
local ProgressionUpdateRemote = RemotesFolder:WaitForChild("ProgressionUpdate") :: RemoteEvent
local UpgradeRequestRemote = RemotesFolder:WaitForChild("UpgradeRequest") :: RemoteEvent
local CityFeedbackRemote = RemotesFolder:WaitForChild("CityFeedback") :: RemoteEvent
local RebuildCityRequestRemote = RemotesFolder:WaitForChild("RebuildCityRequest") :: RemoteEvent
local CitySelectRequestRemote = RemotesFolder:WaitForChild("CitySelectRequest") :: RemoteEvent
local TitanSelectRequestRemote = RemotesFolder:WaitForChild("TitanSelectRequest") :: RemoteEvent
local TitanFeedbackRemote = RemotesFolder:WaitForChild("TitanFeedback") :: RemoteEvent
local TitanEffectRemote = RemotesFolder:WaitForChild("TitanEffect") :: RemoteEvent

-- UI Elements: StatsFrame
local StatsFrame = MainUI:WaitForChild("StatsFrame") :: Frame
local LevelLabel = StatsFrame:WaitForChild("LevelLabel") :: TextLabel
local CashLabel = StatsFrame:WaitForChild("CashLabel") :: TextLabel
local PointsLabel = StatsFrame:WaitForChild("PointsLabel") :: TextLabel
local ComboLabel = StatsFrame:WaitForChild("ComboLabel") :: TextLabel
local ComboBarBg = StatsFrame:WaitForChild("ComboBarBg") :: Frame
local ComboBarFill = ComboBarBg:WaitForChild("ComboBarFill") :: Frame
local UpgradesButton = StatsFrame:WaitForChild("UpgradesButton") :: TextButton
local CitySelectButton = StatsFrame:WaitForChild("CitySelectButton") :: TextButton
local TitanSelectButton = StatsFrame:WaitForChild("TitanSelectButton") :: TextButton

local XPBarFrame = StatsFrame:WaitForChild("XPBarFrame") :: Frame
local XPFill = XPBarFrame:WaitForChild("XPFill") :: Frame
local XPText = XPBarFrame:WaitForChild("XPText") :: TextLabel

-- UI Elements: CitySelectionPanel
local CitySelectionPanel = MainUI:WaitForChild("CitySelectionPanel") :: Frame
local CityHeader = CitySelectionPanel:WaitForChild("Header") :: Frame
local CityCloseButton = CityHeader:WaitForChild("CloseButton") :: TextButton
local CardsContainer = CitySelectionPanel:WaitForChild("CardsContainer") :: Frame
local CardSmallTown = CardsContainer:WaitForChild("Card_SmallTown") :: Frame
local CardMetrovale = CardsContainer:WaitForChild("Card_Metrovale") :: Frame

-- UI Elements: TitanSelectionPanel
local TitanSelectionPanel = MainUI:WaitForChild("TitanSelectionPanel") :: Frame
local TitanHeader = TitanSelectionPanel:WaitForChild("Header") :: Frame
local TitanCloseButton = TitanHeader:WaitForChild("CloseButton") :: TextButton
local TitanCardsContainer = TitanSelectionPanel:WaitForChild("CardsContainer") :: Frame
local CardRavager = TitanCardsContainer:WaitForChild("Card_Ravager") :: Frame
local CardBrontara = TitanCardsContainer:WaitForChild("Card_Brontara") :: Frame

-- UI Elements: UpgradePanel
local UpgradePanel = MainUI:WaitForChild("UpgradePanel") :: Frame
local HeaderFrame = UpgradePanel:WaitForChild("HeaderFrame") :: Frame
local CloseButton = HeaderFrame:WaitForChild("CloseButton") :: TextButton
local UpgradeList = UpgradePanel:WaitForChild("UpgradeList") :: ScrollingFrame

-- UI Elements: LevelUpBanner
local LevelUpBanner = MainUI:WaitForChild("LevelUpBanner") :: Frame
local BannerTitle = LevelUpBanner:WaitForChild("BannerTitle") :: TextLabel
local BannerDesc = LevelUpBanner:WaitForChild("BannerDesc") :: TextLabel

-- UI Elements: CityProgressFrame
local CityProgressFrame = MainUI:WaitForChild("CityProgressFrame") :: Frame
local CityNameLabel = CityProgressFrame:WaitForChild("CityNameLabel") :: TextLabel
local TimerLabel = CityProgressFrame:WaitForChild("TimerLabel") :: TextLabel
local BuildingsLabel = CityProgressFrame:WaitForChild("BuildingsLabel") :: TextLabel
local DestructionLabel = CityProgressFrame:WaitForChild("DestructionLabel") :: TextLabel
local ProgressBarBg = CityProgressFrame:WaitForChild("ProgressBarBg") :: Frame
local ProgressBarFill = ProgressBarBg:WaitForChild("ProgressBarFill") :: Frame

-- UI Elements: CityCompletionScreen
local CompletionScreen = MainUI:WaitForChild("CityCompletionScreen") :: Frame
local ScoreCard = CompletionScreen:WaitForChild("ScoreCard") :: Frame
local ScoreValue = ScoreCard:WaitForChild("ScoreValue") :: TextLabel
local ScoreBadge = ScoreCard:WaitForChild("ScoreBadge") :: TextLabel
local ScoreBreakdown = ScoreCard:WaitForChild("ScoreBreakdown") :: TextLabel

local StatsCard = CompletionScreen:WaitForChild("StatsCard") :: Frame
local CardBuildings = StatsCard:WaitForChild("BuildingsText") :: TextLabel
local CardTime = StatsCard:WaitForChild("TimeText") :: TextLabel
local CardCombo = StatsCard:WaitForChild("ComboText") :: TextLabel
local CardDamage = StatsCard:WaitForChild("DamageText") :: TextLabel
local CardPace = StatsCard:WaitForChild("PaceText") :: TextLabel
local CardAbilities = StatsCard:WaitForChild("AbilitiesText") :: TextLabel

local RewardsCard = CompletionScreen:WaitForChild("RewardsCard") :: Frame
local RewBuildings = RewardsCard:WaitForChild("BuildingsReward") :: TextLabel
local RewBonus = RewardsCard:WaitForChild("BonusReward") :: TextLabel
local RewTotal = RewardsCard:WaitForChild("TotalReward") :: TextLabel
local RebuildButton = CompletionScreen:WaitForChild("RebuildButton") :: TextButton

local function formatCommas(amount: number): string
    local formatted = tostring(math.floor(amount))
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

-- Local state cache
local localProgression = {
    Level = 1,
    CurrentXP = 0,
    NextLevelXP = 500,
    Cash = 0,
    DestructionPoints = 0,
    Upgrades = {} :: { [string]: number },
}

local cityState = {
    RunStartTime = 0,
    IsCompleted = false,
}

-- Audio tracking state
local buildingHealthRatios: { [Instance]: number } = {}
local lastComboMult = 1

-- Throttled 3D floating damage numbers queue (Max 15 concurrent)
local activeDamageNumbers: { { Anchor: Instance, Billboard: Instance } } = {}
local MAX_CONCURRENT_DAMAGE_NUMBERS = 15

local function spawnDamageNumber(pos: Vector3, dmg: number, combo: number, source: string?)
    -- Throttle oldest active numbers if cap reached
    while #activeDamageNumbers >= MAX_CONCURRENT_DAMAGE_NUMBERS do
        local oldest = table.remove(activeDamageNumbers, 1)
        if oldest and oldest.Anchor and oldest.Anchor.Parent then oldest.Anchor:Destroy() end
    end

    local isStomp = (source == "Stomp")
    local anchorPos = pos + Vector3.new(math.random(-3, 3), 7 + math.random(0, 3), math.random(-3, 3))

    local anchor = Instance.new("Part")
    anchor.Name = "DamageAnchor"
    anchor.Transparency = 1
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.CanTouch = false
    anchor.Anchored = true
    anchor.Size = Vector3.new(0.2, 0.2, 0.2)
    anchor.Position = anchorPos
    anchor.Parent = Workspace

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "DamageBillboard"
    billboard.Size = if isStomp then UDim2.new(0, 160, 0, 50) else UDim2.new(0, 130, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 0, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = anchor
    billboard.Parent = anchor

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(0.2, 0, 0.2, 0) -- Starts small for pop-in
    text.Position = UDim2.new(0.4, 0, 0.4, 0)
    text.BackgroundTransparency = 1
    text.TextStrokeTransparency = 0.15
    text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

    if isStomp then
        text.Text = if combo > 1 then string.format("💥 -%d (%dx)", dmg, combo) else string.format("💥 -%d", dmg)
        text.TextColor3 = if combo >= 4
            then Color3.fromRGB(255, 240, 80)
            elseif combo >= 2 then Color3.fromRGB(255, 185, 30)
            else Color3.fromRGB(255, 160, 15)
        text.Font = Enum.Font.GothamBlack
        text.TextSize = if combo >= 4 then 34 elseif combo >= 2 then 31 else 28
    else
        text.Text = if combo > 1 then string.format("-%d (%dx)", dmg, combo) else string.format("-%d", dmg)
        text.TextColor3 = if combo >= 4
            then Color3.fromRGB(255, 230, 60)
            elseif combo >= 2 then Color3.fromRGB(255, 140, 40)
            else Color3.fromRGB(255, 80, 40)
        text.Font = Enum.Font.GothamBlack
        text.TextSize = if combo >= 4 then 26 elseif combo >= 2 then 24 else 22
    end
    text.Parent = billboard

    local entry = { Anchor = anchor, Billboard = billboard }
    table.insert(activeDamageNumbers, entry)

    -- Pop-in scale animation (0.10s Back easing)
    local popTween = TweenService:Create(text, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
    })
    popTween:Play()

    -- Upward float and fade out over 0.85s
    local floatTween = TweenService:Create(billboard, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        StudsOffset = Vector3.new(0, 4.5, 0),
    })
    local fadeDelay = 0.35
    task.delay(fadeDelay, function()
        if text and text.Parent then
            local fadeTween = TweenService:Create(text, TweenInfo.new(0.50, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                TextTransparency = 1,
                TextStrokeTransparency = 1,
            })
            fadeTween:Play()
        end
    end)
    floatTween:Play()

    task.delay(0.90, function()
        local idx = table.find(activeDamageNumbers, entry)
        if idx then table.remove(activeDamageNumbers, idx) end
        if anchor and anchor.Parent then anchor:Destroy() end
    end)
end

-- Registry of upgrade row UI elements
local upgradeRows: { [string]: {
    Row: Frame,
    LevelText: TextLabel,
    ValueText: TextLabel,
    BuyButton: TextButton,
} } = {}

--[=[
    Formats stat values according to category formatting.
]=]
local function formatValue(catId: string, val: number): string
    local cat = UpgradeConfig.Categories[catId]
    if not cat then return tostring(val) end
    if cat.Unit == "s" then
        return string.format("%.2fs cd", val)
    elseif cat.Unit == "DMG" then
        return string.format("%d DMG", math.floor(val))
    elseif cat.Unit == "Studs" then
        return string.format("%d Studs", math.floor(val))
    elseif cat.Unit == "Speed" then
        return string.format("%d Speed", math.floor(val))
    end
    return tostring(val)
end

--[=[
    Populates the Upgrade Matrix rows.
]=]
--[=[
    Centralized visual state engine for upgrade buttons.
    Determines and applies visual styling across three distinct states:
    - STATE A (AFFORDABLE): Vibrant fiery orange (#FF7814), pure white text, active.
    - STATE B (UNAFFORDABLE): Dark slate-crimson (#382830), readable rose-white cost text (#ECD4D4), active error feedback.
    - STATE C (MAX LEVEL): Muted charcoal (#2A3038), gold status indicator, inactive.
]=]
local function updateUpgradeButtonVisualState(
    catId: string,
    widgets: { Row: Frame, LevelText: TextLabel, ValueText: TextLabel, BuyButton: TextButton },
    currentLevel: number,
    catConfig: any,
    playerCash: number,
    playerPoints: number
)
    local curValue = UpgradeConfig.GetTierValue(catId, currentLevel)
    widgets.LevelText.Text = string.format("%s (Lvl %d/%d)", catConfig.DisplayName, currentLevel, catConfig.MaxLevel)

    if currentLevel >= catConfig.MaxLevel then
        -- STATE C: MAX LEVEL (Tier 5 reached)
        widgets.ValueText.Text = string.format("⚡ %s (MAX LEVEL)", formatValue(catId, curValue))
        widgets.ValueText.TextColor3 = Color3.fromRGB(255, 210, 40) -- Gold

        widgets.BuyButton.Text = "MAX"
        widgets.BuyButton.BackgroundColor3 = Color3.fromRGB(42, 48, 56) -- Muted Charcoal
        widgets.BuyButton.BackgroundTransparency = 0
        widgets.BuyButton.TextColor3 = Color3.fromRGB(145, 155, 168) -- Muted Grey
        widgets.BuyButton.TextTransparency = 0
        widgets.BuyButton.Active = false
        widgets.BuyButton.AutoButtonColor = false
        pcall(function()
            (widgets.BuyButton :: any).Interactable = false
        end)
    else
        local nextTier = UpgradeConfig.GetNextTier(catId, currentLevel)
        if not nextTier then return end

        widgets.ValueText.Text = string.format("%s ➔ %s", formatValue(catId, curValue), formatValue(catId, nextTier.Value))
        widgets.BuyButton.Text = string.format("UPGRADE\n$%d • %dP", nextTier.CashCost, nextTier.PointCost)
        widgets.BuyButton.BackgroundTransparency = 0
        widgets.BuyButton.TextTransparency = 0
        widgets.BuyButton.Active = true
        widgets.BuyButton.AutoButtonColor = true
        pcall(function()
            (widgets.BuyButton :: any).Interactable = true
        end)

        local canAfford = (playerCash >= nextTier.CashCost) and (playerPoints >= nextTier.PointCost)
        if canAfford then
            -- STATE A: AFFORDABLE (Visibly enabled & clickable)
            widgets.ValueText.TextColor3 = Color3.fromRGB(180, 205, 230)
            widgets.BuyButton.BackgroundColor3 = Color3.fromRGB(255, 120, 20) -- Vibrant Fiery Orange (#FF7814)
            widgets.BuyButton.TextColor3 = Color3.fromRGB(255, 255, 255) -- Crisp White
        else
            -- STATE B: UNAFFORDABLE (Dark slate-crimson with high-contrast readable cost text)
            widgets.ValueText.TextColor3 = Color3.fromRGB(160, 170, 185)
            widgets.BuyButton.BackgroundColor3 = Color3.fromRGB(56, 40, 48) -- Rich Dark Slate-Crimson
            widgets.BuyButton.TextColor3 = Color3.fromRGB(235, 185, 185) -- Rose-tinted readable cost text
        end
    end
end

--[=[
    Populates the Upgrade Matrix rows with explicit ZIndex hierarchy.
]=]
local function buildUpgradeMatrix()
    UpgradeList:ClearAllChildren()

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 6)
    listLayout.Parent = UpgradeList

    local totalHeight = 0

    for orderIdx, catId in ipairs(UpgradeConfig.DisplayOrder) do
        local cat = UpgradeConfig.Categories[catId]
        if cat then
            local row = Instance.new("Frame")
            row.Name = "Row_" .. catId
            row.Size = UDim2.new(1, -6, 0, 58)
            row.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
            row.BorderSizePixel = 0
            row.LayoutOrder = orderIdx
            row.ZIndex = 12
            row.Parent = UpgradeList

            local rowCorner = Instance.new("UICorner")
            rowCorner.CornerRadius = UDim.new(0, 6)
            rowCorner.Parent = row

            local rowStroke = Instance.new("UIStroke")
            rowStroke.Color = Color3.fromRGB(45, 50, 62)
            rowStroke.Thickness = 1
            rowStroke.Parent = row

            -- Title and Level
            local title = Instance.new("TextLabel")
            title.Name = "Title"
            title.Size = UDim2.new(0.6, -10, 0, 20)
            title.Position = UDim2.new(0, 10, 0, 6)
            title.BackgroundTransparency = 1
            title.Text = cat.DisplayName
            title.TextColor3 = Color3.fromRGB(255, 255, 255)
            title.Font = Enum.Font.GothamBold
            title.TextSize = 13
            title.TextXAlignment = Enum.TextXAlignment.Left
            title.ZIndex = 13
            title.Parent = row

            -- Value / Next Value Label
            local valLabel = Instance.new("TextLabel")
            valLabel.Name = "ValueLabel"
            valLabel.Size = UDim2.new(0.6, -10, 0, 18)
            valLabel.Position = UDim2.new(0, 10, 0, 28)
            valLabel.BackgroundTransparency = 1
            valLabel.Text = "Loading..."
            valLabel.TextColor3 = Color3.fromRGB(170, 180, 195)
            valLabel.Font = Enum.Font.Gotham
            valLabel.TextSize = 11
            valLabel.TextXAlignment = Enum.TextXAlignment.Left
            valLabel.ZIndex = 13
            valLabel.Parent = row

            -- Buy Button
            local buyBtn = Instance.new("TextButton")
            buyBtn.Name = "BuyButton"
            buyBtn.Size = UDim2.new(0.38, -10, 0, 38)
            buyBtn.Position = UDim2.new(0.62, 0, 0, 10)
            buyBtn.BackgroundColor3 = Color3.fromRGB(255, 120, 20)
            buyBtn.Text = "UPGRADE"
            buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            buyBtn.Font = Enum.Font.GothamBlack
            buyBtn.TextSize = 11
            buyBtn.ZIndex = 14
            buyBtn.Parent = row

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 5)
            btnCorner.Parent = buyBtn

            -- Bind upgrade request
            buyBtn.MouseButton1Click:Connect(function()
                local currentLevel = localProgression.Upgrades[catId] or 1
                local nextTier = UpgradeConfig.GetNextTier(catId, currentLevel)
                if nextTier then
                    local canAfford = (localProgression.Cash >= nextTier.CashCost)
                        and (localProgression.DestructionPoints >= nextTier.PointCost)
                    if canAfford then
                        AudioController.PlayUI("ButtonClick")
                    else
                        AudioController.PlayUI("UpgradeError")
                    end
                end
                UpgradeRequestRemote:FireServer(catId)
            end)

            upgradeRows[catId] = {
                Row = row,
                LevelText = title,
                ValueText = valLabel,
                BuyButton = buyBtn,
            }

            totalHeight += 64
        end
    end

    UpgradeList.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
end

--[=[
    Refreshes all upgrade button states and labels using the centralized visual state engine.
]=]
local function updateUpgradeMatrixView()
    local cash = localProgression.Cash or 0
    local points = localProgression.DestructionPoints or 0

    for catId, widgets in pairs(upgradeRows) do
        local cat = UpgradeConfig.Categories[catId]
        if cat then
            local currentLevel = localProgression.Upgrades[catId] or 1
            updateUpgradeButtonVisualState(catId, widgets, currentLevel, cat, cash, points)
        end
    end
end

--[=[
    Updates HUD with progression data (Level, XP bar, Cash, Points).
]=]
local function updateHUD(data: any)
    if not data then return end

    if data.Level ~= nil then localProgression.Level = data.Level end
    if data.CurrentXP ~= nil then localProgression.CurrentXP = data.CurrentXP end
    if data.NextLevelXP ~= nil then localProgression.NextLevelXP = data.NextLevelXP end
    if data.Cash ~= nil then localProgression.Cash = data.Cash end
    if data.DestructionPoints ~= nil then localProgression.DestructionPoints = data.DestructionPoints end
    if data.Upgrades ~= nil then localProgression.Upgrades = data.Upgrades end

    -- Update UI
    LevelLabel.Text = string.format("LVL %d", localProgression.Level)
    CashLabel.Text = string.format("💵 Cash: $%d", localProgression.Cash)
    PointsLabel.Text = string.format("💥 Points: %d", localProgression.DestructionPoints)

    local targetRatio = math.clamp(localProgression.CurrentXP / math.max(1, localProgression.NextLevelXP), 0, 1)
    TweenService:Create(XPFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(targetRatio, 0, 1, 0),
    }):Play()

    XPText.Text = string.format("XP: %d / %d", localProgression.CurrentXP, localProgression.NextLevelXP)

    updateUpgradeMatrixView()
end

--[=[
    Displays animated Level-Up banner.
]=]
local function showLevelUpBanner(newLevel: number)
    BannerTitle.Text = string.format("⭐ LEVEL UP! LEVEL %d ⭐", newLevel)
    BannerDesc.Text = "Colossal Destruction Power Surging! New Upgrades Unlocked!"

    LevelUpBanner.Position = UDim2.new(0.5, 0, 0, -100)
    LevelUpBanner.Visible = true

    local dropTween = TweenService:Create(LevelUpBanner, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0, 25),
    })
    dropTween:Play()

    task.delay(0.5, function()
        local pulse = TweenService:Create(LevelUpBanner, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 2, true), {
            Size = UDim2.new(0, 400, 0, 74),
        })
        pulse:Play()
    end)

    task.delay(2.6, function()
        local retract = TweenService:Create(LevelUpBanner, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, 0, -100),
        })
        retract:Play()
    end)
end

-- Build matrix on startup and request authoritative initial sync
buildUpgradeMatrix()
updateUpgradeMatrixView()
ProgressionUpdateRemote:FireServer("RequestSync")
TitanSelectRequestRemote:FireServer("RequestSync")

-- Remote Event: ProgressionUpdate
ProgressionUpdateRemote.OnClientEvent:Connect(function(data: any)
    if not data then return end

    updateHUD(data)

    if data.LeveledUp == true and data.Level then
        AudioController.PlayLevelUp()
        showLevelUpBanner(data.Level)
    end

    if data.Type == "UpgradeSuccess" and data.UpgradeId then
        AudioController.PlayUI("UpgradeSuccess")
        local rowData = upgradeRows[data.UpgradeId]
        if rowData then
            local flash = TweenService:Create(rowData.Row, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 1, true), {
                BackgroundColor3 = Color3.fromRGB(30, 75, 45),
            })
            flash:Play()
        end
    elseif data.Type == "UpgradeFailed" and data.UpgradeId then
        AudioController.PlayUI("UpgradeError")
        local rowData = upgradeRows[data.UpgradeId]
        if rowData then
            local flash = TweenService:Create(rowData.Row, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 1, true), {
                BackgroundColor3 = Color3.fromRGB(65, 25, 30),
            })
            flash:Play()
        end
    end
end)

-- Button Bindings for UpgradePanel
UpgradesButton.MouseButton1Click:Connect(function()
    AudioController.PlayUI("ButtonClick")
    UpgradePanel.Visible = not UpgradePanel.Visible
    if UpgradePanel.Visible then
        ProgressionUpdateRemote:FireServer("RequestSync")
        updateUpgradeMatrixView()
    end
end)

CloseButton.MouseButton1Click:Connect(function()
    AudioController.PlayUI("PanelToggle")
    UpgradePanel.Visible = false
end)

-- City Selection Button & Card Bindings
CitySelectButton.MouseButton1Click:Connect(function()
    AudioController.PlayUI("CitySelect")
    CitySelectionPanel.Visible = not CitySelectionPanel.Visible
end)

CityCloseButton.MouseButton1Click:Connect(function()
    AudioController.PlayUI("PanelToggle")
    CitySelectionPanel.Visible = false
end)

local btnSmallTown = CardSmallTown:WaitForChild("ActionButton") :: TextButton
local btnMetrovale = CardMetrovale:WaitForChild("ActionButton") :: TextButton

btnSmallTown.MouseButton1Click:Connect(function()
    AudioController.PlayUI("CityPlay")
    CitySelectRequestRemote:FireServer("SmallTown")
end)

btnMetrovale.MouseButton1Click:Connect(function()
    AudioController.PlayUI("CityPlay")
    CitySelectRequestRemote:FireServer("Metrovale")
end)

-- Titan Selection Panel & Button Bindings
TitanSelectButton.MouseButton1Click:Connect(function()
    AudioController.PlayUI("PanelToggle")
    TitanSelectionPanel.Visible = not TitanSelectionPanel.Visible
    if TitanSelectionPanel.Visible then TitanSelectRequestRemote:FireServer("RequestSync") end
end)

TitanCloseButton.MouseButton1Click:Connect(function()
    AudioController.PlayUI("PanelToggle")
    TitanSelectionPanel.Visible = false
end)

local lastKnownTitans: { [string]: { Unlocked: boolean } } = { Ravager = { Unlocked = true }, Brontara = { Unlocked = false } }
local lastKnownSelected = "Ravager"
local boundTitanButtons: { [string]: boolean } = {}

local function updateTitanSelectionView(data: any)
    if not data then return end
    if data.Titans then lastKnownTitans = data.Titans end
    if data.SelectedTitan then
        lastKnownSelected = data.SelectedTitan
    elseif data.TitanId then
        lastKnownSelected = data.TitanId
    end

    local titans = lastKnownTitans
    local selected = lastKnownSelected

    for _, titanDef in ipairs(TitanRegistry.GetList()) do
        local card = TitanCardsContainer:FindFirstChild("Card_" .. titanDef.Id) :: Frame?
        if card then
            local isSelected = (selected == titanDef.Id)
            local isUnlocked = if titans[titanDef.Id]
                then (titans[titanDef.Id].Unlocked == true)
                else (titanDef.UnlockRequirement.Level <= 1 and titanDef.UnlockRequirement.Clears <= 0)

            local titanNameLbl = card:FindFirstChild("TitanName") :: TextLabel?
            if titanNameLbl then titanNameLbl.Text = titanDef.DisplayName end

            local titleLbl = card:FindFirstChild("Title") :: TextLabel?
            if titleLbl then titleLbl.Text = titanDef.Title end

            local reqLbl = card:FindFirstChild("Requirements") :: TextLabel?
            if reqLbl then
                if titanDef.UnlockRequirement.Level > 1 or titanDef.UnlockRequirement.Clears > 0 then
                    reqLbl.Text = string.format(
                        "Requires: Level %d • %d City Clears",
                        titanDef.UnlockRequirement.Level,
                        titanDef.UnlockRequirement.Clears
                    )
                else
                    reqLbl.Text = "Starter Titan • Always Available"
                end
            end

            local statusLbl = card:FindFirstChild("Status") :: TextLabel?
            local actionBtn = card:FindFirstChild("ActionButton") :: TextButton?
            local stroke = card:FindFirstChild("CardStroke") :: UIStroke?

            if statusLbl then
                if isSelected then
                    statusLbl.Text = "⭐ ACTIVE TITAN"
                    statusLbl.TextColor3 = Color3.fromRGB(255, 230, 80)
                    statusLbl.BackgroundColor3 = Color3.fromRGB(55, 45, 20)
                elseif isUnlocked then
                    statusLbl.Text = "✓ UNLOCKED"
                    statusLbl.TextColor3 = Color3.fromRGB(100, 255, 140)
                    statusLbl.BackgroundColor3 = Color3.fromRGB(25, 45, 35)
                else
                    statusLbl.Text = "🔒 LOCKED"
                    statusLbl.TextColor3 = Color3.fromRGB(255, 95, 95)
                    statusLbl.BackgroundColor3 = Color3.fromRGB(45, 25, 25)
                end
            end

            if stroke then
                stroke.Color = if isSelected then Color3.fromRGB(255, 200, 50) else Color3.fromRGB(60, 70, 90)
                stroke.Thickness = if isSelected then 2.5 else 1.5
            end

            if actionBtn then
                if isSelected then
                    actionBtn.Text = "CURRENT TITAN"
                    actionBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 65)
                    actionBtn.TextColor3 = Color3.fromRGB(150, 165, 185)
                    actionBtn.AutoButtonColor = false
                elseif isUnlocked then
                    actionBtn.Text = "SELECT TITAN"
                    actionBtn.BackgroundColor3 = Color3.fromRGB(45, 140, 75)
                    actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    actionBtn.AutoButtonColor = true
                else
                    actionBtn.Text = "LOCKED"
                    actionBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 45)
                    actionBtn.TextColor3 = Color3.fromRGB(120, 125, 135)
                    actionBtn.AutoButtonColor = false
                end

                if not boundTitanButtons[titanDef.Id] then
                    boundTitanButtons[titanDef.Id] = true
                    local targetId = titanDef.Id
                    actionBtn.MouseButton1Click:Connect(function()
                        local currentSel = lastKnownSelected
                        local isCurrentlyUnlocked = if lastKnownTitans[targetId]
                            then (lastKnownTitans[targetId].Unlocked == true)
                            else false
                        if targetId == "Ravager" then isCurrentlyUnlocked = true end

                        if currentSel == targetId then return end

                        if not isCurrentlyUnlocked then
                            AudioController.PlayUI("UpgradeError")
                            return
                        end

                        AudioController.PlayUI("ButtonClick")
                        TitanSelectRequestRemote:FireServer("Select", targetId)
                    end)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Dynamic HUD Ability Cooldown Bar (Milestone 9D)
--------------------------------------------------------------------------------
type AbilitySlotUI = {
    Slot: TitanRegistry.AbilitySlot,
    Card: Frame,
    CardStroke: UIStroke,
    KeybindLabel: TextLabel,
    NameLabel: TextLabel,
    TypeLabel: TextLabel,
    Overlay: Frame,
    Sweep: Frame,
    TimerLabel: TextLabel,
    AbilityName: string?,
}

local activeTitanIdForHUD = "Ravager"
local abilitySlotWidgets: { [TitanRegistry.AbilitySlot]: AbilitySlotUI } = {}
local activeAbilityCooldowns: { [string]: { EndTime: number, Duration: number } } = {}

--------------------------------------------------------------------------------
-- Titan Stamina Gauge & Mobile Sprint Controller (Milestone 12C)
--------------------------------------------------------------------------------
local SprintToggleBindable = RemotesFolder:FindFirstChild("SprintToggle") :: BindableEvent?
if not SprintToggleBindable then
    SprintToggleBindable = Instance.new("BindableEvent")
    SprintToggleBindable.Name = "SprintToggle"
    SprintToggleBindable.Parent = RemotesFolder
end

local StaminaFrame = MainUI:FindFirstChild("StaminaFrame") :: Frame?
if not StaminaFrame then
    StaminaFrame = Instance.new("Frame")
    StaminaFrame.Name = "StaminaFrame"
    StaminaFrame.Size = UDim2.new(0, 360, 0, 18)
    StaminaFrame.Position = UDim2.new(0.5, 0, 1, -94)
    StaminaFrame.AnchorPoint = Vector2.new(0.5, 1)
    StaminaFrame.BackgroundColor3 = Color3.fromRGB(14, 17, 24)
    StaminaFrame.BackgroundTransparency = 0.25
    StaminaFrame.BorderSizePixel = 0
    StaminaFrame.ZIndex = 15
    StaminaFrame.Parent = MainUI

    local staminaCorner = Instance.new("UICorner")
    staminaCorner.CornerRadius = UDim.new(0, 8)
    staminaCorner.Parent = StaminaFrame

    local staminaStroke = Instance.new("UIStroke")
    staminaStroke.Name = "StaminaStroke"
    staminaStroke.Color = Color3.fromRGB(48, 62, 85)
    staminaStroke.Thickness = 1.5
    staminaStroke.Parent = StaminaFrame
end

local StaminaBarFill = StaminaFrame:FindFirstChild("StaminaFill") :: Frame?
if not StaminaBarFill then
    StaminaBarFill = Instance.new("Frame")
    StaminaBarFill.Name = "StaminaFill"
    StaminaBarFill.Size = UDim2.new(1, 0, 1, 0)
    StaminaBarFill.BackgroundColor3 = Color3.fromRGB(0, 220, 255)
    StaminaBarFill.BorderSizePixel = 0
    StaminaBarFill.ZIndex = 16
    StaminaBarFill.Parent = StaminaFrame

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 6)
    fillCorner.Parent = StaminaBarFill

    local fillGrad = Instance.new("UIGradient")
    fillGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 210, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 255, 180)),
    })
    fillGrad.Parent = StaminaBarFill
end

local StaminaLabel = StaminaFrame:FindFirstChild("StaminaLabel") :: TextLabel?
if not StaminaLabel then
    StaminaLabel = Instance.new("TextLabel")
    StaminaLabel.Name = "StaminaLabel"
    StaminaLabel.Size = UDim2.new(1, 0, 1, 0)
    StaminaLabel.BackgroundTransparency = 1
    StaminaLabel.Font = Enum.Font.GothamBold
    StaminaLabel.TextSize = 11
    StaminaLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    StaminaLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    StaminaLabel.TextStrokeTransparency = 0.4
    StaminaLabel.Text = "⚡ STAMINA: 100 / 100"
    StaminaLabel.ZIndex = 17
    StaminaLabel.Parent = StaminaFrame
end

-- Mobile Sprint Touch Button (Visible on Touch devices)
local MobileSprintButton = MainUI:FindFirstChild("MobileSprintButton") :: TextButton?
if not MobileSprintButton and UserInputService.TouchEnabled then
    MobileSprintButton = Instance.new("TextButton")
    MobileSprintButton.Name = "MobileSprintButton"
    MobileSprintButton.Size = UDim2.new(0, 64, 0, 64)
    MobileSprintButton.Position = UDim2.new(1, -85, 1, -155)
    MobileSprintButton.AnchorPoint = Vector2.new(1, 1)
    MobileSprintButton.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
    MobileSprintButton.BackgroundTransparency = 0.2
    MobileSprintButton.Text = "⚡\nSPRINT"
    MobileSprintButton.Font = Enum.Font.GothamBlack
    MobileSprintButton.TextSize = 12
    MobileSprintButton.TextColor3 = Color3.fromRGB(0, 220, 255)
    MobileSprintButton.ZIndex = 25
    MobileSprintButton.Parent = MainUI

    local mbCorner = Instance.new("UICorner")
    mbCorner.CornerRadius = UDim.new(1, 0)
    mbCorner.Parent = MobileSprintButton

    local mbStroke = Instance.new("UIStroke")
    mbStroke.Name = "Stroke"
    mbStroke.Color = Color3.fromRGB(0, 200, 255)
    mbStroke.Thickness = 2
    mbStroke.Parent = MobileSprintButton

    MobileSprintButton.MouseButton1Click:Connect(function()
        if SprintToggleBindable then SprintToggleBindable:Fire() end
    end)
end

-- Attribute observer for character stamina
local function bindCharacterStamina(character: Model)
    local function updateStaminaUI()
        local cur = character:GetAttribute("SprintStamina")
        local max = character:GetAttribute("SprintMaxStamina")
        local isExhausted = character:GetAttribute("IsExhausted") == true
        local isSprinting = character:GetAttribute("IsSprinting") == true

        local curStaminaVal = if type(cur) == "number" then cur else 100
        local maxStaminaVal = if type(max) == "number" then math.max(1, max) else 100
        local ratio = math.clamp(curStaminaVal / maxStaminaVal, 0, 1)

        if StaminaBarFill then
            TweenService:Create(StaminaBarFill, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(ratio, 0, 1, 0),
            }):Play()

            if isExhausted then
                StaminaBarFill.BackgroundColor3 = Color3.fromRGB(240, 50, 50)
            elseif ratio <= 0.3 then
                StaminaBarFill.BackgroundColor3 = Color3.fromRGB(255, 140, 20)
            else
                StaminaBarFill.BackgroundColor3 = Color3.fromRGB(0, 220, 255)
            end
        end

        if StaminaLabel then
            if isExhausted then
                StaminaLabel.Text = "⚠️ EXHAUSTED (RECOVERING...)"
                StaminaLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            elseif isSprinting then
                StaminaLabel.Text = string.format("⚡ SPRINTING: %d / %d", curStaminaVal, maxStaminaVal)
                StaminaLabel.TextColor3 = Color3.fromRGB(255, 240, 120)
            else
                StaminaLabel.Text = string.format("⚡ STAMINA: %d / %d", curStaminaVal, maxStaminaVal)
                StaminaLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end

        if MobileSprintButton then
            if isSprinting then
                MobileSprintButton.BackgroundColor3 = Color3.fromRGB(0, 140, 180)
                MobileSprintButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                MobileSprintButton.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
                MobileSprintButton.TextColor3 = Color3.fromRGB(0, 220, 255)
            end
        end
    end

    character:GetAttributeChangedSignal("SprintStamina"):Connect(updateStaminaUI)
    character:GetAttributeChangedSignal("SprintMaxStamina"):Connect(updateStaminaUI)
    character:GetAttributeChangedSignal("IsSprinting"):Connect(updateStaminaUI)
    character:GetAttributeChangedSignal("IsExhausted"):Connect(updateStaminaUI)
    updateStaminaUI()
end

if LocalPlayer.Character then bindCharacterStamina(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(bindCharacterStamina)

local AbilitiesFrame = MainUI:FindFirstChild("AbilitiesFrame") :: Frame?
if not AbilitiesFrame then
    AbilitiesFrame = Instance.new("Frame")
    AbilitiesFrame.Name = "AbilitiesFrame"
    AbilitiesFrame.Size = UDim2.new(0, 490, 0, 70)
    AbilitiesFrame.Position = UDim2.new(0.5, 0, 1, -18)
    AbilitiesFrame.AnchorPoint = Vector2.new(0.5, 1)
    AbilitiesFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
    AbilitiesFrame.BackgroundTransparency = 0.35
    AbilitiesFrame.BorderSizePixel = 0
    AbilitiesFrame.ZIndex = 15
    AbilitiesFrame.Parent = MainUI

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 8)
    barCorner.Parent = AbilitiesFrame

    local barStroke = Instance.new("UIStroke")
    barStroke.Color = Color3.fromRGB(48, 58, 78)
    barStroke.Thickness = 1.5
    barStroke.Parent = AbilitiesFrame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.Parent = AbilitiesFrame
end

local SLOT_ORDER: { TitanRegistry.AbilitySlot } = { "Primary", "Stomp", "Signature", "Utility" }

local function createAbilitySlotCard(slot: TitanRegistry.AbilitySlot, orderIndex: number): AbilitySlotUI
    local card = Instance.new("Frame")
    card.Name = "Slot_" .. slot
    card.Size = UDim2.new(0, 110, 0, 56)
    card.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
    card.BorderSizePixel = 0
    card.LayoutOrder = orderIndex
    card.ZIndex = 16
    card.Parent = AbilitiesFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.fromRGB(45, 54, 72)
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local keybind = Instance.new("TextLabel")
    keybind.Name = "Keybind"
    keybind.Size = UDim2.new(0.6, 0, 0, 14)
    keybind.Position = UDim2.new(0, 6, 0, 4)
    keybind.BackgroundTransparency = 1
    keybind.Font = Enum.Font.GothamBold
    keybind.TextSize = 10
    keybind.TextColor3 = Color3.fromRGB(255, 205, 50)
    keybind.TextXAlignment = Enum.TextXAlignment.Left
    keybind.ZIndex = 17
    keybind.Parent = card

    local typeLabel = Instance.new("TextLabel")
    typeLabel.Name = "TypeLabel"
    typeLabel.Size = UDim2.new(0.4, -6, 0, 14)
    typeLabel.Position = UDim2.new(0.6, 0, 0, 4)
    typeLabel.BackgroundTransparency = 1
    typeLabel.Font = Enum.Font.Gotham
    typeLabel.TextSize = 9
    typeLabel.TextColor3 = Color3.fromRGB(130, 145, 165)
    typeLabel.TextXAlignment = Enum.TextXAlignment.Right
    typeLabel.Text = slot
    typeLabel.ZIndex = 17
    typeLabel.Parent = card

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "AbilityName"
    nameLabel.Size = UDim2.new(1, -8, 0, 32)
    nameLabel.Position = UDim2.new(0, 4, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBlack
    nameLabel.TextSize = 11
    nameLabel.TextColor3 = Color3.fromRGB(245, 245, 250)
    nameLabel.TextWrapped = true
    nameLabel.ZIndex = 17
    nameLabel.Parent = card

    local overlay = Instance.new("Frame")
    overlay.Name = "CooldownOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
    overlay.BackgroundTransparency = 0.35
    overlay.BorderSizePixel = 0
    overlay.Visible = false
    overlay.ZIndex = 18
    overlay.Parent = card

    local overlayCorner = Instance.new("UICorner")
    overlayCorner.CornerRadius = UDim.new(0, 6)
    overlayCorner.Parent = overlay

    local sweep = Instance.new("Frame")
    sweep.Name = "Sweep"
    sweep.Size = UDim2.new(1, 0, 0, 0)
    sweep.Position = UDim2.new(0, 0, 1, 0)
    sweep.AnchorPoint = Vector2.new(0, 1)
    sweep.BackgroundColor3 = Color3.fromRGB(255, 100, 20)
    sweep.BackgroundTransparency = 0.75
    sweep.BorderSizePixel = 0
    sweep.ZIndex = 19
    sweep.Parent = overlay

    local sweepCorner = Instance.new("UICorner")
    sweepCorner.CornerRadius = UDim.new(0, 6)
    sweepCorner.Parent = sweep

    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name = "Timer"
    timerLabel.Size = UDim2.new(1, 0, 1, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Font = Enum.Font.GothamBlack
    timerLabel.TextSize = 15
    timerLabel.TextColor3 = Color3.fromRGB(255, 225, 90)
    timerLabel.Text = "0.0s"
    timerLabel.ZIndex = 20
    timerLabel.Parent = overlay

    return {
        Slot = slot,
        Card = card,
        CardStroke = cardStroke,
        KeybindLabel = keybind,
        NameLabel = nameLabel,
        TypeLabel = typeLabel,
        Overlay = overlay,
        Sweep = sweep,
        TimerLabel = timerLabel,
        AbilityName = nil,
    }
end

for idx, slot in ipairs(SLOT_ORDER) do
    abilitySlotWidgets[slot] = createAbilitySlotCard(slot, idx)
end

local function refreshAbilitiesHUD(titanId: string)
    activeTitanIdForHUD = titanId
    table.clear(activeAbilityCooldowns)

    local titanDef = TitanRegistry.Get(titanId) or TitanRegistry.Get("Ravager")
    if not titanDef then return end

    for _, slot in ipairs(SLOT_ORDER) do
        local widget = abilitySlotWidgets[slot]
        if widget then
            local ability = TitanRegistry.GetAbilityForSlot(titanId, slot)
            if ability then
                widget.Card.Visible = true
                widget.NameLabel.Text = ability.DisplayName
                widget.KeybindLabel.Text = ability.KeybindDisplay
                widget.AbilityName = ability.Name
                widget.Overlay.Visible = false
                widget.CardStroke.Color = Color3.fromRGB(45, 54, 72)
            else
                widget.Card.Visible = false
                widget.AbilityName = nil
                widget.Overlay.Visible = false
            end
        end
    end
end

local function triggerAbilityCooldownUI(abilityName: string, duration: number)
    local now = os.clock()
    activeAbilityCooldowns[abilityName] = {
        EndTime = now + duration,
        Duration = duration,
    }
    for _, widget in pairs(abilitySlotWidgets) do
        if widget.AbilityName == abilityName then
            widget.Overlay.Visible = true
            widget.TimerLabel.Text = string.format("%.1fs", duration)
            widget.Sweep.Size = UDim2.new(1, 0, 1, 0)
            widget.CardStroke.Color = Color3.fromRGB(180, 50, 40)
        end
    end
end

-- Short centred notice for titan awaken results (pedestal prompts and the selection panel)
local activeToast: TextLabel? = nil
local function showToast(message: string, color: Color3)
    if activeToast then activeToast:Destroy() end

    local toast = Instance.new("TextLabel")
    toast.Name = "Toast"
    toast.AnchorPoint = Vector2.new(0.5, 0)
    toast.Position = UDim2.new(0.5, 0, 0.22, 0)
    toast.Size = UDim2.new(0, 520, 0, 46)
    toast.BackgroundColor3 = Color3.fromRGB(20, 18, 22)
    toast.BackgroundTransparency = 0.25
    toast.Text = message
    toast.TextColor3 = color
    toast.TextStrokeTransparency = 0.4
    toast.Font = Enum.Font.GothamBlack
    toast.TextSize = 22
    toast.TextWrapped = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = toast
    toast.Parent = MainUI
    activeToast = toast

    task.delay(2.4, function()
        if not toast.Parent then return end
        local fade = TweenService:Create(toast, TweenInfo.new(0.4), {
            TextTransparency = 1,
            TextStrokeTransparency = 1,
            BackgroundTransparency = 1,
        })
        fade:Play()
        fade.Completed:Connect(function()
            toast:Destroy()
        end)
    end)
end

TitanFeedbackRemote.OnClientEvent:Connect(function(eventType: string, data: any)
    if not data then return end
    if eventType == "TitanSelected" and type(data.TitanId) == "string" then
        local def = TitanRegistry.Get(data.TitanId)
        showToast(string.format("%s AWAKENS!", string.upper(if def then def.DisplayName else data.TitanId)), Color3.fromRGB(255, 150, 40))
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
        AudioController.PlayTitanRoar(data.TitanId, root)
    elseif eventType == "TitanSelectRejected" and type(data.Reason) == "string" then
        showToast(data.Reason, Color3.fromRGB(235, 200, 190))
        AudioController.PlayUI("UpgradeError")
    end
    if eventType == "TitanListSync" or eventType == "TitanSelected" then
        updateTitanSelectionView(data)
        local newSel = data.SelectedTitan or data.TitanId
        if newSel and type(newSel) == "string" then refreshAbilitiesHUD(newSel) end
    elseif eventType == "TitanSpawned" then
        if data.TitanId and type(data.TitanId) == "string" then refreshAbilitiesHUD(data.TitanId) end
    elseif eventType == "AbilityUsed" then
        if data.Ability and data.Cooldown then triggerAbilityCooldownUI(data.Ability, data.Cooldown) end
    elseif eventType == "AbilityRejected" then
        if data.Remaining and data.Ability then triggerAbilityCooldownUI(data.Ability, data.Remaining) end
        if data.Reason then warn("[TitanSelect] " .. tostring(data.Reason)) end
    end
end)

TitanEffectRemote.OnClientEvent:Connect(function(effectType: string, sourceChar: Model, data: any)
    if sourceChar == LocalPlayer.Character then
        local abilityMap: { [string]: string } = {
            BasicAttack = "BasicAttack",
            TailSweep = "TailSweep",
            Stomp = "Stomp",
            StompWindup = "Stomp",
            HeavyStomp = "HeavyStomp",
            HeavyStompWindup = "HeavyStomp",
            NeckStrike = "NeckStrike",
            Roar = "Roar",
        }
        local ab = abilityMap[effectType]
        if ab and not activeAbilityCooldowns[ab] then
            local def = TitanRegistry.GetAbility(activeTitanIdForHUD, ab)
            if def and def.Cooldown then triggerAbilityCooldownUI(ab, def.Cooldown) end
        end
    end
end)

refreshAbilitiesHUD("Ravager")

local function updateCitySelectionView(citiesList: { any })
    for _, cityInfo in ipairs(citiesList) do
        local card = if cityInfo.CityId == "SmallTown" then CardSmallTown elseif cityInfo.CityId == "Metrovale" then CardMetrovale else nil
        if card then
            local statusLbl = card:FindFirstChild("Status") :: TextLabel?
            local reqLbl = card:FindFirstChild("Requirements") :: TextLabel?
            local recBox = card:FindFirstChild("RecordsBox") :: Frame?
            local actionBtn = card:FindFirstChild("ActionButton") :: TextButton?

            if statusLbl then
                if cityInfo.Unlocked then
                    statusLbl.Text = if cityInfo.IsActive then "⭐ CURRENT CITY" else "✓ UNLOCKED"
                    statusLbl.BackgroundColor3 = if cityInfo.IsActive then Color3.fromRGB(30, 80, 140) else Color3.fromRGB(18, 45, 30)
                    statusLbl.TextColor3 = if cityInfo.IsActive then Color3.fromRGB(120, 200, 255) else Color3.fromRGB(80, 230, 120)
                else
                    statusLbl.Text = "🔒 LOCKED"
                    statusLbl.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
                    statusLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
                end
            end

            if reqLbl then
                if cityInfo.Unlocked then
                    reqLbl.Text = string.format("Completed %d times", cityInfo.Completions or 0)
                    reqLbl.TextColor3 = Color3.fromRGB(140, 210, 160)
                else
                    reqLbl.Text = cityInfo.LockReason or "Requirements not met"
                    reqLbl.TextColor3 = Color3.fromRGB(240, 130, 130)
                end
            end

            if recBox then
                local bestTimeLbl = recBox:FindFirstChild("BestTime") :: TextLabel?
                local bestComboLbl = recBox:FindFirstChild("BestCombo") :: TextLabel?

                if bestTimeLbl then
                    local bt = cityInfo.BestTime or 0
                    if bt > 0 then
                        local m = math.floor(bt / 60)
                        local s = bt % 60
                        bestTimeLbl.Text = string.format("⏱️ Best Time: %02dm %02ds", m, s)
                    else
                        bestTimeLbl.Text = "⏱️ Best Time: --:--"
                    end
                end

                if bestComboLbl then
                    local bc = cityInfo.BestCombo or 1
                    bestComboLbl.Text = string.format("🔥 Best Combo: %dx", bc)
                end

                local bestScoreLbl = recBox:FindFirstChild("BestScore") :: TextLabel?
                if bestScoreLbl then
                    local bs = cityInfo.BestScore or 0
                    if bs > 0 then
                        bestScoreLbl.Text = string.format("⭐ Best Score: %s", formatCommas(bs))
                    else
                        bestScoreLbl.Text = "⭐ Best Score: --"
                    end
                end
            end

            if actionBtn then
                if cityInfo.IsActive then
                    actionBtn.Text = "ACTIVE CITY"
                    actionBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 60)
                    actionBtn.TextColor3 = Color3.fromRGB(160, 165, 175)
                    actionBtn.AutoButtonColor = false
                elseif cityInfo.Unlocked then
                    actionBtn.Text = "SELECT & PLAY"
                    actionBtn.BackgroundColor3 = Color3.fromRGB(255, 120, 20)
                    actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    actionBtn.AutoButtonColor = true
                else
                    actionBtn.Text = "LOCKED"
                    actionBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 45)
                    actionBtn.TextColor3 = Color3.fromRGB(120, 125, 135)
                    actionBtn.AutoButtonColor = false
                end
            end
        end
    end
end

-- Keybinds: U for Upgrades, M for Cities/Map
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.U then
        UpgradePanel.Visible = not UpgradePanel.Visible
        if UpgradePanel.Visible then
            ProgressionUpdateRemote:FireServer("RequestSync")
            updateUpgradeMatrixView()
        end
    elseif input.KeyCode == Enum.KeyCode.M then
        CitySelectionPanel.Visible = not CitySelectionPanel.Visible
    elseif input.KeyCode == Enum.KeyCode.T then
        TitanSelectionPanel.Visible = not TitanSelectionPanel.Visible
        if TitanSelectionPanel.Visible then TitanSelectRequestRemote:FireServer("RequestSync") end
    end
end)

-- Remote Event: CityFeedback (Progress, Completion, Reset)
CityFeedbackRemote.OnClientEvent:Connect(function(eventType: string, data: any)
    if not data then return end

    if eventType == "CityListSync" then
        if type(data) == "table" then updateCitySelectionView(data) end
    elseif eventType == "CityLoaded" then
        for _, entry in ipairs(activeDamageNumbers) do
            if entry.Anchor and entry.Anchor.Parent then entry.Anchor:Destroy() end
        end
        table.clear(activeDamageNumbers)
        table.clear(buildingHealthRatios)
        CitySelectionPanel.Visible = false
        if data and (data.CityName or data.CityId) then
            CityNameLabel.Text = string.format("🏙️ %s", string.upper(data.CityName or data.CityId))
        end
        cityState.IsCompleted = false
        cityState.RunStartTime = os.clock()
        TimerLabel.Text = "⏱️ 00:00.00"
    elseif eventType == "CityUnlocked" then
        if data and data.CityName then
            BannerTitle.Text = string.format("🔓 %s UNLOCKED!", string.upper(data.CityName))
            BannerDesc.Text = "A massive new urban battlefield awaits your colossal rampage!"
            LevelUpBanner.Position = UDim2.new(0.5, 0, 0, -100)
            LevelUpBanner.Visible = true
            TweenService:Create(LevelUpBanner, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, 0, 0, 25),
            }):Play()
            task.delay(3.0, function()
                TweenService:Create(LevelUpBanner, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = UDim2.new(0.5, 0, 0, -100),
                }):Play()
            end)
        end
    elseif eventType == "CitySelectRejected" then
        if data and data.Reason then warn("[CitySelect] Selection rejected: " .. tostring(data.Reason)) end
    elseif eventType == "CityProgressUpdate" then
        if data.CityName then CityNameLabel.Text = string.format("🏙️ %s", string.upper(data.CityName)) end

        local total = data.TotalBuildings or 15
        local destroyed = data.DestroyedBuildings or 0
        local completionPct = data.CityCompletionPercentage or 0

        BuildingsLabel.Text = string.format("Buildings: %d / %d", destroyed, total)
        DestructionLabel.Text = string.format("Destruction: %d%%", completionPct)

        local ratio = math.clamp(destroyed / math.max(1, total), 0, 1)
        TweenService:Create(ProgressBarFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(ratio, 0, 1, 0),
        }):Play()

        if data.RunStartTime then cityState.RunStartTime = data.RunStartTime end
        cityState.IsCompleted = (data.CityCompleted == true)
    elseif eventType == "CityCompleted" then
        cityState.IsCompleted = true
        AudioController.PlayCityComplete()

        -- Celebration camera rumble
        task.spawn(function()
            for _ = 1, 8 do
                Workspace.CurrentCamera.CFrame = Workspace.CurrentCamera.CFrame
                    * CFrame.Angles(math.rad(math.random(-10, 10) * 0.05), math.rad(math.random(-10, 10) * 0.05), 0)
                task.wait(0.03)
            end
        end)

        -- Duration formatting (MM:SS.cs)
        local duration = data.Duration or 0
        local dMins = math.floor(duration / 60)
        local dSecs = math.floor(duration % 60)
        local dCs = math.floor((duration % 1) * 100)
        local timeFormatted = string.format("%02d:%02d.%02d", dMins, dSecs, dCs)

        local bestTime = data.BestTime or duration
        local btMins = math.floor(bestTime / 60)
        local btSecs = math.floor(bestTime % 60)
        local bestTimeFormatted = string.format("%02d:%02d", btMins, btSecs)

        -- 1. Score Card Display with animated count-up
        local finalScore = data.DestructionScore or 0
        local sb = data.ScoreBreakdown or {}
        ScoreBreakdown.Text = string.format(
            "Base: %s | Combo: +%s | Speed: +%s | Clear: +%s",
            formatCommas(sb.BaseScore or 0),
            formatCommas(sb.ComboBonus or 0),
            formatCommas(sb.SpeedBonus or 0),
            formatCommas(sb.CompletionBonus or 0)
        )

        ScoreBadge.Visible = (data.IsNewBestScore == true)
        if data.IsNewBestScore then ScoreBadge.Text = "★ NEW BEST SCORE! ★" end

        -- Animate score count-up
        task.spawn(function()
            local steps = 20
            for i = 1, steps do
                local cur = math.floor((finalScore / steps) * i)
                ScoreValue.Text = formatCommas(cur)
                task.wait(0.02)
            end
            ScoreValue.Text = formatCommas(finalScore)
        end)

        -- 2. Stats Card with Personal Best comparisons
        local timeTag = if data.IsNewBestTime then " ★ NEW BEST!" else string.format(" (Best: %s)", bestTimeFormatted)
        CardTime.Text = string.format("⏱️ Clear Time: %s%s", timeFormatted, timeTag)
        if data.IsNewBestTime then
            CardTime.TextColor3 = Color3.fromRGB(255, 215, 60)
        else
            CardTime.TextColor3 = Color3.fromRGB(255, 255, 255)
        end

        local comboTag = if data.IsNewBestCombo then " ★ NEW BEST!" else string.format(" (Best: %dx)", data.BestCombo or 1)
        CardCombo.Text = string.format("🔥 Max Combo: %dx%s", data.HighestCombo or 1, comboTag)
        if data.IsNewBestCombo then
            CardCombo.TextColor3 = Color3.fromRGB(255, 140, 40)
        else
            CardCombo.TextColor3 = Color3.fromRGB(255, 255, 255)
        end

        local bpm = data.BuildingsPerMinute or 0
        local bpmTag = if data.IsNewBestBpm then " ★ NEW BEST!" else string.format(" (Best: %.1f)", data.BestBPM or bpm)
        CardPace.Text = string.format("⚡ Pace: %.1f BPM%s", bpm, bpmTag)
        if data.IsNewBestBpm then
            CardPace.TextColor3 = Color3.fromRGB(120, 220, 255)
        else
            CardPace.TextColor3 = Color3.fromRGB(255, 255, 255)
        end

        local totalBld = data.TotalBuildings or 15
        local destroyedBld = data.DestroyedBuildings or totalBld
        CardBuildings.Text = string.format("🏛️ Flattened: %d / %d (100%%)", destroyedBld, totalBld)
        CardDamage.Text = string.format("💥 Total DMG: %s", formatCommas(data.TotalDamage or 0))

        local attacks = data.BasicAttacks or 0
        local stomps = data.Stomps or 0
        local roars = data.Roars or 0
        CardAbilities.Text = string.format("⚔️ Abilities: %d Strikes | %d Stomps | %d Roars", attacks, stomps, roars)

        -- 3. Rewards Card
        RewBuildings.Text = string.format(
            "Buildings: +$%s Cash | +%s Pts | +%s XP",
            formatCommas(data.BuildingsCash or 0),
            formatCommas(data.BuildingsPoints or 0),
            formatCommas(data.BuildingsXP or 0)
        )
        RewBonus.Text = string.format(
            "City Bonus: +$%s Cash | +%s Pts | +%s XP",
            formatCommas(data.CompletionCash or 5000),
            formatCommas(data.CompletionPoints or 2500),
            formatCommas(data.CompletionXP or 2000)
        )
        RewTotal.Text = string.format(
            "TOTAL RUN: +$%s Cash | +%s Pts | +%s XP",
            formatCommas(data.TotalCash or 0),
            formatCommas(data.TotalPoints or 0),
            formatCommas(data.TotalXP or 0)
        )

        -- Animate completion screen into view
        CompletionScreen.Position = UDim2.new(0.5, 0, 0.45, 0)
        CompletionScreen.Visible = true
        TweenService:Create(CompletionScreen, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0.5, 0),
        }):Play()
    elseif eventType == "CityReset" then
        for _, entry in ipairs(activeDamageNumbers) do
            if entry.Anchor and entry.Anchor.Parent then entry.Anchor:Destroy() end
        end
        table.clear(activeDamageNumbers)
        table.clear(buildingHealthRatios)
        cityState.IsCompleted = false
        cityState.RunStartTime = data.RunStartTime or os.clock()

        -- Hide completion screen
        CompletionScreen.Visible = false

        -- Reset progress UI
        local total = data.TotalBuildings or 15
        BuildingsLabel.Text = string.format("Buildings: 0 / %d", total)
        DestructionLabel.Text = "Destruction: 0%"
        TweenService:Create(ProgressBarFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 0, 1, 0),
        }):Play()
        TimerLabel.Text = "⏱️ 00:00.00"
    end
end)

-- Rebuild City Button Binding
RebuildButton.MouseButton1Click:Connect(function()
    AudioController.PlayUI("Rebuild")
    RebuildCityRequestRemote:FireServer("SmallTown")
end)

-- Live Run Timer background task (smooth millisecond tracking)
local RunService = game:GetService("RunService")
local comboDrainTween: Tween? = nil
local comboResetFeedbackActive = false

RunService.Heartbeat:Connect(function()
    if cityState.RunStartTime > 0 and not cityState.IsCompleted then
        local elapsed = math.max(0, os.clock() - cityState.RunStartTime)
        local mins = math.floor(elapsed / 60)
        local secs = math.floor(elapsed % 60)
        local cs = math.floor((elapsed % 1) * 100)
        TimerLabel.Text = string.format("⏱️ %02d:%02d.%02d", mins, secs, cs)
    end

    -- Real-time Cooldown HUD update
    local now = os.clock()
    for _, widget in pairs(abilitySlotWidgets) do
        if widget.Card.Visible and widget.AbilityName then
            local cd = activeAbilityCooldowns[widget.AbilityName]
            if cd and now < cd.EndTime then
                local remaining = cd.EndTime - now
                local fraction = math.clamp(remaining / math.max(0.05, cd.Duration), 0, 1)
                widget.Overlay.Visible = true
                widget.TimerLabel.Text = string.format("%.1fs", remaining)
                widget.Sweep.Size = UDim2.new(1, 0, fraction, 0)
            elseif widget.Overlay.Visible then
                widget.Overlay.Visible = false
                activeAbilityCooldowns[widget.AbilityName] = nil
                widget.CardStroke.Color = Color3.fromRGB(100, 255, 140)
                TweenService:Create(widget.CardStroke, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Color = Color3.fromRGB(45, 54, 72),
                }):Play()
            end
        end
    end
end)

--[=[
    Spawns juicy building impact particles: concrete dust clouds and masonry friction sparks.
]=]
local function spawnBuildingImpactVFX(pos: Vector3, tier: number)
    local vfxPart = Instance.new("Part")
    vfxPart.Name = "BuildingImpactVFX"
    vfxPart.Size = Vector3.new(1, 1, 1)
    vfxPart.CFrame = CFrame.new(pos)
    vfxPart.Transparency = 1
    vfxPart.Anchored = true
    vfxPart.CanCollide = false
    vfxPart.CanTouch = false
    vfxPart.CanQuery = false
    vfxPart.Parent = Workspace

    local att = Instance.new("Attachment")
    att.Parent = vfxPart

    -- 1. Billowing Concrete Dust Puff
    local dust = Instance.new("ParticleEmitter")
    dust.Name = "ConcreteDust"
    dust.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(195, 185, 175)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(160, 150, 140)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 105, 100)),
    })
    dust.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 3.5),
        NumberSequenceKeypoint.new(0.4, 7.5 + (tier * 1.5)),
        NumberSequenceKeypoint.new(1, 11.0 + (tier * 2.0)),
    })
    dust.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.25),
        NumberSequenceKeypoint.new(0.6, 0.45),
        NumberSequenceKeypoint.new(1, 1),
    })
    dust.Speed = NumberRange.new(14, 28 + (tier * 6))
    dust.SpreadAngle = Vector2.new(180, 180)
    dust.Lifetime = NumberRange.new(0.5, 0.85)
    dust.Rate = 0
    dust.LightEmission = 0
    dust.LightInfluence = 0.5
    dust.Parent = att
    dust:Emit(22 + (tier * 6))

    -- 2. Flying Masonry Friction Sparks
    local sparks = Instance.new("ParticleEmitter")
    sparks.Name = "MasonrySparks"
    sparks.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 120)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 150, 40)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 10)),
    })
    sparks.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.0),
        NumberSequenceKeypoint.new(1, 0),
    })
    sparks.Speed = NumberRange.new(30, 70 + (tier * 10))
    sparks.SpreadAngle = Vector2.new(180, 180)
    sparks.Lifetime = NumberRange.new(0.3, 0.6)
    sparks.Rate = 0
    sparks.LightEmission = 1
    sparks.LightInfluence = 0
    sparks.Acceleration = Vector3.new(0, -45, 0)
    sparks.Parent = att
    sparks:Emit(25 + (tier * 8))

    -- 3. High-impact Flash Disc
    local flash = Instance.new("Part")
    flash.Name = "ImpactFlashDisc"
    flash.Shape = Enum.PartType.Ball
    flash.Size = Vector3.new(4 + tier * 2, 4 + tier * 2, 4 + tier * 2)
    flash.CFrame = CFrame.new(pos)
    flash.Material = Enum.Material.Neon
    flash.Color = Color3.fromRGB(255, 225, 160)
    flash.Anchored = true
    flash.CanCollide = false
    flash.CanTouch = false
    flash.CanQuery = false
    flash.Parent = Workspace

    local ft = TweenService:Create(flash, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(10 + tier * 4, 10 + tier * 4, 10 + tier * 4),
        Transparency = 1,
    })
    ft:Play()
    ft.Completed:Connect(function()
        flash:Destroy()
    end)

    task.delay(1.0, function()
        vfxPart:Destroy()
    end)
end

--[=[
    Spawns massive collapse dust explosion and rubble debris.
]=]
local function spawnCollapseDustVFX(pos: Vector3, tier: number)
    local vfxPart = Instance.new("Part")
    vfxPart.Name = "CollapseDustVFX"
    vfxPart.Size = Vector3.new(1, 1, 1)
    vfxPart.CFrame = CFrame.new(pos)
    vfxPart.Transparency = 1
    vfxPart.Anchored = true
    vfxPart.CanCollide = false
    vfxPart.CanTouch = false
    vfxPart.CanQuery = false
    vfxPart.Parent = Workspace

    local att = Instance.new("Attachment")
    att.Parent = vfxPart

    local dustRing = Instance.new("ParticleEmitter")
    dustRing.Name = "CollapseDustRing"
    dustRing.Color = ColorSequence.new(Color3.fromRGB(150, 140, 130), Color3.fromRGB(90, 85, 80))
    dustRing.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 6.0),
        NumberSequenceKeypoint.new(0.5, 18.0 + (tier * 4.0)),
        NumberSequenceKeypoint.new(1, 26.0 + (tier * 6.0)),
    })
    dustRing.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.7, 0.6),
        NumberSequenceKeypoint.new(1, 1),
    })
    dustRing.Speed = NumberRange.new(25, 60 + (tier * 12))
    dustRing.SpreadAngle = Vector2.new(180, 45)
    dustRing.Lifetime = NumberRange.new(1.0, 1.8)
    dustRing.Rate = 0
    dustRing.Acceleration = Vector3.new(0, 8, 0)
    dustRing.Parent = att
    dustRing:Emit(45 + (tier * 15))

    task.delay(2.2, function()
        vfxPart:Destroy()
    end)
end

-- Remote Event: DestructionFeedback (Visuals & Audio)
DestructionFeedback.OnClientEvent:Connect(function(eventType: string, data: any)
    if eventType == "ComboUpdate" then
        if data and data.Multiplier then
            local mult = math.clamp(data.Multiplier, 1, 5)
            local timeout = data.Timeout or 4.0
            if mult > lastComboMult then AudioController.PlayComboProgress(mult) end
            lastComboMult = mult

            local comboColors = {
                [1] = Color3.fromRGB(220, 160, 90),
                [2] = Color3.fromRGB(255, 215, 0),
                [3] = Color3.fromRGB(255, 130, 20),
                [4] = Color3.fromRGB(255, 60, 20),
                [5] = Color3.fromRGB(255, 20, 20),
            }
            local comboSizes = { [1] = 16, [2] = 18, [3] = 20, [4] = 22, [5] = 25 }
            local targetSize = comboSizes[mult] or 18
            local targetColor = comboColors[mult] or Color3.fromRGB(255, 100, 20)

            comboResetFeedbackActive = false
            ComboLabel.Text = if mult >= 5 then "🔥 MAX COMBO: 5x 🔥" else string.format("🔥 COMBO: %dx", mult)
            ComboLabel.TextColor3 = targetColor

            local tween = TweenService:Create(ComboLabel, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                TextSize = targetSize + 4,
            })
            tween:Play()
            tween.Completed:Connect(function()
                TweenService:Create(ComboLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    TextSize = targetSize,
                }):Play()
            end)

            -- Animate draining timer bar
            if comboDrainTween then
                comboDrainTween:Cancel()
                comboDrainTween = nil
            end

            ComboBarFill.BackgroundColor3 = targetColor
            ComboBarFill.Size = UDim2.new(1, 0, 1, 0)
            comboDrainTween = TweenService:Create(ComboBarFill, TweenInfo.new(timeout, Enum.EasingStyle.Linear), {
                Size = UDim2.new(0, 0, 1, 0),
            })
            comboDrainTween:Play()
        end
    elseif eventType == "ComboReset" then
        if comboDrainTween then
            comboDrainTween:Cancel()
            comboDrainTween = nil
        end
        ComboBarFill.Size = UDim2.new(0, 0, 1, 0)

        if lastComboMult > 1 then
            ComboLabel.Text = "💨 COMBO LOST"
            ComboLabel.TextColor3 = Color3.fromRGB(190, 85, 85)
            comboResetFeedbackActive = true
            task.delay(1.2, function()
                if comboResetFeedbackActive and lastComboMult == 1 then
                    ComboLabel.Text = "🔥 COMBO: 1x"
                    ComboLabel.TextColor3 = Color3.fromRGB(180, 185, 190)
                    comboResetFeedbackActive = false
                end
            end)
        else
            ComboLabel.Text = "🔥 COMBO: 1x"
            ComboLabel.TextColor3 = Color3.fromRGB(180, 185, 190)
        end
        lastComboMult = 1
    elseif eventType == "BuildingDamaged" then
        local pos = data.Position or Vector3.zero
        local dmg = data.Damage or 0
        local combo = data.Combo or 1
        local bld = data.Building
        local source = data.Source

        -- Audio Feedback: Building tier impact & structural health state transitions
        local tier = 1
        if bld and bld:IsA("Model") then
            tier = tonumber(bld:GetAttribute("DestructionTier")) or 1
            local curHp = data.CurrentHealth or 0
            local maxHp = data.MaxHealth or 1000
            local newRatio = if maxHp > 0 then curHp / maxHp else 0
            local oldRatio = buildingHealthRatios[bld] or 1.0
            buildingHealthRatios[bld] = newRatio

            AudioController.PlayStructuralDamage(newRatio, oldRatio, pos)
        end

        AudioController.PlayBuildingImpact(tier, pos)
        AudioController.PlayReward(combo)

        -- Concrete dust puff and masonry friction sparks on building impact
        spawnBuildingImpactVFX(pos, tier)

        -- Spawn distinct, throttled floating damage number
        spawnDamageNumber(pos, dmg, combo, source)
    elseif eventType == "BuildingDestroyed" then
        local pos = data.Position or Vector3.zero
        local rewards = data.Rewards or {}
        local cash = rewards.Cash or 0
        local combo = rewards.Combo or 1
        local bld = data.Building

        -- Audio Feedback: Multi-stage structural collapse sequence & reward
        local tier = 1
        if bld and bld:IsA("Model") then
            tier = tonumber(bld:GetAttribute("DestructionTier")) or 1
            buildingHealthRatios[bld] = 0
        end

        AudioController.PlayCollapseSequence(tier, pos)
        AudioController.PlayReward(combo)

        -- Massive building collapse dust plume
        spawnCollapseDustVFX(pos, tier)

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "DestroyedBillboard"
        billboard.Size = UDim2.new(0, 180, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 15, 0)
        billboard.AlwaysOnTop = true

        local text = Instance.new("TextLabel")
        text.Size = UDim2.new(1, 0, 1, 0)
        text.BackgroundTransparency = 1
        text.Text = string.format("💥 DESTROYED! +$%d (%dx)", cash, combo)
        text.TextColor3 = Color3.fromRGB(255, 220, 50)
        text.TextStrokeTransparency = 0.1
        text.Font = Enum.Font.GothamBlack
        text.TextSize = 24
        text.Parent = billboard

        local anchor = Instance.new("Part")
        anchor.Transparency = 1
        anchor.CanCollide = false
        anchor.CanQuery = false
        anchor.CanTouch = false
        anchor.Anchored = true
        anchor.Size = Vector3.new(0.5, 0.5, 0.5)
        anchor.Position = pos
        anchor.Parent = Workspace
        billboard.Adornee = anchor
        billboard.Parent = anchor

        local tween = TweenService:Create(billboard, TweenInfo.new(1.0, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            StudsOffset = Vector3.new(0, 25, 0),
        })
        local fade = TweenService:Create(text, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            TextTransparency = 1,
            TextStrokeTransparency = 1,
        })
        tween:Play()
        fade:Play()

        task.delay(1.1, function()
            anchor:Destroy()
        end)
    end
end)

-- Remote Event: DropFeedback (Cash pickup chime and green sparkle burst)
local DropFeedbackRemote = RemotesFolder:FindFirstChild("DropFeedback") :: RemoteEvent?
if not DropFeedbackRemote then
    pcall(function()
        DropFeedbackRemote = RemotesFolder:WaitForChild("DropFeedback", 4) :: RemoteEvent?
    end)
end

if DropFeedbackRemote then
    DropFeedbackRemote.OnClientEvent:Connect(function(actionType: string, data: any)
        if actionType == "CashCollected" then
            local amt = data.Amount or 0
            local pos = data.Position or Vector3.zero

            -- Play crisp currency chime sound
            local chime = Instance.new("Sound")
            chime.SoundId = "rbxasset://sounds/electronicpingshort.wav"
            chime.Volume = 0.50
            chime.PlaybackSpeed = math.random(115, 140) / 100
            chime.Parent = Workspace
            chime:Play()
            chime.Ended:Connect(function()
                chime:Destroy()
            end)

            -- Floating green cash indicator "+$50"
            local billboard = Instance.new("BillboardGui")
            billboard.Size = UDim2.new(0, 130, 0, 38)
            billboard.AlwaysOnTop = true

            local anchor = Instance.new("Part")
            anchor.Transparency = 1
            anchor.CanCollide = false
            anchor.CanQuery = false
            anchor.CanTouch = false
            anchor.Anchored = true
            anchor.Size = Vector3.new(0.5, 0.5, 0.5)
            anchor.Position = pos + Vector3.new(0, 2, 0)
            anchor.Parent = Workspace

            billboard.Adornee = anchor
            billboard.Parent = anchor

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = string.format("💵 +$%d", amt)
            lbl.TextColor3 = Color3.fromRGB(100, 255, 130)
            lbl.TextStrokeColor3 = Color3.fromRGB(0, 45, 15)
            lbl.TextStrokeTransparency = 0.2
            lbl.Font = Enum.Font.GothamBlack
            lbl.TextSize = 20
            lbl.Parent = billboard

            local tw = TweenService:Create(billboard, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                StudsOffset = Vector3.new(0, 5, 0),
            })
            local ft = TweenService:Create(lbl, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                TextTransparency = 1,
                TextStrokeTransparency = 1,
            })
            tw:Play()
            ft:Play()
            task.delay(0.8, function()
                anchor:Destroy()
            end)
        elseif actionType == "CashPop" then
            local pos = data.Position or Vector3.zero
            local popPart = Instance.new("Part")
            popPart.Size = Vector3.new(1, 1, 1)
            popPart.CFrame = CFrame.new(pos)
            popPart.Transparency = 1
            popPart.Anchored = true
            popPart.CanCollide = false
            popPart.CanTouch = false
            popPart.CanQuery = false
            popPart.Parent = Workspace

            local att = Instance.new("Attachment")
            att.Parent = popPart

            local p = Instance.new("ParticleEmitter")
            p.Color = ColorSequence.new(Color3.fromRGB(80, 255, 120), Color3.fromRGB(255, 255, 255))
            p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.0), NumberSequenceKeypoint.new(1, 0) })
            p.Speed = NumberRange.new(10, 25)
            p.SpreadAngle = Vector2.new(180, 180)
            p.Lifetime = NumberRange.new(0.3, 0.5)
            p.Rate = 0
            p.LightEmission = 1
            p.Parent = att
            p:Emit(18)

            task.delay(0.6, function()
                popPart:Destroy()
            end)
        end
    end)
end

print("[DestructionHUD] City progress, completion tracking, and cash drops initialized.")
