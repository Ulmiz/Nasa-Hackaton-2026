-- Día 3: telescopio modular, órbita sol/sombra, ventanas de contacto, antena (dB) y cola de transmisión.
local TweenService = game:GetService("TweenService")

return function(ctx)
	local Config = ctx.Config
	local M = { day = 3, actions = {} }
	local LM = ctx.X:WaitForChild("ScienceLab"):WaitForChild("Misiones")
	local OM = ctx.X:WaitForChild("ObservationDeck"):WaitForChild("Misiones")
	local function textOf(inst) return inst:FindFirstChild("Texto", true) end

	local slotModels = {
		target = LM:WaitForChild("Ranura_target"), w = LM:WaitForChild("Ranura_w"),
		i = LM:WaitForChild("Ranura_i"), o = LM:WaitForChild("Ranura_o"),
	}
	local bigText = textOf(LM:WaitForChild("PantallaTelescopio"))
	local holo = OM:WaitForChild("HologramaTierra")
	local globe = holo:WaitForChild("Globo")
	local holoText = textOf(globe)
	local GLOBE_COLOR = globe.Color

	local TARGET_IDS = { "A", "B", "C", "D" }
	local SHORT = { A = "Exoplanetas", B = "Fondo cósmico", C = "Viento solar", D = "Galaxias lejanas" }
	local LISTS = { w = Config.Wavelengths, i = Config.Instruments, o = Config.Optics }
	local TITLES = { target = "OBJETIVO", w = "LONGITUD DE ONDA", i = "INSTRUMENTO", o = "ÓPTICA" }
	local taz, tel = 180, 45

	local function st() return ctx.S() end
	local function d3() return ctx.S().d3 end
	local function pkgOf(id)
		for _, p in Config.Packages do if p.id == id then return p end end
		return nil
	end
	local function valueName(slot, v)
		if slot == "target" then
			local p = pkgOf(v)
			return p and ("%s · %s"):format(p.id, SHORT[p.id] or p.name) or v
		end
		return Config.nameOf(LISTS[slot], v)
	end

	local GOOD = Color3.fromRGB(110, 240, 170)
	local CYAN = Color3.fromRGB(90, 220, 255)
	local function iconFor(slot, v) return (Config.Icons and Config.Icons[slot] and Config.Icons[slot][v]) or "" end
	local function nameFor(slot, v)
		if slot == "target" then return v .. " · " .. ((Config.TargetShort and Config.TargetShort[v]) or v) end
		return Config.nameOf(LISTS[slot], v)
	end
	local function setMonitor(model, slot, v)
		local mon = model:FindFirstChild("Monitor")
		local icon = mon and mon:FindFirstChild("Icono", true)
		local txt = mon and mon:FindFirstChild("Texto", true)
		if icon then icon.Text = iconFor(slot, v) end
		if txt then txt.Text = nameFor(slot, v) end
	end
	local function currentCorrect()
		local s = d3().slots
		return Config.evaluateObservation(s.target, s.w, s.i, s.o) ~= nil
	end

	local function renderLab(msg, good)
		local d = d3()
		for slot, model in slotModels do
			setMonitor(model, slot, d.slots[slot])
		end
		local ok = currentCorrect()
		for _, model in slotModels do
			local r = model:FindFirstChild("Ranura")
			if r then r.Color = ok and GOOD or CYAN end
		end
		if msg == nil and ok then msg = "✔ ¡Combinación correcta! Pulsa OBSERVAR."; good = true end
		local obs = {}
		for _, id in TARGET_IDS do if d.observed[id] then table.insert(obs, id) end end
		local t = Config.Targets[d.slots.target]
		local fails = (d.fails and d.fails[d.slots.target]) or 0
		local hint
		if fails >= 2 then
			hint = ("Solución: %s + %s + %s"):format(Config.nameOf(LISTS.w, t.ideal[1]), Config.nameOf(LISTS.i, t.ideal[2]), Config.nameOf(LISTS.o, t.ideal[3]))
		else
			hint = "Pista: " .. t.hint
		end
		local color = good == nil and "#8caabe" or (good and "#6ef0aa" or "#ff6e5a")
		bigText.Text = ("<b>TELESCOPIO · %s</b>\n<font color=\"%s\">%s</font>\n<font color=\"#ffc846\">%s</font>\nListos: %s"):format(
			valueName("target", d.slots.target), color, msg or "Ajusta las ranuras y pulsa OBSERVAR.", hint, #obs > 0 and table.concat(obs, ", ") or "—")
	end

	local function setHolo(text, flash)
		holoText.Text = text
		if flash then
			globe.Color = Color3.fromRGB(110, 255, 170)
			TweenService:Create(globe, TweenInfo.new(1.5), { Color = GLOBE_COLOR }):Play()
		end
	end

	---------------------------------------------------------------- prompts
	for slot, model in slotModels do
		ctx.prompt(model.PrimaryPart, "slot_" .. slot, "Cambiar", TITLES[slot]:sub(1, 1) .. TITLES[slot]:sub(2):lower(), 3)
	end
	ctx.prompt(LM:WaitForChild("BotonObservar").PrimaryPart, "observe", "OBSERVAR", "Telescopio modular", 3)
	local pSym = ctx.prompt(LM:WaitForChild("BotonObservar").PrimaryPart, "symbols", "Guía de símbolos", "Telescopio modular", 3)
	pSym.KeyboardKeyCode = Enum.KeyCode.R
	pSym.UIOffset = Vector2.new(0, 70)
	ctx.prompt(ctx.Comms:WaitForChild("Panel 3"), "antenna", "Apuntar antena", "Antena de la estación (dB)", 3)
	ctx.prompt(ctx.Comms:WaitForChild("Panel 2"), "queue", "Abrir cola", "Cola de transmisión", 3)
	ctx.prompt(ctx.Comms:WaitForChild("Panel 1"), "queue", "Abrir cola", "Cola de transmisión", 3)

	function M.onPrompt(key)
		local d = d3()
		local slot = key:match("^slot_(%a+)$")
		if slot then
			local list = slot == "target" and TARGET_IDS or LISTS[slot]
			local cur = d.slots[slot]
			local idx = 1
			for n, v in list do
				local id = type(v) == "table" and v.id or v
				if id == cur then idx = n end
			end
			local nxt = list[idx % #list + 1]
			d.slots[slot] = type(nxt) == "table" and nxt.id or nxt
			renderLab()
			if currentCorrect() then ctx.toast("✔ ¡Combinación correcta! Pulsa OBSERVAR.", "good") end
			ctx.push()
			return
		end
		if key == "symbols" then
			ctx.fire("open", "manual", "symbols")
			return
		end
		if key == "observe" then
			local s = d.slots
			local q, msg = Config.evaluateObservation(s.target, s.w, s.i, s.o)
			d.attempts += 1
			if q then
				local prev = d.observed[s.target]
				if prev ~= "alta" then d.observed[s.target] = q end
				local p = pkgOf(s.target)
				local queued = false
				if not d.sent[p.id] then
					local inQ, used = false, d.sentGB
					for _, x in d.queue do used += pkgOf(x).gb if x == p.id then inQ = true end end
					if not inQ and used + p.gb <= Config.LINK_CAPACITY then table.insert(d.queue, p.id) queued = true end
					if inQ then queued = true end
				end
				renderLab(msg, true)
				ctx.fire("open", "card", { pkg = p.id, name = p.name, gb = p.gb, quality = d.observed[s.target], msg = msg, card = Config.Targets[p.id].card, queued = queued })
				ctx.toast(("Paquete %s listo%s."):format(p.id, queued and " y en cola" or ""), "good")
			else
				d.fails = d.fails or {}
				d.fails[s.target] = (d.fails[s.target] or 0) + 1
				if d.wrongFirst == "" then d.wrongFirst = msg end
				renderLab(msg, false)
				ctx.toast(msg, "bad")
			end
			ctx.push()
			return
		end
		if key == "antenna" then
			ctx.fire("open", "antenna", { az = d.az, el = d.el, taz = taz, tel = tel, ok = d.antennaOk, margin = d.margin })
			return
		end
		if key == "queue" then
			ctx.fire("open", "queue")
			return
		end
	end

	---------------------------------------------------------------- acciones
	local function queuedGB()
		local d = d3()
		local gb = d.sentGB
		for _, id in d.queue do gb += pkgOf(id).gb end
		return gb
	end

	function M.actions.antenna(data)
		local d = d3()
		if st().day ~= 3 or type(data) ~= "table" then return end
		local az = math.clamp(math.floor(tonumber(data.az) or 0), 0, 359)
		local el = math.clamp(math.floor(tonumber(data.el) or 0), 0, 90)
		d.az, d.el = az, el
		local margin = Config.linkMargin(az, el, taz, tel)
		if margin >= Config.LINK_REQUIRED_DB then
			d.antennaOk = true
			d.margin = margin
			ctx.toast(("Antena apuntada: margen de enlace de %.1f dB (≥ 3 dB)."):format(margin), "good")
		else
			ctx.toast(("Margen insuficiente: %.1f dB. CML 4 exige al menos 3 dB."):format(margin), "bad")
		end
		ctx.push()
	end

	function M.actions.enqueue(data)
		local d = d3()
		local id = type(data) == "table" and data.id
		local p = id and pkgOf(id)
		if not p then return end
		if not d.observed[id] then ctx.toast("Primero observa ese objetivo en el telescopio del Laboratorio.", "warn") return end
		if d.sent[id] then ctx.toast("Ese paquete ya se transmitió.") return end
		for _, q in d.queue do if q == id then return end end
		if queuedGB() + p.gb > Config.LINK_CAPACITY then
			ctx.toast(("No cabe: superarías los %d GB del enlace."):format(Config.LINK_CAPACITY), "bad")
			return
		end
		table.insert(d.queue, id)
		ctx.push()
	end

	function M.actions.dequeue(data)
		local d = d3()
		local id = type(data) == "table" and data.id
		for n, q in d.queue do
			if q == id then
				if n == 1 and d.progress > 0 then ctx.toast("Ese paquete ya se está transmitiendo.", "warn") return end
				table.remove(d.queue, n)
				ctx.push()
				return
			end
		end
	end

	function M.actions.filter(data)
		local d = d3()
		d.filter = type(data) == "table" and data.on == true
		ctx.push()
	end

	---------------------------------------------------------------- transmisión
	local function complete(id)
		local S = st()
		local d = d3()
		local p = pkgOf(id)
		local loss = 0
		if not d.filter and d.sentGB + p.gb > Config.LINK_CAPACITY * (1 - Config.LINK_MARGIN) then
			loss = math.floor((Config.LOSS_MIN + math.random() * (Config.LOSS_MAX - Config.LOSS_MIN)) * 100) / 100
			d.lossAny = true
		end
		local q = d.observed[id] or "media"
		local points = math.floor(p.points * Config.QUALITY_FACTOR[q] * (1 - loss))
		S.score += points
		d.sent[id] = { gb = p.gb, points = points, loss = loss, quality = q }
		d.sentGB += p.gb
		S.data = d.sentGB
		d.transmitted += 1
		table.remove(d.queue, 1)
		d.current = ""
		d.progress = 0
		setHolo(("RECIBIDO · Paquete %s\n%s · calidad %s"):format(p.id, p.name, q), true)
		if loss > 0 then
			ctx.toast(("Paquete %s recibido con pérdida del %d %%: +%d pts."):format(id, loss * 100, points), "bad")
		else
			ctx.toast(("Paquete %s recibido en la Tierra: +%d pts. ¡Ya puedes terminar!"):format(id, points), "good")
		end
	end

	function M.onTick()
		local S = st()
		local d = d3()
		if S.paused then return end
		d.orbitT = (d.orbitT + 1) % Config.ORBIT_PERIOD
		d.sun = d.orbitT < Config.SUN_SECONDS
		local was = d.contact
		d.contact = d.orbitT >= Config.CONTACT_START and d.orbitT < Config.CONTACT_END
		if d.sun then S.power = math.min(100, S.power + Config.SUN_RECHARGE) end
		if d.contact and not was then
			if not d.antennaOk then
				ctx.toast("📡 Contacto abierto, pero falta apuntar la antena (ENLACE 03).", "warn")
			elseif #d.queue == 0 then
				ctx.toast("📡 Contacto abierto: no hay paquetes en cola.", "warn")
			else
				ctx.toast("📡 Transmitiendo a la Tierra…", "good")
			end
		elseif was and not d.contact then
			ctx.toast("Fin de la ventana de contacto.")
		end
		if d.contact and d.antennaOk and #d.queue > 0 then
			local id = d.queue[1]
			local p = pkgOf(id)
			d.current = id
			local rate = d.filter and Config.RATE_FILTER or Config.RATE
			local step = math.min(rate, p.gb - d.progress)
			local cost = step * p.power / p.gb
			if S.power < cost then
				if not d.warnedPower then
					ctx.toast("Batería insuficiente para transmitir: espera a estar al sol.", "bad")
					d.warnedPower = true
				end
				return
			end
			d.warnedPower = false
			S.power -= cost
			d.progress += step
			if not d.filter then d.filterAll = false end
			if d.progress >= p.gb - 1e-6 then complete(id) end
		end
	end

	---------------------------------------------------------------- ciclo de vida
	function M.fresh(S)
		S.d3 = { slots = { target = "A", w = "optical", i = "camera", o = "none" }, observed = {}, attempts = 0, fails = {}, wrongFirst = "",
			antennaOk = false, margin = 0, az = 90, el = 10, queue = {}, current = "", progress = 0, sent = {}, sentGB = 0,
			filter = false, filterAll = true, orbitT = 0, sun = true, contact = false, transmitted = 0, lossAny = false, warnedPower = false }
	end
	function M.onStart()
		local S = st()
		M.fresh(S)
		S.data = 0
		taz = math.random(24, 48) * 5
		tel = math.random(4, 14) * 5
		renderLab()
		setHolo("ESTACIÓN TERRENA\nEsperando datos científicos")
		task.delay(1.5, function() ctx.toast("Día 3: ① Laboratorio → telescopio   ② Comunicaciones → antena (ENLACE 03)", "warn") end)
	end
	function M.reset()
		setHolo("ESTACIÓN TERRENA\nEsperando datos científicos")
	end
	function M.canAdvance() return d3().transmitted >= 1 end
	function M.pendingOptional()
		local d = d3()
		return (d.filter and d.filterAll and not d.lossAny) and 0 or 1
	end
	function M.onFinish()
		local S = st()
		local d = d3()
		local sentList, pts = {}, 0
		for _, id in TARGET_IDS do
			local s = d.sent[id]
			if s then
				pts += s.points
				table.insert(sentList, { id = id, name = pkgOf(id).name, gb = s.gb, points = s.points, loss = s.loss, quality = s.quality, card = Config.Targets[id].card })
			end
		end
		local optional = d.transmitted >= 1 and d.filterAll and not d.lossAny and d.sentGB <= Config.LINK_CAPACITY * (1 - Config.LINK_MARGIN)
		if d.transmitted >= 1 then
			ctx.addRep(Config.REP_MANDATORY); S.score += Config.SCORE_MANDATORY
			if optional then ctx.addRep(Config.REP_OPTIONAL); S.score += Config.SCORE_OPTIONAL end
		else
			ctx.addRep(Config.REP_FAIL)
		end
		local bonus = S.res.d3 and S.res.d3.bonus
		S.res.d3 = { submitted = d.transmitted >= 1, transmitted = d.transmitted, gb = d.sentGB, points = pts, optional = optional,
			attempts = d.attempts, wrongFirst = d.wrongFirst, loss = d.lossAny, margin = d.margin, antennaOk = d.antennaOk, sent = sentList, bonus = bonus }
	end
	function M.report(add)
		local r = st().res.d3
		if (r.attempts or 0) > 0 then add(("Configuraste el telescopio en %d intento(s)."):format(r.attempts), true) end
		if r.wrongFirst and r.wrongFirst ~= "" then add("Lección del telescopio: " .. r.wrongFirst, false) end
		if r.antennaOk then
			add(("Apuntaste la antena con %.1f dB de margen (el checklist CML 4 exige ≥ 3 dB)."):format(r.margin), true)
		else
			add("No apuntaste la antena: sin margen de enlace no hay transmisión posible.", false)
		end
		for _, s in r.sent or {} do
			local lossTxt = s.loss > 0 and (", con pérdida del %d %%"):format(s.loss * 100) or ""
			add(("Paquete %s · %s: %d GB, calidad %s%s → +%d pts. %s"):format(s.id, s.name, s.gb, s.quality, lossTxt, s.points, s.card), s.loss == 0)
		end
		if r.loss then add("Sin filtro de calidad y con más del 85 % del enlace ocupado, perdiste parte de los datos.", false) end
		if r.optional then add("Activaste el control de calidad y dejaste un 15 % del enlace libre: sin pérdida de paquetes.", true) end
		if not r.submitted then add("No transmitiste datos científicos a la Tierra.", false) end
		if r.bonus then add(("Bono de eficiencia del Día 3: +%d puntos."):format(r.bonus), true) end
	end

	return M
end
