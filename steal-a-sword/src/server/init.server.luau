--!strict
-- Serveur principal de "Voler une Épée" :
-- 1. Tapis de course : il suffit d'être dessus (sans bouger) pour gagner de la Vitesse chaque seconde.
-- 2. Pierres d'Épée : ramassage uniquement par clic ou touche E (plus de ramassage accidentel au contact).
-- 3. Éclosion : l'épée reste sur son emplacement dans la base (pas dans la main du joueur) et peut être récupérée dans l'inventaire pour être revendue.
-- 4. Récolte d'Argent : l'argent s'accumule sur chaque épée et se récupère en marchant sur le bouton vert devant l'épée !
-- 5. Décorations dans chaque zone (Cactus dans le désert, etc.) et Vendeurs/Gardes style vrais personnages Roblox.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ModelBuilder = require(Shared:WaitForChild("ModelBuilder"))

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if Remotes then
	Remotes:Destroy()
end
Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage

local StateUpdateEvent = Instance.new("RemoteEvent")
StateUpdateEvent.Name = "StateUpdate"
StateUpdateEvent.Parent = Remotes

local NotificationEvent = Instance.new("RemoteEvent")
NotificationEvent.Name = "Notification"
NotificationEvent.Parent = Remotes

local SwordRevealEvent = Instance.new("RemoteEvent")
SwordRevealEvent.Name = "SwordReveal"
SwordRevealEvent.Parent = Remotes

local ActionEvent = Instance.new("RemoteEvent")
ActionEvent.Name = "PlayerAction"
ActionEvent.Parent = Remotes

local PopupEvent = Instance.new("RemoteEvent")
PopupEvent.Name = "FloatingPopup"
PopupEvent.Parent = Remotes

local OpenMerchantEvent = Instance.new("RemoteEvent")
OpenMerchantEvent.Name = "OpenMerchant"
OpenMerchantEvent.Parent = Remotes

local MapFolder = Workspace:FindFirstChild("StealASwordMap")
if MapFolder then
	MapFolder:Destroy()
end
MapFolder = Instance.new("Folder")
MapFolder.Name = "StealASwordMap"
MapFolder.Parent = Workspace

local defaultBaseplate = Workspace:FindFirstChild("Baseplate")
if defaultBaseplate and defaultBaseplate:IsA("BasePart") then
	defaultBaseplate.Transparency = 1
	defaultBaseplate.CanCollide = false
end

local function createPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = if props.Anchored ~= nil then props.Anchored else true
	p.CanCollide = if props.CanCollide ~= nil then props.CanCollide else true
	p.Material = props.Material or Enum.Material.Plastic
	p.Color = props.Color or Color3.fromRGB(200, 200, 200)
	p.Size = props.Size or Vector3.new(4, 1, 4)
	p.CFrame = props.CFrame or CFrame.new()
	p.TopSurface = props.TopSurface or Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Name then
		p.Name = props.Name
	end
	if props.Transparency then
		p.Transparency = props.Transparency
	end
	if props.Shape then
		p.Shape = props.Shape
	end
	if props.Parent then
		p.Parent = props.Parent
	end
	return p
end

local function createStyledWall(parent: Instance, cframe: CFrame, size: Vector3, wallColor: Color3?)
	local wColor = wallColor or Color3.fromRGB(185, 140, 88)
	local wall = createPart({
		Name = "PerimeterWall",
		Size = size,
		CFrame = cframe,
		Color = wColor,
		Material = Enum.Material.Brick,
		TopSurface = Enum.SurfaceType.Studs,
		Parent = parent,
	})
	ModelBuilder.ApplySurfaceTexture(
		wall,
		"rbxassetid://6372755229",
		{ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right },
		12,
		0.72,
		Color3.new(0, 0, 0)
	)
	createPart({
		Name = "WallTopGreen",
		Size = Vector3.new(size.X + 0.6, 2.5, size.Z + 0.6),
		CFrame = cframe * CFrame.new(0, size.Y / 2 + 1.25, 0),
		Color = Color3.fromRGB(65, 225, 45),
		Material = Enum.Material.Plastic,
		TopSurface = Enum.SurfaceType.Studs,
		Parent = parent,
	})
	return wall
end

type BaseSlot = {
	SlotIndex: number,
	State: "Empty" | "Forging" | "Ready" | "Sword",
	StoneId: string?,
	EndTime: number?,
	SwordItem: GameConfig.OwnedSwordItem?,
	AccumulatedMoney: number, -- Argent accumulé par cette épée en attendant que le joueur passe sur le bouton !
	PadPart: Part,
	CollectButtonPart: Part, -- Bouton vert devant l'épée pour récolter l'argent accumulé
	CollectLabel: TextLabel,
	TitleLabel: TextLabel,
	SubLabel: TextLabel,
	PrimaryPrompt: ProximityPrompt,
	VisualModel: Model?,
}

type PersonalTreadmillData = {
	Model: Model,
	Belt: Part,
	Prompt: ProximityPrompt,
	TitleLabel: TextLabel,
	BoardLabel: TextLabel,
}

type PlayerSession = {
	Player: Player,
	Money: number,
	TrainedSpeed: number,
	SlowMode: boolean,
	SpeedBoostUntil: number,
	MoneyBoostUntil: number,
	CarryingStoneId: string?,
	CarriedModel: Model?,
	OwnedTrails: { [string]: boolean },
	EquippedTrailId: string?,
	Inventory: { GameConfig.OwnedSwordItem }, -- Toutes les épées possédées (qu'elles soient posées sur la base ou rangées en sac)
	Discovered: { [string]: boolean },
	Upgrades: {
		SpeedLevel: number,
		CarryStrength: number,
		ForgeSpeed: number,
		SlotCount: number,
	},
	BaseIndex: number,
	BaseCenter: Vector3,
	BaseModel: Model,
	SpawnCFrame: CFrame,
	Slots: { BaseSlot },
	Treadmill: PersonalTreadmillData?,
	NextSwordUidCounter: number,
}

local PlayerSessions: { [Player]: PlayerSession } = {}
local AssignedBases: { [number]: Player? } = {}
local NightEventCycleEnd = os.clock() + 230

local RUNWAY_START_Z = 35
local CORRIDOR_WIDTH = 120
local HUB_WIDTH = 225
local HUB_DEPTH = 150
local HUB_CENTER = Vector3.new(0, 0, RUNWAY_START_Z + HUB_DEPTH / 2)

local function getTrailMultipliers(session: PlayerSession): (number, number)
	if not session.EquippedTrailId then
		return 1.0, 1.0
	end
	for _, t in ipairs(GameConfig.Trails) do
		if t.Id == session.EquippedTrailId then
			return t.SpeedMultiplier, t.MoneyMultiplier
		end
	end
	return 1.0, 1.0
end

local function getPlayerTotalSpeed(session: PlayerSession): number
	local spd = 18 + session.TrainedSpeed
	local trailSpdMult, _ = getTrailMultipliers(session)
	spd *= trailSpdMult
	if os.clock() < session.SpeedBoostUntil then
		spd *= 2
	end
	return math.floor(spd)
end

local function getPlayerMoneyPerSec(session: PlayerSession): number
	local total = 0
	for _, slot in ipairs(session.Slots) do
		if slot.State == "Sword" and slot.SwordItem then
			total += slot.SwordItem.MoneyPerSec
		end
	end
	local _, trailMoneyMult = getTrailMultipliers(session)
	total *= trailMoneyMult
	if os.clock() < session.MoneyBoostUntil then
		total *= 2
	end
	return math.floor(total)
end

local function applyCharacterWalkSpeed(session: PlayerSession)
	local char = session.Player.Character
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end

	local statSpeed = getPlayerTotalSpeed(session)
	local walkSpeed = GameConfig.StatSpeedToWalkSpeed(statSpeed)

	if session.SlowMode then
		walkSpeed = 20
	end

	if session.CarryingStoneId then
		local slowFactor = 0.72
		for _, tier in ipairs(GameConfig.StoneTiers) do
			if tier.Id == session.CarryingStoneId then
				slowFactor = tier.CarrySlowFactor
				break
			end
		end
		local bonus = (session.Upgrades.CarryStrength - 1) * 0.03
		walkSpeed = math.max(13, walkSpeed * math.clamp(slowFactor + bonus, 0.45, 0.95))
	end

	hum.WalkSpeed = walkSpeed
end

local function applyTrailOnCharacter(session: PlayerSession)
	local char = session.Player.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	for _, child in ipairs(hrp:GetChildren()) do
		if child.Name == "TrailAtt0" or child.Name == "TrailAtt1" or child.Name == "PlayerTrailEffect" then
			child:Destroy()
		end
	end

	if not session.EquippedTrailId then
		return
	end

	local foundTrail: GameConfig.TrailInfo? = nil
	for _, t in ipairs(GameConfig.Trails) do
		if t.Id == session.EquippedTrailId then
			foundTrail = t
			break
		end
	end
	if not foundTrail then
		return
	end

	local att0 = Instance.new("Attachment")
	att0.Name = "TrailAtt0"
	att0.Position = Vector3.new(0, 1.5, 0)
	att0.Parent = hrp

	local att1 = Instance.new("Attachment")
	att1.Name = "TrailAtt1"
	att1.Position = Vector3.new(0, -1.8, 0)
	att1.Parent = hrp

	local trail = Instance.new("Trail")
	trail.Name = "PlayerTrailEffect"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new(foundTrail.Color1, foundTrail.Color2)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.65
	trail.LightEmission = 1
	trail.MinLength = 0.1
	trail.Parent = hrp
end

-- Vérifie quelles épées sont actuellement posées sur la base
local function getPlacedSwordUids(session: PlayerSession): { [string]: boolean }
	local placed: { [string]: boolean } = {}
	for _, slot in ipairs(session.Slots) do
		if slot.State == "Sword" and slot.SwordItem then
			placed[slot.SwordItem.Uid] = true
		end
	end
	return placed
end

local function syncPlayerState(session: PlayerSession)
	local mps = getPlayerMoneyPerSec(session)
	local spd = getPlayerTotalSpeed(session)
	local trailSpdMult, trailMoneyMult = getTrailMultipliers(session)

	local leaderstats = session.Player:FindFirstChild("leaderstats")
	if leaderstats then
		local mpsVal = leaderstats:FindFirstChild("Money/s") :: StringValue?
		if mpsVal then
			mpsVal.Value = GameConfig.FormatNumber(mps)
		end
		local spdVal = leaderstats:FindFirstChild("Vitesse") :: StringValue?
		if spdVal then
			spdVal.Value = GameConfig.FormatNumber(spd)
		end
	end

	StateUpdateEvent:FireClient(session.Player, {
		Money = session.Money,
		MoneyPerSec = mps,
		TotalSpeed = spd,
		TreadmillLevel = session.Upgrades.SpeedLevel,
		TreadmillGain = GameConfig.GetTreadmillGainPerTick(session.Upgrades.SpeedLevel),
		SlowMode = session.SlowMode,
		CarryingStoneId = session.CarryingStoneId,
		PlacedSwordUids = getPlacedSwordUids(session),
		OwnedTrails = session.OwnedTrails,
		EquippedTrailId = session.EquippedTrailId,
		TrailSpeedMult = trailSpdMult,
		TrailMoneyMult = trailMoneyMult,
		Inventory = session.Inventory,
		Discovered = session.Discovered,
		Upgrades = session.Upgrades,
		NightRemaining = math.max(0, math.ceil(NightEventCycleEnd - os.clock())),
		PotionRemaining = math.max(0, math.ceil(math.max(session.SpeedBoostUntil, session.MoneyBoostUntil) - os.clock())),
	})
end

local function clearCarriedStone(session: PlayerSession)
	session.CarryingStoneId = nil
	if session.CarriedModel then
		session.CarriedModel:Destroy()
		session.CarriedModel = nil
	end
	applyCharacterWalkSpeed(session)
	syncPlayerState(session)
end

local function giveCarriedStone(session: PlayerSession, stoneTier: GameConfig.StoneTier)
	clearCarriedStone(session)
	local char = session.Player.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	session.CarryingStoneId = stoneTier.Id
	local stoneModel = ModelBuilder.CreateSwordStoneModel(stoneTier, hrp.CFrame * CFrame.new(0, 3.2, 0), true)
	stoneModel.Name = "CarriedSwordStone"
	stoneModel.Parent = char

	if stoneModel.PrimaryPart then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hrp
		weld.Part1 = stoneModel.PrimaryPart
		weld.Parent = stoneModel.PrimaryPart
	end

	session.CarriedModel = stoneModel
	applyCharacterWalkSpeed(session)
	syncPlayerState(session)
end

-- ============================================================================
-- GESTION DU TAPIS DE COURSE PERSONNEL
-- ============================================================================

local function updateTreadmillLabels(session: PlayerSession)
	local tm = session.Treadmill
	if not tm then
		return
	end
	local lvl = session.Upgrades.SpeedLevel
	local gain = GameConfig.GetTreadmillGainPerTick(lvl)
	local cost = GameConfig.GetUpgradeCost("SpeedLevel", lvl)
	tm.TitleLabel.Text = string.format("👟 Tapis de %s (Niv. %d)\n+%s Vitesse / sec (Reste dessus !)", session.Player.DisplayName, lvl, GameConfig.FormatNumber(gain))
	if lvl >= GameConfig.Upgrades.SpeedLevel.MaxLevel then
		tm.BoardLabel.Text = string.format("Tapis Niveau MAX (%d)", lvl)
		tm.Prompt.ActionText = "Niveau MAX"
	else
		tm.BoardLabel.Text = string.format("Améliorer Tapis\nNiv. %d -> Niv. %d\n💵 $%s", lvl, lvl + 1, GameConfig.FormatNumber(cost))
		tm.Prompt.ActionText = "Améliorer ($" .. GameConfig.FormatNumber(cost) .. ")"
	end
end

local function spawnOrMovePersonalTreadmill(session: PlayerSession, targetPos: Vector3, notifyPlayer: boolean)
	if targetPos.Z <= RUNWAY_START_Z + 10 then
		NotificationEvent:FireClient(
			session.Player,
			"⛔ Impossible de poser ton Tapis dans les Zones de Pierres ! Pose-le dans le Hub !",
			Color3.fromRGB(255, 80, 80)
		)
		return
	end

	if session.Treadmill and session.Treadmill.Model then
		session.Treadmill.Model:Destroy()
		session.Treadmill = nil
	end

	local cleanPos = Vector3.new(
		math.clamp(targetPos.X, -HUB_WIDTH / 2 + 16, HUB_WIDTH / 2 - 16),
		0.6,
		math.clamp(targetPos.Z, RUNWAY_START_Z + 14, RUNWAY_START_Z + HUB_DEPTH - 14)
	)

	local lvl = session.Upgrades.SpeedLevel
	local gain = GameConfig.GetTreadmillGainPerTick(lvl)
	local cost = GameConfig.GetUpgradeCost("SpeedLevel", lvl)

	local model, belt, prompt, titleLbl, boardLbl = ModelBuilder.CreatePersonalTreadmill(
		session.Player.DisplayName,
		cleanPos,
		lvl,
		gain,
		cost
	)
	model.Parent = MapFolder

	prompt.Triggered:Connect(function(triggerPlr: Player)
		if triggerPlr ~= session.Player then
			NotificationEvent:FireClient(
				triggerPlr,
				"⛔ Ce Tapis appartient à " .. session.Player.DisplayName .. " !",
				Color3.fromRGB(255, 95, 95)
			)
			return
		end
		local curLvl = session.Upgrades.SpeedLevel
		if curLvl >= GameConfig.Upgrades.SpeedLevel.MaxLevel then
			return
		end
		local upgCost = GameConfig.GetUpgradeCost("SpeedLevel", curLvl)
		if session.Money < upgCost then
			NotificationEvent:FireClient(
				session.Player,
				"Pas assez d'Argent ! Il faut $" .. GameConfig.FormatNumber(upgCost),
				Color3.fromRGB(255, 85, 85)
			)
			return
		end
		session.Money -= upgCost
		session.Upgrades.SpeedLevel += 1
		updateTreadmillLabels(session)
		syncPlayerState(session)
		NotificationEvent:FireClient(
			session.Player,
			string.format("👟 Tapis amélioré au Niveau %d (+%s Vitesse/sec) !", session.Upgrades.SpeedLevel, GameConfig.FormatNumber(GameConfig.GetTreadmillGainPerTick(session.Upgrades.SpeedLevel))),
			Color3.fromRGB(85, 255, 130)
		)
	end)

	session.Treadmill = {
		Model = model,
		Belt = belt,
		Prompt = prompt,
		TitleLabel = titleLbl,
		BoardLabel = boardLbl,
	}

	if notifyPlayer then
		NotificationEvent:FireClient(
			session.Player,
			"👟 Ton Tapis de Course a été posé ici ! Reste simplement dessus pour gagner de la vitesse !",
			Color3.fromRGB(255, 95, 235)
		)
	end
end

local function giveTreadmillSpawnerTool(player: Player)
	local backpack = player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	if backpack:FindFirstChild("Poser Tapis") or (player.Character and player.Character:FindFirstChild("Poser Tapis")) then
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = "Poser Tapis"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	createPart({
		Name = "Handle",
		Size = Vector3.new(1.4, 0.5, 2.0),
		Color = Color3.fromRGB(255, 85, 25),
		Material = Enum.Material.Neon,
		Anchored = false,
		CanCollide = false,
		Parent = tool,
	})

	tool.Activated:Connect(function()
		local sess = PlayerSessions[player]
		if not sess then
			return
		end
		local char = player.Character
		local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if hrp then
			local forwardPos = hrp.Position + hrp.CFrame.LookVector * 12
			spawnOrMovePersonalTreadmill(sess, forwardPos, true)
		end
	end)

	tool.Parent = backpack
end

-- ============================================================================
-- GESTION DES EMPLACEMENTS DE BASE & BOUTON DE RÉCOLTE D'ARGENT DEVANT L'ÉPÉE
-- ============================================================================

local function refreshSlotVisuals(session: PlayerSession, slot: BaseSlot)
	local unlocked = slot.SlotIndex <= session.Upgrades.SlotCount
	if not unlocked then
		slot.PadPart.Color = Color3.fromRGB(70, 75, 85)
		slot.PadPart.Transparency = 0.5
		slot.CollectButtonPart.Transparency = 1
		slot.CollectLabel.Text = ""
		slot.PrimaryPrompt.Enabled = false
		slot.TitleLabel.Text = "🔒 Verrouillé"
		slot.TitleLabel.TextColor3 = Color3.fromRGB(165, 170, 180)
		slot.SubLabel.Text = "Boutique (+Emplacement)"
		return
	end

	slot.PadPart.Transparency = 0
	if slot.State == "Empty" then
		slot.PadPart.Color = Color3.fromRGB(120, 235, 65)
		slot.CollectButtonPart.Transparency = 0.75
		slot.CollectButtonPart.Color = Color3.fromRGB(90, 110, 90)
		slot.CollectLabel.Text = ""
		slot.TitleLabel.Text = "Emplacement Libre"
		slot.TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		slot.SubLabel.Text = "Rentre avec une Pierre !"
		slot.PrimaryPrompt.Enabled = true
		slot.PrimaryPrompt.ObjectText = "Emplacement #" .. slot.SlotIndex
		slot.PrimaryPrompt.ActionText = "Poser Pierre / Épée"

	elseif slot.State == "Forging" then
		slot.PadPart.Color = Color3.fromRGB(255, 185, 45)
		slot.CollectButtonPart.Transparency = 0.75
		slot.CollectLabel.Text = ""
		local rem = if slot.EndTime then math.max(0, math.ceil(slot.EndTime - os.clock())) else 0
		slot.TitleLabel.Text = "Éclosion en cours..."
		slot.TitleLabel.TextColor3 = Color3.fromRGB(255, 210, 65)
		slot.SubLabel.Text = "⏳ " .. GameConfig.FormatTime(rem)
		slot.PrimaryPrompt.Enabled = false

	elseif slot.State == "Ready" then
		slot.PadPart.Color = Color3.fromRGB(255, 65, 65)
		slot.CollectButtonPart.Transparency = 0.75
		slot.CollectLabel.Text = ""
		slot.TitleLabel.Text = "Pierre\nPrête!"
		slot.TitleLabel.TextColor3 = Color3.fromRGB(255, 65, 65)
		slot.SubLabel.Text = "Éclosion !\n[E] Ouvrir !"
		slot.PrimaryPrompt.Enabled = true
		slot.PrimaryPrompt.ObjectText = "Pierre Prête !"
		slot.PrimaryPrompt.ActionText = "Faire éclore l'Épée !"

	elseif slot.State == "Sword" and slot.SwordItem then
		local rarity = GameConfig.Rarities[slot.SwordItem.Rarity] or GameConfig.Rarities.Common
		slot.PadPart.Color = rarity.Color
		slot.CollectButtonPart.Transparency = 0
		slot.CollectButtonPart.Color = Color3.fromRGB(45, 235, 65)
		slot.CollectLabel.Text = "💵 $" .. GameConfig.FormatNumber(slot.AccumulatedMoney)
		slot.TitleLabel.Text = string.format("[%s] %s", rarity.Name, slot.SwordItem.Name)
		slot.TitleLabel.TextColor3 = rarity.Color
		slot.SubLabel.Text = string.format("+$%s / sec", GameConfig.FormatNumber(slot.SwordItem.MoneyPerSec))
		slot.PrimaryPrompt.Enabled = true
		slot.PrimaryPrompt.ObjectText = slot.SwordItem.Name
		slot.PrimaryPrompt.ActionText = "Récupérer dans l'inventaire"
	end
end

local function refreshAllBaseSlots(session: PlayerSession)
	for _, slot in ipairs(session.Slots) do
		refreshSlotVisuals(session, slot)
	end
end

-- Place une épée spécifique de l'inventaire sur un emplacement libre de la base
local function placeSwordItemOnSlot(session: PlayerSession, slot: BaseSlot, item: GameConfig.OwnedSwordItem)
	if slot.SlotIndex > session.Upgrades.SlotCount or slot.State ~= "Empty" then
		return
	end
	if slot.VisualModel then
		slot.VisualModel:Destroy()
	end

	slot.State = "Sword"
	slot.SwordItem = item
	slot.AccumulatedMoney = 0

	local swordModel = ModelBuilder.CreateSwordModel(
		item.SwordId,
		slot.PadPart.CFrame * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, 0, math.rad(180)),
		true
	)
	swordModel.Parent = session.BaseModel
	slot.VisualModel = swordModel

	refreshSlotVisuals(session, slot)
	syncPlayerState(session)
end

local function placeCarriedStoneOnSlot(session: PlayerSession, slot: BaseSlot): boolean
	if slot.SlotIndex > session.Upgrades.SlotCount or slot.State ~= "Empty" or not session.CarryingStoneId then
		return false
	end

	local stoneId = session.CarryingStoneId
	local foundTier: GameConfig.StoneTier? = nil
	for _, tier in ipairs(GameConfig.StoneTiers) do
		if tier.Id == stoneId then
			foundTier = tier
			break
		end
	end
	if not foundTier then
		return false
	end

	clearCarriedStone(session)

	local speedMult = 1 + (session.Upgrades.ForgeSpeed - 1) * 0.25
	local duration = math.max(4, math.ceil(foundTier.ForgeTime / speedMult))

	slot.State = "Forging"
	slot.StoneId = stoneId
	slot.EndTime = os.clock() + duration
	slot.AccumulatedMoney = 0

	if slot.VisualModel then
		slot.VisualModel:Destroy()
	end
	local stoneModel = ModelBuilder.CreateSwordStoneModel(foundTier, slot.PadPart.CFrame * CFrame.new(0, 1.2, 0), false)
	stoneModel.Parent = session.BaseModel
	slot.VisualModel = stoneModel

	refreshSlotVisuals(session, slot)
	NotificationEvent:FireClient(
		session.Player,
		string.format("🪨 %s déposée dans ta base ! Éclosion dans %s", foundTier.Name, GameConfig.FormatTime(duration)),
		foundTier.CrystalColor
	)
	return true
end

-- Éclosion : l'épée reste sur son emplacement dans la base (NE va PAS dans la main du joueur !)
local function hatchStoneOnSlot(session: PlayerSession, slot: BaseSlot)
	if slot.State ~= "Ready" or not slot.StoneId then
		return
	end

	local forgedStoneId = slot.StoneId
	slot.StoneId = nil
	slot.EndTime = nil
	if slot.VisualModel then
		slot.VisualModel:Destroy()
		slot.VisualModel = nil
	end

	session.NextSwordUidCounter += 1
	local wonItem = GameConfig.RollRandomSwordFromStone(forgedStoneId, session.NextSwordUidCounter)
	local rarityInfo = GameConfig.Rarities[wonItem.Rarity] or GameConfig.Rarities.Common

	table.insert(session.Inventory, wonItem)
	session.Discovered[wonItem.SwordId] = true

	-- L'épée reste directement sur son emplacement dans la base et commence à accumuler de l'argent !
	placeSwordItemOnSlot(session, slot, wonItem)

	SwordRevealEvent:FireClient(session.Player, {
		SwordId = wonItem.SwordId,
		Name = wonItem.Name,
		Rarity = rarityInfo.Name,
		RarityColor = rarityInfo.Color,
		MoneyPerSec = wonItem.MoneyPerSec,
		SellPrice = wonItem.SellPrice,
	})
end

-- Récolte tout l'argent accumulé sur l'emplacement quand le joueur marche sur le bouton vert devant l'épée !
local function collectSlotMoney(session: PlayerSession, slot: BaseSlot)
	if slot.State ~= "Sword" or slot.AccumulatedMoney <= 0 then
		return
	end
	local amount = math.floor(slot.AccumulatedMoney)
	slot.AccumulatedMoney = 0
	session.Money += amount
	slot.CollectLabel.Text = "💵 $0"
	PopupEvent:FireClient(session.Player, "Money", "+$" .. GameConfig.FormatNumber(amount))
	syncPlayerState(session)
end

-- ============================================================================
-- CONSTRUCTION DU HUB COMPACT + MARCHANDS ROBLOX + BASES AVEC BOUTONS DE RÉCOLTE
-- ============================================================================

local hubFloor = createPart({
	Name = "HubGrassFloor",
	Size = Vector3.new(HUB_WIDTH, 4, HUB_DEPTH),
	CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, -2, 0)),
	Parent = MapFolder,
})
ModelBuilder.ApplyFloorVisuals(hubFloor, Color3.fromRGB(102, 224, 38), Enum.Material.Plastic)

local hubSpawn = Instance.new("SpawnLocation")
hubSpawn.Name = "HubSpawn"
hubSpawn.Anchored = true
hubSpawn.CanCollide = false
hubSpawn.Transparency = 1
hubSpawn.Size = Vector3.new(12, 1, 12)
hubSpawn.CFrame = CFrame.new(0, 0.5, 95)
hubSpawn.Parent = MapFolder

local wallHeight = 30
createStyledWall(MapFolder, CFrame.new(0, wallHeight / 2, HUB_CENTER.Z + HUB_DEPTH / 2), Vector3.new(HUB_WIDTH + 8, wallHeight, 8))
createStyledWall(MapFolder, CFrame.new(-HUB_WIDTH / 2, wallHeight / 2, HUB_CENTER.Z), Vector3.new(8, wallHeight, HUB_DEPTH))
createStyledWall(MapFolder, CFrame.new(HUB_WIDTH / 2, wallHeight / 2, HUB_CENTER.Z), Vector3.new(8, wallHeight, HUB_DEPTH))

local sideWallW = (HUB_WIDTH - CORRIDOR_WIDTH) / 2
createStyledWall(
	MapFolder,
	CFrame.new(-CORRIDOR_WIDTH / 2 - sideWallW / 2, wallHeight / 2, RUNWAY_START_Z),
	Vector3.new(sideWallW, wallHeight, 8)
)
createStyledWall(
	MapFolder,
	CFrame.new(CORRIDOR_WIDTH / 2 + sideWallW / 2, wallHeight / 2, RUNWAY_START_Z),
	Vector3.new(sideWallW, wallHeight, 8)
)

-- LES 2 STANDS DE MARCHANDS AVEC VRAIS PERSONNAGES ROBLOX
local sellStallPrompt = ModelBuilder.CreateMerchantStall(
	MapFolder,
	CFrame.new(-42, 0, 52) * CFrame.Angles(0, math.rad(-25), 0),
	"💰 ACHETEUR D'ÉPÉES",
	"Revends tes épées récupérées contre du Cash ($)",
	Color3.fromRGB(255, 195, 40),
	"Vendre / Gérer mes Épées",
	"Merchant"
)
sellStallPrompt.Triggered:Connect(function(plr: Player)
	OpenMerchantEvent:FireClient(plr, "SellSwords")
end)

local trailStallPrompt = ModelBuilder.CreateMerchantStall(
	MapFolder,
	CFrame.new(42, 0, 52) * CFrame.Angles(0, math.rad(25), 0),
	"✨ BOUTIQUE DE SENTIERS",
	"Traînées : Multiplicateur Vitesse & Argent",
	Color3.fromRGB(55, 215, 255),
	"Ouvrir Boutique de Traînées",
	"Wizard"
)
trailStallPrompt.Triggered:Connect(function(plr: Player)
	OpenMerchantEvent:FireClient(plr, "TrailsShop")
end)

local FENCE_COLORS = {
	Color3.fromRGB(245, 248, 255),
	Color3.fromRGB(45, 175, 255),
	Color3.fromRGB(255, 200, 45),
	Color3.fromRGB(170, 115, 55),
}

local function buildSimplePlayerBase(baseIndex: number, plotCenter: Vector3, fenceColor: Color3)
	local model = Instance.new("Model")
	model.Name = "PlayerBase_" .. baseIndex
	model.Parent = MapFolder

	local baseFloor = createPart({
		Name = "BaseFloor",
		Size = Vector3.new(48, 0.4, 38),
		CFrame = CFrame.new(plotCenter + Vector3.new(0, 0.2, 0)),
		Parent = model,
	})
	ModelBuilder.ApplyFloorVisuals(baseFloor, Color3.fromRGB(122, 238, 58), Enum.Material.Plastic)
	ModelBuilder.CreateFenceRect(model, plotCenter, 48, 38, fenceColor, true)

	-- Dès que le joueur rentre dans sa base avec une Pierre d'Épée, elle se pose sur un emplacement libre !
	local autoDropZone = createPart({
		Name = "AutoDropTrigger",
		Size = Vector3.new(46, 10, 36),
		CFrame = CFrame.new(plotCenter + Vector3.new(0, 5, 0)),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})

	autoDropZone.Touched:Connect(function(hit: BasePart)
		local char = hit.Parent
		local plr = if char then Players:GetPlayerFromCharacter(char) else nil
		if not plr then
			return
		end
		local sess = PlayerSessions[plr]
		if sess and sess.BaseIndex == baseIndex and sess.CarryingStoneId then
			for _, slot in ipairs(sess.Slots) do
				if slot.SlotIndex <= sess.Upgrades.SlotCount and slot.State == "Empty" then
					placeCarriedStoneOnSlot(sess, slot)
					break
				end
			end
		end
	end)

	local slots: { BaseSlot } = {}
	local slotOffsets = {
		Vector3.new(-15.5, 0.6, -6),
		Vector3.new(-5.2, 0.6, -6),
		Vector3.new(5.2, 0.6, -6),
		Vector3.new(15.5, 0.6, -6),
		Vector3.new(-15.5, 0.6, 10),
		Vector3.new(-5.2, 0.6, 10),
		Vector3.new(5.2, 0.6, 10),
		Vector3.new(15.5, 0.6, 10),
	}

	for i, off in ipairs(slotOffsets) do
		-- Socle où l'épée / la pierre est posée
		local pad = createPart({
			Name = "BaseSlot_" .. i,
			Size = Vector3.new(6.8, 1.0, 6.8),
			CFrame = CFrame.new(plotCenter + off),
			Color = Color3.fromRGB(120, 235, 65),
			Material = Enum.Material.SmoothPlastic,
			TopSurface = Enum.SurfaceType.Studs,
			Parent = model,
		})

		-- BOUTON VERT DE RÉCOLTE D'ARGENT juste devant l'emplacement de l'épée !
		local collectBtn = createPart({
			Name = "CollectButton_" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 4.2, 4.2),
			CFrame = CFrame.new(plotCenter + off + Vector3.new(0, 0.25, -5.4)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(45, 235, 65),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = model,
		})

		local collectBg = Instance.new("BillboardGui")
		collectBg.Size = UDim2.fromOffset(150, 42)
		collectBg.StudsOffset = Vector3.new(0, 2.6, 0)
		collectBg.AlwaysOnTop = true
		collectBg.MaxDistance = 90
		collectBg.Parent = collectBtn

		local collectLbl = Instance.new("TextLabel")
		collectLbl.Size = UDim2.fromScale(1, 1)
		collectLbl.BackgroundTransparency = 1
		collectLbl.Font = Enum.Font.FredokaOne
		collectLbl.TextColor3 = Color3.fromRGB(75, 255, 85)
		collectLbl.TextStrokeTransparency = 0
		collectLbl.TextScaled = true
		collectLbl.Text = ""
		collectLbl.Parent = collectBg

		local bg = Instance.new("BillboardGui")
		bg.Size = UDim2.fromOffset(195, 76)
		bg.StudsOffset = Vector3.new(0, 6.2, 0)
		bg.AlwaysOnTop = true
		bg.MaxDistance = 110
		bg.Parent = pad

		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(1, 0, 0.58, 0)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Font = Enum.Font.FredokaOne
		titleLbl.TextColor3 = Color3.new(1, 1, 1)
		titleLbl.TextStrokeTransparency = 0
		titleLbl.TextScaled = true
		titleLbl.Text = "Emplacement Libre"
		titleLbl.Parent = bg

		local subLbl = Instance.new("TextLabel")
		subLbl.Size = UDim2.new(1, 0, 0.42, 0)
		subLbl.Position = UDim2.fromScale(0, 0.58)
		subLbl.BackgroundTransparency = 1
		subLbl.Font = Enum.Font.GothamBold
		subLbl.TextColor3 = Color3.fromRGB(235, 255, 235)
		subLbl.TextStrokeTransparency = 0
		subLbl.TextScaled = true
		subLbl.Text = "Rentre avec une Pierre !"
		subLbl.Parent = bg

		local primaryPrompt = Instance.new("ProximityPrompt")
		primaryPrompt.ObjectText = "Emplacement #" .. i
		primaryPrompt.ActionText = "Interagir"
		primaryPrompt.HoldDuration = 0
		primaryPrompt.MaxActivationDistance = 11
		primaryPrompt.RequiresLineOfSight = false
		primaryPrompt.Parent = pad

		local slot: BaseSlot = {
			SlotIndex = i,
			State = "Empty",
			StoneId = nil,
			EndTime = nil,
			SwordItem = nil,
			AccumulatedMoney = 0,
			PadPart = pad,
			CollectButtonPart = collectBtn,
			CollectLabel = collectLbl,
			TitleLabel = titleLbl,
			SubLabel = subLbl,
			PrimaryPrompt = primaryPrompt,
			VisualModel = nil,
		}

		-- Marcher sur le bouton vert devant l'épée récolte tout l'argent accumulé !
		collectBtn.Touched:Connect(function(hit: BasePart)
			local char = hit.Parent
			local plr = if char then Players:GetPlayerFromCharacter(char) else nil
			if not plr then
				return
			end
			local sess = PlayerSessions[plr]
			if sess and sess.BaseIndex == baseIndex then
				collectSlotMoney(sess, slot)
			end
		end)

		primaryPrompt.Triggered:Connect(function(plr: Player)
			local sess = PlayerSessions[plr]
			if not sess or sess.BaseIndex ~= baseIndex then
				return
			end
			if slot.State == "Empty" then
				if sess.CarryingStoneId then
					placeCarriedStoneOnSlot(sess, slot)
				else
					-- S'il a une épée non posée dans son inventaire, la poser ici !
					local placedUids = getPlacedSwordUids(sess)
					for _, item in ipairs(sess.Inventory) do
						if not placedUids[item.Uid] then
							placeSwordItemOnSlot(sess, slot, item)
							NotificationEvent:FireClient(plr, "⚔️ " .. item.Name .. " posée sur l'emplacement !", Color3.fromRGB(85, 255, 130))
							return
						end
					end
					NotificationEvent:FireClient(plr, "Va chercher une Pierre d'Épée dans les Zones !", Color3.fromRGB(255, 200, 75))
				end
			elseif slot.State == "Ready" then
				hatchStoneOnSlot(sess, slot)
			elseif slot.State == "Sword" and slot.SwordItem then
				-- Récupérer l'argent restant puis ranger l'épée dans l'inventaire (pour la revendre ou libérer la place) !
				collectSlotMoney(sess, slot)
				local itemName = slot.SwordItem.Name
				slot.State = "Empty"
				slot.SwordItem = nil
				if slot.VisualModel then
					slot.VisualModel:Destroy()
					slot.VisualModel = nil
				end
				refreshSlotVisuals(sess, slot)
				syncPlayerState(sess)
				NotificationEvent:FireClient(
					plr,
					"🎒 " .. itemName .. " récupérée dans ton inventaire ! Tu peux la revendre au Marchand ou la reposer.",
					Color3.fromRGB(255, 215, 75)
				)
			end
		end)

		table.insert(slots, slot)
	end

	local signAnchor = createPart({
		Name = "OwnerBadgeAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(plotCenter + Vector3.new(0, 11, -19)),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	local ownerBg = Instance.new("BillboardGui")
	ownerBg.Size = UDim2.fromOffset(140, 90)
	ownerBg.AlwaysOnTop = true
	ownerBg.MaxDistance = 200
	ownerBg.Parent = signAnchor

	local avatarCircle = Instance.new("ImageLabel")
	avatarCircle.Size = UDim2.fromOffset(54, 54)
	avatarCircle.Position = UDim2.new(0.5, -27, 0, 0)
	avatarCircle.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
	avatarCircle.Parent = ownerBg
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = avatarCircle
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(20, 20, 20)
	s.Thickness = 3
	s.Parent = avatarCircle

	local ownerNameLbl = Instance.new("TextLabel")
	ownerNameLbl.Size = UDim2.new(1, 0, 0, 28)
	ownerNameLbl.Position = UDim2.fromOffset(0, 56)
	ownerNameLbl.BackgroundTransparency = 1
	ownerNameLbl.Font = Enum.Font.FredokaOne
	ownerNameLbl.TextColor3 = Color3.new(1, 1, 1)
	ownerNameLbl.TextStrokeTransparency = 0
	ownerNameLbl.TextScaled = true
	ownerNameLbl.Text = "Base Libre"
	ownerNameLbl.Parent = ownerBg

	local spawnCF = CFrame.new(plotCenter + Vector3.new(0, 4, -21), plotCenter + Vector3.new(0, 4, -65))
	return model, spawnCF, slots, ownerNameLbl, avatarCircle
end

local BaseSlotsData = {}
local plotCoords = {
	Vector3.new(-74, 0, 95),
	Vector3.new(74, 0, 95),
	Vector3.new(-74, 0, 152),
	Vector3.new(74, 0, 152),
}
for i, coord in ipairs(plotCoords) do
	local model, spawnCF, slots, ownerNameLbl, avatarCircle = buildSimplePlayerBase(i, coord, FENCE_COLORS[i])
	BaseSlotsData[i] = {
		Center = coord,
		Model = model,
		SpawnCFrame = spawnCF,
		Slots = slots,
		OwnerNameLabel = ownerNameLbl,
		AvatarImage = avatarCircle,
	}
end

-- ============================================================================
-- LA GRANDE ALLÉE DES 10 ZONES + DÉCORATIONS + RAMASSAGE PAR CLIC OU TOUCHE E UNIQUEMENT
-- ============================================================================

type ActiveStoneSpawn = {
	Tier: GameConfig.StoneTier,
	SpawnPos: Vector3,
	CurrentModel: Model?,
	RespawnAt: number?,
}

type ActiveGuardian = {
	Tier: GameConfig.StoneTier,
	Model: Model,
	ZoneZMin: number,
	ZoneZMax: number,
	CornerRestPos: Vector3,
	AnimTime: number,
	StatusLabel: TextLabel?,
}

local StoneSpawns: { ActiveStoneSpawn } = {}
local Guardians: { ActiveGuardian } = {}

local function tryGrabStone(plr: Player, slot: ActiveStoneSpawn)
	if not slot.CurrentModel then
		return
	end
	local sess = PlayerSessions[plr]
	if not sess then
		return
	end
	if sess.CarryingStoneId then
		NotificationEvent:FireClient(plr, "Tu portes déjà une Pierre d'Épée ! Ramène-la dans ta Base !", Color3.fromRGB(255, 160, 55))
		return
	end

	slot.CurrentModel:Destroy()
	slot.CurrentModel = nil
	slot.RespawnAt = os.clock() + 8

	giveCarriedStone(sess, slot.Tier)
	NotificationEvent:FireClient(
		plr,
		string.format("⚠️ %s attrapée ! Le %s se réveille, cours à ta Base !", slot.Tier.Name, slot.Tier.GuardianName),
		slot.Tier.CrystalColor
	)
end

local function spawnSwordStoneAt(slot: ActiveStoneSpawn)
	if slot.CurrentModel then
		slot.CurrentModel:Destroy()
		slot.CurrentModel = nil
	end

	local model = ModelBuilder.CreateSwordStoneModel(slot.Tier, CFrame.new(slot.SpawnPos), false)
	model.Parent = MapFolder
	slot.CurrentModel = model

	local root = model.PrimaryPart
	if not root then
		return
	end

	local bg = Instance.new("BillboardGui")
	bg.Size = UDim2.fromOffset(240, 62)
	bg.StudsOffset = Vector3.new(0, 5.5, 0)
	bg.AlwaysOnTop = true
	bg.MaxDistance = 150
	bg.Parent = root

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextColor3 = slot.Tier.CrystalColor
	lbl.TextStrokeTransparency = 0
	lbl.TextScaled = true
	lbl.Text = string.format(
		"%s ($%s-$%s/s)\n[E ou Clic] Voler (%s)",
		slot.Tier.Name,
		GameConfig.FormatNumber(slot.Tier.MinBaseMoneyPerSec),
		GameConfig.FormatNumber(slot.Tier.MaxBaseMoneyPerSec * 3),
		GameConfig.FormatTime(slot.Tier.ForgeTime)
	)
	lbl.Parent = bg

	-- Ramassage UNIQUEMENT par Touche E ou Clic souris (plus de ramassage involontaire en marchant dessus !)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = slot.Tier.Name
	prompt.ActionText = "Voler la Pierre"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	prompt.Triggered:Connect(function(plr: Player)
		tryGrabStone(plr, slot)
	end)

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 22
	click.Parent = root
	click.MouseClick:Connect(function(plr: Player)
		tryGrabStone(plr, slot)
	end)
end

local currentZMax = RUNWAY_START_Z

for idx, tier in ipairs(GameConfig.StoneTiers) do
	local zLength = tier.ZoneLength
	local zMax = currentZMax
	local zMin = zMax - zLength
	local zCenter = (zMax + zMin) / 2
	currentZMax = zMin

	local zoneCenter = Vector3.new(0, 0, zCenter)

	local zoneFloor = createPart({
		Name = "ZoneFloor_" .. idx,
		Size = Vector3.new(CORRIDOR_WIDTH, 4, zLength),
		CFrame = CFrame.new(0, -2, zCenter),
		Parent = MapFolder,
	})
	ModelBuilder.ApplyFloorVisuals(zoneFloor, tier.FloorColor, Enum.Material.Plastic)

	createStyledWall(
		MapFolder,
		CFrame.new(-CORRIDOR_WIDTH / 2 - 4, 14, zCenter),
		Vector3.new(8, 28, zLength),
		tier.WallColor
	)
	createStyledWall(
		MapFolder,
		CFrame.new(CORRIDOR_WIDTH / 2 + 4, 14, zCenter),
		Vector3.new(8, 28, zLength),
		tier.WallColor
	)

	-- Décorations thématiques de la Zone (Cactus dans le désert, arbres, cristaux, etc.)
	ModelBuilder.CreateZoneDecorations(MapFolder, idx, zoneCenter, zLength, CORRIDOR_WIDTH)

	local gateBar = createPart({
		Name = "ZoneDivider_" .. idx,
		Size = Vector3.new(CORRIDOR_WIDTH, 0.5, 3.0),
		CFrame = CFrame.new(0, 0.1, zMax),
		Color = tier.CrystalColor,
		Material = Enum.Material.Neon,
		TopSurface = Enum.SurfaceType.Smooth,
		Parent = MapFolder,
	})

	local zoneBg = Instance.new("BillboardGui")
	zoneBg.Size = UDim2.fromOffset(390, 74)
	zoneBg.StudsOffset = Vector3.new(0, 18, 0)
	zoneBg.AlwaysOnTop = true
	zoneBg.MaxDistance = 300
	zoneBg.Parent = gateBar

	local zoneLbl = Instance.new("TextLabel")
	zoneLbl.Size = UDim2.fromScale(1, 1)
	zoneLbl.BackgroundTransparency = 1
	zoneLbl.Font = Enum.Font.FredokaOne
	zoneLbl.TextColor3 = tier.CrystalColor
	zoneLbl.TextStrokeTransparency = 0
	zoneLbl.TextScaled = true
	zoneLbl.Text = string.format(
		"%s\n👟 Vitesse Garde : %s   |   ⏳ Éclosion : %s",
		tier.ZoneName,
		GameConfig.FormatNumber(tier.GuardianSpeedStat),
		GameConfig.FormatTime(tier.ForgeTime)
	)
	zoneLbl.Parent = zoneBg

	local zQuarter = zLength * 0.28
	local stoneOffsets = {
		Vector3.new(-30, 0.5, zQuarter),
		Vector3.new(30, 0.5, zQuarter),
		Vector3.new(0, 0.5, 0),
		Vector3.new(-30, 0.5, -zQuarter),
		Vector3.new(30, 0.5, -zQuarter),
		Vector3.new(0, 0.5, -zQuarter * 1.3),
	}
	for _, off in ipairs(stoneOffsets) do
		local entry: ActiveStoneSpawn = {
			Tier = tier,
			SpawnPos = zoneCenter + off,
			CurrentModel = nil,
			RespawnAt = nil,
		}
		table.insert(StoneSpawns, entry)
		spawnSwordStoneAt(entry)
	end

	local cornerX = if idx % 2 == 1 then (-CORRIDOR_WIDTH / 2 + 16) else (CORRIDOR_WIDTH / 2 - 16)
	local cornerRestPos = Vector3.new(cornerX, 0, zMin + 16)

	local gModel = ModelBuilder.CreateGuardianModel(tier, cornerRestPos)
	gModel.Parent = MapFolder
	local head = gModel:FindFirstChild("Head")
	local tag = if head then head:FindFirstChild("GuardianTag") else nil
	local statusLbl = if tag then tag:FindFirstChild("Status") :: TextLabel? else nil

	table.insert(Guardians, {
		Tier = tier,
		Model = gModel,
		ZoneZMin = zMin + 4,
		ZoneZMax = zMax - 4,
		CornerRestPos = cornerRestPos,
		AnimTime = 0,
		StatusLabel = statusLbl,
	})
end

createStyledWall(
	MapFolder,
	CFrame.new(0, 16, currentZMax),
	Vector3.new(CORRIDOR_WIDTH + 16, 32, 8),
	Color3.fromRGB(255, 215, 65)
)

-- ============================================================================
-- CONNEXION DES JOUEURS & ACTIONS
-- ============================================================================

local function onPlayerAdded(player: Player)
	local chosenIndex = 1
	for i = 1, 4 do
		if not AssignedBases[i] then
			chosenIndex = i
			AssignedBases[i] = player
			break
		end
	end

	local baseSlot = BaseSlotsData[chosenIndex]
	baseSlot.OwnerNameLabel.Text = player.DisplayName
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and content then
			baseSlot.AvatarImage.Image = content
		end
	end)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local mpsVal = Instance.new("StringValue")
	mpsVal.Name = "Money/s"
	mpsVal.Value = "0"
	mpsVal.Parent = leaderstats

	local spdVal = Instance.new("StringValue")
	spdVal.Name = "Vitesse"
	spdVal.Value = "18"
	spdVal.Parent = leaderstats

	local session: PlayerSession = {
		Player = player,
		Money = 60,
		TrainedSpeed = 0,
		SlowMode = false,
		SpeedBoostUntil = 0,
		MoneyBoostUntil = 0,
		CarryingStoneId = nil,
		CarriedModel = nil,
		OwnedTrails = {},
		EquippedTrailId = nil,
		Inventory = {},
		Discovered = {},
		Upgrades = {
			SpeedLevel = 1,
			CarryStrength = 1,
			ForgeSpeed = 1,
			SlotCount = 4,
		},
		BaseIndex = chosenIndex,
		BaseCenter = baseSlot.Center,
		BaseModel = baseSlot.Model,
		SpawnCFrame = baseSlot.SpawnCFrame,
		Slots = baseSlot.Slots,
		Treadmill = nil,
		NextSwordUidCounter = 0,
	}
	PlayerSessions[player] = session

	refreshAllBaseSlots(session)

	local defaultTreadmillPos = baseSlot.Center + Vector3.new(if baseSlot.Center.X < 0 then 36 else -36, 0, 0)
	spawnOrMovePersonalTreadmill(session, defaultTreadmillPos, false)

	player.CharacterAdded:Connect(function(char: Model)
		task.wait(0.15)
		local hrp = char:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		if hrp then
			hrp.CFrame = session.SpawnCFrame
		end
		session.CarryingStoneId = nil
		session.CarriedModel = nil
		applyTrailOnCharacter(session)
		giveTreadmillSpawnerTool(player)
		applyCharacterWalkSpeed(session)
		syncPlayerState(session)
	end)

	if player.Character then
		local hrp = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.CFrame = session.SpawnCFrame
		end
		applyTrailOnCharacter(session)
		giveTreadmillSpawnerTool(player)
		applyCharacterWalkSpeed(session)
	end

	task.delay(0.5, function()
		syncPlayerState(session)
	end)
end

local function onPlayerRemoving(player: Player)
	local sess = PlayerSessions[player]
	if sess then
		AssignedBases[sess.BaseIndex] = nil
		local baseSlot = BaseSlotsData[sess.BaseIndex]
		if baseSlot then
			baseSlot.OwnerNameLabel.Text = "Base Libre"
			baseSlot.AvatarImage.Image = ""
		end
		if sess.Treadmill and sess.Treadmill.Model then
			sess.Treadmill.Model:Destroy()
			sess.Treadmill = nil
		end
		for _, slot in ipairs(sess.Slots) do
			slot.State = "Empty"
			slot.StoneId = nil
			slot.EndTime = nil
			slot.SwordItem = nil
			slot.AccumulatedMoney = 0
			if slot.VisualModel then
				slot.VisualModel:Destroy()
				slot.VisualModel = nil
			end
		end
		PlayerSessions[player] = nil
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, plr in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, plr)
end

ActionEvent.OnServerEvent:Connect(function(player: Player, actionType: string, payload: any)
	local sess = PlayerSessions[player]
	if not sess then
		return
	end

	if actionType == "ToggleSlowMode" then
		sess.SlowMode = not sess.SlowMode
		applyCharacterWalkSpeed(sess)
		syncPlayerState(sess)

	elseif actionType == "SpawnTreadmill" then
		local char = player.Character
		local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if hrp then
			local targetPos = hrp.Position + hrp.CFrame.LookVector * 12
			spawnOrMovePersonalTreadmill(sess, targetPos, true)
		end

	elseif actionType == "BuyUpgrade" and typeof(payload) == "string" then
		local upgConfig = GameConfig.Upgrades[payload]
		local currentLvl = (sess.Upgrades :: any)[payload]
		if not upgConfig or not currentLvl or currentLvl >= upgConfig.MaxLevel then
			return
		end
		local cost = GameConfig.GetUpgradeCost(payload, currentLvl)
		if sess.Money < cost then
			NotificationEvent:FireClient(player, "Il te manque $" .. GameConfig.FormatNumber(cost - sess.Money) .. " !", Color3.fromRGB(255, 90, 90))
			return
		end
		sess.Money -= cost
		;(sess.Upgrades :: any)[payload] = currentLvl + 1
		if payload == "SlotCount" then
			refreshAllBaseSlots(sess)
		elseif payload == "SpeedLevel" then
			updateTreadmillLabels(sess)
		end
		applyCharacterWalkSpeed(sess)
		syncPlayerState(sess)
		NotificationEvent:FireClient(player, "✨ " .. upgConfig.Name .. " Niveau " .. (currentLvl + 1) .. " !", Color3.fromRGB(85, 255, 125))

	elseif actionType == "TogglePlaceSword" and typeof(payload) == "string" then
		-- Permet depuis l'inventaire de poser une épée sur sa base ou de la retirer dans son sac !
		for _, slot in ipairs(sess.Slots) do
			if slot.State == "Sword" and slot.SwordItem and slot.SwordItem.Uid == payload then
				collectSlotMoney(sess, slot)
				slot.State = "Empty"
				slot.SwordItem = nil
				if slot.VisualModel then
					slot.VisualModel:Destroy()
					slot.VisualModel = nil
				end
				refreshSlotVisuals(sess, slot)
				syncPlayerState(sess)
				NotificationEvent:FireClient(player, "🎒 Épée rangée dans ton inventaire !", Color3.fromRGB(255, 210, 75))
				return
			end
		end

		for _, item in ipairs(sess.Inventory) do
			if item.Uid == payload then
				for _, slot in ipairs(sess.Slots) do
					if slot.SlotIndex <= sess.Upgrades.SlotCount and slot.State == "Empty" then
						placeSwordItemOnSlot(sess, slot, item)
						NotificationEvent:FireClient(player, "⚔️ " .. item.Name .. " posée dans ta Base !", Color3.fromRGB(85, 255, 125))
						return
					end
				end
				NotificationEvent:FireClient(player, "Tous les emplacements de ta Base sont occupés !", Color3.fromRGB(255, 110, 80))
				return
			end
		end

	elseif actionType == "SellSword" and typeof(payload) == "string" then
		for idx, item in ipairs(sess.Inventory) do
			if item.Uid == payload then
				for _, slot in ipairs(sess.Slots) do
					if slot.State == "Sword" and slot.SwordItem and slot.SwordItem.Uid == payload then
						collectSlotMoney(sess, slot)
						slot.State = "Empty"
						slot.SwordItem = nil
						if slot.VisualModel then
							slot.VisualModel:Destroy()
							slot.VisualModel = nil
						end
						refreshSlotVisuals(sess, slot)
					end
				end
				sess.Money += item.SellPrice
				table.remove(sess.Inventory, idx)
				syncPlayerState(sess)
				NotificationEvent:FireClient(
					player,
					string.format("💰 %s vendue pour +$%s !", item.Name, GameConfig.FormatNumber(item.SellPrice)),
					Color3.fromRGB(85, 255, 110)
				)
				break
			end
		end

	elseif actionType == "BuyOrEquipTrail" and typeof(payload) == "string" then
		local foundTrail: GameConfig.TrailInfo? = nil
		for _, t in ipairs(GameConfig.Trails) do
			if t.Id == payload then
				foundTrail = t
				break
			end
		end
		if not foundTrail then
			return
		end

		if sess.OwnedTrails[foundTrail.Id] then
			sess.EquippedTrailId = foundTrail.Id
			applyTrailOnCharacter(sess)
			applyCharacterWalkSpeed(sess)
			syncPlayerState(sess)
			NotificationEvent:FireClient(player, "✨ Traînée équipée : " .. foundTrail.Name, foundTrail.Color1)
		else
			if sess.Money < foundTrail.Price then
				NotificationEvent:FireClient(
					player,
					"Pas assez d'Argent ! Il faut $" .. GameConfig.FormatNumber(foundTrail.Price),
					Color3.fromRGB(255, 90, 90)
				)
				return
			end
			sess.Money -= foundTrail.Price
			sess.OwnedTrails[foundTrail.Id] = true
			sess.EquippedTrailId = foundTrail.Id
			applyTrailOnCharacter(sess)
			applyCharacterWalkSpeed(sess)
			syncPlayerState(sess)
			NotificationEvent:FireClient(
				player,
				string.format("✨ %s achetée et équipée (x%.2f Vitesse & x%.2f Argent) !", foundTrail.Name, foundTrail.SpeedMultiplier, foundTrail.MoneyMultiplier),
				foundTrail.Color1
			)
		end

	elseif actionType == "ActivatePotion" and typeof(payload) == "string" then
		local cost = 500
		if sess.Money < cost then
			NotificationEvent:FireClient(player, "Il faut $500 pour activer une Potion Boost (3 min) !", Color3.fromRGB(255, 95, 95))
			return
		end
		sess.Money -= cost
		local now = os.clock()
		if payload == "Speed" then
			sess.SpeedBoostUntil = math.max(now, sess.SpeedBoostUntil) + 180
			applyCharacterWalkSpeed(sess)
			NotificationEvent:FireClient(player, "🧪 Potion x2 Vitesse activée (3 min) !", Color3.fromRGB(85, 225, 255))
		else
			sess.MoneyBoostUntil = math.max(now, sess.MoneyBoostUntil) + 180
			NotificationEvent:FireClient(player, "🧪 Potion x2 Argent activée (3 min) !", Color3.fromRGB(95, 255, 120))
		end
		syncPlayerState(sess)
	end
end)

-- Boucle 1 seconde :
-- - L'argent s'accumule sur chaque épée de la base (et se récolte en passant sur le bouton vert devant l'épée !)
-- - Le Tapis de Course donne de la vitesse simplement en restant dessus (sans besoin de bouger !)
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.clock()
		if now >= NightEventCycleEnd then
			NightEventCycleEnd = now + 240
		end

		for _, slot in ipairs(StoneSpawns) do
			if not slot.CurrentModel and slot.RespawnAt and now >= slot.RespawnAt then
				slot.RespawnAt = nil
				spawnSwordStoneAt(slot)
			end
		end

		for _, sess in pairs(PlayerSessions) do
			local trailSpdMult, trailMoneyMult = getTrailMultipliers(sess)
			local moneyMult = trailMoneyMult * (if now < sess.MoneyBoostUntil then 2 else 1)

			-- Tapis de course : il suffit d'être dessus (même immobile) pour gagner de la vitesse !
			if sess.Treadmill and sess.Treadmill.Belt then
				local char = sess.Player.Character
				local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
				if hrp then
					local diff = hrp.Position - sess.Treadmill.Belt.Position
					if math.abs(diff.X) <= 5.5 and math.abs(diff.Z) <= 10.5 and math.abs(diff.Y) <= 6.5 then
						local baseGain = GameConfig.GetTreadmillGainPerTick(sess.Upgrades.SpeedLevel)
						local finalGain = math.floor(baseGain * trailSpdMult)
						sess.TrainedSpeed += finalGain
						applyCharacterWalkSpeed(sess)
						PopupEvent:FireClient(sess.Player, "Speed", "+" .. GameConfig.FormatNumber(finalGain))
					end
				end
			end

			-- Mise à jour des emplacements de la base (Éclosion + Accumulation d'argent sur chaque épée)
			for _, slot in ipairs(sess.Slots) do
				if slot.State == "Forging" and slot.EndTime then
					local rem = math.ceil(slot.EndTime - now)
					if rem > 0 then
						slot.SubLabel.Text = "⏳ " .. GameConfig.FormatTime(rem)
					else
						slot.State = "Ready"
						refreshSlotVisuals(sess, slot)
					end
				elseif slot.State == "Sword" and slot.SwordItem then
					slot.AccumulatedMoney += math.floor(slot.SwordItem.MoneyPerSec * moneyMult)
					slot.CollectLabel.Text = "💵 $" .. GameConfig.FormatNumber(slot.AccumulatedMoney)
				end
			end

			syncPlayerState(sess)
		end
	end
end)

-- Boucle 60 FPS : Gardes AFK dans leur coin qui ne bougent QUE lorsqu'un joueur vole une Pierre d'Épée
RunService.Heartbeat:Connect(function(dt: number)
	for _, g in ipairs(Guardians) do
		local root = g.Model.PrimaryPart
		if not root then
			continue
		end

		g.AnimTime += dt

		local targetSession: PlayerSession? = nil
		local targetPos: Vector3? = nil
		local bestDist = 9999

		for _, sess in pairs(PlayerSessions) do
			if sess.CarryingStoneId ~= nil then
				local char = sess.Player.Character
				local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
				if hrp then
					local pPos = hrp.Position
					if pPos.Z <= g.ZoneZMax + 6 and pPos.Z >= g.ZoneZMin - 6 and math.abs(pPos.X) <= CORRIDOR_WIDTH / 2 then
						local d = (pPos - root.Position).Magnitude
						if d < bestDist then
							bestDist = d
							targetSession = sess
							targetPos = pPos
						end
					end
				end
			end
		end

		local currentPos = root.Position
		local nextPos: Vector3
		local lookTarget: Vector3
		local isMoving = false

		if targetSession and targetPos then
			isMoving = true
			if g.StatusLabel then
				g.StatusLabel.Text = "😡 POURSUITE : " .. targetSession.Player.DisplayName .. " !"
				g.StatusLabel.TextColor3 = Color3.fromRGB(255, 65, 65)
			end

			local playerChar = targetSession.Player.Character
			local playerHum = if playerChar then playerChar:FindFirstChildOfClass("Humanoid") else nil
			local playerWalkSpeed = if playerHum then playerHum.WalkSpeed else 16
			local playerStatSpeed = math.max(1, getPlayerTotalSpeed(targetSession))
			local guardStatSpeed = g.Tier.GuardianSpeedStat

			local speedRatio = math.clamp(guardStatSpeed / playerStatSpeed, 0.55, 1.65)
			local guardPhysicalSpeed = math.clamp(playerWalkSpeed * speedRatio * 1.15, 18, 195)

			local dir = Vector3.new(targetPos.X - currentPos.X, 0, targetPos.Z - currentPos.Z)
			if dir.Magnitude > 0.1 then
				nextPos = currentPos + dir.Unit * guardPhysicalSpeed * dt
				lookTarget = Vector3.new(targetPos.X, currentPos.Y, targetPos.Z)
			else
				nextPos = currentPos
				lookTarget = currentPos + Vector3.new(0, 0, 1)
			end

			if bestDist < 6.5 then
				clearCarriedStone(targetSession)
				NotificationEvent:FireClient(
					targetSession.Player,
					string.format(
						"💥 Rattrapé par %s (Vit: %s) !",
						g.Tier.GuardianName,
						GameConfig.FormatNumber(g.Tier.GuardianSpeedStat)
					),
					Color3.fromRGB(255, 75, 75)
				)
				local hrp = if playerChar then playerChar:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
				if hrp then
					hrp.CFrame = targetSession.SpawnCFrame
				end
			end
		else
			local cornerTarget = Vector3.new(g.CornerRestPos.X, currentPos.Y, g.CornerRestPos.Z)
			local toCorner = Vector3.new(cornerTarget.X - currentPos.X, 0, cornerTarget.Z - currentPos.Z)
			if toCorner.Magnitude > 1.2 then
				isMoving = true
				if g.StatusLabel then
					g.StatusLabel.Text = "🚶 Retourne dans son coin..."
					g.StatusLabel.TextColor3 = Color3.fromRGB(215, 225, 240)
				end
				nextPos = currentPos + toCorner.Unit * math.min(toCorner.Magnitude, 36 * dt)
				lookTarget = Vector3.new(cornerTarget.X, currentPos.Y, cornerTarget.Z)
			else
				isMoving = false
				if g.StatusLabel then
					g.StatusLabel.Text = "💤 AFK (Immobile)"
					g.StatusLabel.TextColor3 = Color3.fromRGB(190, 225, 255)
				end
				nextPos = cornerTarget
				lookTarget = Vector3.new(0, currentPos.Y, g.CornerRestPos.Z + 20)
			end
		end

		local rootCF = CFrame.lookAt(nextPos, lookTarget)
		ModelBuilder.PositionAndAnimateGuardian(g.Model, g.Tier.GuardianScale, rootCF, g.AnimTime, isMoving)
	end
end)
