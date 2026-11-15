-- Genera cohetes y naves de carga con piezas básicas (sin assets externos). Se usan en el muelle y como hologramas.
local Rocket = {}

Rocket.SPECS = {
	light = { h = 16, r = 2.0, accent = Color3.fromRGB(255, 140, 60), boosters = 0 },
	medium = { h = 24, r = 2.8, accent = Color3.fromRGB(170, 110, 255), boosters = 0 },
	heavy = { h = 30, r = 3.4, accent = Color3.fromRGB(255, 80, 90), boosters = 2 },
}

local WHITE = Color3.fromRGB(232, 238, 244)
local DARK = Color3.fromRGB(40, 44, 52)

local function part(model, props)
	local p = Instance.new(props.class or "Part")
	props.class = nil
	p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = model
	return p
end

-- cilindro vertical centrado en (x, y, z) relativo a la base
local function cyl(model, base, x, y, z, len, radius, color, mat)
	return part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, radius * 2, radius * 2),
		CFrame = base * CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Material = mat or Enum.Material.Metal })
end

local function stack(model, base, x, z, r, h, s, accent, engineName)
	local y = 0
	local engine = cyl(model, base, x, 0.6 * s, z, 1.2 * s, r * 0.7, DARK, Enum.Material.DiamondPlate)
	engine.Name = engineName or "Motor"
	local a = Instance.new("Attachment"); a.Name = "Escape"; a.Position = Vector3.new(-0.6 * s, 0, 0); a.Parent = engine
	y = 1.2 * s
	cyl(model, base, x, y + h / 2, z, h, r, WHITE).Name = "Cuerpo"
	for _, f in { 0.08, 0.55, 0.92 } do cyl(model, base, x, y + h * f, z, 0.5 * s, r * 1.04, accent, Enum.Material.SmoothPlastic).Name = "Banda" end
	y += h
	local tiers = { { 0.8, 0.12 }, { 0.55, 0.1 }, { 0.3, 0.08 } }
	for _, t in tiers do
		local th = h * t[2]
		cyl(model, base, x, y + th / 2, z, th, r * t[1], WHITE).Name = "Cofia"
		y += th
	end
	part(model, { Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.6, r * 0.6, r * 0.6), CFrame = base * CFrame.new(x, y, z), Color = accent, Material = Enum.Material.SmoothPlastic }).Name = "Punta"
	return y
end

function Rocket.build(kind, baseCF, scale, hologram)
	local spec = Rocket.SPECS[kind] or Rocket.SPECS.light
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "Cohete_" .. kind
	local r, h = spec.r * s, spec.h * s
	local top = stack(model, baseCF, 0, 0, r, h, s, spec.accent, "Motor")
	-- aletas
	for i = 0, 3 do
		local ang = i * math.pi / 2
		local fin = part(model, { class = "WedgePart", Size = Vector3.new(0.3 * s, 4 * s, 3 * s), Color = spec.accent, Material = Enum.Material.SmoothPlastic })
		fin.CFrame = baseCF * CFrame.Angles(0, ang, 0) * CFrame.new(0, 3.2 * s, -(r + 1.4 * s)) * CFrame.Angles(0, 0, 0)
		fin.Name = "Aleta"
	end
	for b = 1, spec.boosters do
		local side = b == 1 and 1 or -1
		stack(model, baseCF, side * (r + r * 0.55 + 0.2 * s), 0, r * 0.55, h * 0.55, s, spec.accent, "MotorLateral")
	end
	if hologram then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Material = Enum.Material.ForceField
				p.Color = Color3.fromRGB(90, 220, 255)
				p.CastShadow = false
			end
		end
	end
	model.WorldPivot = baseCF
	model:SetAttribute("Height", top)
	return model
end

---------------------------------------------------------------- naves de carga (Día 2)
-- La nave se construye "hacia atrás" desde su puerto de acople: frontCF apunta hacia la estación
-- (LookVector) y el cuerpo se extiende detrás. Sin assets externos.
Rocket.SHIPS = {
	light = { L = 10, r = 2.0, panels = 2, span = 6 },
	medium = { L = 14, r = 2.6, panels = 2, span = 9 },
	heavy = { L = 18, r = 3.2, panels = 4, span = 10 },
}
local GREY = Color3.fromRGB(150, 156, 166)
local PANEL = Color3.fromRGB(28, 52, 110)

-- cilindro alineado con el eje de la nave, centrado a "z" studs detrás del frente
local function axial(model, frontCF, z, len, radius, color, mat, name)
	local p = part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, radius * 2, radius * 2),
		CFrame = frontCF * CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi / 2, 0), Color = color, Material = mat or Enum.Material.Metal })
	p.Name = name or "Casco"
	return p
end

function Rocket.buildShip(kind, frontCF, scale, hologram)
	local spec = Rocket.SHIPS[kind] or Rocket.SHIPS.light
	local accent = (Rocket.SPECS[kind] or Rocket.SPECS.light).accent
	local s = scale or 1
	local L, r = spec.L * s, spec.r * s
	local model = Instance.new("Model")
	model.Name = "Nave_" .. kind
	-- adaptador de acople y anillo
	axial(model, frontCF, 0.4 * s, 0.8 * s, r * 0.62, DARK, Enum.Material.DiamondPlate, "Adaptador")
	axial(model, frontCF, 0.08 * s, 0.16 * s, r * 0.66, accent, Enum.Material.Neon, "AnilloAcople")
	axial(model, frontCF, 1.3 * s, 1.0 * s, r * 0.85, WHITE, nil, "Transicion")
	-- módulo presurizado (bodega)
	local zP = 1.8 * s
	local lenP = L * 0.58
	axial(model, frontCF, zP + lenP / 2, lenP, r, WHITE, Enum.Material.SmoothPlastic, "Bodega")
	for _, f in { 0.1, 0.5, 0.9 } do
		axial(model, frontCF, zP + lenP * f, 0.45 * s, r * 1.03, accent, Enum.Material.SmoothPlastic, "Banda")
	end
	-- agarre para el brazo robótico
	part(model, { Size = Vector3.new(1.0 * s, 0.6 * s, 1.0 * s), CFrame = frontCF * CFrame.new(0, r + 0.25 * s, zP + lenP * 0.3),
		Color = DARK, Material = Enum.Material.DiamondPlate }).Name = "Agarre"
	-- módulo de servicio
	local zS = zP + lenP
	local lenS = L * 0.3
	axial(model, frontCF, zS + lenS / 2, lenS, r * 0.92, GREY, Enum.Material.Metal, "Servicio")
	-- motor principal (tobera que se ensancha hacia atrás)
	local zE = zS + lenS
	axial(model, frontCF, zE + 0.3 * s, 0.6 * s, r * 0.32, DARK, Enum.Material.Metal, "Garganta")
	local bell = axial(model, frontCF, zE + 1.0 * s, 0.9 * s, r * 0.5, DARK, Enum.Material.Metal, "Motor")
	local a = Instance.new("Attachment"); a.Name = "Escape"; a.Parent = bell
	a.WorldCFrame = CFrame.fromMatrix((frontCF * CFrame.new(0, 0, zE + 1.5 * s)).Position, frontCF.RightVector, frontCF.LookVector * -1)
	-- propulsores de maniobra (RCS) cerca del frente: empujan la nave hacia atrás al desacoplar
	for i = 0, 3 do
		local ang = i * math.pi / 2 + math.pi / 4
		local off = CFrame.Angles(0, 0, ang) * CFrame.new(0, r * 0.98, 0)
		local q = part(model, { Size = Vector3.new(0.5 * s, 0.4 * s, 0.7 * s), CFrame = frontCF * off * CFrame.new(0, 0, zP + 0.6 * s),
			Color = DARK, Material = Enum.Material.Metal })
		q.Name = "RCS"
		local ra = Instance.new("Attachment"); ra.Name = "RCS"; ra.Parent = q
		ra.WorldCFrame = CFrame.fromMatrix((frontCF * off * CFrame.new(0, 0, zP + 0.2 * s)).Position, frontCF.RightVector, frontCF.LookVector)
	end
	-- paneles solares
	local zPanel = zS + lenS * 0.5
	local dirs = { 0, math.pi }
	if spec.panels == 4 then dirs = { math.pi / 6, math.pi - math.pi / 6, math.pi + math.pi / 6, -math.pi / 6 } end
	local span = spec.span * s
	for _, ang in dirs do
		local rot = frontCF * CFrame.new(0, 0, zPanel) * CFrame.Angles(0, 0, ang)
		part(model, { Size = Vector3.new(1.2 * s + r, 0.25 * s, 0.25 * s), CFrame = rot * CFrame.new(r * 0.5 + 0.6 * s, 0, 0), Color = GREY, Material = Enum.Material.Metal }).Name = "Mastil"
		local pnl = part(model, { Size = Vector3.new(span, 0.12 * s, 2.6 * s), CFrame = rot * CFrame.new(r + 1.2 * s + span / 2, 0, 0),
			Color = PANEL, Material = Enum.Material.Glass, Reflectance = 0.15 })
		pnl.Name = "PanelSolar"
		part(model, { Size = Vector3.new(span, 0.14 * s, 0.12 * s), CFrame = rot * CFrame.new(r + 1.2 * s + span / 2, 0, 0), Color = accent, Material = Enum.Material.SmoothPlastic }).Name = "PanelBorde"
	end
	if hologram then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Material = Enum.Material.ForceField
				p.Color = Color3.fromRGB(90, 220, 255)
				p.Reflectance = 0
				p.CastShadow = false
			end
		end
	end
	model.WorldPivot = frontCF
	model:SetAttribute("Length", zE + 1.5 * s)
	return model
end

return Rocket
