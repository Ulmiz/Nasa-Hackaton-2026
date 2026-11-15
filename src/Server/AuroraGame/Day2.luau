-- Día 2: carga de suministros por la escotilla del muelle, nave de carga, revisión RYG y liberación hacia la base lunar.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Rocket = require(game:GetService("ReplicatedStorage"):WaitForChild("Aurora"):WaitForChild("AuroraRocket"))

return function(ctx)
	local Config = ctx.Config
	local M = { day = 2, actions = {} }
	local CM = ctx.X:WaitForChild("CargoBay"):WaitForChild("Misiones")
	local DM = ctx.X:WaitForChild("DockingBay"):WaitForChild("Misiones")
	local DB = DM.Parent
	local function textOf(inst) return inst:FindFirstChild("Texto", true) end

	local scaleText = textOf(CM:WaitForChild("BasculaDisplay"))
	local cart = CM:WaitForChild("Carrito")
	local board = DM:WaitForChild("TableroRYG")
	local boardText = textOf(board)
	local lever = DM:WaitForChild("PalancaOrbita")
	local leverText = textOf(lever:WaitForChild("Letrero"))
	local leverPivot = lever:WaitForChild("Base").Position + Vector3.new(0, 1.5, 0)
	local console = DM:WaitForChild("ConsolaLanzamiento")
	local cover = console:WaitForChild("Tapa")
	local coverClosed = cover.CFrame
	local consoleText = textOf(console:WaitForChild("Letrero"))
	local pedestals = {}
	for _, k in { "light", "medium", "heavy" } do pedestals[k] = DM:WaitForChild("Pedestal_" .. k) end
	local KIND_COLOR = { light = Rocket.SPECS.light.accent, medium = Rocket.SPECS.medium.accent, heavy = Rocket.SPECS.heavy.accent }

	-- la escotilla exterior es el puerto de atraque de la nave de carga
	local hatch = DB:WaitForChild("Escotilla exterior sellada")
	local hatchCol = hatch:WaitForChild("Colision")
	local doors = { hatch:WaitForChild("Door Left"), hatch:WaitForChild("Door Right") }
	local doorClosed = {}
	for i, dr in doors do doorClosed[i] = dr.CFrame end
	local hatchNeon = {}
	for _, p in hatch:GetDescendants() do if p:IsA("BasePart") and p.Material == Enum.Material.Neon then table.insert(hatchNeon, p) end end
	local hatchSign
	local idn = DB:FindFirstChild("Identificación de la escotilla")
	if idn then for _, t in idn:GetDescendants() do if t:IsA("TextLabel") and t.Text:find("PUERTO") then hatchSign = t end end end
	local port = DM:WaitForChild("PuertoAtraque")
	local dockCF = port:WaitForChild("PuntoAcople").CFrame
	local zone = port:WaitForChild("ZonaCarga")
	local holdText = textOf(DM:WaitForChild("PantallaEscotilla"))

	local function st() return ctx.S() end
	local function d2() return ctx.S().d2 end
	local function rocketSpec(id)
		for _, r in Config.Rockets do if r.id == id then return r end end
		return nil
	end
	local ORBIT_NAME = { low = "eficiente", high = "rápida" }

	---------------------------------------------------------------- cálculo
	local function totals()
		local d = d2()
		local mass, cost = 0, 0
		for _, t in Config.CRATE_ORDER do
			mass += d.loaded[t] * Config.CRATE_KG
			cost += d.loaded[t] * Config.Crates[t].cost
		end
		if d.cart then cost += Config.CART_COST end
		local r = rocketSpec(d.rocket)
		if r then cost += r.cost end
		local cap = r and Config.capacity(r.id, d.orbit) or 0
		return mass, cost, cap, r
	end

	---------------------------------------------------------------- visuales
	local function makeCrate(t)
		local c = Instance.new("Part")
		c.Name = "Caja_" .. t; c.Size = Vector3.new(1.8, 1.8, 1.8)
		c.Color = Config.Crates[t].color; c.Material = Enum.Material.SmoothPlastic
		c.Anchored = true; c.CanCollide = false; c.CanTouch = false; c.CanQuery = false
		c.TopSurface = Enum.SurfaceType.Smooth; c.BottomSurface = Enum.SurfaceType.Smooth
		local band = Instance.new("SelectionBox"); band.Adornee = c; band.LineThickness = 0.04
		band.Color3 = Color3.fromRGB(20, 30, 40); band.Parent = c
		return c
	end

	local function buildCartAt(baseCF, parent)
		local parts = {}
		local function add(name, size, cf, color, mat, shape)
			local p = Instance.new("Part")
			p.Name = name; p.Size = size; p.CFrame = baseCF * cf; p.Color = color
			p.Material = mat or Enum.Material.Metal
			if shape then p.Shape = shape end
			p.Anchored = false; p.Massless = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
			p.Parent = parent
			table.insert(parts, p)
		end
		add("CarritoCuerpo", Vector3.new(4, 1.2, 2.6), CFrame.new(0, 1.3, 0), Color3.fromRGB(240, 190, 60))
		add("CarritoAsa", Vector3.new(0.3, 2.2, 2.6), CFrame.new(-2.1, 2.4, 0), Color3.fromRGB(60, 70, 80))
		for _, w in { { -1.4, -1.1 }, { -1.4, 1.1 }, { 1.4, -1.1 }, { 1.4, 1.1 } } do
			add("CarritoRueda", Vector3.new(0.5, 1.1, 1.1), CFrame.new(w[1], 0.55, w[2]) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
		return parts
	end

	local carryParts = {}
	local function renderCarry()
		for _, p in carryParts do p:Destroy() end
		carryParts = {}
		local plr = ctx.player()
		local char = plr and plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp then return end
		local d = d2()
		local function weld(p)
			p.Anchored = false; p.Massless = true; p.CanCollide = false
			local w = Instance.new("WeldConstraint"); w.Part0 = hrp; w.Part1 = p; w.Parent = p
			table.insert(carryParts, p)
		end
		if d.cart then
			-- el carrito va delante del jugador, apoyado en el suelo, y las cajas se apilan encima
			local g = (hum and hum.HipHeight or 2) + hrp.Size.Y / 2
			local base = hrp.CFrame * CFrame.new(0, -g, -3.8) * CFrame.Angles(0, math.pi / 2, 0)
			for _, p in buildCartAt(base, char) do weld(p) end
			local slots = { CFrame.new(1.0, 2.8, 0), CFrame.new(-0.85, 2.8, 0), CFrame.new(1.0, 4.65, 0) }
			for i, t in d.carry do
				local c = makeCrate(t)
				c.CFrame = base * (slots[i] or slots[1])
				c.Parent = char
				weld(c)
			end
		else
			for i, t in d.carry do
				local c = makeCrate(t)
				c.CFrame = hrp.CFrame * CFrame.new(0, -0.3 + (i - 1) * 1.85, -1.9)
				c.Parent = char
				weld(c)
			end
		end
	end

	-- cajas dentro del túnel de atraque (camino a la bodega) + pantallas de manifiesto
	local function renderHold()
		local old = DM:FindFirstChild("CargaEnNave")
		if old then old:Destroy() end
		local f = Instance.new("Folder"); f.Name = "CargaEnNave"
		local n = 0
		local XS = { -1.1, 1.1 }
		local ZS = { -3.6, -1.8, 1.8, 3.6, 0 }
		for _, t in Config.CRATE_ORDER do
			for _ = 1, d2().loaded[t] do
				n += 1
				local i = n - 1
				local layer = i // 10
				local k = i % 10
				local c = makeCrate(t)
				c.CFrame = CFrame.new(zone.Position + Vector3.new(XS[k // 5 + 1], 0.9 + layer * 1.85, ZS[k % 5 + 1]))
				c.Parent = f
			end
		end
		f.Parent = DM
		local d = d2()
		local mass, cost, cap, r = totals()
		local parts = {}
		for _, c in Config.Cargo do
			local kg = d.loaded[c.id] * Config.CRATE_KG
			local col = kg >= c.min and "#6ef0aa" or "#ff6e5a"
			table.insert(parts, ('<font color="%s">%s %d/%d kg</font>'):format(col, Config.Crates[c.id].short, kg, c.min))
		end
		local capTxt = r and (" / %d kg"):format(cap) or ""
		local over = r and mass > cap
		holdText.Text = ("<b>BODEGA · NAVE %s</b>\n%s\nTOTAL <font color=\"%s\"><b>%d kg</b>%s</font> · %d / %d cr"):format(
			r and r.name:upper() or "SIN ACOPLAR", table.concat(parts, " · "), over and "#ff6e5a" or "#ffffff", mass, capTxt, cost, st().budget)
		scaleText.Text = ("<b>MANIFIESTO DE CARGA</b>\n%s\nLleva las cajas a la <b>ESCOTILLA</b> del muelle (oeste)"):format(table.concat(parts, " · "))
	end

	local function setLever()
		local high = d2().orbit == "high"
		local ang = math.rad(high and 30 or -30)
		lever.Brazo.CFrame = CFrame.new(leverPivot) * CFrame.Angles(ang, 0, 0) * CFrame.new(0, 1.5, 0)
		lever.Pomo.CFrame = CFrame.new(leverPivot) * CFrame.Angles(ang, 0, 0) * CFrame.new(0, 3.1, 0)
		leverText.Text = "TRAYECTORIA: " .. (high and "RÁPIDA" or "EFICIENTE")
	end

	local function setCover(open)
		d2().coverOpen = open
		local target = open and (coverClosed * CFrame.new(0, 0, 1.1) * CFrame.Angles(math.rad(80), 0, 0) * CFrame.new(0, 0, -1.1)) or coverClosed
		TweenService:Create(cover, TweenInfo.new(0.4), { CFrame = target }):Play()
	end

	-- estado visual de la escotilla: puertas, luces y letrero
	local function hatchVisual()
		local d = d2()
		local open = d.hatchOpen
		for i, dr in doors do
			local dir = math.sign(dr.Position.Z - hatchCol.Position.Z)
			if dir == 0 then dir = i == 1 and 1 or -1 end
			local target = open and (doorClosed[i] + Vector3.new(0, 0, dir * 5.6)) or doorClosed[i]
			TweenService:Create(dr, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { CFrame = target, Transparency = open and 1 or 0 }):Play()
			dr.CanCollide = not open
		end
		local color, sign
		if d.rocket == "" then
			color, sign = Color3.fromRGB(255, 80, 80), "PUERTO DE ATRAQUE  /  SIN NAVE"
		elseif d.docking then
			color, sign = Color3.fromRGB(255, 190, 60), "NAVE EN APROXIMACIÓN"
		elseif open then
			color, sign = Color3.fromRGB(255, 190, 60), "ABIERTA  /  CARGANDO"
		else
			color, sign = Color3.fromRGB(110, 240, 170), "NAVE ACOPLADA  /  SELLADO"
		end
		for _, p in hatchNeon do p.Color = color end
		if hatchSign then hatchSign.Text = sign end
	end

	local function boardIdle(msg)
		boardText.Text = "<b>REVISIÓN PREVIA AL DESACOPLE</b>\n" .. msg
		consoleText.Text = "LIBERACIÓN · BLOQUEADA"
	end

	local function invalidate()
		local d = d2()
		local hadTest = d.tested or #d.test > 0
		d.tested = false
		d.test = {}
		if d.coverOpen then setCover(false) end
		if hadTest then boardIdle("Se detectaron cambios en la carga o la nave.\nVuelve a pulsar <b>PROBAR</b>.") end
	end

	local function refreshNumbers()
		local mass, cost = totals()
		st().mass = mass
		st().cost = cost
		renderHold()
	end

	local shipToken = 0
	local function clearShip()
		shipToken += 1
		local r = DM:FindFirstChild("NaveActiva")
		if r then r:Destroy() end
	end

	-- la nave llega desde el sur, pasa frente a la estación y se acopla al puerto
	local function dockShip(kind)
		clearShip()
		local my = shipToken
		local S = st()
		local d = d2()
		local model = Rocket.buildShip(kind, dockCF, 1, false)
		model.Name = "NaveActiva"
		local p0 = dockCF.Position + Vector3.new(-45, 22, -75)
		local p1 = (dockCF * CFrame.new(0, 0, 16)).Position
		local rot = dockCF.Rotation
		model:PivotTo(CFrame.new(p0) * rot)
		model.Parent = DM
		d.docking = true
		hatchVisual()
		task.spawn(function()
			local t0 = os.clock()
			while true do
				if shipToken ~= my or ctx.S() ~= S then return end
				local t = os.clock() - t0
				local pos
				if t < 4 then
					local a = 1 - (1 - t / 4) ^ 2
					pos = p0:Lerp(p1, a)
				elseif t < 6.5 then
					pos = p1:Lerp(dockCF.Position, (t - 4) / 2.5)
				else
					break
				end
				model:PivotTo(CFrame.new(pos) * rot)
				RunService.Heartbeat:Wait()
			end
			model:PivotTo(dockCF)
			d.docking = false
			hatchVisual()
			local r = rocketSpec(kind)
			ctx.toast(("Nave %s acoplada ✔. Abre la escotilla (E) y carga las cajas."):format(r and r.name:lower() or ""), "good")
			ctx.push()
		end)
	end

	local function resetWorld()
		for _, p in carryParts do p:Destroy() end
		carryParts = {}
		local old = DM:FindFirstChild("CargaEnNave")
		if old then old:Destroy() end
		clearShip()
		cover.CFrame = coverClosed
		for i, dr in doors do dr.CFrame = doorClosed[i]; dr.Transparency = 0; dr.CanCollide = true end
		for _, p in hatchNeon do p.Color = Color3.fromRGB(255, 80, 80) end
		if hatchSign then hatchSign.Text = "PUERTO DE ATRAQUE  /  SIN NAVE" end
		for _, p in cart:GetDescendants() do if p:IsA("BasePart") then p.Transparency = 0 end end
		for k, pd in pedestals do pd.Anillo.Color = KIND_COLOR[k] end
		boardIdle("Pide una nave, cárgala por la escotilla,\nciérrala y pulsa <b>PROBAR</b>.")
		scaleText.Text = "<b>MANIFIESTO DE CARGA</b>\nLleva las cajas a la <b>ESCOTILLA</b> del muelle (oeste)"
		holdText.Text = "<b>BODEGA DE LA NAVE</b>\nSin nave acoplada"
	end

	---------------------------------------------------------------- revisión RYG
	local function runTest()
		local d = d2()
		local budget = st().budget
		local mass, cost, cap, r = totals()
		local minsOk = true
		for _, c in Config.Cargo do if d.loaded[c.id] * Config.CRATE_KG < c.min then minsOk = false end end
		local reserve = math.floor(budget * (1 - Config.BUDGET_RESERVE))
		local maxMass = math.floor(cap * (1 - Config.MASS_MARGIN))
		local sealed = r ~= nil and not d.hatchOpen and not d.docking
		local lights = {
			{ name = "Mínimos por suministro (80 / 60 / 40 kg)", s = minsOk and "G" or "R",
				why = minsOk and "Completo" or "Falta carga de algún suministro" },
			{ name = "Al menos 180 kg en la bodega", s = mass >= Config.CARGO_MIN_TOTAL and "G" or "R", why = ("Llevas %d kg"):format(mass) },
			{ name = "Masa dentro de la capacidad de la nave", s = (r and mass <= cap) and "G" or "R",
				why = r and ("%d / %d kg · trayectoria %s"):format(mass, cap, ORBIT_NAME[d.orbit]) or "No hay nave acoplada" },
			{ name = "Costo dentro del presupuesto", s = cost <= budget and "G" or "R", why = ("%d / %d cr"):format(cost, budget) },
			{ name = "Escotilla cerrada y sellada", s = sealed and "G" or "R",
				why = sealed and "Presión estable" or (r and "Cierra la escotilla (F)" or "No hay nave acoplada") },
			{ name = "Márgenes de seguridad (10 % presupuesto · 15 % masa)", s = (r and cost <= reserve and mass <= maxMass) and "G" or "Y",
				why = ("Gasta ≤ %d cr y carga ≤ %d kg"):format(reserve, maxMass) },
		}
		local greens, reds = 0, 0
		for _, l in lights do
			if l.s == "G" then greens += 1 elseif l.s == "R" then reds += 1 end
		end
		local pass = reds == 0 and greens / #lights >= 0.8
		d.tests += 1
		d.test = lights
		d.tested = pass
		if not pass then
			if r and r.id == "light" and d.orbit == "high" and mass >= Config.CARGO_MIN_TOTAL and mass > cap then d.lightHigh = true end
			if d.firstFail == "" then
				for _, l in lights do if l.s == "R" then d.firstFail = l.name .. ": " .. l.why break end end
			end
		end
		local COLORS = { G = "#6ef0aa", Y = "#ffc846", R = "#ff6e5a" }
		local rows = { ("<b>REVISIÓN PREVIA AL DESACOPLE #%d</b>"):format(d.tests) }
		for _, l in lights do
			table.insert(rows, ('<font color="%s">●</font> %s — <font color="#8caabe">%s</font>'):format(COLORS[l.s], l.name, l.why))
		end
		table.insert(rows, pass and ('<font color="#6ef0aa"><b>APROBADO · %d %% en verde · Liberación autorizada</b></font>'):format(math.floor(greens / #lights * 100))
			or ('<font color="#ff6e5a"><b>NO APROBADO · se necesita 80 %% en verde y ningún rojo</b></font>'))
		boardText.Text = table.concat(rows, "\n")
		consoleText.Text = pass and "LISTO · MANTÉN F" or "LIBERACIÓN · BLOQUEADA"
		if pass then setCover(true) end
		ctx.toast(pass and "Revisión aprobada: ve a la consola y mantén F para liberar la nave." or "Revisión no aprobada: corrige lo que está en rojo.", pass and "good" or "bad")
	end

	---------------------------------------------------------------- liberación
	local function emitter(a, props)
		local p = Instance.new("ParticleEmitter")
		for k, v in props do p[k] = v end
		p.EmissionDirection = Enum.NormalId.Top
		p.Parent = a
		return p
	end
	local function rcsFx(model)
		local list = {}
		for _, a in model:GetDescendants() do
			if a:IsA("Attachment") and a.Name == "RCS" then
				table.insert(list, emitter(a, { Color = ColorSequence.new(Color3.fromRGB(235, 240, 255)), LightEmission = 0.4,
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.4) }),
					Transparency = NumberSequence.new(0.2, 1), Lifetime = NumberRange.new(0.3, 0.6), Rate = 40,
					Speed = NumberRange.new(8, 12), SpreadAngle = Vector2.new(10, 10) }))
			end
		end
		return list
	end
	local function engineFx(model)
		for _, a in model:GetDescendants() do
			if a:IsA("Attachment") and a.Name == "Escape" then
				emitter(a, { Color = ColorSequence.new(Color3.fromRGB(160, 220, 255), Color3.fromRGB(80, 120, 255)), LightEmission = 1,
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.5) }),
					Transparency = NumberSequence.new(0.1, 1), Lifetime = NumberRange.new(0.3, 0.6), Rate = 140,
					Speed = NumberRange.new(30, 40), SpreadAngle = Vector2.new(6, 6) })
				local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(140, 190, 255); light.Range = 26; light.Brightness = 4; light.Parent = a
			end
		end
	end

	local function applyResult(success, abort)
		local S = st()
		local d = d2()
		local mass, cost, cap, r = totals()
		local optional = success and cost <= S.budget * (1 - Config.BUDGET_RESERVE) and mass <= cap * (1 - Config.MASS_MARGIN)
		d.result = success and "success" or "abort"
		S.res.d2 = { submitted = true, ok = success, abort = abort, optional = optional, orbit = d.orbit, total = mass, cost = cost, cap = cap,
			tests = d.tests, lightHigh = d.lightHigh, storm = d.storm, firstFail = d.firstFail, rocket = r and r.name or "" }
		if success then
			ctx.addRep(Config.REP_MANDATORY); S.score += Config.SCORE_MANDATORY
			if d.orbit == "high" then S.score += Config.SCORE_HIGH_ORBIT end
			if optional then ctx.addRep(Config.REP_OPTIONAL); S.score += Config.SCORE_OPTIONAL end
			ctx.toast(optional and "¡Nave en camino a la base lunar con márgenes óptimos! Ya puedes pasar al siguiente día." or "¡Nave en camino a la base lunar! Ya puedes pasar al siguiente día.", "good")
		else
			ctx.addRep(Config.REP_FAIL)
			ctx.toast("La tormenta solar dañó la electrónica de la nave: se perdió el cargamento.", "bad")
		end
		consoleText.Text = success and "NAVE EN CAMINO" or "NAVE PERDIDA"
		d.rocket = ""
		hatchVisual()
	end

	local function release(abort)
		local S = st()
		local d = d2()
		d.countdown = Config.COUNTDOWN
		S.paused = true
		ctx.push()
		task.spawn(function()
			for i = Config.COUNTDOWN, 1, -1 do
				if ctx.S() ~= S or S.phase ~= "playing" then return end
				d.countdown = i
				ctx.fire("countdown", i)
				ctx.push()
				task.wait(1)
			end
			d.countdown = 0
			local model = DM:FindFirstChild("NaveActiva")
			ctx.fire("launch", { model = model, abort = abort, cam = Vector3.new(-218, 22, 30), ignite = 6.5, dur = abort and 9.5 or 11.5, lookUp = 1 })
			if model then
				local my = shipToken
				local base = model:GetPivot()
				local back = -base.LookVector
				local puffs = rcsFx(model)
				local dir = Vector3.new(-0.55, 0.12, -1).Unit
				local t0 = os.clock()
				local exploded, ignited = false, false
				local pos, rot = base.Position, base.Rotation
				local turnFrom, turnTo
				while true do
					if shipToken ~= my then break end
					local t = os.clock() - t0
					if t > 11 then break end
					if t < 3.5 then
						-- 1) los propulsores RCS empujan la nave hacia atrás, fuera del puerto
						pos = base.Position + back * (t * t * 0.6)
					elseif t < 6.5 then
						-- 2) se aleja despacio y gira hacia su trayectoria
						if not turnFrom then
							turnFrom = rot
							turnTo = CFrame.lookAt(Vector3.zero, dir).Rotation
							for _, p in puffs do p.Enabled = false end
						end
						pos = base.Position + back * (7.35 + (t - 3.5) * 2.2)
						local a = (t - 3.5) / 3
						rot = turnFrom:Lerp(turnTo, a * a * (3 - 2 * a))
					else
						-- 3) enciende el motor principal rumbo a la Luna
						if not ignited then ignited = true; engineFx(model) end
						local s = t - 6.5
						pos = base.Position + back * (7.35 + 6.6) + dir * (s * s * 4 + s * 2)
						rot = turnTo
						if abort and s > 1.5 then
							local ex = Instance.new("Explosion")
							ex.Position = model:GetPivot().Position
							ex.BlastPressure = 0; ex.DestroyJointRadiusPercent = 0; ex.BlastRadius = 14
							ex.Parent = workspace
							exploded = true
							break
						end
					end
					model:PivotTo(CFrame.new(pos) * rot)
					RunService.Heartbeat:Wait()
				end
				model:Destroy()
				if exploded then task.wait(1.5) end
			end
			if ctx.S() ~= S then return end
			applyResult(not abort, abort)
			S.paused = false
			ctx.push()
		end)
	end

	---------------------------------------------------------------- prompts
	for _, t in Config.CRATE_ORDER do
		local rack = CM:WaitForChild("Estante_" .. t)
		local c = Config.Crates[t]
		ctx.prompt(rack.PrimaryPart, "take_" .. t, "Tomar caja", ("%s · 20 kg · %d cr"):format(c.name, c.cost), 2)
	end
	ctx.prompt(cart.PrimaryPart, "cart", "Alquilar carrito", ("Lleva 3 cajas a la vez · %d cr"):format(Config.CART_COST), 2)
	local pHatch = ctx.prompt(hatchCol, "hatch", "Abrir escotilla", "Puerto de atraque", 2)
	local pSeal = ctx.prompt(hatchCol, "seal", "Cerrar y sellar", "Puerto de atraque", 2)
	pSeal.KeyboardKeyCode = Enum.KeyCode.F
	pSeal.UIOffset = Vector2.new(0, 70)
	local pRemove = ctx.prompt(hatchCol, "remove", "Sacar última caja", "Puerto de atraque", 2)
	pRemove.KeyboardKeyCode = Enum.KeyCode.R
	pRemove.UIOffset = Vector2.new(0, 140)
	for k, pd in pedestals do
		local r = rocketSpec(k)
		ctx.prompt(pd.PrimaryPart, "rocket_" .. k, "Pedir nave", ("Nave %s · %d kg · %d cr"):format(r.name:lower(), r.leo, r.cost), 2)
	end
	ctx.prompt(lever.PrimaryPart, "orbit", "Cambiar trayectoria", "Palanca de trayectoria", 2)
	ctx.prompt(DM:WaitForChild("BotonProbar").PrimaryPart, "test", "PROBAR", "Revisión previa al desacople (RYG)", 2)
	local pLaunch = ctx.prompt(console.PrimaryPart, "launch", "LIBERAR NAVE", "Consola de desacople", 2)
	pLaunch.KeyboardKeyCode = Enum.KeyCode.F
	pLaunch.HoldDuration = 1

	local function syncHatchPrompts()
		local d = d2()
		pHatch.ActionText = d.hatchOpen and "Cargar cajas" or "Abrir escotilla"
	end

	local function locked()
		local d = d2()
		if d.result ~= "" then ctx.toast("La nave ya fue liberada.") return true end
		if d.countdown > 0 or d.stormPending then ctx.toast("Desacople en curso.") return true end
		return false
	end

	local function setHatch(open)
		d2().hatchOpen = open
		hatchVisual()
		syncHatchPrompts()
	end

	function M.onPrompt(key)
		local S = st()
		local d = d2()
		local take = key:match("^take_(%a+)$")
		if take then
			if locked() then return end
			local cap = d.cart and Config.CART_CAPACITY or 1
			if #d.carry >= cap then
				ctx.toast(d.cart and "El carrito está lleno (3 cajas). Llévalas a la escotilla del muelle." or "Solo puedes cargar 1 caja a mano. Alquila el carrito o llévala a la escotilla del muelle.", "warn")
				return
			end
			table.insert(d.carry, take)
			renderCarry()
			ctx.toast(("Tomaste una caja de %s (20 kg)."):format(Config.Crates[take].short))
			ctx.push()
			return
		end
		if key == "hatch" then
			if locked() then return end
			if d.rocket == "" then ctx.toast("No hay nave acoplada: pide una en los pedestales del muelle.", "warn") return end
			if d.docking then ctx.toast("Espera a que la nave termine de acoplarse.", "warn") return end
			if not d.hatchOpen then
				setHatch(true)
				invalidate()
				ctx.toast("Presión igualada: escotilla abierta. Carga las cajas (E).", "good")
				ctx.push()
				return
			end
			if #d.carry == 0 then ctx.toast("No llevas cajas: tómalas de los estantes del Depósito.") return end
			for _, t in d.carry do
				d.loaded[t] += 1
				table.insert(d.order, t)
			end
			ctx.toast(("Cargaste %d caja(s) en la bodega de la nave."):format(#d.carry), "good")
			d.carry = {}
			renderCarry()
			invalidate()
			refreshNumbers()
			ctx.push()
			return
		end
		if key == "seal" then
			if locked() then return end
			if not d.hatchOpen then ctx.toast("La escotilla ya está cerrada.") return end
			setHatch(false)
			invalidate()
			ctx.toast("Escotilla cerrada y sellada ✔. Ahora pulsa PROBAR.", "good")
			ctx.push()
			return
		end
		if key == "remove" then
			if locked() then return end
			if not d.hatchOpen then ctx.toast("Abre la escotilla (E) para sacar cajas.") return end
			local t = table.remove(d.order)
			if not t then ctx.toast("La bodega está vacía.") return end
			d.loaded[t] -= 1
			ctx.toast(("Sacaste una caja de %s."):format(Config.Crates[t].short))
			invalidate()
			refreshNumbers()
			ctx.push()
			return
		end
		if key == "cart" then
			if locked() then return end
			if d.cart then ctx.toast("Ya tienes el carrito alquilado.") return end
			d.cart = true
			for _, p in cart:GetDescendants() do if p:IsA("BasePart") and p.Name ~= "Letrero" then p.Transparency = 1 end end
			renderCarry()
			ctx.toast(("🛒 Carrito alquilado (−%d cr): ahora llevas 3 cajas a la vez."):format(Config.CART_COST), "good")
			invalidate()
			refreshNumbers()
			ctx.push()
			return
		end
		local rk = key:match("^rocket_(%a+)$")
		if rk then
			if locked() then return end
			if d.hatchOpen then ctx.toast("Cierra la escotilla (F) antes de cambiar de nave.", "warn") return end
			if d.docking then ctx.toast("Espera a que la nave termine de acoplarse.", "warn") return end
			if d.rocket == rk then ctx.toast("Esa nave ya está acoplada.") return end
			local had = d.rocket ~= ""
			d.rocket = rk
			for k, pd in pedestals do pd.Anillo.Color = k == rk and Color3.new(1, 1, 1) or KIND_COLOR[k] end
			dockShip(rk)
			ctx.toast(("Nave %s en aproximación: mírala por el ventanal y espera el acople."):format(rocketSpec(rk).name:lower())
				.. (had and " La carga se pasa a la nueva nave." or ""), "good")
			invalidate()
			refreshNumbers()
			ctx.push()
			return
		end
		if key == "orbit" then
			if locked() then return end
			d.orbit = d.orbit == "low" and "high" or "low"
			setLever()
			local r = rocketSpec(d.rocket)
			ctx.toast(d.orbit == "high" and (r and ("Trayectoria rápida: llega antes, pero gasta más combustible; la capacidad baja a %d kg (+200 pts)."):format(Config.capacity(r.id, "high")) or "Trayectoria rápida: −30 % de capacidad, +200 pts.") or "Trayectoria eficiente seleccionada.")
			invalidate()
			refreshNumbers()
			ctx.push()
			return
		end
		if key == "test" then
			if locked() then return end
			runTest()
			ctx.push()
			return
		end
		if key == "launch" then
			if locked() then return end
			if not d.tested then ctx.toast("Primero aprueba la revisión previa al desacople (botón PROBAR).", "warn") return end
			if d.hatchOpen then ctx.toast("Cierra y sella la escotilla (F) primero.", "warn") return end
			if not d.stormRolled then
				d.stormRolled = true
				if math.random() < Config.STORM_CHANCE then
					d.stormPending = true
					ctx.fire("open", "storm")
					ctx.push()
					return
				end
			end
			release(false)
			return
		end
	end

	function M.actions.storm(data)
		local S = st()
		local d = d2()
		if S.day ~= 2 or not d.stormPending or type(data) ~= "table" then return end
		d.stormPending = false
		if data.choice == "wait" then
			d.storm = "wait"
			S.timeLeft = math.max(5, S.timeLeft - Config.STORM_WAIT)
			ctx.toast("Esperaste a que pasara la tormenta solar (−30 s). Iniciando cuenta regresiva.", "warn")
			release(false)
		else
			d.storm = "risk"
			release(math.random() < Config.STORM_RISK)
		end
	end

	---------------------------------------------------------------- ciclo de vida
	function M.fresh(S)
		S.d2 = { carry = {}, cart = false, loaded = { food = 0, water = 0, meds = 0 }, order = {}, rocket = "", orbit = "low",
			tested = false, test = {}, tests = 0, lightHigh = false, firstFail = "", coverOpen = false, countdown = 0,
			hatchOpen = false, docking = false,
			stormRolled = false, stormPending = false, storm = "", result = "" }
	end
	function M.onStart()
		local S = st()
		S.budget = Config.budgetFor(S.rep)
		M.fresh(S)
		S.mass = 0; S.cost = 0
		resetWorld()
		setLever()
		syncHatchPrompts()
		refreshNumbers()
	end
	function M.reset() resetWorld() end
	function M.onRespawn() if ctx.S().day == 2 then renderCarry() end end
	function M.canAdvance() return d2().result ~= "" end
	function M.pendingOptional() return 0 end
	function M.onFinish()
		local S = st()
		local d = d2()
		if d.result == "" then
			S.res.d2 = { submitted = false, tests = d.tests, lightHigh = d.lightHigh, firstFail = d.firstFail }
			ctx.addRep(Config.REP_FAIL)
		end
		for _, p in carryParts do p:Destroy() end
		carryParts = {}
		d.carry = {}
	end
	function M.report(add)
		local r = st().res.d2
		if r.lightHigh then
			add("Envío bloqueado en revisión: la trayectoria rápida redujo la capacidad de la nave pequeña a 140 kg, impidiendo enviar los 180 kg mínimos de suministros.", false)
		end
		if r.submitted then
			if (r.tests or 0) > 1 then
				add(("Necesitaste %d revisiones RYG para aprobar: es el ciclo de diseño de la NASA (simular, fallar y rediseñar)."):format(r.tests), true)
			end
			if r.storm == "wait" then add("Esperaste a que pasara la tormenta solar: perdiste 30 s pero protegiste la nave.", true) end
			if r.abort then
				add("Liberaste la nave durante la tormenta solar y su electrónica falló: el riesgo del 25 % se cumplió y se perdió el cargamento.", false)
			elseif r.ok then
				if r.storm == "risk" then add("Liberaste la nave en plena tormenta solar y tuviste suerte.", true) end
				if r.optional then
					add("Diseño sobresaliente: equilibraste masa, trayectoria y nave respetando el 10 % de reserva presupuestaria y el margen libre de masa.", true)
				else
					add(("Suministros en camino a la base lunar (%d kg en la nave %s por %d cr), aunque sin los márgenes de seguridad completos."):format(r.total, r.rocket:lower(), r.cost), true)
				end
				if r.orbit == "high" then add("La trayectoria rápida te dio +200 puntos por dificultad.", true) end
			end
		else
			add("No enviaste la nave de suministros antes de que terminara el día.", false)
		end
		if r.bonus then add(("Bono de eficiencia del Día 2: +%d puntos."):format(r.bonus), true) end
	end

	resetWorld()
	return M
end
