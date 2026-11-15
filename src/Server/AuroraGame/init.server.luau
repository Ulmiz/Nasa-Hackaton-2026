-- Estación Aurora: núcleo del juego (un jugador por servidor). Días 0 y 1 aquí; días 2 y 3 en módulos hijos.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("Aurora"):WaitForChild("AuroraConfig"))
local remote = RS.Aurora:WaitForChild("AuroraRemote")

local E = workspace:WaitForChild("EstacionAurora")
local X = E:WaitForChild("ExpansionOrbital")
local Comms = E:WaitForChild("CommsRoom")
local GH = E:WaitForChild("GreenhouseRoom")

local DAY_NAMES = { [0] = "Día 0 · Reparar el ala de comunicaciones", [1] = "Día 1 · Invernadero BioNutrients",
	[2] = "Día 2 · Envío de suministros", [3] = "Día 3 · Ciencia y transmisión" }

local player = nil
local S
local modules = {}

local function roomSpawn(room, x, z, lx, lz)
	local cub = room:FindFirstChild("Cubierta")
	if not cub then return nil end
	local pos = (cub.CFrame * CFrame.new(x, 4, z)).Position
	local look = (cub.CFrame * CFrame.new(lx, 4, lz)).Position
	return CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z))
end
local DAY_ROOM = {
	[0] = { Comms, 0, 1, 0, -8 }, [1] = { GH, 0, 1, 0, -9 },
	[2] = { X:WaitForChild("CargoBay"), 0, 10, 0, -10 }, [3] = { X:WaitForChild("ScienceLab"), -10, -4, -10, 6 },
}
local function spawnFor(day)
	local d = DAY_ROOM[day] or DAY_ROOM[0]
	return roomSpawn(d[1], d[2], d[3], d[4], d[5])
end

local function moduleFor(day)
	for _, m in modules do if m.day == day then return m end end
	return nil
end

local function aliveCount()
	local a = 0
	for _, u in S.units do if u.alive then a += 1 end end
	return a
end

local function canAdvance()
	if S.phase ~= "playing" then return false end
	if S.day == 0 then return S.panels[1] and S.panels[2] and S.panels[3] end
	if S.day == 1 then return S.alert and aliveCount() >= Config.Greenhouse.minAlive and S.thermostat == Config.Greenhouse.correctTemp end
	local m = moduleFor(S.day)
	return m and m.canAdvance and m.canAdvance() or false
end
local function pendingOpt()
	if S.day == 0 then return S.panels[4] and 0 or 1 end
	if S.day == 1 then return S.frozen and 0 or 1 end
	local m = moduleFor(S.day)
	return m and m.pendingOptional and m.pendingOptional() or 0
end

local function push()
	if not player then return end
	S.canAdvance = canAdvance()
	S.pendingOpt = pendingOpt()
	remote:FireClient(player, "state", S)
end
local function toast(msg, kind)
	if player then remote:FireClient(player, "toast", msg, kind or "info") end
end
local function fire(...)
	if player then remote:FireClient(player, ...) end
end

---------------------------------------------------------------- luces
local commsLights = {}
for _, d in Comms:GetDescendants() do
	if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") or (d:IsA("BasePart") and d.Name == "Luminaria") then
		table.insert(commsLights, { obj = d, color = d.Color })
	end
end
local function setCommsAlarm(on)
	for _, l in commsLights do l.obj.Color = on and Color3.fromRGB(255, 60, 50) or l.color end
end
local incubadora = GH:WaitForChild("Incubadora")
local alertLight = Instance.new("PointLight")
alertLight.Name = "AlertaAgitacion"; alertLight.Color = Color3.fromRGB(255, 200, 40)
alertLight.Range = 14; alertLight.Brightness = 2; alertLight.Enabled = false; alertLight.Parent = incubadora

---------------------------------------------------------------- reputación
local function addRep(delta)
	S.rep = math.clamp(S.rep + delta, 0, 100)
	if S.rep <= Config.REP_RETIRE and S.phase ~= "retired" then
		S.phase = "retired"
		setCommsAlarm(false)
		alertLight.Enabled = false
	end
end

---------------------------------------------------------------- prompts
local prompts = {}
local function prompt(part, key, action, objectText, day)
	local p = Instance.new("ProximityPrompt")
	p.Name = "AuroraPrompt"
	p.ActionText = action
	p.ObjectText = objectText
	p.HoldDuration = 0
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Enabled = false
	p:SetAttribute("Key", key)
	p.Parent = part
	table.insert(prompts, { prompt = p, day = day })
	return p
end
local function promptHolder(model, name)
	local cf = model:GetBoundingBox()
	local part = Instance.new("Part")
	part.Name = name; part.Anchored = true; part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
	part.Transparency = 1; part.Size = Vector3.new(1, 1, 1); part.CFrame = cf
	part.Parent = model
	return part
end
local function refreshPrompts()
	for _, p in prompts do p.prompt.Enabled = (S.phase == "playing" and S.day == p.day and not S.userPaused) end
end

---------------------------------------------------------------- contexto compartido con los módulos de día
local ctx = {
	Config = Config, remote = remote, E = E, X = X, Comms = Comms,
	S = function() return S end,
	player = function() return player end,
	push = push, toast = toast, fire = fire, addRep = addRep,
	prompt = prompt, holder = promptHolder,
}
for _, ms in script:GetChildren() do
	if ms:IsA("ModuleScript") then
		local ok, m = pcall(function() return require(ms)(ctx) end)
		if ok then table.insert(modules, m) else warn("[Aurora] módulo " .. ms.Name .. ": " .. tostring(m)) end
	end
end

local function newState()
	local units = {}
	for i = 1, Config.Greenhouse.units do units[i] = { hyd = 100, alive = true } end
	local st = {
		phase = "intro", day = 0, timeLeft = Config.DAY_LENGTH[0], paused = false, userPaused = false,
		power = 100, comms = 0, budget = 0, cost = 0, mass = 0, data = 0,
		rep = Config.REP_START, score = 0,
		panels = { false, false, false, false }, commsDoneAt = 0,
		water = Config.Greenhouse.tank, wasted = 0, units = units, thermostat = "", alert = false,
		agitated = false, frozen = false, quizDone = false,
		res = { d0 = {}, d1 = {}, d2 = {}, d3 = {} },
		dayName = DAY_NAMES[0], canAdvance = false, pendingOpt = 0,
	}
	for _, m in modules do if m.fresh then m.fresh(st) end end
	return st
end
S = newState()

---------------------------------------------------------------- informe
local function buildReport()
	local lines = {}
	local r = S.res
	local function add(text, good) table.insert(lines, { text = text, good = good }) end
	if r.d0.done then
		if r.d0.late then
			add("Recuperaste tarde el enlace UHF de 437 MHz y el controlador de paquetes, lo que redujo tu tiempo operativo y tu reputación inicial.", false)
		else
			add("Restableciste a tiempo el TNC a 9600 bps, el transceptor de 437 MHz y el apuntado TLE: enlace al 100 %.", true)
		end
	else
		add("No completaste la reparación del ala de comunicaciones: la estación quedó sin enlace estable con la Tierra.", false)
	end
	if r.d0.optional then add("Certificaste los inhibidores: respetaste los 45 minutos de espera antes de transmitir.", true) end
	if r.d0.bonus then add(("Bono de eficiencia del Día 0: +%d puntos."):format(r.d0.bonus), true) end
	if r.d1.temp ~= "30" then
		if r.d1.temp == "42" or r.d1.temp == "amb" then
			add("Fallo en el cultivo: no incubaste a 30 grados (usaste el perfil de 42 grados de yogur o ambiente de kéfir), por lo que la levadura no produjo los 3 microgramos por mL de betacaroteno.", false)
		else
			add("No ajustaste el termostato de incubación: la levadura necesitaba exactamente 30 °C.", false)
		end
	end
	if r.d1.early then add("Terminaste el día antes de la mitad de la incubación (luz amarilla): la levadura no alcanzó a producir betacaroteno.", false) end
	if r.d1.tankEmpty then add("Sobrehidrataste las bolsas al inicio y agotaste el tanque de agua antes de completar la incubación.", false) end
	if r.d1.alive and r.d1.alive < Config.Greenhouse.minAlive then
		add(("Solo sobrevivieron %d de 4 unidades de cultivo: necesitabas al menos 3."):format(r.d1.alive), false)
	end
	if r.d1.ok then add(("Cultivo exitoso: %d unidades vivas incubadas a 30 °C."):format(r.d1.alive), true) end
	if r.d1.optional then add("Agitaste el lote y lo congelaste en MELFI cumpliendo los requisitos de éxito (≥12 muestras, ≥30 mL, <250 g, <300 mL).", true) end
	if r.d1.bonus then add(("Bono de eficiencia del Día 1: +%d puntos."):format(r.d1.bonus), true) end
	for _, m in modules do if m.report then m.report(add) end end
	return lines
end

---------------------------------------------------------------- días
local function startDay(day)
	S.day = day
	S.dayName = DAY_NAMES[day]
	S.phase = "playing"
	S.paused = false
	S.userPaused = false
	S.timeLeft = Config.DAY_LENGTH[day] or Config.DAY_SECONDS
	local lowRep = S.rep < 30
	S.power = (day > 0 and lowRep) and 80 or 100
	if day == 0 then
		setCommsAlarm(true)
	elseif day == 1 then
		S.water = lowRep and Config.Greenhouse.tankLow or Config.Greenhouse.tank
		S.wasted = 0
		for i = 1, Config.Greenhouse.units do S.units[i] = { hyd = 100, alive = true } end
		S.thermostat = ""; S.alert = false; S.agitated = false; S.frozen = false; S.quizDone = false
	end
	local m = moduleFor(day)
	if m and m.onStart then m.onStart() end
	local char = player and player.Character
	local cf = spawnFor(day)
	if char and cf then char:PivotTo(cf) end
	refreshPrompts()
	push()
end

local function finishDay()
	if S.phase ~= "playing" then return end
	local day = S.day
	local r = S.res
	if day == 0 then
		local done = S.panels[1] and S.panels[2] and S.panels[3]
		r.d0.done = done
		if done then
			addRep(Config.REP_MANDATORY); S.score += Config.SCORE_MANDATORY
			if S.commsDoneAt > Config.LATE_THRESHOLD then r.d0.late = true; addRep(Config.REP_LATE) end
		else
			addRep(Config.REP_FAIL)
		end
		setCommsAlarm(false)
	elseif day == 1 then
		local alive = aliveCount()
		r.d1.alive = alive
		r.d1.temp = S.thermostat
		r.d1.tankEmpty = S.water < Config.Greenhouse.waterCost and S.wasted > 0
		r.d1.early = not S.alert
		r.d1.ok = S.alert and alive >= Config.Greenhouse.minAlive and S.thermostat == Config.Greenhouse.correctTemp
		if r.d1.ok then addRep(Config.REP_MANDATORY); S.score += Config.SCORE_MANDATORY else addRep(Config.REP_FAIL) end
		alertLight.Enabled = false
	else
		local m = moduleFor(day)
		if m and m.onFinish then m.onFinish() end
	end
	S.paused = false
	refreshPrompts()
	if S.phase == "retired" then push() return end
	if day >= 3 then
		S.phase = "report"
		push()
		fire("report", buildReport())
	else
		S.phase = "dayEnd"
		push()
	end
end
ctx.finishDay = finishDay

---------------------------------------------------------------- prompts de los días 0 y 1
for i = 1, 3 do prompt(Comms:WaitForChild("Panel " .. i), "panel" .. i, "Calibrar", Config.Panels[i].title, 0) end
do
	local best, bestD
	local ref = Comms:WaitForChild("Panel 3").Position
	for _, m in Comms:WaitForChild("Paneles y equipo"):GetChildren() do
		if m.Name == "Panel de servicio" then
			local d = (m:GetBoundingBox().Position - ref).Magnitude
			if not bestD or d < bestD then best, bestD = m, d end
		end
	end
	if best then prompt(promptHolder(best, "PromptInhibidores"), "panel4", "Certificar (opcional)", "Inhibidores de despliegue", 0) end
end
for i = 1, Config.Greenhouse.units do
	prompt(promptHolder(GH:WaitForChild("Cultivo " .. i), "PromptCultivo"), "unit" .. i, "Inyectar agua", "Unidad de cultivo " .. i, 1)
end
prompt(promptHolder(GH:WaitForChild("Thermostat"), "PromptTermostato"), "thermostat", "Ajustar", "Termostato de incubación", 1)
prompt(incubadora, "agitate", "Agitar 1 min", "Incubadora", 1)
local melfi = GH:FindFirstChild("Congelador MELFI")
if melfi then prompt(promptHolder(melfi, "PromptMELFI"), "freeze", "Congelar lote", "Congelador MELFI", 1) end

local function spend(power)
	if S.power < power then toast("Potencia insuficiente para esta acción.", "bad") return false end
	S.power -= power
	return true
end

local function onPrompt(key)
	if S.phase ~= "playing" then return end
	local panelId = key:match("^panel(%d)$")
	if panelId then
		local i = tonumber(panelId)
		if S.panels[i] then toast("Este panel ya está calibrado.") return end
		if S.power < Config.Panels[i].power then toast("Potencia insuficiente para calibrar.", "bad") return end
		fire("open", "puzzle", i)
		return
	end
	local unitId = key:match("^unit(%d)$")
	if unitId then
		local u = S.units[tonumber(unitId)]
		local G = Config.Greenhouse
		if not u.alive then toast("Esta unidad ya se perdió.", "bad") return end
		if S.water < G.waterCost then toast("Tanque PWD vacío.", "bad") return end
		if not spend(G.powerCost) then return end
		S.water -= G.waterCost
		if u.hyd > G.wasteAbove then
			S.wasted += 1
			toast("La bolsa ya estaba sobre 80 %: desperdiciaste 15 unidades de agua.", "bad")
		else
			u.hyd = math.min(100, u.hyd + G.waterGain)
			toast("Agua inyectada con jeringa por la válvula sin aguja.", "good")
		end
		push()
		return
	end
	if key == "thermostat" then fire("open", "thermostat") return end
	if key == "agitate" then
		if not S.alert then toast("La incubadora aún no pide agitación.") return end
		if S.agitated then toast("El lote ya fue agitado. Llévalo al congelador MELFI.") return end
		S.agitated = true
		alertLight.Enabled = false
		toast("Agitación de 1 minuto completada. Transfiere el lote al congelador MELFI.", "good")
		push()
		return
	end
	if key == "freeze" then
		if not S.agitated then toast("Primero agita el lote en la incubadora (luz amarilla).") return end
		if S.quizDone then toast("El lote ya fue procesado.") return end
		fire("open", "freezeQuiz")
		return
	end
	local m = moduleFor(S.day)
	if m and m.onPrompt then m.onPrompt(key) end
end

---------------------------------------------------------------- acciones del cliente
local actions = {}

function actions.start()
	if S.phase == "intro" then startDay(0)
	elseif S.phase == "dayEnd" then startDay(S.day + 1) end
end
function actions.endDay() finishDay() end
function actions.nextDay()
	if S.phase ~= "playing" or S.paused or not canAdvance() then return end
	local bonus = math.floor(math.max(0, S.timeLeft) * Config.EFFICIENCY_BONUS)
	S.score += bonus
	S.res["d" .. S.day].bonus = bonus
	toast(("Bono de eficiencia: +%d puntos"):format(bonus), "good")
	finishDay()
end
function actions.restart()
	setCommsAlarm(false); alertLight.Enabled = false
	for _, m in modules do if m.reset then m.reset() end end
	S = newState()
	refreshPrompts()
	if player and player.Character then player:LoadCharacter() end
	push()
end
function actions.puzzle(data)
	if S.phase ~= "playing" or S.day ~= 0 or type(data) ~= "table" then return end
	local i = tonumber(data.panel)
	local P = i and Config.Panels[i]
	if not P or S.panels[i] then return end
	if tonumber(data.value) ~= P.target then toast("Valor incorrecto.", "bad") return end
	if not spend(P.power) then return end
	S.panels[i] = true
	if P.optional then
		addRep(Config.REP_OPTIONAL); S.score += Config.SCORE_OPTIONAL
		S.res.d0.optional = true
		toast("Inhibidores certificados: +8 reputación.", "good")
	else
		S.comms = math.min(100, S.comms + P.comms)
		if S.panels[1] and S.panels[2] and S.panels[3] then
			S.comms = 100
			S.commsDoneAt = Config.DAY_LENGTH[0] - S.timeLeft
			setCommsAlarm(false)
			toast("Enlace con la Tierra al 100 %. Ya puedes pasar al siguiente día.", "good")
		else
			toast(P.title .. " calibrado.", "good")
		end
	end
	push()
end
function actions.puzzleFail()
	if S.phase ~= "playing" or S.day ~= 0 then return end
	S.power = math.max(0, S.power - Config.PUZZLE_FAIL_POWER)
	toast("Se agotó la batería del panel: -5 % de potencia.", "bad")
	push()
end
function actions.thermostat(data)
	if S.phase ~= "playing" or S.day ~= 1 or type(data) ~= "table" then return end
	for _, o in Config.Greenhouse.tempOptions do
		if o.id == data.value then
			S.thermostat = o.id
			toast("Termostato fijado en " .. o.text .. ".")
			push()
			return
		end
	end
end
function actions.quiz(data)
	if S.phase ~= "playing" or S.day ~= 1 or not S.agitated or S.quizDone or type(data) ~= "table" then return end
	S.quizDone = true
	local ok = true
	for i, q in Config.FreezeQuiz do if tonumber(data[i]) ~= q.answer then ok = false end end
	if ok then
		S.frozen = true; S.res.d1.optional = true
		addRep(Config.REP_OPTIONAL); S.score += Config.SCORE_OPTIONAL
		toast("Lote congelado en MELFI y validado: +8 reputación.", "good")
	else
		toast("La validación no cumplió los requisitos de éxito. El lote se descarta.", "bad")
	end
	push()
end

remote.OnServerEvent:Connect(function(who, action, data)
	if who ~= player or type(action) ~= "string" then return end
	if action == "hello" then push() return end
	-- pausa del jugador: congela el reloj, el invernadero, la órbita y las interacciones
	if action == "pause" then
		if S.phase == "playing" and not S.paused and type(data) == "table" then
			S.userPaused = data.on == true
			refreshPrompts()
			push()
		end
		return
	end
	if S.userPaused and action ~= "restart" then return end
	local fn = actions[action]
	if fn then
		fn(data)
	else
		local m = moduleFor(S.day)
		if m and m.actions and m.actions[action] and S.phase == "playing" then m.actions[action](data) end
	end
	refreshPrompts()
end)

for _, p in prompts do
	p.prompt.Triggered:Connect(function(who)
		if who ~= player or S.userPaused then return end
		onPrompt(p.prompt:GetAttribute("Key"))
	end)
end

---------------------------------------------------------------- reloj
task.spawn(function()
	while true do
		task.wait(1)
		if S.phase == "playing" and not S.userPaused then
			if not S.paused then S.timeLeft -= 1 end
			if S.day == 1 then
				local G = Config.Greenhouse
				for _, u in S.units do
					if u.alive then
						u.hyd -= G.decayPerSecond
						if u.hyd <= 0 then u.hyd = 0; u.alive = false; toast("Una unidad de cultivo se deshidrató.", "bad") end
					end
				end
				if not S.alert and S.timeLeft <= G.alertAt then
					S.alert = true
					alertLight.Enabled = true
					toast("Luz amarilla en la incubadora: es hora de la agitación de 6 horas (opcional).", "warn")
				end
			end
			local m = moduleFor(S.day)
			if m and m.onTick then m.onTick() end
			if S.timeLeft <= 0 and not S.paused then finishDay() end
			push()
		end
	end
end)

---------------------------------------------------------------- jugador
local function registerPlayer(p)
	if player or p.Parent ~= Players then return end
	player = p
	S = newState()

	local lastCharacter
	local function onCharacterAdded(char)
		if char == lastCharacter then return end
		lastCharacter = char
		char:WaitForChild("HumanoidRootPart", 5)
		task.wait(0.1)
		if player ~= p or p.Character ~= char then return end
		local cf = spawnFor(S.day)
		if cf then char:PivotTo(cf) end
		for _, m in modules do if m.onRespawn then m.onRespawn(char) end end
		task.wait(0.4)
		if player == p and p.Character == char then push() end
	end

	p.CharacterAdded:Connect(onCharacterAdded)
	if p.Character then task.spawn(onCharacterAdded, p.Character) end
end

Players.PlayerAdded:Connect(registerPlayer)
for _, p in Players:GetPlayers() do registerPlayer(p) end
Players.PlayerRemoving:Connect(function(p)
	if p == player then
		player = nil
		setCommsAlarm(false); alertLight.Enabled = false
		for _, m in modules do if m.reset then m.reset() end end
		S = newState(); refreshPrompts()
	end
end)
