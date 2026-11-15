-- Aplica el estilo militar de Aurora a una sala: superficies, zócalos, bandas, cornisas, columnas y marcos de compuerta.
-- Nada se coloca si choca con cualquier pieza existente (incluidas las no consultables).
local Estilo = {}

local GUN = Color3.fromRGB(100, 108, 119)
local DARK = Color3.fromRGB(46, 50, 58)
local BLUE = Color3.fromRGB(80, 190, 255)
local AMBER = Color3.fromRGB(255, 168, 50)
local UP = Vector3.new(0, 1, 0)
local WALLS = { Mamparo = true, ["Mamparo de casco"] = true }
local IGNORE = { Cubierta = true, Techo = true, ["Protección inferior"] = true, Dintel = true, ["Guía de tránsito"] = true,
	Luminaria = true, ["Luminaria orbital"] = true, ["Relleno de iluminación"] = true }
local WINDOW = { ["Marco superior"] = true, ["Marco inferior"] = true, ["Nervadura del ventanal"] = true, ["Extremo del ventanal"] = true }

local function aabb(p)
	local cf, s = p.CFrame, p.Size
	local ext = Vector3.new(
		math.abs(cf.RightVector.X) * s.X / 2 + math.abs(cf.UpVector.X) * s.Y / 2 + math.abs(cf.LookVector.X) * s.Z / 2,
		math.abs(cf.RightVector.Y) * s.X / 2 + math.abs(cf.UpVector.Y) * s.Y / 2 + math.abs(cf.LookVector.Y) * s.Z / 2,
		math.abs(cf.RightVector.Z) * s.X / 2 + math.abs(cf.UpVector.Z) * s.Y / 2 + math.abs(cf.LookVector.Z) * s.Z / 2)
	return cf.Position - ext, cf.Position + ext, ext
end

local function restyleSurfaces(room)
	for _, c in room:GetDescendants() do
		if c:IsA("BasePart") and not c:FindFirstAncestor("Misiones") and not c:FindFirstAncestor("Decoracion") then
			local parentModel = c:FindFirstAncestorOfClass("Model")
			local inEquip = parentModel and parentModel ~= room and (parentModel.Name == "Panel de servicio" or parentModel.Name == "Casillero de equipo")
			if WALLS[c.Name] and c.Parent == room then c.Material = Enum.Material.Metal; c.MaterialVariant = "AuroraPanelMilitar"; c.Color = Color3.fromRGB(112, 120, 131)
			elseif c.Name == "Dintel" then c.Material = Enum.Material.Metal; c.MaterialVariant = "AuroraPanelMilitar"; c.Color = DARK
			elseif c.Name == "Cubierta" and c.Parent == room then c.Material = Enum.Material.DiamondPlate; c.MaterialVariant = "AuroraSueloMilitar"; c.Color = Color3.fromRGB(88, 94, 103)
			elseif c.Name == "Techo" and c.Parent == room then c.Material = Enum.Material.Metal; c.MaterialVariant = "AuroraPanelMilitar"; c.Color = Color3.fromRGB(70, 76, 85)
			elseif c.Name == "Protección inferior" then c.Material = Enum.Material.Metal; c.MaterialVariant = ""; c.Color = DARK
			elseif c.Name == "Guía de tránsito" then c.Color = BLUE
			elseif c.Name == "Luminaria" or c.Name == "Luminaria orbital" then
				if c.Position.Y < 1 then c.Color = BLUE else c.Color = Color3.fromRGB(215, 232, 255) end
				for _, l in c:GetChildren() do if l:IsA("PointLight") then l.Color = Color3.fromRGB(200, 225, 255); l.Brightness = math.max(l.Brightness, 1.4); l.Range = math.max(l.Range, 28) end end
			elseif WINDOW[c.Name] then c.Material = Enum.Material.Metal; c.MaterialVariant = "AuroraPanelMilitar"; c.Color = DARK
			elseif c:FindFirstAncestor("Panel panorámico") and c.Transparency < 0.5 then c.Material = Enum.Material.Metal; c.MaterialVariant = "AuroraPanelMilitar"; c.Color = DARK
			elseif inEquip and c.Name ~= "Colision" and c.Transparency < 0.9 then
				if c.Material == Enum.Material.Neon then c.Color = BLUE
				else
					local s = c.Size
					local big = s.X * s.Y * s.Z > 3 or math.max(s.X, s.Y, s.Z) > 4
					c.Material = Enum.Material.Metal; c.MaterialVariant = big and "AuroraPanelMilitar" or ""
					c.Color = big and Color3.fromRGB(74, 80, 90) or Color3.fromRGB(36, 40, 46)
				end
			end
		end
	end
end

function Estilo.apply(room, station)
	local cub, techo = room:FindFirstChild("Cubierta"), room:FindFirstChild("Techo")
	if not cub or not techo then return "sin Cubierta/Techo" end
	restyleSurfaces(room)
	local old = room:FindFirstChild("Decoracion") if old then old:Destroy() end
	local D = Instance.new("Folder"); D.Name = "Decoracion"; D.Parent = room

	local floorY = cub.Position.Y + cub.Size.Y / 2
	local ceilY = techo.Position.Y - techo.Size.Y / 2
	local fLo, fHi = aabb(cub)
	local center = cub.Position

	-- obstáculos alrededor de la sala (todas las piezas, también las no consultables)
	local bLo, bHi = fLo - Vector3.new(10, 2, 10), fHi + Vector3.new(10, ceilY + 4, 10)
	local obstacles = {}
	for _, p in station:GetDescendants() do
		if p:IsA("BasePart") and not IGNORE[p.Name] and (p.Transparency < 0.95 or p.Name == "Colision") and not p:IsDescendantOf(D) then
			local lo, hi = aabb(p)
			if hi.X > bLo.X and lo.X < bHi.X and hi.Z > bLo.Z and lo.Z < bHi.Z and hi.Y > bLo.Y and lo.Y < bHi.Y then
				table.insert(obstacles, { lo = lo, hi = hi, part = p })
			end
		end
	end
	local function blocked(c, size, skip)
		local h = size / 2
		local lo, hi = c - h, c + h
		for _, o in obstacles do
			if o.part ~= skip and hi.X > o.lo.X + 0.02 and lo.X < o.hi.X - 0.02 and hi.Y > o.lo.Y + 0.02 and lo.Y < o.hi.Y - 0.02 and hi.Z > o.lo.Z + 0.02 and lo.Z < o.hi.Z - 0.02 then
				return true
			end
		end
		return false
	end
	local function mk(class, name, size, cf, color, mat, variant, collide)
		local p = Instance.new(class)
		p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
		p.Material = mat or Enum.Material.Metal
		if variant then p.MaterialVariant = variant end
		p.Anchored = true; p.CanCollide = collide == true; p.CanTouch = false; p.CanQuery = false
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = D
		return p
	end

	-- tramos de pared derivados de las piezas de pared de la sala
	local segs = {}
	for _, w in room:GetChildren() do
		if w:IsA("BasePart") and WALLS[w.Name] then
			local lo, hi, ext = aabb(w)
			local thickX = ext.X < ext.Z
			local sign
			if thickX then sign = (center.X > w.Position.X) and 1 or -1 else sign = (center.Z > w.Position.Z) and 1 or -1 end
			local n = thickX and Vector3.new(sign, 0, 0) or Vector3.new(0, 0, sign)
			local dir = thickX and Vector3.new(0, 0, 1) or Vector3.new(1, 0, 0)
			local a0 = thickX and math.max(lo.Z, fLo.Z) or math.max(lo.X, fLo.X)
			local a1 = thickX and math.min(hi.Z, fHi.Z) or math.min(hi.X, fHi.X)
			local inner = thickX and (w.Position.X + sign * ext.X) or (w.Position.Z + sign * ext.Z)
			if a1 - a0 > 1.5 then
				local o = thickX and Vector3.new(inner, floorY, a0) or Vector3.new(a0, floorY, inner)
				table.insert(segs, { o = o, dir = dir, n = n, len = a1 - a0, wall = w })
			end
		end
	end
	local function boxSize(seg, along, height, depth)
		local a, n = seg.dir, seg.n
		return Vector3.new(math.abs(a.X) * along + math.abs(n.X) * depth, height, math.abs(a.Z) * along + math.abs(n.Z) * depth)
	end
	local function freeRuns(seg, yc, h, depth)
		local runs, start = {}, nil
		local step, t = 0.25, 0
		while t <= seg.len + 1e-6 do
			local c = seg.o + seg.dir * (t + step / 2) + UP * (yc - floorY) + seg.n * (depth / 2 + 0.05)
			local free = (t + step <= seg.len + 1e-6) and not blocked(c, boxSize(seg, step, h, depth), seg.wall)
			if free and not start then start = t end
			if not free and start then
				if t - start >= 1.5 then table.insert(runs, { start + 0.1, t - 0.1 }) end
				start = nil
			end
			t += step
		end
		if start and seg.len - start >= 1.5 then table.insert(runs, { start + 0.1, seg.len - 0.1 }) end
		return runs
	end
	local function wallCF(seg, t, y, out)
		local p = seg.o + seg.dir * t + UP * (y - floorY) + seg.n * out
		return CFrame.lookAt(p, p + seg.n)
	end

	local st = { base = 0, band = 0, cove = 0, col = 0, door = 0 }
	local coveY = ceilY - 1.2
	local colBottom, colTop = floorY + 1.4, ceilY - 2.4
	local colH, colY = colTop - colBottom - 0.1, (colTop + colBottom) / 2
	for _, s in segs do
		for _, r in freeRuns(s, floorY + 0.75, 1.4, 1.3) do
			local L, mid = r[2] - r[1], (r[1] + r[2]) / 2
			mk("WedgePart", "ZocaloAngular", Vector3.new(L, 1.4, 1.3), wallCF(s, mid, floorY + 0.7, 0.65), DARK, Enum.Material.Metal, "AuroraPanelMilitar", true)
			mk("Part", "ZocaloLuz", Vector3.new(math.max(L - 0.4, 0.5), 0.1, 0.1), wallCF(s, mid, floorY + 0.06, 1.33), BLUE, Enum.Material.Neon)
			st.base += 1
		end
		for _, r in freeRuns(s, floorY + 5, 0.9, 0.3) do
			local L, mid = r[2] - r[1], (r[1] + r[2]) / 2
			mk("Part", "BandaMedia", Vector3.new(L, 0.9, 0.25), wallCF(s, mid, floorY + 5, 0.13), DARK, Enum.Material.Metal, nil, true)
			st.band += 1
		end
		for _, r in freeRuns(s, coveY, 2.4, 1.7) do
			local L, mid = r[2] - r[1], (r[1] + r[2]) / 2
			mk("WedgePart", "CornisaAngular", Vector3.new(L, 2.4, 1.7), wallCF(s, mid, coveY, 0.85) * CFrame.Angles(0, 0, math.pi), DARK, Enum.Material.Metal, "AuroraPanelMilitar")
			local strip = mk("Part", "CornisaLuz", Vector3.new(math.max(L - 0.3, 0.5), 0.14, 0.2), wallCF(s, mid, ceilY - 2.45, 1.6), BLUE, Enum.Material.Neon)
			local pl = Instance.new("PointLight"); pl.Color = BLUE; pl.Range = 14; pl.Brightness = 0.9; pl.Parent = strip
			st.cove += 1
		end
		local spots = { 0.9, s.len / 2, s.len - 0.9 }
		if s.len > 22 then table.insert(spots, s.len / 4); table.insert(spots, s.len * 3 / 4) end
		for _, t in spots do
			local c = s.o + s.dir * t + UP * (colY - floorY) + s.n * 0.5
			if not blocked(c, boxSize(s, 1.4, colH, 1.0), s.wall) then
				mk("Part", "Columna", Vector3.new(1.1, colH, 0.85), wallCF(s, t, colY, 0.45), GUN, Enum.Material.Metal, "AuroraPanelMilitar", true)
				mk("Part", "ColumnaLuz", Vector3.new(0.18, math.min(5.5, colH - 2), 0.06), wallCF(s, t, colY, 0.9), BLUE, Enum.Material.Neon)
				st.col += 1
			end
		end
	end

	-- marcos de compuerta (pasillos de Conexiones y escotillas)
	local frames = {}
	for _, f in station:GetDescendants() do
		if f:IsA("BasePart") and f.Name == "Frame" then table.insert(frames, f) end
	end
	for _, f in frames do
		local look = f.CFrame.LookVector
		local axisX = math.abs(look.X) > math.abs(look.Z)
		local lat = axisX and f.Position.Z or f.Position.X
		local latLo, latHi = axisX and fLo.Z or fLo.X, axisX and fHi.Z or fHi.X
		if lat > latLo + 4 and lat < latHi - 4 then
			-- pared paralela más cercana de esta sala
			local best, bestD
			for _, s in segs do
				local sThickX = s.n.X ~= 0
				if sThickX == axisX then
					local plane = axisX and s.o.X or s.o.Z
					local fp = axisX and f.Position.X or f.Position.Z
					local d = math.abs(plane - fp)
					if d < 14 and (not bestD or d < bestD) then best, bestD = s, d end
				end
			end
			if best then
				local n = best.n
				local dir = best.dir
				local cpos = axisX and Vector3.new(best.o.X, floorY, f.Position.Z) or Vector3.new(f.Position.X, floorY, best.o.Z)
				local function cfAt(a, y, out) local p = cpos + dir * a + UP * (y - floorY) + n * out return CFrame.lookAt(p, p + n) end
				local seg = { dir = dir, n = n }
				for _, side in { -1, 1 } do
					local c = cpos + dir * (side * 5.25) + UP * 4.7 + n * 0.55
					if not blocked(c, boxSize(seg, 1.3, 9.4, 1.0)) then
						mk("Part", "PilarCompuerta", Vector3.new(1.3, 9.4, 1.0), cfAt(side * 5.25, floorY + 4.7, 0.55), GUN, Enum.Material.Metal, "AuroraPanelMilitar", true)
						mk("Part", "PilarFranja", Vector3.new(0.25, 6, 0.06), cfAt(side * 5.25, floorY + 4.5, 1.07), AMBER, Enum.Material.Neon)
						st.door += 1
					end
				end
				if f.Parent and f.Parent.Name == "Compuerta" then
					local th = mk("Part", "UmbralAdvertencia", Vector3.new(9, 0.04, 1.4), cfAt(0, floorY + 0.02, 0.75), AMBER, Enum.Material.SmoothPlastic)
					local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Top; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 40; sg.LightInfluence = 0.5; sg.Parent = th
					local box = Instance.new("Frame"); box.Size = UDim2.fromScale(1, 1); box.BackgroundColor3 = AMBER; box.BorderSizePixel = 0; box.ClipsDescendants = true; box.Parent = sg
					for i = -2, 16 do
						local stripe = Instance.new("Frame"); stripe.AnchorPoint = Vector2.new(0.5, 0.5); stripe.Size = UDim2.new(0, 14, 3, 0)
						stripe.Position = UDim2.new(0, i * 28, 0.5, 0); stripe.Rotation = 35; stripe.BackgroundColor3 = Color3.fromRGB(25, 25, 28); stripe.BorderSizePixel = 0; stripe.Parent = box
					end
				end
			end
		end
	end
	return ("%s: tramos=%d zócalos=%d bandas=%d cornisas=%d columnas=%d pilares=%d obstáculos=%d"):format(room.Name, #segs, st.base, st.band, st.cove, st.col, st.door, #obstacles)
end

return Estilo
