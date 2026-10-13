--!strict
-- Générateur de modèles 3D :
-- - Vrais personnages Roblox (Humanoid + Mesh de Tête + Visage + Chapeau/Armure) pour les Marchands et les Gardes
-- - Décorations thématiques par Zone (Cactus dans le désert, Sapins enneigés, Cristaux, Colonnes, etc.)
-- - Pierres d'Épée, Épées 3D, Clôtures, Tapis de course personnel

local Players = game:GetService("Players")
local GameConfig = require(script.Parent.GameConfig)

local ModelBuilder = {}

local function createPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = if props.Anchored ~= nil then props.Anchored else true
	p.CanCollide = if props.CanCollide ~= nil then props.CanCollide else false
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or Color3.fromRGB(200, 200, 200)
	p.Size = props.Size or Vector3.new(1, 1, 1)
	p.CFrame = props.CFrame or CFrame.new()
	p.TopSurface = props.TopSurface or Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	if props.Transparency then
		p.Transparency = props.Transparency
	end
	if props.Name then
		p.Name = props.Name
	end
	if props.Parent then
		p.Parent = props.Parent
	end
	return p
end

local function weldParts(root: BasePart, part: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = part
	w.Parent = root
end

function ModelBuilder.ApplySurfaceTexture(part: BasePart, textureId: string, faces: { Enum.NormalId }, studsPerTile: number, transparency: number?, color: Color3?)
	for _, face in ipairs(faces) do
		local tex = Instance.new("Texture")
		tex.Texture = textureId
		tex.Face = face
		tex.StudsPerTileU = studsPerTile
		tex.StudsPerTileV = studsPerTile
		tex.Transparency = transparency or 0.65
		if color then
			tex.Color3 = color
		end
		tex.Parent = part
	end
end

function ModelBuilder.ApplyFloorVisuals(floorPart: BasePart, baseColor: Color3, material: Enum.Material?)
	floorPart.Color = baseColor
	floorPart.Material = material or Enum.Material.Plastic
	floorPart.TopSurface = Enum.SurfaceType.Studs
	ModelBuilder.ApplySurfaceTexture(
		floorPart,
		"rbxassetid://6372755229",
		{ Enum.NormalId.Top },
		16,
		0.78,
		Color3.new(0, 0, 0)
	)
end

-- ============================================================================
-- 1. DÉCORATIONS THÉMATIQUES PAR ZONE (LÉGÈRES, ESTHÉTIQUES, SUR LES BORDS)
-- ============================================================================
function ModelBuilder.CreateZoneDecorations(parent: Instance, zoneOrder: number, zoneCenter: Vector3, zLength: number, corridorWidth: number)
	local decoFolder = Instance.new("Folder")
	decoFolder.Name = "ZoneDecor_" .. zoneOrder
	decoFolder.Parent = parent

	-- 4 emplacements de décor sur les côtés de la zone (pour ne jamais gêner la course au milieu)
	local sideX = (corridorWidth / 2) - 10
	local zOff = zLength * 0.27
	local spots = {
		zoneCenter + Vector3.new(-sideX, 0, zOff),
		zoneCenter + Vector3.new(sideX, 0, zOff),
		zoneCenter + Vector3.new(-sideX, 0, -zOff),
		zoneCenter + Vector3.new(sideX, 0, -zOff),
	}

	for i, pos in ipairs(spots) do
		if zoneOrder == 1 then
			-- Zone 1 (Prairie) : Arbres ronds et buissons fleuris
			createPart({
				Size = Vector3.new(2.2, 8, 2.2),
				CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)),
				Color = Color3.fromRGB(125, 85, 50),
				Material = Enum.Material.Wood,
				Parent = decoFolder,
			})
			createPart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(9, 9, 9),
				CFrame = CFrame.new(pos + Vector3.new(0, 9.5, 0)),
				Color = Color3.fromRGB(65, 195, 55),
				Material = Enum.Material.Grass,
				Parent = decoFolder,
			})

		elseif zoneOrder == 2 then
			-- Zone 2 (Vallée Rocheuse) : Rochers anciens et piliers de pierre
			createPart({
				Size = Vector3.new(6, 5, 5),
				CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, math.rad(i * 40), math.rad(8)),
				Color = Color3.fromRGB(115, 120, 130),
				Material = Enum.Material.Rock,
				Parent = decoFolder,
			})
			createPart({
				Size = Vector3.new(3.5, 8, 3.5),
				CFrame = CFrame.new(pos + Vector3.new(2, 4, 1.5)) * CFrame.Angles(math.rad(-10), 0, 0),
				Color = Color3.fromRGB(95, 100, 110),
				Material = Enum.Material.Slate,
				Parent = decoFolder,
			})

		elseif zoneOrder == 3 then
			-- Zone 3 (Désert Doré) : Vrais Cactus à bras !
			local trunk = createPart({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(10, 2.4, 2.4),
				CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(55, 165, 65),
				Material = Enum.Material.SmoothPlastic,
				Parent = decoFolder,
			})
			createPart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(2.4, 2.4, 2.4),
				CFrame = CFrame.new(pos + Vector3.new(0, 10, 0)),
				Color = Color3.fromRGB(55, 165, 65),
				Parent = decoFolder,
			})
			-- Bras gauche et droit du cactus
			for _, side in ipairs({ -1, 1 }) do
				local armY = if side == -1 then 5.2 else 6.4
				createPart({
					Size = Vector3.new(2.2, 1.5, 1.5),
					CFrame = CFrame.new(pos + Vector3.new(side * 1.6, armY, 0)),
					Color = Color3.fromRGB(55, 165, 65),
					Parent = decoFolder,
				})
				createPart({
					Size = Vector3.new(1.5, 3.2, 1.5),
					CFrame = CFrame.new(pos + Vector3.new(side * 2.4, armY + 1.4, 0)),
					Color = Color3.fromRGB(55, 165, 65),
					Parent = decoFolder,
				})
			end
			local _ = trunk

		elseif zoneOrder == 4 then
			-- Zone 4 (Jungle d'Émeraude) : Palmiers tropicaux et cristaux d'émeraude
			createPart({
				Size = Vector3.new(2.0, 12, 2.0),
				CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(i % 2 == 0 and 6 or -6)),
				Color = Color3.fromRGB(115, 75, 40),
				Material = Enum.Material.Wood,
				Parent = decoFolder,
			})
			for a = 1, 4 do
				local ang = math.rad(a * 90)
				createPart({
					Size = Vector3.new(1.8, 0.5, 6.5),
					CFrame = CFrame.new(pos + Vector3.new(math.cos(ang) * 2.8, 11.8, math.sin(ang) * 2.8))
						* CFrame.Angles(math.rad(-20), ang, 0),
					Color = Color3.fromRGB(40, 205, 85),
					Material = Enum.Material.Grass,
					Parent = decoFolder,
				})
			end

		elseif zoneOrder == 5 then
			-- Zone 5 (Terres Gelées) : Sapins enneigés et pics de glace
			createPart({
				Size = Vector3.new(2, 5, 2),
				CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0)),
				Color = Color3.fromRGB(95, 65, 45),
				Material = Enum.Material.Wood,
				Parent = decoFolder,
			})
			createPart({
				Size = Vector3.new(7, 5, 7),
				CFrame = CFrame.new(pos + Vector3.new(0, 6.5, 0)),
				Color = Color3.fromRGB(220, 245, 255),
				Material = Enum.Material.Snow,
				Parent = decoFolder,
			})
			createPart({
				Size = Vector3.new(4.5, 4.5, 4.5),
				CFrame = CFrame.new(pos + Vector3.new(0, 10.5, 0)),
				Color = Color3.fromRGB(240, 250, 255),
				Material = Enum.Material.Ice,
				Parent = decoFolder,
			})

		elseif zoneOrder == 6 then
			-- Zone 6 (Canyon d'Améthyste) : Grappes de Cristaux géants
			for c = 1, 3 do
				createPart({
					Size = Vector3.new(1.8, 7 + c * 2, 1.8),
					CFrame = CFrame.new(pos + Vector3.new((c - 2) * 1.6, 3.5 + c, 0))
						* CFrame.Angles(math.rad((c - 2) * 15), math.rad(c * 30), math.rad((c - 2) * 12)),
					Color = Color3.fromRGB(205, 85, 255),
					Material = Enum.Material.Neon,
					Parent = decoFolder,
				})
			end

		elseif zoneOrder == 7 then
			-- Zone 7 (Terres de Lave) : Piliers de basalte et bassins de magma
			createPart({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.8, 7, 7),
				CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(255, 95, 20),
				Material = Enum.Material.Neon,
				Parent = decoFolder,
			})
			createPart({
				Size = Vector3.new(3.5, 9, 3.5),
				CFrame = CFrame.new(pos + Vector3.new(0, 4.5, 0)),
				Color = Color3.fromRGB(50, 25, 25),
				Material = Enum.Material.Basalt,
				Parent = decoFolder,
			})

		elseif zoneOrder == 8 then
			-- Zone 8 (Royaume des Ténèbres) : Obélisques noirs runiques
			createPart({
				Size = Vector3.new(3.2, 14, 3.2),
				CFrame = CFrame.new(pos + Vector3.new(0, 7, 0)),
				Color = Color3.fromRGB(25, 18, 38),
				Material = Enum.Material.Slate,
				Parent = decoFolder,
			})
			createPart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(2.8, 2.8, 2.8),
				CFrame = CFrame.new(pos + Vector3.new(0, 15.8, 0)),
				Color = Color3.fromRGB(255, 35, 95),
				Material = Enum.Material.Neon,
				Parent = decoFolder,
			})

		elseif zoneOrder == 9 then
			-- Zone 9 (Nébuleuse Stellaire) : Planètes flottantes à anneaux
			local planet = createPart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(5.5, 5.5, 5.5),
				CFrame = CFrame.new(pos + Vector3.new(0, 9, 0)),
				Color = Color3.fromRGB(85, 130, 255),
				Material = Enum.Material.Neon,
				Parent = decoFolder,
			})
			createPart({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, 10, 10),
				CFrame = planet.CFrame * CFrame.Angles(math.rad(25), 0, math.rad(70)),
				Color = Color3.fromRGB(185, 220, 255),
				Material = Enum.Material.Neon,
				Transparency = 0.2,
				Parent = decoFolder,
			})

		elseif zoneOrder == 10 then
			-- Zone 10 (Sanctuaire Divin) : Colonnes dorées antiques
			createPart({
				Size = Vector3.new(4.2, 1.5, 4.2),
				CFrame = CFrame.new(pos + Vector3.new(0, 0.75, 0)),
				Color = Color3.fromRGB(245, 240, 225),
				Material = Enum.Material.Marble,
				Parent = decoFolder,
			})
			createPart({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(13, 3.0, 3.0),
				CFrame = CFrame.new(pos + Vector3.new(0, 7.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(250, 248, 235),
				Material = Enum.Material.Marble,
				Parent = decoFolder,
			})
			createPart({
				Size = Vector3.new(4.4, 1.6, 4.4),
				CFrame = CFrame.new(pos + Vector3.new(0, 14.5, 0)),
				Color = Color3.fromRGB(255, 215, 65),
				Material = Enum.Material.Metal,
				Parent = decoFolder,
			})
		end
	end
end

-- ============================================================================
-- 2. VRAI PERSONNAGE ROBLOX (HUMANOID + MESH TÊTE + VISAGE + VÊTEMENTS/CHAPEAU)
-- ============================================================================
function ModelBuilder.CreateRobloxCharacterNPC(
	name: string,
	rootCF: CFrame,
	scale: number,
	skinColor: Color3,
	torsoColor: Color3,
	legsColor: Color3,
	hatType: "Merchant" | "Wizard" | "Knight",
	accentColor: Color3
): Model
	local s = scale
	local npc = Instance.new("Model")
	npc.Name = name

	local hum = Instance.new("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = npc

	-- Torse Roblox avec biseaux doux
	local torso = createPart({
		Name = "HumanoidRootPart",
		Size = Vector3.new(2.0 * s, 2.0 * s, 1.0 * s),
		Color = torsoColor,
		Material = Enum.Material.SmoothPlastic,
		CFrame = rootCF,
		Anchored = true,
		CanCollide = true,
		Parent = npc,
	})
	npc.PrimaryPart = torso

	-- Col / Foulard / Plastron décoratif
	createPart({
		Name = "Collar",
		Size = Vector3.new(2.1 * s, 0.45 * s, 1.1 * s),
		Color = accentColor,
		Material = Enum.Material.Fabric,
		CFrame = rootCF * CFrame.new(0, 0.8 * s, 0),
		Parent = npc,
	})

	-- Ceinture avec boucle dorée
	createPart({
		Name = "Belt",
		Size = Vector3.new(2.05 * s, 0.32 * s, 1.05 * s),
		Color = Color3.fromRGB(45, 35, 25),
		Material = Enum.Material.Fabric,
		CFrame = rootCF * CFrame.new(0, -0.85 * s, 0),
		Parent = npc,
	})
	createPart({
		Name = "BeltBuckle",
		Size = Vector3.new(0.45 * s, 0.38 * s, 0.15 * s),
		Color = Color3.fromRGB(255, 210, 55),
		Material = Enum.Material.Neon,
		CFrame = rootCF * CFrame.new(0, -0.85 * s, -0.52 * s),
		Parent = npc,
	})

	-- Tête cylindrique authentique Roblox + Visage souriant !
	local head = createPart({
		Name = "Head",
		Size = Vector3.new(2.0 * s, 1.0 * s, 1.0 * s),
		Color = skinColor,
		Material = Enum.Material.SmoothPlastic,
		CFrame = rootCF * CFrame.new(0, 1.5 * s, 0),
		Parent = npc,
	})
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head

	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

	-- Bras et Jambes avec biseaux Roblox
	local leftArm = createPart({
		Name = "LeftArm",
		Size = Vector3.new(1.0 * s, 2.0 * s, 1.0 * s),
		Color = torsoColor,
		Material = Enum.Material.SmoothPlastic,
		CFrame = rootCF * CFrame.new(-1.5 * s, 0, 0),
		Parent = npc,
	})
	-- Main gauche couleur peau
	createPart({
		Name = "LeftHand",
		Size = Vector3.new(0.95 * s, 0.45 * s, 0.95 * s),
		Color = skinColor,
		CFrame = leftArm.CFrame * CFrame.new(0, -0.8 * s, 0),
		Parent = npc,
	})

	local rightArm = createPart({
		Name = "RightArm",
		Size = Vector3.new(1.0 * s, 2.0 * s, 1.0 * s),
		Color = torsoColor,
		Material = Enum.Material.SmoothPlastic,
		CFrame = rootCF * CFrame.new(1.5 * s, 0, 0),
		Parent = npc,
	})
	createPart({
		Name = "RightHand",
		Size = Vector3.new(0.95 * s, 0.45 * s, 0.95 * s),
		Color = skinColor,
		CFrame = rightArm.CFrame * CFrame.new(0, -0.8 * s, 0),
		Parent = npc,
	})

	createPart({
		Name = "LeftLeg",
		Size = Vector3.new(1.0 * s, 2.0 * s, 1.0 * s),
		Color = legsColor,
		Material = Enum.Material.SmoothPlastic,
		CFrame = rootCF * CFrame.new(-0.5 * s, -2.0 * s, 0),
		Parent = npc,
	})

	createPart({
		Name = "RightLeg",
		Size = Vector3.new(1.0 * s, 2.0 * s, 1.0 * s),
		Color = legsColor,
		Material = Enum.Material.SmoothPlastic,
		CFrame = rootCF * CFrame.new(0.5 * s, -2.0 * s, 0),
		Parent = npc,
	})

	-- Chapeau / Coiffe selon le rôle du PNJ
	if hatType == "Merchant" then
		-- Haut-de-forme / Chapeau de riche Marchand doré avec ruban
		createPart({
			Name = "HatBrim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2 * s, 2.2 * s, 2.2 * s),
			CFrame = head.CFrame * CFrame.new(0, 0.55 * s, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(30, 32, 40),
			Parent = npc,
		})
		createPart({
			Name = "HatTop",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2 * s, 1.45 * s, 1.45 * s),
			CFrame = head.CFrame * CFrame.new(0, 1.15 * s, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(30, 32, 40),
			Parent = npc,
		})
		createPart({
			Name = "HatBand",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3 * s, 1.5 * s, 1.5 * s),
			CFrame = head.CFrame * CFrame.new(0, 0.78 * s, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = accentColor,
			Material = Enum.Material.Neon,
			Parent = npc,
		})
	elseif hatType == "Wizard" then
		-- Chapeau mystique de Maître des Sentiers / Traînées
		createPart({
			Name = "HatBrim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.18 * s, 2.5 * s, 2.5 * s),
			CFrame = head.CFrame * CFrame.new(0, 0.55 * s, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(35, 65, 145),
			Parent = npc,
		})
		createPart({
			Name = "WizardCone",
			Size = Vector3.new(1.3 * s, 1.8 * s, 1.3 * s),
			CFrame = head.CFrame * CFrame.new(0, 1.35 * s, 0) * CFrame.Angles(math.rad(-10), math.rad(45), 0),
			Color = accentColor,
			Material = Enum.Material.Neon,
			Parent = npc,
		})
	end

	return npc
end

-- ============================================================================
-- 3. GARDES DE ZONE AMÉLIORÉS (VRAI STYLE CHEVALIER ROBLOX EN ARMURE ROYALE)
-- ============================================================================
function ModelBuilder.CreateGuardianModel(stoneTier: GameConfig.StoneTier, spawnPos: Vector3): Model
	local s = stoneTier.GuardianScale * 1.35
	local rootCF = CFrame.new(spawnPos + Vector3.new(0, 3.0 * s, 0))

	local model = ModelBuilder.CreateRobloxCharacterNPC(
		stoneTier.GuardianName,
		rootCF,
		s,
		Color3.fromRGB(235, 200, 165),
		stoneTier.GuardianArmorColor,
		stoneTier.GuardianColor,
		"Knight",
		stoneTier.CrystalColor
	)

	local head = model:FindFirstChild("Head") :: BasePart
	local rightArm = model:FindFirstChild("RightArm") :: BasePart

	-- Casque de Chevalier Royal avec Visière lumineuse et Cornes
	createPart({
		Name = "HelmetTop",
		Size = Vector3.new(1.35 * s, 0.45 * s, 1.35 * s),
		Color = stoneTier.GuardianArmorColor,
		Material = Enum.Material.Metal,
		CFrame = head.CFrame * CFrame.new(0, 0.52 * s, 0),
		Parent = model,
	})
	createPart({
		Name = "VisorGlow",
		Size = Vector3.new(1.1 * s, 0.24 * s, 0.2 * s),
		Color = stoneTier.CrystalColor,
		Material = Enum.Material.Neon,
		CFrame = head.CFrame * CFrame.new(0, 0.12 * s, -0.58 * s),
		Parent = model,
	})
	for _, side in ipairs({ -1, 1 }) do
		createPart({
			Name = "HelmetHorn",
			Size = Vector3.new(0.28 * s, 1.3 * s, 0.28 * s),
			Color = stoneTier.CrystalColor,
			Material = Enum.Material.Neon,
			CFrame = head.CFrame * CFrame.new(side * 0.72 * s, 0.65 * s, 0) * CFrame.Angles(math.rad(-12), 0, math.rad(-side * 26)),
			Parent = model,
		})
		createPart({
			Name = "Pauldron",
			Size = Vector3.new(1.25 * s, 0.9 * s, 1.3 * s),
			Color = stoneTier.GuardianColor,
			Material = Enum.Material.Metal,
			CFrame = rootCF * CFrame.new(side * 1.55 * s, 0.85 * s, 0) * CFrame.Angles(0, 0, math.rad(-side * 12)),
			Parent = model,
		})
	end

	-- Cape royale dans le dos
	createPart({
		Name = "Cape",
		Size = Vector3.new(2.1 * s, 3.3 * s, 0.18 * s),
		Color = stoneTier.CrystalColor,
		Material = Enum.Material.Fabric,
		CFrame = rootCF * CFrame.new(0, -0.45 * s, 0.65 * s) * CFrame.Angles(math.rad(10), 0, 0),
		Parent = model,
	})

	-- Épée Runique dans la main droite du Garde
	createPart({
		Name = "GuardBlade",
		Size = Vector3.new(0.28 * s, 4.8 * s, 0.95 * s),
		Color = stoneTier.CrystalColor,
		Material = Enum.Material.Neon,
		CFrame = rightArm.CFrame * CFrame.new(0, -0.8 * s, -1.8 * s) * CFrame.Angles(math.rad(-75), 0, 0),
		Parent = model,
	})

	local bg = Instance.new("BillboardGui")
	bg.Name = "GuardianTag"
	bg.Size = UDim2.fromOffset(260, 66)
	bg.StudsOffset = Vector3.new(0, 2.8 * s, 0)
	bg.AlwaysOnTop = true
	bg.MaxDistance = 260
	bg.Parent = head

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.55)
	title.BackgroundTransparency = 1
	title.Text = string.format("⚔️ %s (Vit: %s)", stoneTier.GuardianName, GameConfig.FormatNumber(stoneTier.GuardianSpeedStat))
	title.TextColor3 = stoneTier.CrystalColor
	title.TextStrokeTransparency = 0
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Parent = bg

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Position = UDim2.fromScale(0, 0.55)
	status.Size = UDim2.fromScale(1, 0.45)
	status.BackgroundTransparency = 1
	status.Text = "💤 AFK (Immobile)"
	status.TextColor3 = Color3.fromRGB(200, 225, 255)
	status.TextStrokeTransparency = 0
	status.Font = Enum.Font.GothamBold
	status.TextScaled = true
	status.Parent = bg

	return model
end

function ModelBuilder.PositionAndAnimateGuardian(model: Model, baseScale: number, rootCF: CFrame, animTime: number, isMoving: boolean)
	local s = baseScale * 1.35
	local swingAmp = if isMoving then math.rad(42) else 0
	local swing = if isMoving then math.sin(animTime * 10) * swingAmp else 0

	local torso = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if torso then
		torso.CFrame = rootCF
	end
	local collar = model:FindFirstChild("Collar") :: BasePart?
	if collar then
		collar.CFrame = rootCF * CFrame.new(0, 0.8 * s, 0)
	end
	local belt = model:FindFirstChild("Belt") :: BasePart?
	if belt then
		belt.CFrame = rootCF * CFrame.new(0, -0.85 * s, 0)
	end
	local buckle = model:FindFirstChild("BeltBuckle") :: BasePart?
	if buckle then
		buckle.CFrame = rootCF * CFrame.new(0, -0.85 * s, -0.52 * s)
	end
	local cape = model:FindFirstChild("Cape") :: BasePart?
	if cape then
		local capeWave = math.rad(12) + math.abs(swing) * 0.4
		cape.CFrame = rootCF * CFrame.new(0, -0.45 * s, 0.65 * s) * CFrame.Angles(capeWave, 0, 0)
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		head.CFrame = rootCF * CFrame.new(0, 1.5 * s, 0)
		local hTop = model:FindFirstChild("HelmetTop") :: BasePart?
		if hTop then
			hTop.CFrame = head.CFrame * CFrame.new(0, 0.52 * s, 0)
		end
		local visor = model:FindFirstChild("VisorGlow") :: BasePart?
		if visor then
			visor.CFrame = head.CFrame * CFrame.new(0, 0.12 * s, -0.58 * s)
		end
	end

	local leftArm = model:FindFirstChild("LeftArm") :: BasePart?
	if leftArm then
		leftArm.CFrame = rootCF * CFrame.new(-1.5 * s, 0.7 * s, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -0.7 * s, 0)
		local lHand = model:FindFirstChild("LeftHand") :: BasePart?
		if lHand then
			lHand.CFrame = leftArm.CFrame * CFrame.new(0, -0.8 * s, 0)
		end
	end

	local rightArm = model:FindFirstChild("RightArm") :: BasePart?
	if rightArm then
		local rAngle = if isMoving then math.rad(35) - swing * 0.7 else 0
		rightArm.CFrame = rootCF * CFrame.new(1.5 * s, 0.7 * s, 0) * CFrame.Angles(rAngle, 0, 0) * CFrame.new(0, -0.7 * s, 0)
		local rHand = model:FindFirstChild("RightHand") :: BasePart?
		if rHand then
			rHand.CFrame = rightArm.CFrame * CFrame.new(0, -0.8 * s, 0)
		end
		local blade = model:FindFirstChild("GuardBlade") :: BasePart?
		if blade then
			blade.CFrame = rightArm.CFrame * CFrame.new(0, -0.8 * s, -1.8 * s) * CFrame.Angles(math.rad(-75), 0, 0)
		end
	end

	local leftLeg = model:FindFirstChild("LeftLeg") :: BasePart?
	if leftLeg then
		leftLeg.CFrame = rootCF * CFrame.new(-0.5 * s, -1.0 * s, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1.0 * s, 0)
	end
	local rightLeg = model:FindFirstChild("RightLeg") :: BasePart?
	if rightLeg then
		rightLeg.CFrame = rootCF * CFrame.new(0.5 * s, -1.0 * s, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1.0 * s, 0)
	end

	local hornIdx = 0
	local pauldronIdx = 0
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			if child.Name == "HelmetHorn" and head then
				hornIdx += 1
				local side = if hornIdx == 1 then -1 else 1
				child.CFrame = head.CFrame * CFrame.new(side * 0.72 * s, 0.65 * s, 0) * CFrame.Angles(math.rad(-12), 0, math.rad(-side * 26))
			elseif child.Name == "Pauldron" then
				pauldronIdx += 1
				local side = if pauldronIdx == 1 then -1 else 1
				child.CFrame = rootCF * CFrame.new(side * 1.55 * s, 0.85 * s, 0) * CFrame.Angles(0, 0, math.rad(-side * 12))
			end
		end
	end
end

-- ============================================================================
-- 4. BOUTIQUES & VENDEURS AUTHENTIQUES ROBLOX
-- ============================================================================
function ModelBuilder.CreateMerchantStall(
	parent: Instance,
	centerCF: CFrame,
	titleText: string,
	subtitleText: string,
	themeColor: Color3,
	actionText: string,
	merchantType: "Merchant" | "Wizard"
): ProximityPrompt
	local stall = Instance.new("Model")
	stall.Name = titleText
	stall.Parent = parent

	-- Tapis d'accueil devant le stand
	createPart({
		Name = "WelcomeRug",
		Size = Vector3.new(10, 0.2, 6),
		CFrame = centerCF * CFrame.new(0, 0.1, -3.5),
		Color = themeColor,
		Material = Enum.Material.Fabric,
		Parent = stall,
	})

	-- Comptoir détaillé avec bordure dorée
	local counter = createPart({
		Name = "Counter",
		Size = Vector3.new(13, 3.4, 4.2),
		CFrame = centerCF * CFrame.new(0, 1.7, 0),
		Color = Color3.fromRGB(115, 72, 40),
		Material = Enum.Material.WoodPlanks,
		CanCollide = true,
		Parent = stall,
	})
	createPart({
		Name = "CounterTop",
		Size = Vector3.new(13.6, 0.5, 4.8),
		CFrame = centerCF * CFrame.new(0, 3.55, 0),
		Color = Color3.fromRGB(235, 225, 205),
		Material = Enum.Material.Marble,
		Parent = stall,
	})

	-- Coffre d'or ou Cristaux exposés sur le comptoir
	if merchantType == "Merchant" then
		createPart({
			Size = Vector3.new(2.6, 1.6, 1.8),
			CFrame = centerCF * CFrame.new(-3.8, 4.5, 0) * CFrame.Angles(0, math.rad(15), 0),
			Color = Color3.fromRGB(255, 205, 45),
			Material = Enum.Material.Metal,
			Parent = stall,
		})
	else
		createPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.2, 2.2, 2.2),
			CFrame = centerCF * CFrame.new(3.8, 4.8, 0),
			Color = Color3.fromRGB(80, 235, 255),
			Material = Enum.Material.Neon,
			Parent = stall,
		})
	end

	-- 4 Piliers en bois sculpté
	for _, sideX in ipairs({ -5.8, 5.8 }) do
		for _, sideZ in ipairs({ -1.6, 2.2 }) do
			createPart({
				Size = Vector3.new(0.85, 10.5, 0.85),
				CFrame = centerCF * CFrame.new(sideX, 5.25, sideZ),
				Color = Color3.fromRGB(85, 52, 28),
				Material = Enum.Material.Wood,
				Parent = stall,
			})
		end
	end

	-- Auvent rayé (Blanc & Couleur du thème, exactement comme sur l'image 2 !)
	local stripeCount = 7
	local stripeW = 14.0 / stripeCount
	for i = 1, stripeCount do
		local xOff = -7.0 + (i - 0.5) * stripeW
		createPart({
			Name = "AwningStripe_" .. i,
			Size = Vector3.new(stripeW, 1.2, 7.2),
			CFrame = centerCF * CFrame.new(xOff, 10.8, 0.2) * CFrame.Angles(math.rad(10), 0, 0),
			Color = if i % 2 == 1 then themeColor else Color3.fromRGB(250, 250, 252),
			Material = Enum.Material.SmoothPlastic,
			Parent = stall,
		})
	end

	-- Vrai Personnage Marchand Roblox derrière le comptoir (regardant vers le joueur, Z négatif)
	local npcCF = centerCF * CFrame.new(0, 3.1, 3.2)
	local npc = ModelBuilder.CreateRobloxCharacterNPC(
		"Vendeur_" .. titleText,
		npcCF,
		1.25,
		Color3.fromRGB(255, 215, 175),
		if merchantType == "Merchant" then Color3.fromRGB(185, 45, 45) else Color3.fromRGB(45, 95, 200),
		Color3.fromRGB(40, 45, 60),
		merchantType,
		themeColor
	)
	npc.Parent = stall

	-- Panneau lumineux au-dessus de l'auvent
	local bg = Instance.new("BillboardGui")
	bg.Size = UDim2.fromOffset(310, 74)
	bg.StudsOffset = Vector3.new(0, 14.8, 0)
	bg.AlwaysOnTop = true
	bg.MaxDistance = 190
	bg.Parent = counter

	local tLbl = Instance.new("TextLabel")
	tLbl.Size = UDim2.new(1, 0, 0.6, 0)
	tLbl.BackgroundTransparency = 1
	tLbl.Font = Enum.Font.FredokaOne
	tLbl.TextColor3 = themeColor
	tLbl.TextStrokeTransparency = 0
	tLbl.TextScaled = true
	tLbl.Text = titleText
	tLbl.Parent = bg

	local sLbl = Instance.new("TextLabel")
	sLbl.Size = UDim2.new(1, 0, 0.4, 0)
	sLbl.Position = UDim2.fromScale(0, 0.6)
	sLbl.BackgroundTransparency = 1
	sLbl.Font = Enum.Font.GothamBold
	sLbl.TextColor3 = Color3.new(1, 1, 1)
	sLbl.TextStrokeTransparency = 0
	sLbl.TextScaled = true
	sLbl.Text = subtitleText
	sLbl.Parent = bg

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = titleText
	prompt.ActionText = actionText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 15
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	local _ = Players
	return prompt
end

-- ============================================================================
-- 5. PIERRES D'ÉPÉE, ÉPÉES 3D, CLÔTURES & TAPIS DE COURSE
-- ============================================================================
function ModelBuilder.CreateSwordStoneModel(stoneTier: GameConfig.StoneTier, cframe: CFrame, isCarried: boolean?): Model
	local model = Instance.new("Model")
	model.Name = stoneTier.Name

	local anchored = not isCarried

	local core = createPart({
		Name = "PrimaryPart",
		Size = Vector3.new(4.4, 5.4, 4.4),
		Color = stoneTier.StoneColor,
		Material = Enum.Material.Rock,
		CFrame = cframe * CFrame.new(0, 2.2, 0),
		Anchored = anchored,
		CanCollide = false,
		Parent = model,
	})
	model.PrimaryPart = core

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1.25, 1)
	mesh.Parent = core

	local ring = createPart({
		Name = "AuraRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.35, 6.2, 6.2),
		Color = stoneTier.CrystalColor,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CFrame = core.CFrame * CFrame.Angles(0, 0, math.rad(90)),
		Anchored = anchored,
		CanCollide = false,
		Parent = model,
	})
	if not anchored then
		weldParts(core, ring)
	end

	local shardAngles = { 0, 45, 90, 135, 180, 225, 270, 315 }
	for i, deg in ipairs(shardAngles) do
		local rad = math.rad(deg)
		local offset = CFrame.new(math.cos(rad) * 1.8, (i % 2 == 0 and 0.4 or -0.5), math.sin(rad) * 1.8)
			* CFrame.Angles(math.rad(22), rad, math.rad(18))
		local shard = createPart({
			Name = "CrystalShard_" .. i,
			Size = Vector3.new(0.85, 3.0, 0.85),
			Color = stoneTier.CrystalColor,
			Material = Enum.Material.Neon,
			CFrame = core.CFrame * offset,
			Anchored = anchored,
			CanCollide = false,
			Parent = model,
		})
		if not anchored then
			weldParts(core, shard)
		end
	end

	local blade = createPart({
		Name = "SealedBlade",
		Size = Vector3.new(0.38, 4.4, 1.15),
		Color = stoneTier.CrystalColor,
		Material = Enum.Material.Neon,
		CFrame = core.CFrame * CFrame.new(0, 2.8, 0),
		Anchored = anchored,
		CanCollide = false,
		Parent = model,
	})
	local guard = createPart({
		Name = "CrossGuard",
		Size = Vector3.new(0.65, 0.45, 2.7),
		Color = Color3.fromRGB(35, 38, 50),
		Material = Enum.Material.Metal,
		CFrame = blade.CFrame * CFrame.new(0, 1.3, 0),
		Anchored = anchored,
		CanCollide = false,
		Parent = model,
	})
	local grip = createPart({
		Name = "Grip",
		Size = Vector3.new(0.42, 1.4, 0.45),
		Color = Color3.fromRGB(95, 60, 35),
		Material = Enum.Material.Wood,
		CFrame = blade.CFrame * CFrame.new(0, 2.1, 0),
		Anchored = anchored,
		CanCollide = false,
		Parent = model,
	})

	if not anchored then
		weldParts(core, blade)
		weldParts(core, guard)
		weldParts(core, grip)
	end

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(stoneTier.CrystalColor, Color3.new(1, 1, 1))
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Lifetime = NumberRange.new(0.5, 1.2)
	particles.Rate = 16
	particles.Speed = NumberRange.new(2, 5)
	particles.LightEmission = 1
	particles.Parent = core

	local light = Instance.new("PointLight")
	light.Color = stoneTier.CrystalColor
	light.Range = 15
	light.Brightness = 2.4
	light.Parent = core

	return model
end

function ModelBuilder.CreateSwordModel(swordId: string, cframe: CFrame, anchored: boolean): Model
	local info = GameConfig.Swords[swordId] or GameConfig.Swords.WoodenDagger
	local rarity = GameConfig.Rarities[info.Rarity] or GameConfig.Rarities.Common
	local scale = info.Scale or 1.0

	local model = Instance.new("Model")
	model.Name = info.Name

	local handle = createPart({
		Name = "Handle",
		Size = Vector3.new(0.34 * scale, 1.35 * scale, 0.38 * scale),
		Color = info.HandleColor,
		Material = Enum.Material.Metal,
		CFrame = cframe,
		Anchored = anchored,
		CanCollide = false,
		Parent = model,
	})
	model.PrimaryPart = handle

	local guard = createPart({
		Name = "Guard",
		Size = Vector3.new(0.55 * scale, 0.42 * scale, 2.3 * scale),
		Color = rarity.Color,
		Material = Enum.Material.Metal,
		CFrame = cframe * CFrame.new(0, 0.72 * scale, 0),
		Anchored = anchored,
		CanCollide = false,
		Parent = model,
	})

	local bladeLength = 4.2 * scale
	local blade = createPart({
		Name = "Blade",
		Size = Vector3.new(0.24 * scale, bladeLength, 0.9 * scale),
		Color = info.BladeColor,
		Material = if rarity.Order >= 3 then Enum.Material.Neon else Enum.Material.Metal,
		CFrame = cframe * CFrame.new(0, 0.72 * scale + bladeLength / 2, 0),
		Anchored = anchored,
		CanCollide = false,
		Parent = model,
	})

	local coreGlow = createPart({
		Name = "CoreGlow",
		Size = Vector3.new(0.28 * scale, bladeLength * 0.88, 0.3 * scale),
		Color = info.GlowColor,
		Material = Enum.Material.Neon,
		CFrame = blade.CFrame,
		Anchored = anchored,
		CanCollide = false,
		Parent = model,
	})

	local pommel = createPart({
		Name = "Pommel",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.62 * scale, 0.62 * scale, 0.62 * scale),
		Color = rarity.Color,
		Material = Enum.Material.Neon,
		CFrame = cframe * CFrame.new(0, -0.78 * scale, 0),
		Anchored = anchored,
		CanCollide = false,
		Parent = model,
	})

	if not anchored then
		weldParts(handle, guard)
		weldParts(handle, blade)
		weldParts(handle, coreGlow)
		weldParts(handle, pommel)
	end

	if rarity.Order >= 2 then
		local particles = Instance.new("ParticleEmitter")
		particles.Color = ColorSequence.new(rarity.Color, info.GlowColor)
		particles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.38 * scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		particles.Lifetime = NumberRange.new(0.6, 1.2)
		particles.Rate = 6 * rarity.Order
		particles.Speed = NumberRange.new(1.5, 4)
		particles.LightEmission = 1
		particles.Parent = blade
	end

	return model
end

function ModelBuilder.CreateFenceRect(parent: Instance, center: Vector3, width: number, depth: number, color: Color3, leaveFrontGap: boolean?)
	local folder = Instance.new("Model")
	folder.Name = "Fence"
	folder.Parent = parent

	local halfW = width / 2
	local halfD = depth / 2

	local corners = {
		Vector3.new(-halfW, 2.0, -halfD),
		Vector3.new(halfW, 2.0, -halfD),
		Vector3.new(-halfW, 2.0, halfD),
		Vector3.new(halfW, 2.0, halfD),
	}
	for _, c in ipairs(corners) do
		createPart({
			Size = Vector3.new(1.0, 4.0, 1.0),
			CFrame = CFrame.new(center + c),
			Color = color,
			Material = Enum.Material.WoodPlanks,
			CanCollide = true,
			Parent = folder,
		})
	end

	for _, yH in ipairs({ 1.2, 2.8 }) do
		createPart({
			Size = Vector3.new(width, 0.45, 0.45),
			CFrame = CFrame.new(center + Vector3.new(0, yH, halfD)),
			Color = color,
			Material = Enum.Material.WoodPlanks,
			CanCollide = true,
			Parent = folder,
		})
		createPart({
			Size = Vector3.new(0.45, 0.45, depth),
			CFrame = CFrame.new(center + Vector3.new(-halfW, yH, 0)),
			Color = color,
			Material = Enum.Material.WoodPlanks,
			CanCollide = true,
			Parent = folder,
		})
		createPart({
			Size = Vector3.new(0.45, 0.45, depth),
			CFrame = CFrame.new(center + Vector3.new(halfW, yH, 0)),
			Color = color,
			Material = Enum.Material.WoodPlanks,
			CanCollide = true,
			Parent = folder,
		})
		if not leaveFrontGap then
			createPart({
				Size = Vector3.new(width, 0.45, 0.45),
				CFrame = CFrame.new(center + Vector3.new(0, yH, -halfD)),
				Color = color,
				Material = Enum.Material.WoodPlanks,
				CanCollide = true,
				Parent = folder,
			})
		else
			local segW = (width - 12) / 2
			if segW > 1 then
				createPart({
					Size = Vector3.new(segW, 0.45, 0.45),
					CFrame = CFrame.new(center + Vector3.new(-halfW + segW / 2, yH, -halfD)),
					Color = color,
					Material = Enum.Material.WoodPlanks,
					CanCollide = true,
					Parent = folder,
				})
				createPart({
					Size = Vector3.new(segW, 0.45, 0.45),
					CFrame = CFrame.new(center + Vector3.new(halfW - segW / 2, yH, -halfD)),
					Color = color,
					Material = Enum.Material.WoodPlanks,
					CanCollide = true,
					Parent = folder,
				})
			end
		end
	end
end

function ModelBuilder.CreatePersonalTreadmill(ownerName: string, centerPos: Vector3, level: number, gainPerTick: number, upgradeCost: number): (Model, Part, ProximityPrompt, TextLabel, TextLabel)
	local tm = Instance.new("Model")
	tm.Name = "PersonalTreadmill_" .. ownerName

	local belt = createPart({
		Name = "LavaBelt",
		Size = Vector3.new(9, 1.0, 18),
		CFrame = CFrame.new(centerPos),
		Color = Color3.fromRGB(255, 85, 20),
		Material = Enum.Material.CrackedLava,
		Parent = tm,
	})
	tm.PrimaryPart = belt
	ModelBuilder.ApplySurfaceTexture(belt, "rbxassetid://6372755229", { Enum.NormalId.Top }, 6, 0.55, Color3.fromRGB(255, 220, 60))

	for _, side in ipairs({ -5.1, 5.1 }) do
		createPart({
			Size = Vector3.new(1.4, 2.0, 19),
			CFrame = CFrame.new(centerPos + Vector3.new(side, 0.5, 0)),
			Color = Color3.fromRGB(65, 42, 35),
			Material = Enum.Material.Basalt,
			Parent = tm,
		})
	end

	for _, side in ipairs({ -5.1, 5.1 }) do
		local pillar = createPart({
			Size = Vector3.new(1.8, 9.5, 1.8),
			CFrame = CFrame.new(centerPos + Vector3.new(side, 4.7, -8.5)),
			Color = Color3.fromRGB(75, 45, 35),
			Material = Enum.Material.Brick,
			Parent = tm,
		})
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 6
		fire.Parent = pillar
	end

	createPart({
		Size = Vector3.new(12.2, 1.8, 2.0),
		CFrame = CFrame.new(centerPos + Vector3.new(0, 9.5, -8.5)),
		Color = Color3.fromRGB(55, 35, 28),
		Material = Enum.Material.Brick,
		Parent = tm,
	})

	local bg = Instance.new("BillboardGui")
	bg.Size = UDim2.fromOffset(250, 62)
	bg.StudsOffset = Vector3.new(0, 12.5, -8.5)
	bg.AlwaysOnTop = true
	bg.MaxDistance = 120
	bg.Parent = belt

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.fromScale(1, 1)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.FredokaOne
	titleLbl.TextColor3 = Color3.fromRGB(255, 75, 230)
	titleLbl.TextStrokeTransparency = 0
	titleLbl.TextScaled = true
	titleLbl.Text = string.format("👟 Tapis de %s (Niv. %d)\n+%s Vitesse / sec (Reste dessus !)", ownerName, level, GameConfig.FormatNumber(gainPerTick))
	titleLbl.Parent = bg

	local board = createPart({
		Name = "UpgradeStand",
		Size = Vector3.new(6.2, 5.2, 1.1),
		CFrame = CFrame.new(centerPos + Vector3.new(9.5, 3.0, -2)) * CFrame.Angles(0, math.rad(-22), 0),
		Color = Color3.fromRGB(22, 26, 36),
		Material = Enum.Material.SmoothPlastic,
		Parent = tm,
	})

	local boardBg = Instance.new("BillboardGui")
	boardBg.Size = UDim2.fromOffset(190, 75)
	boardBg.StudsOffset = Vector3.new(0, 0.5, 0)
	boardBg.AlwaysOnTop = true
	boardBg.MaxDistance = 90
	boardBg.Parent = board

	local boardLbl = Instance.new("TextLabel")
	boardLbl.Size = UDim2.fromScale(1, 1)
	boardLbl.BackgroundTransparency = 1
	boardLbl.Font = Enum.Font.FredokaOne
	boardLbl.TextColor3 = Color3.fromRGB(85, 255, 110)
	boardLbl.TextStrokeTransparency = 0
	boardLbl.TextScaled = true
	boardLbl.Text = string.format("Améliorer Tapis\nNiv. %d -> Niv. %d\n💵 $%s", level, level + 1, GameConfig.FormatNumber(upgradeCost))
	boardLbl.Parent = boardBg

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Tapis de " .. ownerName
	prompt.ActionText = "Améliorer ($" .. GameConfig.FormatNumber(upgradeCost) .. ")"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = board

	return tm, belt, prompt, titleLbl, boardLbl
end

return ModelBuilder
