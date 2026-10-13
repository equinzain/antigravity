--!strict
-- Interface Client de "Voler une Épée" :
-- - Gain hors ligne fortement réduit et réaliste
-- - Gestion des épées posées dans la base vs dans l'inventaire + Revente au Marchand
-- - Popups verts "+$..." quand on marche sur le bouton de récolte devant une épée

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StateUpdateEvent = Remotes:WaitForChild("StateUpdate") :: RemoteEvent
local NotificationEvent = Remotes:WaitForChild("Notification") :: RemoteEvent
local SwordRevealEvent = Remotes:WaitForChild("SwordReveal") :: RemoteEvent
local ActionEvent = Remotes:WaitForChild("PlayerAction") :: RemoteEvent
local PopupEvent = Remotes:WaitForChild("FloatingPopup") :: RemoteEvent
local OpenMerchantEvent = Remotes:WaitForChild("OpenMerchant") :: RemoteEvent

local currentState = {
	Money = 60,
	MoneyPerSec = 0,
	TotalSpeed = 18,
	TreadmillLevel = 1,
	TreadmillGain = 2,
	SlowMode = false,
	CarryingStoneId = nil :: string?,
	PlacedSwordUids = {} :: { [string]: boolean },
	OwnedTrails = {} :: { [string]: boolean },
	EquippedTrailId = nil :: string?,
	TrailSpeedMult = 1.0,
	TrailMoneyMult = 1.0,
	Inventory = {} :: { GameConfig.OwnedSwordItem },
	Discovered = {} :: { [string]: boolean },
	Upgrades = {
		SpeedLevel = 1,
		CarryStrength = 1,
		ForgeSpeed = 1,
		SlotCount = 4,
	},
	NightRemaining = 230,
	PotionRemaining = 0,
}

local oldGui = playerGui:FindFirstChild("StealASwordHUD")
if oldGui then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StealASwordHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local function addCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function addStroke(parent: Instance, color: Color3, thickness: number, strokeMode: Enum.ApplyStrokeMode?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	if strokeMode then
		s.ApplyStrokeMode = strokeMode
	end
	s.Parent = parent
	return s
end

-- ============================================================================
-- 1. HAUT CENTRE : "Vous gagnez $.../jour hors ligne ! 😈" (FORTEMENT RÉDUIT)
-- ============================================================================
local offlineLabel = Instance.new("TextLabel")
offlineLabel.Name = "OfflineEarningsBanner"
offlineLabel.Size = UDim2.fromOffset(720, 48)
offlineLabel.Position = UDim2.new(0.5, -360, 0, 14)
offlineLabel.BackgroundTransparency = 1
offlineLabel.Font = Enum.Font.FredokaOne
offlineLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
offlineLabel.TextScaled = true
offlineLabel.Text = "Vous gagnez $0/jour hors ligne ! 😈"
offlineLabel.Parent = screenGui
addStroke(offlineLabel, Color3.fromRGB(0, 0, 0), 3)

-- ============================================================================
-- 2. GAUCHE MILIEU : BOUTIQUE (!), INDICE, MODE LENT, ET POSER MON TAPIS
-- ============================================================================
local leftPanel = Instance.new("Frame")
leftPanel.Size = UDim2.fromOffset(180, 260)
leftPanel.Position = UDim2.new(0, 14, 0.5, -110)
leftPanel.BackgroundTransparency = 1
leftPanel.Parent = screenGui

local shopBtn = Instance.new("TextButton")
shopBtn.Name = "ShopButton"
shopBtn.Size = UDim2.fromOffset(152, 54)
shopBtn.Position = UDim2.fromOffset(0, 0)
shopBtn.BackgroundColor3 = Color3.fromRGB(55, 235, 45)
shopBtn.Font = Enum.Font.FredokaOne
shopBtn.TextColor3 = Color3.new(1, 1, 1)
shopBtn.TextSize = 25
shopBtn.Text = "🛒Boutique"
shopBtn.Parent = leftPanel
addCorner(shopBtn, 10)
addStroke(shopBtn, Color3.new(0, 0, 0), 3, Enum.ApplyStrokeMode.Border)
addStroke(shopBtn, Color3.new(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

local alertBadge = Instance.new("TextLabel")
alertBadge.Size = UDim2.fromOffset(24, 24)
alertBadge.Position = UDim2.new(1, -14, 0, -8)
alertBadge.BackgroundColor3 = Color3.fromRGB(235, 35, 35)
alertBadge.Font = Enum.Font.FredokaOne
alertBadge.TextColor3 = Color3.new(1, 1, 1)
alertBadge.TextSize = 18
alertBadge.Text = "!"
alertBadge.Parent = shopBtn
addCorner(alertBadge, 12)
addStroke(alertBadge, Color3.new(0, 0, 0), 2)

local indexBtn = Instance.new("TextButton")
indexBtn.Name = "IndexButton"
indexBtn.Size = UDim2.fromOffset(152, 54)
indexBtn.Position = UDim2.fromOffset(0, 64)
indexBtn.BackgroundColor3 = Color3.fromRGB(45, 195, 255)
indexBtn.Font = Enum.Font.FredokaOne
indexBtn.TextColor3 = Color3.new(1, 1, 1)
indexBtn.TextSize = 25
indexBtn.Text = "📘 Indice"
indexBtn.Parent = leftPanel
addCorner(indexBtn, 10)
addStroke(indexBtn, Color3.new(0, 0, 0), 3, Enum.ApplyStrokeMode.Border)
addStroke(indexBtn, Color3.new(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

local slowContainer = Instance.new("Frame")
slowContainer.Size = UDim2.fromOffset(170, 34)
slowContainer.Position = UDim2.fromOffset(0, 128)
slowContainer.BackgroundTransparency = 1
slowContainer.Parent = leftPanel

local slowToggleBtn = Instance.new("TextButton")
slowToggleBtn.Size = UDim2.fromOffset(78, 30)
slowToggleBtn.Position = UDim2.fromOffset(0, 2)
slowToggleBtn.BackgroundColor3 = Color3.fromRGB(25, 95, 25)
slowToggleBtn.Text = ""
slowToggleBtn.Parent = slowContainer
addCorner(slowToggleBtn, 8)
addStroke(slowToggleBtn, Color3.new(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Border)

local slowKnob = Instance.new("Frame")
slowKnob.Size = UDim2.fromOffset(34, 24)
slowKnob.Position = UDim2.fromOffset(3, 3)
slowKnob.BackgroundColor3 = Color3.fromRGB(75, 240, 45)
slowKnob.Parent = slowToggleBtn
addCorner(slowKnob, 6)

local slowLabel = Instance.new("TextLabel")
slowLabel.Size = UDim2.fromOffset(88, 30)
slowLabel.Position = UDim2.fromOffset(84, 2)
slowLabel.BackgroundTransparency = 1
slowLabel.Font = Enum.Font.FredokaOne
slowLabel.TextColor3 = Color3.new(1, 1, 1)
slowLabel.TextXAlignment = Enum.TextXAlignment.Left
slowLabel.TextSize = 18
slowLabel.Text = "Mode lent"
slowLabel.Parent = slowContainer
addStroke(slowLabel, Color3.new(0, 0, 0), 2)

local spawnTreadmillBtn = Instance.new("TextButton")
spawnTreadmillBtn.Name = "SpawnTreadmillButton"
spawnTreadmillBtn.Size = UDim2.fromOffset(152, 46)
spawnTreadmillBtn.Position = UDim2.fromOffset(0, 172)
spawnTreadmillBtn.BackgroundColor3 = Color3.fromRGB(255, 110, 35)
spawnTreadmillBtn.Font = Enum.Font.FredokaOne
spawnTreadmillBtn.TextColor3 = Color3.new(1, 1, 1)
spawnTreadmillBtn.TextScaled = true
spawnTreadmillBtn.Text = "🏃 Poser Tapis [T]"
spawnTreadmillBtn.Parent = leftPanel
addCorner(spawnTreadmillBtn, 10)
addStroke(spawnTreadmillBtn, Color3.new(0, 0, 0), 3, Enum.ApplyStrokeMode.Border)
addStroke(spawnTreadmillBtn, Color3.new(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

-- ============================================================================
-- 3. BAS GAUCHE : 👟 VITESSE (ROSE VIF) ET 💵 $ARGENT (VERT VIF)
-- ============================================================================
local bottomLeft = Instance.new("Frame")
bottomLeft.Size = UDim2.fromOffset(360, 115)
bottomLeft.Position = UDim2.new(0, 14, 1, -125)
bottomLeft.BackgroundTransparency = 1
bottomLeft.Parent = screenGui

local speedRow = Instance.new("Frame")
speedRow.Size = UDim2.new(1, 0, 0, 52)
speedRow.Position = UDim2.fromOffset(0, 0)
speedRow.BackgroundTransparency = 1
speedRow.Parent = bottomLeft

local shoeIcon = Instance.new("TextLabel")
shoeIcon.Size = UDim2.fromOffset(48, 48)
shoeIcon.Position = UDim2.fromOffset(0, 2)
shoeIcon.BackgroundTransparency = 1
shoeIcon.Text = "👟"
shoeIcon.TextScaled = true
shoeIcon.Parent = speedRow

local plusSpeedBtn = Instance.new("TextButton")
plusSpeedBtn.Size = UDim2.fromOffset(22, 22)
plusSpeedBtn.Position = UDim2.fromOffset(30, 28)
plusSpeedBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 35)
plusSpeedBtn.Font = Enum.Font.FredokaOne
plusSpeedBtn.TextColor3 = Color3.new(1, 1, 1)
plusSpeedBtn.TextSize = 18
plusSpeedBtn.Text = "+"
plusSpeedBtn.Parent = speedRow
addCorner(plusSpeedBtn, 5)
addStroke(plusSpeedBtn, Color3.new(0, 0, 0), 2, Enum.ApplyStrokeMode.Border)

local speedValueLabel = Instance.new("TextLabel")
speedValueLabel.Size = UDim2.new(1, -62, 1, 0)
speedValueLabel.Position = UDim2.fromOffset(60, 0)
speedValueLabel.BackgroundTransparency = 1
speedValueLabel.Font = Enum.Font.FredokaOne
speedValueLabel.TextColor3 = Color3.fromRGB(255, 45, 225)
speedValueLabel.TextXAlignment = Enum.TextXAlignment.Left
speedValueLabel.TextScaled = true
speedValueLabel.Text = "18"
speedValueLabel.Parent = speedRow
addStroke(speedValueLabel, Color3.new(0, 0, 0), 3)

local moneyRow = Instance.new("Frame")
moneyRow.Size = UDim2.new(1, 0, 0, 54)
moneyRow.Position = UDim2.fromOffset(0, 56)
moneyRow.BackgroundTransparency = 1
moneyRow.Parent = bottomLeft

local cashIcon = Instance.new("TextLabel")
cashIcon.Size = UDim2.fromOffset(48, 48)
cashIcon.Position = UDim2.fromOffset(0, 2)
cashIcon.BackgroundTransparency = 1
cashIcon.Text = "💵"
cashIcon.TextScaled = true
cashIcon.Parent = moneyRow

local moneyValueLabel = Instance.new("TextLabel")
moneyValueLabel.Size = UDim2.new(1, -62, 1, 0)
moneyValueLabel.Position = UDim2.fromOffset(60, 0)
moneyValueLabel.BackgroundTransparency = 1
moneyValueLabel.Font = Enum.Font.FredokaOne
moneyValueLabel.TextColor3 = Color3.fromRGB(65, 255, 55)
moneyValueLabel.TextXAlignment = Enum.TextXAlignment.Left
moneyValueLabel.TextScaled = true
moneyValueLabel.Text = "$60"
moneyValueLabel.Parent = moneyRow
addStroke(moneyValueLabel, Color3.new(0, 0, 0), 3)

-- ============================================================================
-- 4. DROITE MILIEU : 3 BOUTONS CARRÉS
-- ============================================================================
local rightPanel = Instance.new("Frame")
rightPanel.Size = UDim2.fromOffset(74, 240)
rightPanel.Position = UDim2.new(1, -86, 0.5, -110)
rightPanel.BackgroundTransparency = 1
rightPanel.Parent = screenGui

local function createRightSquareButton(yPos: number, bgColor: Color3, iconText: string): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(64, 64)
	btn.Position = UDim2.fromOffset(5, yPos)
	btn.BackgroundColor3 = bgColor
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = 36
	btn.Text = iconText
	btn.Parent = rightPanel
	addCorner(btn, 10)
	addStroke(btn, Color3.new(0, 0, 0), 3, Enum.ApplyStrokeMode.Border)
	return btn
end

local stonesRightBtn = createRightSquareButton(0, Color3.fromRGB(255, 85, 75), "🪨")
local swordsRightBtn = createRightSquareButton(80, Color3.fromRGB(255, 150, 55), "⚔️")
local potionsRightBtn = createRightSquareButton(168, Color3.fromRGB(95, 235, 55), "🧪")

local potionTimerLabel = Instance.new("TextLabel")
potionTimerLabel.Size = UDim2.fromOffset(84, 22)
potionTimerLabel.Position = UDim2.fromOffset(-5, 144)
potionTimerLabel.BackgroundTransparency = 1
potionTimerLabel.Font = Enum.Font.FredokaOne
potionTimerLabel.TextColor3 = Color3.fromRGB(255, 70, 50)
potionTimerLabel.TextScaled = true
potionTimerLabel.Text = "Boosts"
potionTimerLabel.Parent = rightPanel
addStroke(potionTimerLabel, Color3.new(0, 0, 0), 2)

-- ============================================================================
-- 5. BAS DROITE : PILLULE SOMBRE "🌙 en 3 minutes 50 secondes"
-- ============================================================================
local nightPill = Instance.new("Frame")
nightPill.Size = UDim2.fromOffset(220, 50)
nightPill.Position = UDim2.new(1, -234, 1, -64)
nightPill.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
nightPill.BackgroundTransparency = 0.25
nightPill.Parent = screenGui
addCorner(nightPill, 25)

local moonIcon = Instance.new("TextLabel")
moonIcon.Size = UDim2.fromOffset(42, 42)
moonIcon.Position = UDim2.fromOffset(10, 4)
moonIcon.BackgroundTransparency = 1
moonIcon.Text = "🌙"
moonIcon.TextScaled = true
moonIcon.Parent = nightPill

local nightText = Instance.new("TextLabel")
nightText.Size = UDim2.new(1, -62, 1, -8)
nightText.Position = UDim2.fromOffset(56, 4)
nightText.BackgroundTransparency = 1
nightText.Font = Enum.Font.FredokaOne
nightText.TextColor3 = Color3.new(1, 1, 1)
nightText.TextScaled = true
nightText.Text = "en 3 minutes\n50 secondes"
nightText.Parent = nightPill
addStroke(nightText, Color3.new(0, 0, 0), 2)

-- ============================================================================
-- 6. FENÊTRES MODALES
-- ============================================================================
local function createModalWindow(title: string, strokeColor: Color3): (Frame, ScrollingFrame)
	local modal = Instance.new("Frame")
	modal.Size = UDim2.fromOffset(540, 405)
	modal.Position = UDim2.new(0.5, -270, 0.5, -202)
	modal.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
	modal.Visible = false
	modal.Parent = screenGui
	addCorner(modal, 16)
	addStroke(modal, strokeColor, 3, Enum.ApplyStrokeMode.Border)

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -60, 0, 44)
	header.Position = UDim2.fromOffset(16, 8)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.FredokaOne
	header.TextColor3 = strokeColor
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextSize = 24
	header.Text = title
	header.Parent = modal
	addStroke(header, Color3.new(0, 0, 0), 2)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(38, 38)
	closeBtn.Position = UDim2.new(1, -46, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(235, 55, 55)
	closeBtn.Font = Enum.Font.FredokaOne
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextSize = 22
	closeBtn.Text = "X"
	closeBtn.Parent = modal
	addCorner(closeBtn, 8)
	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -24, 1, -68)
	list.Position = UDim2.fromOffset(12, 56)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.Parent = modal

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list

	return modal, list
end

local shopModal, shopList = createModalWindow("🛒 BOUTIQUE & AMÉLIORATIONS", Color3.fromRGB(65, 235, 55))
local indexModal, indexList = createModalWindow("📘 INDICE DES ÉPÉES (COLLECTION)", Color3.fromRGB(45, 195, 255))
local invModal, invList = createModalWindow("⚔️ INVENTAIRE & MARCHAND D'ÉPÉES", Color3.fromRGB(255, 180, 45))
local zonesModal, zonesList = createModalWindow("🪨 LES 10 ZONES & PALIERS DE VITESSE", Color3.fromRGB(255, 85, 75))
local potionsModal, potionsList = createModalWindow("🧪 POTIONS BOOST (3 MINUTES)", Color3.fromRGB(95, 235, 55))
local trailsModal, trailsList = createModalWindow("✨ BOUTIQUE DE SENTIERS (TRAÎNÉES)", Color3.fromRGB(55, 225, 255))

local allModals = { shopModal, indexModal, invModal, zonesModal, potionsModal, trailsModal }
local function toggleModal(target: Frame)
	local wasVisible = target.Visible
	for _, m in ipairs(allModals) do
		m.Visible = false
	end
	target.Visible = not wasVisible
end

local upgradeRows: { [string]: { Label: TextLabel, Btn: TextButton } } = {}
local upgOrder = { "SpeedLevel", "ForgeSpeed", "CarryStrength", "SlotCount" }
for _, upgId in ipairs(upgOrder) do
	local upgInfo = GameConfig.Upgrades[upgId]
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -10, 0, 68)
	row.BackgroundColor3 = Color3.fromRGB(36, 42, 58)
	row.Parent = shopList
	addCorner(row, 10)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.65, -12, 1, -8)
	lbl.Position = UDim2.fromOffset(10, 4)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextScaled = true
	lbl.Parent = row

	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(0.32, 0, 0, 48)
	buyBtn.Position = UDim2.new(0.66, 0, 0.5, -24)
	buyBtn.BackgroundColor3 = Color3.fromRGB(55, 210, 75)
	buyBtn.Font = Enum.Font.FredokaOne
	buyBtn.TextColor3 = Color3.new(1, 1, 1)
	buyBtn.TextScaled = true
	buyBtn.Parent = row
	addCorner(buyBtn, 8)
	addStroke(buyBtn, Color3.new(0, 0, 0), 2, Enum.ApplyStrokeMode.Border)

	buyBtn.MouseButton1Click:Connect(function()
		ActionEvent:FireServer("BuyUpgrade", upgId)
	end)

	upgradeRows[upgId] = { Label = lbl, Btn = buyBtn }
end
shopList.CanvasSize = UDim2.fromOffset(0, #upgOrder * 78)

local trailRows: { [string]: TextButton } = {}
for _, tInfo in ipairs(GameConfig.Trails) do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -10, 0, 68)
	row.BackgroundColor3 = Color3.fromRGB(36, 42, 58)
	row.Parent = trailsList
	addCorner(row, 10)
	addStroke(row, tInfo.Color1, 1.5, Enum.ApplyStrokeMode.Border)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.65, -12, 1, -8)
	lbl.Position = UDim2.fromOffset(10, 4)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextColor3 = tInfo.Color1
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextScaled = true
	lbl.Text = string.format(
		"✨ %s\n👟 x%.2f Vitesse   |   💵 x%.2f Argent",
		tInfo.Name,
		tInfo.SpeedMultiplier,
		tInfo.MoneyMultiplier
	)
	lbl.Parent = row

	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(0.32, 0, 0, 48)
	buyBtn.Position = UDim2.new(0.66, 0, 0.5, -24)
	buyBtn.BackgroundColor3 = Color3.fromRGB(55, 200, 95)
	buyBtn.Font = Enum.Font.FredokaOne
	buyBtn.TextColor3 = Color3.new(1, 1, 1)
	buyBtn.TextScaled = true
	buyBtn.Text = "$" .. GameConfig.FormatNumber(tInfo.Price)
	buyBtn.Parent = row
	addCorner(buyBtn, 8)
	addStroke(buyBtn, Color3.new(0, 0, 0), 2, Enum.ApplyStrokeMode.Border)

	buyBtn.MouseButton1Click:Connect(function()
		ActionEvent:FireServer("BuyOrEquipTrail", tInfo.Id)
	end)

	trailRows[tInfo.Id] = buyBtn
end
trailsList.CanvasSize = UDim2.fromOffset(0, #GameConfig.Trails * 78)

for _, tier in ipairs(GameConfig.StoneTiers) do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -10, 0, 64)
	row.BackgroundColor3 = Color3.fromRGB(36, 42, 58)
	row.Parent = zonesList
	addCorner(row, 10)
	addStroke(row, tier.CrystalColor, 1.5, Enum.ApplyStrokeMode.Border)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -20, 1, -8)
	lbl.Position = UDim2.fromOffset(10, 4)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextColor3 = tier.CrystalColor
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextScaled = true
	lbl.Text = string.format(
		"%s ($%s - $%s/s)\n⏳ Éclosion : %s  |  ⚔️ %s (Vitesse : %s)",
		tier.ZoneName,
		GameConfig.FormatNumber(tier.MinBaseMoneyPerSec),
		GameConfig.FormatNumber(tier.MaxBaseMoneyPerSec * 3),
		GameConfig.FormatTime(tier.ForgeTime),
		tier.GuardianName,
		GameConfig.FormatNumber(tier.GuardianSpeedStat)
	)
	lbl.Parent = row
end
zonesList.CanvasSize = UDim2.fromOffset(0, #GameConfig.StoneTiers * 74)

local potionTypes = {
	{ Id = "Speed", Title = "🧪 Potion x2 Vitesse (3 minutes)", Color = Color3.fromRGB(55, 195, 255) },
	{ Id = "Money", Title = "🧪 Potion x2 Argent $/s (3 minutes)", Color = Color3.fromRGB(75, 235, 95) },
}
for _, pInfo in ipairs(potionTypes) do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -10, 0, 68)
	row.BackgroundColor3 = Color3.fromRGB(36, 42, 58)
	row.Parent = potionsList
	addCorner(row, 10)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.65, -12, 1, -8)
	lbl.Position = UDim2.fromOffset(10, 4)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextColor3 = pInfo.Color
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextScaled = true
	lbl.Text = pInfo.Title
	lbl.Parent = row

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.32, 0, 0, 48)
	btn.Position = UDim2.new(0.66, 0, 0.5, -24)
	btn.BackgroundColor3 = pInfo.Color
	btn.Font = Enum.Font.FredokaOne
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextScaled = true
	btn.Text = "$500"
	btn.Parent = row
	addCorner(btn, 8)
	addStroke(btn, Color3.new(0, 0, 0), 2, Enum.ApplyStrokeMode.Border)

	btn.MouseButton1Click:Connect(function()
		ActionEvent:FireServer("ActivatePotion", pInfo.Id)
	end)
end

-- ============================================================================
-- 7. CARTE D'ÉCLOSION D'ÉPÉE & NOTIFICATIONS
-- ============================================================================
local revealCard = Instance.new("Frame")
revealCard.Size = UDim2.fromOffset(400, 225)
revealCard.Position = UDim2.new(0.5, -200, 0.25, 0)
revealCard.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
revealCard.Visible = false
revealCard.Parent = screenGui
addCorner(revealCard, 18)
local revealStroke = addStroke(revealCard, Color3.fromRGB(255, 215, 55), 3.5, Enum.ApplyStrokeMode.Border)

local revealTitle = Instance.new("TextLabel")
revealTitle.Size = UDim2.new(1, -20, 0, 38)
revealTitle.Position = UDim2.fromOffset(10, 10)
revealTitle.BackgroundTransparency = 1
revealTitle.Font = Enum.Font.FredokaOne
revealTitle.TextColor3 = Color3.fromRGB(255, 235, 110)
revealTitle.TextScaled = true
revealTitle.Text = "✨ ÉCLOSION DE LA PIERRE ! ✨"
revealTitle.Parent = revealCard

local revealName = Instance.new("TextLabel")
revealName.Size = UDim2.new(1, -20, 0, 58)
revealName.Position = UDim2.fromOffset(10, 52)
revealName.BackgroundTransparency = 1
revealName.Font = Enum.Font.FredokaOne
revealName.TextScaled = true
revealName.Parent = revealCard
addStroke(revealName, Color3.new(0, 0, 0), 2.5)

local revealStats = Instance.new("TextLabel")
revealStats.Size = UDim2.new(1, -20, 0, 44)
revealStats.Position = UDim2.fromOffset(10, 116)
revealStats.BackgroundTransparency = 1
revealStats.Font = Enum.Font.FredokaOne
revealStats.TextColor3 = Color3.fromRGB(75, 255, 95)
revealStats.TextScaled = true
revealStats.Parent = revealCard
addStroke(revealStats, Color3.new(0, 0, 0), 2)

local okBtn = Instance.new("TextButton")
okBtn.Size = UDim2.fromOffset(140, 36)
okBtn.Position = UDim2.new(0.5, -70, 1, -44)
okBtn.BackgroundColor3 = Color3.fromRGB(60, 215, 85)
okBtn.Font = Enum.Font.FredokaOne
okBtn.TextColor3 = Color3.new(1, 1, 1)
okBtn.TextSize = 20
okBtn.Text = "Super !"
okBtn.Parent = revealCard
addCorner(okBtn, 8)
okBtn.MouseButton1Click:Connect(function()
	revealCard.Visible = false
end)

local notifContainer = Instance.new("Frame")
notifContainer.Size = UDim2.fromOffset(520, 120)
notifContainer.Position = UDim2.new(0.5, -260, 1, -155)
notifContainer.BackgroundTransparency = 1
notifContainer.Parent = screenGui

local notifLayout = Instance.new("UIListLayout")
notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
notifLayout.Padding = UDim.new(0, 6)
notifLayout.Parent = notifContainer

local function showNotification(msg: string, color: Color3)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 34)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextColor3 = color
	lbl.TextScaled = true
	lbl.Text = msg
	lbl.Parent = notifContainer
	addStroke(lbl, Color3.new(0, 0, 0), 2.5)

	task.delay(3.5, function()
		local tw = TweenService:Create(lbl, TweenInfo.new(0.4), { TextTransparency = 1 })
		tw:Play()
		tw.Completed:Wait()
		lbl:Destroy()
	end)
end

-- ============================================================================
-- 8. RAFRAÎCHISSEMENT DE L'INTERFACE
-- ============================================================================
local function refreshUI()
	-- Gain hors ligne fortement réduit (ex: $29/s -> ~$5.2K/jour hors ligne au lieu de >$2.5M)
	local dailyOffline = math.floor(currentState.MoneyPerSec * 180)
	offlineLabel.Text = string.format("Vous gagnez $%s/jour hors ligne ! 😈", GameConfig.FormatNumber(dailyOffline))

	if currentState.TrailSpeedMult > 1.0 then
		speedValueLabel.Text = string.format("%s (x%.2f)", GameConfig.FormatNumber(currentState.TotalSpeed), currentState.TrailSpeedMult)
	else
		speedValueLabel.Text = GameConfig.FormatNumber(currentState.TotalSpeed)
	end
	moneyValueLabel.Text = "$" .. GameConfig.FormatNumber(currentState.Money)

	if currentState.SlowMode then
		slowKnob.Position = UDim2.fromOffset(41, 3)
		slowKnob.BackgroundColor3 = Color3.fromRGB(255, 210, 50)
	else
		slowKnob.Position = UDim2.fromOffset(3, 3)
		slowKnob.BackgroundColor3 = Color3.fromRGB(75, 240, 45)
	end

	local nm = math.floor(currentState.NightRemaining / 60)
	local ns = currentState.NightRemaining % 60
	nightText.Text = string.format("en %d minutes\n%d secondes", nm, ns)

	if currentState.PotionRemaining > 0 then
		potionTimerLabel.Text = GameConfig.FormatTime(currentState.PotionRemaining)
	else
		potionTimerLabel.Text = "Boosts"
	end

	for _, upgId in ipairs(upgOrder) do
		local upgInfo = GameConfig.Upgrades[upgId]
		local row = upgradeRows[upgId]
		local lvl = (currentState.Upgrades :: any)[upgId] or 1
		row.Label.Text = string.format("%s (Niv. %d/%d)\n%s", upgInfo.Name, lvl, upgInfo.MaxLevel, upgInfo.Description)
		if lvl >= upgInfo.MaxLevel then
			row.Btn.Text = "MAX"
			row.Btn.BackgroundColor3 = Color3.fromRGB(100, 105, 120)
		else
			local cost = GameConfig.GetUpgradeCost(upgId, lvl)
			row.Btn.Text = "$" .. GameConfig.FormatNumber(cost)
			row.Btn.BackgroundColor3 = if currentState.Money >= cost
				then Color3.fromRGB(55, 215, 75)
				else Color3.fromRGB(165, 60, 60)
		end
	end

	for _, tInfo in ipairs(GameConfig.Trails) do
		local btn = trailRows[tInfo.Id]
		if btn then
			if currentState.EquippedTrailId == tInfo.Id then
				btn.Text = "Équipée"
				btn.BackgroundColor3 = Color3.fromRGB(55, 175, 255)
			elseif currentState.OwnedTrails[tInfo.Id] then
				btn.Text = "Équiper"
				btn.BackgroundColor3 = Color3.fromRGB(65, 210, 95)
			else
				btn.Text = "$" .. GameConfig.FormatNumber(tInfo.Price)
				btn.BackgroundColor3 = if currentState.Money >= tInfo.Price
					then Color3.fromRGB(55, 215, 75)
					else Color3.fromRGB(165, 60, 60)
			end
		end
	end

	for _, c in ipairs(indexList:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for _, sInfo in pairs(GameConfig.Swords) do
		local rInfo = GameConfig.Rarities[sInfo.Rarity]
		local unlocked = currentState.Discovered[sInfo.Id] == true
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 50)
		row.BackgroundColor3 = if unlocked then Color3.fromRGB(36, 44, 62) else Color3.fromRGB(22, 24, 32)
		row.Parent = indexList
		addCorner(row, 8)
		addStroke(row, if unlocked then rInfo.Color else Color3.fromRGB(70, 75, 85), 1.5, Enum.ApplyStrokeMode.Border)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -20, 1, -8)
		lbl.Position = UDim2.fromOffset(10, 4)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextColor3 = if unlocked then rInfo.Color else Color3.fromRGB(130, 135, 145)
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextScaled = true
		lbl.Text = if unlocked
			then string.format("✅ [%s] %s (Débloquée !)", rInfo.Name, sInfo.Name)
			else string.format("🔒 [%s] ??? (Éclos une Pierre pour découvrir)", rInfo.Name)
		lbl.Parent = row
	end

	for _, c in ipairs(invList:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end

	local sortedInv = table.clone(currentState.Inventory)
	table.sort(sortedInv, function(a, b)
		return a.MoneyPerSec > b.MoneyPerSec
	end)

	for _, item in ipairs(sortedInv) do
		local rInfo = GameConfig.Rarities[item.Rarity] or GameConfig.Rarities.Common
		local isPlaced = currentState.PlacedSwordUids[item.Uid] == true
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 64)
		row.BackgroundColor3 = Color3.fromRGB(36, 42, 58)
		row.Parent = invList
		addCorner(row, 10)
		addStroke(row, rInfo.Color, 1.5, Enum.ApplyStrokeMode.Border)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.52, -10, 1, -8)
		lbl.Position = UDim2.fromOffset(10, 4)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextColor3 = rInfo.Color
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextScaled = true
		lbl.Text = string.format(
			"[%s] %s\n+$%s/s (%s)",
			rInfo.Name,
			item.Name,
			GameConfig.FormatNumber(item.MoneyPerSec),
			if isPlaced then "Posée Base" else "En Sac"
		)
		lbl.Parent = row

		local placeBtn = Instance.new("TextButton")
		placeBtn.Size = UDim2.new(0.21, 0, 0, 44)
		placeBtn.Position = UDim2.new(0.53, 0, 0.5, -22)
		placeBtn.BackgroundColor3 = if isPlaced then Color3.fromRGB(70, 155, 235) else Color3.fromRGB(65, 200, 85)
		placeBtn.Font = Enum.Font.FredokaOne
		placeBtn.TextColor3 = Color3.new(1, 1, 1)
		placeBtn.TextScaled = true
		placeBtn.Text = if isPlaced then "Ranger Sac" else "Poser Base"
		placeBtn.Parent = row
		addCorner(placeBtn, 8)
		placeBtn.MouseButton1Click:Connect(function()
			ActionEvent:FireServer("TogglePlaceSword", item.Uid)
		end)

		local sellBtn = Instance.new("TextButton")
		sellBtn.Size = UDim2.new(0.22, 0, 0, 44)
		sellBtn.Position = UDim2.new(0.76, 0, 0.5, -22)
		sellBtn.BackgroundColor3 = Color3.fromRGB(235, 145, 35)
		sellBtn.Font = Enum.Font.FredokaOne
		sellBtn.TextColor3 = Color3.new(1, 1, 1)
		sellBtn.TextScaled = true
		sellBtn.Text = "Vendre\n$" .. GameConfig.FormatNumber(item.SellPrice)
		sellBtn.Parent = row
		addCorner(sellBtn, 8)
		sellBtn.MouseButton1Click:Connect(function()
			ActionEvent:FireServer("SellSword", item.Uid)
		end)
	end
	invList.CanvasSize = UDim2.fromOffset(0, #sortedInv * 72)
end

shopBtn.MouseButton1Click:Connect(function()
	toggleModal(shopModal)
end)
plusSpeedBtn.MouseButton1Click:Connect(function()
	toggleModal(trailsModal)
end)
indexBtn.MouseButton1Click:Connect(function()
	toggleModal(indexModal)
end)
stonesRightBtn.MouseButton1Click:Connect(function()
	toggleModal(zonesModal)
end)
swordsRightBtn.MouseButton1Click:Connect(function()
	toggleModal(invModal)
end)
potionsRightBtn.MouseButton1Click:Connect(function()
	toggleModal(potionsModal)
end)
slowToggleBtn.MouseButton1Click:Connect(function()
	ActionEvent:FireServer("ToggleSlowMode")
end)
spawnTreadmillBtn.MouseButton1Click:Connect(function()
	ActionEvent:FireServer("SpawnTreadmill")
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.T then
		ActionEvent:FireServer("SpawnTreadmill")
	end
end)

OpenMerchantEvent.OnClientEvent:Connect(function(merchantType: string)
	for _, m in ipairs(allModals) do
		m.Visible = false
	end
	if merchantType == "SellSwords" then
		invModal.Visible = true
	elseif merchantType == "TrailsShop" then
		trailsModal.Visible = true
	end
end)

StateUpdateEvent.OnClientEvent:Connect(function(newState)
	currentState = newState
	refreshUI()
end)

NotificationEvent.OnClientEvent:Connect(function(msg: string, color: Color3)
	showNotification(msg, color)
end)

SwordRevealEvent.OnClientEvent:Connect(function(data)
	revealStroke.Color = data.RarityColor
	revealName.Text = string.format("[%s]\n%s", data.Rarity, data.Name)
	revealName.TextColor3 = data.RarityColor
	revealStats.Text = string.format(
		"💵 Revenu aléatoire : +$%s / sec\n(Passe sur le bouton vert devant l'épée pour récolter !)",
		GameConfig.FormatNumber(data.MoneyPerSec)
	)
	revealCard.Visible = true
end)

PopupEvent.OnClientEvent:Connect(function(popupType: string, textValue: string)
	local isMoney = (popupType == "Money")
	local count = if isMoney then 1 else 2
	for i = 1, count do
		task.delay((i - 1) * 0.12, function()
			local pop = Instance.new("TextLabel")
			pop.Size = UDim2.fromOffset(190, 46)
			local rx = math.random(-120, 120)
			local ry = math.random(-60, 40)
			pop.Position = UDim2.new(0.5, rx - 95, 0.45, ry)
			pop.BackgroundTransparency = 1
			pop.Font = Enum.Font.FredokaOne
			pop.TextColor3 = if isMoney then Color3.fromRGB(65, 255, 75) else Color3.fromRGB(255, 55, 225)
			pop.TextScaled = true
			pop.Text = if isMoney then ("💵 " .. textValue) else ("👟 " .. textValue)
			pop.Parent = screenGui
			addStroke(pop, Color3.new(0, 0, 0), 2.5)

			local tw = TweenService:Create(
				pop,
				TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = pop.Position - UDim2.fromOffset(0, 65), TextTransparency = 1 }
			)
			tw:Play()
			tw.Completed:Wait()
			pop:Destroy()
		end)
	end
end)
