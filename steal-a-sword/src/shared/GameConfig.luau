--!strict
-- Configuration centrale de "Voler une Épée" (Steal a Sword)
-- Inclut :
-- - Épées avec revenus $/s aléatoires selon la Zone et la Rareté
-- - Boutique de Traînées (Sentiers) avec multiplicateurs équilibrés et prix élevés
-- - 10 Zones avec Gardes AFK dans un coin qui se réveillent au vol d'une Pierre

local GameConfig = {}

export type RarityInfo = {
	Name: string,
	Color: Color3,
	Order: number,
	StatMultiplier: number, -- Multiplie le jet aléatoire d'argent de la zone
}

export type SwordTemplate = {
	Id: string,
	Name: string,
	Rarity: string,
	BladeColor: Color3,
	HandleColor: Color3,
	GlowColor: Color3,
	Scale: number,
}

-- Instance unique d'une épée possédée par un joueur (avec son revenu $/s aléatoire !)
export type OwnedSwordItem = {
	Uid: string,
	SwordId: string,
	Name: string,
	Rarity: string,
	ZoneOrder: number,
	MoneyPerSec: number,
	SellPrice: number,
}

export type TrailInfo = {
	Id: string,
	Name: string,
	Price: number,
	SpeedMultiplier: number, -- Multiplicateur raisonnable (ex: 1.15x -> 5.0x)
	MoneyMultiplier: number, -- Multiplicateur raisonnable (ex: 1.10x -> 4.0x)
	Color1: Color3,
	Color2: Color3,
	Order: number,
}

export type StoneTier = {
	Id: string,
	Name: string,
	ZoneName: string,
	ZoneOrder: number,
	ZoneLength: number,
	ForgeTime: number,
	CarrySlowFactor: number,
	MinBaseMoneyPerSec: number, -- Fourchette aléatoire de base de la zone
	MaxBaseMoneyPerSec: number,
	FloorColor: Color3,
	WallColor: Color3,
	StoneColor: Color3,
	CrystalColor: Color3,
	GuardianName: string,
	GuardianSpeedStat: number,
	GuardianColor: Color3,
	GuardianArmorColor: Color3,
	GuardianScale: number,
	DropTable: { [string]: number },
}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }
function GameConfig.FormatNumber(n: number): string
	if n < 1000 then
		return tostring(math.floor(n))
	end
	local index = math.min(#SUFFIXES, math.floor(math.log10(n) / 3))
	local scaled = n / (10 ^ (index * 3))
	if scaled >= 100 then
		return string.format("%d%s", math.floor(scaled), SUFFIXES[index])
	else
		return string.format("%.1f%s", scaled, SUFFIXES[index]):gsub("%.0", "")
	end
end

function GameConfig.FormatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds < 60 then
		return string.format("%ds", seconds)
	elseif seconds < 3600 then
		local m = math.floor(seconds / 60)
		local s = seconds % 60
		if s == 0 then
			return string.format("%dm", m)
		end
		return string.format("%dm %ds", m, s)
	else
		local h = math.floor(seconds / 3600)
		local m = math.floor((seconds % 3600) / 60)
		return string.format("%dh %dm", h, m)
	end
end

GameConfig.Rarities = {
	Common = { Name = "Commune", Color = Color3.fromRGB(190, 200, 210), Order = 1, StatMultiplier = 1.0 },
	Rare = { Name = "Rare", Color = Color3.fromRGB(55, 160, 255), Order = 2, StatMultiplier = 1.45 },
	Epic = { Name = "Épique", Color = Color3.fromRGB(190, 70, 255), Order = 3, StatMultiplier = 2.1 },
	Legendary = { Name = "Légendaire", Color = Color3.fromRGB(255, 200, 30), Order = 4, StatMultiplier = 3.2 },
	Mythic = { Name = "Mythique", Color = Color3.fromRGB(255, 45, 90), Order = 5, StatMultiplier = 5.0 },
	Secret = { Name = "Secrète", Color = Color3.fromRGB(65, 255, 235), Order = 6, StatMultiplier = 8.5 },
}

-- Modèles d'épées
GameConfig.Swords = {
	WoodenDagger = {
		Id = "WoodenDagger",
		Name = "Dague d'Entraînement",
		Rarity = "Common",
		BladeColor = Color3.fromRGB(185, 140, 95),
		HandleColor = Color3.fromRGB(110, 75, 45),
		GlowColor = Color3.fromRGB(210, 180, 140),
		Scale = 0.95,
	},
	RustySword = {
		Id = "RustySword",
		Name = "Épée de Fer Forgé",
		Rarity = "Common",
		BladeColor = Color3.fromRGB(175, 185, 195),
		HandleColor = Color3.fromRGB(95, 65, 45),
		GlowColor = Color3.fromRGB(210, 215, 225),
		Scale = 1.0,
	},
	StoneBroadsword = {
		Id = "StoneBroadsword",
		Name = "Glaive de Roche",
		Rarity = "Common",
		BladeColor = Color3.fromRGB(145, 150, 160),
		HandleColor = Color3.fromRGB(70, 75, 85),
		GlowColor = Color3.fromRGB(190, 200, 215),
		Scale = 1.08,
	},
	SquireBlade = {
		Id = "SquireBlade",
		Name = "Lame du Chevalier",
		Rarity = "Rare",
		BladeColor = Color3.fromRGB(120, 195, 255),
		HandleColor = Color3.fromRGB(45, 85, 145),
		GlowColor = Color3.fromRGB(150, 215, 255),
		Scale = 1.12,
	},
	GoldenScimitar = {
		Id = "GoldenScimitar",
		Name = "Cimeterre des Dunes",
		Rarity = "Rare",
		BladeColor = Color3.fromRGB(255, 215, 80),
		HandleColor = Color3.fromRGB(150, 95, 30),
		GlowColor = Color3.fromRGB(255, 235, 120),
		Scale = 1.18,
	},
	CobaltSaber = {
		Id = "CobaltSaber",
		Name = "Sabre de Cobalt",
		Rarity = "Rare",
		BladeColor = Color3.fromRGB(45, 140, 255),
		HandleColor = Color3.fromRGB(30, 40, 65),
		GlowColor = Color3.fromRGB(75, 180, 255),
		Scale = 1.22,
	},
	EmeraldClaymore = {
		Id = "EmeraldClaymore",
		Name = "Claymore d'Émeraude",
		Rarity = "Epic",
		BladeColor = Color3.fromRGB(40, 235, 125),
		HandleColor = Color3.fromRGB(25, 75, 45),
		GlowColor = Color3.fromRGB(80, 255, 160),
		Scale = 1.28,
	},
	ForestRapier = {
		Id = "ForestRapier",
		Name = "Rapière Sylvestre",
		Rarity = "Epic",
		BladeColor = Color3.fromRGB(95, 255, 110),
		HandleColor = Color3.fromRGB(85, 55, 30),
		GlowColor = Color3.fromRGB(140, 255, 150),
		Scale = 1.32,
	},
	FrostbiteBlade = {
		Id = "FrostbiteBlade",
		Name = "Lame Givrante Polaire",
		Rarity = "Epic",
		BladeColor = Color3.fromRGB(110, 235, 255),
		HandleColor = Color3.fromRGB(40, 95, 150),
		GlowColor = Color3.fromRGB(175, 245, 255),
		Scale = 1.36,
	},
	GlacierCleaver = {
		Id = "GlacierCleaver",
		Name = "Fendoir des Glaces",
		Rarity = "Epic",
		BladeColor = Color3.fromRGB(70, 200, 255),
		HandleColor = Color3.fromRGB(30, 60, 110),
		GlowColor = Color3.fromRGB(130, 225, 255),
		Scale = 1.42,
	},
	AmethystKatana = {
		Id = "AmethystKatana",
		Name = "Katana d'Améthyste",
		Rarity = "Legendary",
		BladeColor = Color3.fromRGB(190, 65, 255),
		HandleColor = Color3.fromRGB(50, 20, 75),
		GlowColor = Color3.fromRGB(220, 120, 255),
		Scale = 1.46,
	},
	CrystalReaver = {
		Id = "CrystalReaver",
		Name = "Faucheuse de Cristal",
		Rarity = "Legendary",
		BladeColor = Color3.fromRGB(235, 85, 255),
		HandleColor = Color3.fromRGB(75, 25, 95),
		GlowColor = Color3.fromRGB(255, 150, 255),
		Scale = 1.52,
	},
	MagmaReaper = {
		Id = "MagmaReaper",
		Name = "Brise-Monde Magmatique",
		Rarity = "Legendary",
		BladeColor = Color3.fromRGB(255, 95, 25),
		HandleColor = Color3.fromRGB(55, 20, 15),
		GlowColor = Color3.fromRGB(255, 140, 45),
		Scale = 1.58,
	},
	SolarExcalibur = {
		Id = "SolarExcalibur",
		Name = "Excalibur Solaire",
		Rarity = "Legendary",
		BladeColor = Color3.fromRGB(255, 215, 40),
		HandleColor = Color3.fromRGB(165, 95, 20),
		GlowColor = Color3.fromRGB(255, 240, 115),
		Scale = 1.64,
	},
	ShadowScythe = {
		Id = "ShadowScythe",
		Name = "Lame de l'Ombre Noire",
		Rarity = "Mythic",
		BladeColor = Color3.fromRGB(130, 35, 210),
		HandleColor = Color3.fromRGB(20, 15, 30),
		GlowColor = Color3.fromRGB(185, 75, 255),
		Scale = 1.70,
	},
	Voidbreaker = {
		Id = "Voidbreaker",
		Name = "Fendeuse du Néant",
		Rarity = "Mythic",
		BladeColor = Color3.fromRGB(255, 30, 90),
		HandleColor = Color3.fromRGB(25, 10, 35),
		GlowColor = Color3.fromRGB(255, 70, 130),
		Scale = 1.76,
	},
	NebulaStarblade = {
		Id = "NebulaStarblade",
		Name = "Lame Stellaire Cosmique",
		Rarity = "Mythic",
		BladeColor = Color3.fromRGB(95, 120, 255),
		HandleColor = Color3.fromRGB(30, 25, 75),
		GlowColor = Color3.fromRGB(150, 180, 255),
		Scale = 1.84,
	},
	GalaxySlayer = {
		Id = "GalaxySlayer",
		Name = "Pourfendeuse Galactique",
		Rarity = "Secret",
		BladeColor = Color3.fromRGB(255, 65, 225),
		HandleColor = Color3.fromRGB(45, 15, 65),
		GlowColor = Color3.fromRGB(255, 140, 245),
		Scale = 1.92,
	},
	CelestialArchblade = {
		Id = "CelestialArchblade",
		Name = "Arche-Lame Céleste",
		Rarity = "Secret",
		BladeColor = Color3.fromRGB(85, 255, 240),
		HandleColor = Color3.fromRGB(255, 225, 110),
		GlowColor = Color3.fromRGB(165, 255, 250),
		Scale = 2.05,
	},
	OmegaGodsword = {
		Id = "OmegaGodsword",
		Name = "Épée Suprême de l'Infini",
		Rarity = "Secret",
		BladeColor = Color3.fromRGB(255, 250, 140),
		HandleColor = Color3.fromRGB(255, 80, 120),
		GlowColor = Color3.fromRGB(255, 255, 210),
		Scale = 2.20,
	},
}

-- Boutique de Traînées (Sentiers) : Prix de plus en plus chers, multiplicateurs de vitesse et d'argent équilibrés !
GameConfig.Trails = {
	{
		Id = "WindTrail",
		Name = "Sentier du Vent",
		Price = 500,
		SpeedMultiplier = 1.15,
		MoneyMultiplier = 1.10,
		Color1 = Color3.fromRGB(210, 245, 255),
		Color2 = Color3.fromRGB(140, 215, 255),
		Order = 1,
	},
	{
		Id = "EmeraldTrail",
		Name = "Sentier d'Émeraude",
		Price = 5000, -- $5K
		SpeedMultiplier = 1.30,
		MoneyMultiplier = 1.25,
		Color1 = Color3.fromRGB(65, 255, 120),
		Color2 = Color3.fromRGB(20, 180, 75),
		Order = 2,
	},
	{
		Id = "FlameTrail",
		Name = "Sentier de Flammes",
		Price = 75000, -- $75K
		SpeedMultiplier = 1.50,
		MoneyMultiplier = 1.45,
		Color1 = Color3.fromRGB(255, 195, 45),
		Color2 = Color3.fromRGB(255, 65, 20),
		Order = 3,
	},
	{
		Id = "FrostTrail",
		Name = "Sentier Glacial",
		Price = 1200000, -- $1.2M
		SpeedMultiplier = 1.75,
		MoneyMultiplier = 1.70,
		Color1 = Color3.fromRGB(120, 245, 255),
		Color2 = Color3.fromRGB(35, 130, 255),
		Order = 4,
	},
	{
		Id = "AmethystTrail",
		Name = "Sentier d'Améthyste",
		Price = 25000000, -- $25M
		SpeedMultiplier = 2.10,
		MoneyMultiplier = 2.00,
		Color1 = Color3.fromRGB(220, 110, 255),
		Color2 = Color3.fromRGB(130, 30, 220),
		Order = 5,
	},
	{
		Id = "SolarTrail",
		Name = "Sentier Solaire Royal",
		Price = 600000000, -- $600M
		SpeedMultiplier = 2.50,
		MoneyMultiplier = 2.40,
		Color1 = Color3.fromRGB(255, 245, 120),
		Color2 = Color3.fromRGB(255, 165, 20),
		Order = 6,
	},
	{
		Id = "VoidTrail",
		Name = "Sentier du Néant",
		Price = 18000000000, -- $18B
		SpeedMultiplier = 3.00,
		MoneyMultiplier = 2.90,
		Color1 = Color3.fromRGB(255, 40, 100),
		Color2 = Color3.fromRGB(35, 10, 55),
		Order = 7,
	},
	{
		Id = "CelestialTrail",
		Name = "Sentier Céleste Infini",
		Price = 750000000000, -- $750B
		SpeedMultiplier = 3.80,
		MoneyMultiplier = 3.50,
		Color1 = Color3.fromRGB(85, 255, 240),
		Color2 = Color3.fromRGB(255, 220, 95),
		Order = 8,
	},
}

-- Les 10 Zones avec fourchettes d'argent aléatoires croissantes !
GameConfig.StoneTiers = {
	{
		Id = "Zone1Stone",
		Name = "Pierre d'Épée de Bois",
		ZoneName = "Zone 1 : Prairie Paisible",
		ZoneOrder = 1,
		ZoneLength = 150,
		ForgeTime = 15,
		CarrySlowFactor = 0.78,
		MinBaseMoneyPerSec = 8,
		MaxBaseMoneyPerSec = 28,
		FloorColor = Color3.fromRGB(105, 195, 75),
		WallColor = Color3.fromRGB(165, 125, 80),
		StoneColor = Color3.fromRGB(145, 110, 75),
		CrystalColor = Color3.fromRGB(130, 235, 100),
		GuardianName = "Sentinelle des Bois",
		GuardianSpeedStat = 35,
		GuardianColor = Color3.fromRGB(140, 100, 65),
		GuardianArmorColor = Color3.fromRGB(90, 135, 65),
		GuardianScale = 1.25,
		DropTable = {
			WoodenDagger = 65,
			RustySword = 28,
			StoneBroadsword = 7,
		},
	},
	{
		Id = "Zone2Stone",
		Name = "Pierre d'Épée de Fer",
		ZoneName = "Zone 2 : Vallée Rocheuse",
		ZoneOrder = 2,
		ZoneLength = 190,
		ForgeTime = 45,
		CarrySlowFactor = 0.74,
		MinBaseMoneyPerSec = 55,
		MaxBaseMoneyPerSec = 190,
		FloorColor = Color3.fromRGB(140, 150, 160),
		WallColor = Color3.fromRGB(100, 105, 115),
		StoneColor = Color3.fromRGB(115, 120, 130),
		CrystalColor = Color3.fromRGB(130, 200, 255),
		GuardianName = "Chevalier d'Acier",
		GuardianSpeedStat = 180,
		GuardianColor = Color3.fromRGB(135, 145, 160),
		GuardianArmorColor = Color3.fromRGB(70, 80, 95),
		GuardianScale = 1.35,
		DropTable = {
			RustySword = 50,
			StoneBroadsword = 35,
			SquireBlade = 15,
		},
	},
	{
		Id = "Zone3Stone",
		Name = "Pierre d'Épée des Sables",
		ZoneName = "Zone 3 : Désert Doré",
		ZoneOrder = 3,
		ZoneLength = 240,
		ForgeTime = 120,
		CarrySlowFactor = 0.70,
		MinBaseMoneyPerSec = 380,
		MaxBaseMoneyPerSec = 1350,
		FloorColor = Color3.fromRGB(230, 195, 110),
		WallColor = Color3.fromRGB(190, 145, 70),
		StoneColor = Color3.fromRGB(185, 145, 80),
		CrystalColor = Color3.fromRGB(255, 215, 65),
		GuardianName = "Gardien Pharaon",
		GuardianSpeedStat = 950,
		GuardianColor = Color3.fromRGB(235, 185, 60),
		GuardianArmorColor = Color3.fromRGB(45, 115, 185),
		GuardianScale = 1.45,
		DropTable = {
			StoneBroadsword = 42,
			SquireBlade = 38,
			GoldenScimitar = 16,
			CobaltSaber = 4,
		},
	},
	{
		Id = "Zone4Stone",
		Name = "Pierre d'Épée Sylvestre",
		ZoneName = "Zone 4 : Jungle d'Émeraude",
		ZoneOrder = 4,
		ZoneLength = 300,
		ForgeTime = 270,
		CarrySlowFactor = 0.66,
		MinBaseMoneyPerSec = 2800,
		MaxBaseMoneyPerSec = 9800,
		FloorColor = Color3.fromRGB(50, 160, 85),
		WallColor = Color3.fromRGB(35, 110, 55),
		StoneColor = Color3.fromRGB(45, 105, 65),
		CrystalColor = Color3.fromRGB(65, 255, 140),
		GuardianName = "Colosse d'Émeraude",
		GuardianSpeedStat = 5000,
		GuardianColor = Color3.fromRGB(45, 185, 95),
		GuardianArmorColor = Color3.fromRGB(25, 85, 45),
		GuardianScale = 1.55,
		DropTable = {
			GoldenScimitar = 40,
			CobaltSaber = 36,
			EmeraldClaymore = 19,
			ForestRapier = 5,
		},
	},
	{
		Id = "Zone5Stone",
		Name = "Pierre d'Épée Polaire",
		ZoneName = "Zone 5 : Terres Gelées",
		ZoneOrder = 5,
		ZoneLength = 370,
		ForgeTime = 480,
		CarrySlowFactor = 0.62,
		MinBaseMoneyPerSec = 22000,
		MaxBaseMoneyPerSec = 78000,
		FloorColor = Color3.fromRGB(140, 215, 250),
		WallColor = Color3.fromRGB(85, 160, 210),
		StoneColor = Color3.fromRGB(85, 150, 195),
		CrystalColor = Color3.fromRGB(135, 245, 255),
		GuardianName = "Seigneur du Givre",
		GuardianSpeedStat = 28000,
		GuardianColor = Color3.fromRGB(95, 205, 255),
		GuardianArmorColor = Color3.fromRGB(40, 95, 160),
		GuardianScale = 1.65,
		DropTable = {
			EmeraldClaymore = 38,
			ForestRapier = 35,
			FrostbiteBlade = 21,
			GlacierCleaver = 6,
		},
	},
	{
		Id = "Zone6Stone",
		Name = "Pierre d'Épée Cristalline",
		ZoneName = "Zone 6 : Canyon d'Améthyste",
		ZoneOrder = 6,
		ZoneLength = 450,
		ForgeTime = 900,
		CarrySlowFactor = 0.58,
		MinBaseMoneyPerSec = 180000,
		MaxBaseMoneyPerSec = 650000,
		FloorColor = Color3.fromRGB(145, 70, 210),
		WallColor = Color3.fromRGB(90, 38, 140),
		StoneColor = Color3.fromRGB(80, 35, 120),
		CrystalColor = Color3.fromRGB(215, 95, 255),
		GuardianName = "Archonte de Cristal",
		GuardianSpeedStat = 160000,
		GuardianColor = Color3.fromRGB(175, 65, 245),
		GuardianArmorColor = Color3.fromRGB(75, 25, 115),
		GuardianScale = 1.75,
		DropTable = {
			FrostbiteBlade = 36,
			GlacierCleaver = 36,
			AmethystKatana = 21,
			CrystalReaver = 7,
		},
	},
	{
		Id = "Zone7Stone",
		Name = "Pierre d'Épée Volcanique",
		ZoneName = "Zone 7 : Terres de Lave",
		ZoneOrder = 7,
		ZoneLength = 550,
		ForgeTime = 1500,
		CarrySlowFactor = 0.55,
		MinBaseMoneyPerSec = 1500000,
		MaxBaseMoneyPerSec = 5500000,
		FloorColor = Color3.fromRGB(190, 58, 32),
		WallColor = Color3.fromRGB(90, 28, 22),
		StoneColor = Color3.fromRGB(75, 25, 20),
		CrystalColor = Color3.fromRGB(255, 115, 30),
		GuardianName = "Titan Volcanique",
		GuardianSpeedStat = 950000,
		GuardianColor = Color3.fromRGB(245, 80, 25),
		GuardianArmorColor = Color3.fromRGB(50, 20, 20),
		GuardianScale = 1.88,
		DropTable = {
			AmethystKatana = 35,
			CrystalReaver = 36,
			MagmaReaper = 21,
			SolarExcalibur = 8,
		},
	},
	{
		Id = "Zone8Stone",
		Name = "Pierre d'Épée de l'Ombre",
		ZoneName = "Zone 8 : Royaume des Ténèbres",
		ZoneOrder = 8,
		ZoneLength = 670,
		ForgeTime = 2400,
		CarrySlowFactor = 0.52,
		MinBaseMoneyPerSec = 14000000,
		MaxBaseMoneyPerSec = 52000000,
		FloorColor = Color3.fromRGB(45, 35, 65),
		WallColor = Color3.fromRGB(25, 20, 40),
		StoneColor = Color3.fromRGB(30, 22, 48),
		CrystalColor = Color3.fromRGB(255, 45, 105),
		GuardianName = "Exécuteur du Néant",
		GuardianSpeedStat = 6000000,
		GuardianColor = Color3.fromRGB(210, 30, 85),
		GuardianArmorColor = Color3.fromRGB(20, 15, 30),
		GuardianScale = 2.0,
		DropTable = {
			MagmaReaper = 34,
			SolarExcalibur = 37,
			ShadowScythe = 21,
			Voidbreaker = 8,
		},
	},
	{
		Id = "Zone9Stone",
		Name = "Pierre d'Épée Cosmique",
		ZoneName = "Zone 9 : Nébuleuse Stellaire",
		ZoneOrder = 9,
		ZoneLength = 810,
		ForgeTime = 3600,
		CarrySlowFactor = 0.48,
		MinBaseMoneyPerSec = 130000000,
		MaxBaseMoneyPerSec = 480000000,
		FloorColor = Color3.fromRGB(38, 58, 140),
		WallColor = Color3.fromRGB(20, 30, 85),
		StoneColor = Color3.fromRGB(30, 45, 110),
		CrystalColor = Color3.fromRGB(110, 175, 255),
		GuardianName = "Conquérant Astral",
		GuardianSpeedStat = 45000000,
		GuardianColor = Color3.fromRGB(90, 145, 255),
		GuardianArmorColor = Color3.fromRGB(25, 35, 95),
		GuardianScale = 2.15,
		DropTable = {
			ShadowScythe = 34,
			Voidbreaker = 37,
			NebulaStarblade = 21,
			GalaxySlayer = 8,
		},
	},
	{
		Id = "Zone10Stone",
		Name = "Pierre d'Épée Divine",
		ZoneName = "Zone 10 : Sanctuaire de l'Infini",
		ZoneOrder = 10,
		ZoneLength = 980,
		ForgeTime = 5400,
		CarrySlowFactor = 0.45,
		MinBaseMoneyPerSec = 1500000000,
		MaxBaseMoneyPerSec = 6500000000,
		FloorColor = Color3.fromRGB(240, 220, 125),
		WallColor = Color3.fromRGB(210, 170, 60),
		StoneColor = Color3.fromRGB(240, 230, 195),
		CrystalColor = Color3.fromRGB(80, 255, 240),
		GuardianName = "Empereur Céleste",
		GuardianSpeedStat = 400000000,
		GuardianColor = Color3.fromRGB(255, 215, 60),
		GuardianArmorColor = Color3.fromRGB(245, 248, 255),
		GuardianScale = 2.35,
		DropTable = {
			Voidbreaker = 24,
			NebulaStarblade = 34,
			GalaxySlayer = 24,
			CelestialArchblade = 13,
			OmegaGodsword = 5,
		},
	},
}

function GameConfig.GetTreadmillGainPerTick(treadmillLevel: number): number
	return math.floor(2 * (1.85 ^ (treadmillLevel - 1)))
end

GameConfig.Upgrades = {
	SpeedLevel = {
		Name = "Niveau du Tapis de Course",
		Description = "Multiplie par x1.85 la Vitesse gagnée sur ton Tapis",
		BaseCost = 30,
		CostMultiplier = 2.1,
		MaxLevel = 50,
	},
	CarryStrength = {
		Name = "Force de Portage",
		Description = "Réduit le ralentissement quand tu portes une Pierre",
		BaseCost = 150,
		CostMultiplier = 2.0,
		MaxLevel = 15,
	},
	ForgeSpeed = {
		Name = "Éclosion Rapide",
		Description = "Les Pierres d'Épée éclosent +25% plus vite par niveau",
		BaseCost = 300,
		CostMultiplier = 2.2,
		MaxLevel = 20,
	},
	SlotCount = {
		Name = "Emplacement de Base (+1)",
		Description = "Ajoute un emplacement dans ta base (Max 8)",
		BaseCost = 800,
		CostMultiplier = 4.5,
		MaxLevel = 8,
	},
}

function GameConfig.GetUpgradeCost(upgradeId: string, currentLevel: number): number
	local upg = GameConfig.Upgrades[upgradeId]
	if not upg then
		return 999999
	end
	return math.floor(upg.BaseCost * (upg.CostMultiplier ^ (currentLevel - 1)))
end

function GameConfig.StatSpeedToWalkSpeed(statSpeed: number): number
	if statSpeed <= 18 then
		return 16
	end
	local logVal = math.log10(statSpeed / 18 + 1)
	return math.clamp(16 + logVal * 16, 16, 155)
end

-- Tire une épée aléatoire ET génère un revenu d'argent $/s aléatoire en fonction de la zone et de la rareté !
function GameConfig.RollRandomSwordFromStone(stoneId: string, uidCounter: number): OwnedSwordItem
	for _, tier in ipairs(GameConfig.StoneTiers) do
		if tier.Id == stoneId then
			local totalWeight = 0
			for _, weight in pairs(tier.DropTable) do
				totalWeight += weight
			end
			local roll = math.random() * totalWeight
			local cumulative = 0
			local chosenSwordId = "WoodenDagger"
			for swordId, weight in pairs(tier.DropTable) do
				cumulative += weight
				if roll <= cumulative then
					chosenSwordId = swordId
					break
				end
			end

			local template = GameConfig.Swords[chosenSwordId] or GameConfig.Swords.WoodenDagger
			local rarityInfo = GameConfig.Rarities[template.Rarity] or GameConfig.Rarities.Common

			-- Jet aléatoire entre MinBaseMoneyPerSec et MaxBaseMoneyPerSec * multiplicateur de rareté
			local randomFactor = tier.MinBaseMoneyPerSec + math.random() * (tier.MaxBaseMoneyPerSec - tier.MinBaseMoneyPerSec)
			local finalMoneyPerSec = math.max(5, math.floor(randomFactor * rarityInfo.StatMultiplier))
			local sellPrice = math.floor(finalMoneyPerSec * 18) -- Valeur de revente chez le Marchand d'Épées

			return {
				Uid = string.format("sword_%d_%d", uidCounter, math.random(1000, 9999)),
				SwordId = chosenSwordId,
				Name = template.Name,
				Rarity = template.Rarity,
				ZoneOrder = tier.ZoneOrder,
				MoneyPerSec = finalMoneyPerSec,
				SellPrice = sellPrice,
			}
		end
	end

	return {
		Uid = "sword_default_" .. tostring(uidCounter),
		SwordId = "WoodenDagger",
		Name = "Dague d'Entraînement",
		Rarity = "Common",
		ZoneOrder = 1,
		MoneyPerSec = 10,
		SellPrice = 180,
	}
end

return GameConfig
