-- Configuración central de Estación Aurora. Todos los números del diseño viven aquí.
local Config = {}

Config.DAY_SECONDS = 180
Config.LATE_THRESHOLD = 120 -- segundos usados en el Día 0 antes de considerarse "tarde"

Config.REP_START = 50
Config.REP_MANDATORY = 15
Config.REP_OPTIONAL = 8
Config.REP_FAIL = -15
Config.REP_LATE = -5
Config.REP_RETIRE = 10

Config.SCORE_MANDATORY = 100
Config.SCORE_OPTIONAL = 50
Config.SCORE_HIGH_ORBIT = 200

-- Día 0: paneles del ala de comunicaciones (mismo minipuzzle, distinto texto)
Config.Panels = {
	{ id = 1, title = "Controlador de Nodo Terminal (TNC)",
	  info = "Ensambla la telemetría en paquetes de radio y activa el transmisor hacia la estación terrena.",
	  label = "Velocidad de paquetes", unit = "bps", target = 9600, start = 4800, steps = {100, 1200}, min = 0, max = 19200,
	  power = 10, comms = 33 },
	{ id = 2, title = "Transceptor UHF · Banda de 437 MHz",
	  info = "Los satélites pequeños usan la banda de 437 MHz para emitir balizas de rastreo hacia la Tierra.",
	  label = "Frecuencia", unit = "MHz", target = 437, start = 400, steps = {1, 10}, min = 380, max = 480,
	  power = 10, comms = 33 },
	{ id = 3, title = "Rastreo Orbital TLE y Apuntado",
	  info = "El código TLE predice la posición orbital; el acimut y la elevación de la antena se calibran con el Sol o la Luna.",
	  label = "Elevación de la antena", unit = "°", target = 45, start = 10, steps = {1, 5}, min = 0, max = 90,
	  power = 10, comms = 34 },
	{ id = 4, optional = true, title = "Certificación de Inhibidores",
	  info = "Pin RBF retirado y switches de separación liberados. El protocolo exige esperar al menos 45 minutos tras el despliegue antes de transmitir.",
	  label = "Temporizador de seguridad", unit = "min", target = 45, start = 5, steps = {1, 5}, min = 0, max = 120,
	  power = 10, comms = 0 },
}
Config.PUZZLE_SECONDS = 25
Config.PUZZLE_FAIL_POWER = 5

-- Día 1: invernadero BioNutrients
Config.Greenhouse = {
	units = 4,
	decayPerSecond = 0.6,
	waterGain = 40,
	wasteAbove = 80,
	tank = 120, tankLow = 90,
	waterCost = 15,
	powerCost = 5,
	minAlive = 3,
	correctTemp = "30",
	tempOptions = { {id = "30", text = "30 °C"}, {id = "42", text = "42 °C"}, {id = "amb", text = "Ambiente"} },
	alertAt = 90, -- segundos restantes en los que se enciende la luz amarilla
}
Config.FreezeQuiz = {
	{ q = "Número de muestras replicadas", options = {"≥ 6", "≥ 12"}, answer = 2 },
	{ q = "Volumen por muestra", options = {"≥ 30 mL", "≥ 10 mL"}, answer = 1 },
	{ q = "Masa del contenedor vacío", options = {"< 500 g", "< 250 g"}, answer = 2 },
	{ q = "Volumen ocupado total", options = {"< 300 mL", "< 1 L"}, answer = 1 },
	{ q = "Meta de betacaroteno", options = {"≥ 3 µg/mL", "≥ 0.3 µg/mL"}, answer = 1 },
}

-- Día 2: envío de suministros a la base lunar en una nave de carga (leo = trayectoria eficiente, high = rápida)
Config.Budget = { high = 300, normal = 240, low = 200 }
Config.Cargo = {
	{ id = "food", name = "Comida liofilizada", min = 80, cost = 10 },
	{ id = "water", name = "Agua potable", min = 60, cost = 5 },
	{ id = "meds", name = "Suministros médicos", min = 40, cost = 15 },
}
Config.CARGO_STEP = 10
Config.CARGO_MIN_TOTAL = 180
Config.Rockets = {
	{ id = "light", name = "Pequeña", cost = 30, leo = 200, high = 140 },
	{ id = "medium", name = "Mediana", cost = 55, leo = 280, high = 200 },
	{ id = "heavy", name = "Grande", cost = 90, leo = 450, high = 315 },
}
Config.HIGH_ORBIT_FACTOR = 0.7
Config.BUDGET_RESERVE = 0.10
Config.MASS_MARGIN = 0.15

-- Día 3: transmisión de datos
Config.LINK_CAPACITY = 100
Config.LINK_MARGIN = 0.15
Config.Packages = {
	{ id = "A", name = "Exoplanetas en Óptico", gb = 25, power = 15, points = 100,
	  info = "Curvas de luz del tránsito de un planeta del tamaño de la Tierra en la zona habitable." },
	{ id = "B", name = "Fondo Cósmico en Microondas", gb = 35, power = 20, points = 150,
	  info = "Mapa de fluctuaciones de temperatura del universo temprano captado con radiómetros." },
	{ id = "C", name = "Viento Solar en Constelación LEO", gb = 50, power = 30, points = 220,
	  info = "Observaciones 3D de la corona solar tomadas por 4 microsatélites." },
	{ id = "D", name = "Telescopio IR de Espejo Segmentado", gb = 75, power = 45, points = 350,
	  info = "Espectros de helio y agua en exoplanetas e imágenes de las primeras galaxias." },
}

function Config.capacity(rocketId, orbit)
	for _, r in Config.Rockets do
		if r.id == rocketId then
			return orbit == "high" and r.high or r.leo
		end
	end
	return 0
end

function Config.budgetFor(rep)
	if rep >= 70 then return Config.Budget.high, "Alta" end
	if rep >= 30 then return Config.Budget.normal, "Normal" end
	return Config.Budget.low, "Baja"
end

------------------------------------------------------------------ v2: días 2 y 3 interactivos
Config.DAY_LENGTH = { [0] = 180, [1] = 180, [2] = 300, [3] = 300 }
Config.EFFICIENCY_BONUS = 0.5 -- puntos por segundo sobrante al usar "Siguiente día"

-- Día 2: carga física
Config.CRATE_KG = 20
Config.Crates = {
	food = { name = "Comida liofilizada", short = "comida", cost = 20, color = Color3.fromRGB(255, 150, 60) },
	water = { name = "Agua potable", short = "agua", cost = 10, color = Color3.fromRGB(70, 160, 255) },
	meds = { name = "Suministros médicos", short = "medicinas", cost = 30, color = Color3.fromRGB(255, 80, 90) },
}
Config.CRATE_ORDER = { "food", "water", "meds" }
Config.CART_COST = 10
Config.CART_CAPACITY = 3
Config.COUNTDOWN = 10
Config.STORM_CHANCE = 0.4
Config.STORM_WAIT = 30
Config.STORM_RISK = 0.25

-- Día 3: telescopio modular (Build It Yourself: Telescope)
Config.Wavelengths = {
	{ id = "xray", name = "Rayos X" }, { id = "gamma", name = "Rayos Gamma" }, { id = "optical", name = "Óptico" },
	{ id = "uv", name = "Ultravioleta" }, { id = "ir", name = "Infrarrojo" }, { id = "micro", name = "Microondas" },
}
Config.Instruments = {
	{ id = "camera", name = "Cámara" }, { id = "spectro", name = "Espectrómetro" }, { id = "radiometer", name = "Radiómetro" },
	{ id = "propcounter", name = "Contador proporcional" }, { id = "scint", name = "Centelleador" },
}
Config.Optics = {
	{ id = "single", name = "Espejo primario único" }, { id = "segmented", name = "Espejo segmentado / anidado" }, { id = "none", name = "Sin óptica" },
}
Config.Targets = {
	A = { ideal = { "optical", "camera", "single" }, alt = { { "optical", "spectro", "single" }, { "ir", "spectro", "segmented" } },
		hint = "Los tránsitos de exoplanetas se miden como curvas de luz visible.",
		card = "TESS · Descubrió TOI 700 d, un planeta del tamaño de la Tierra en la zona habitable, con cámaras en luz óptica." },
	B = { ideal = { "micro", "radiometer", "single" }, alt = { { "micro", "radiometer", "none" } },
		hint = "El Fondo Cósmico es la luz más antigua del universo y hoy llega como microondas.",
		card = "WMAP / COBE · Mapearon las fluctuaciones de temperatura del universo temprano con radiómetros de microondas." },
	C = { ideal = { "uv", "camera", "single" }, alt = { { "optical", "camera", "single" } },
		hint = "La corona solar brilla en ultravioleta; PUNCH la sigue también en luz visible.",
		card = "PUNCH · 4 satélites pequeños en órbita baja observan la corona y el viento solar en 3D." },
	D = { ideal = { "ir", "spectro", "segmented" }, alt = { { "ir", "camera", "segmented" } },
		hint = "Las primeras galaxias y las atmósferas de exoplanetas se estudian en infrarrojo con un espejo enorme.",
		card = "James Webb (JWST) · Espejo segmentado de berilio de 6.5 m; sus espectrógrafos detectan agua en exoplanetas." },
}
Config.QUALITY_FACTOR = { alta = 1, media = 0.6 }

function Config.nameOf(list, id)
	for _, x in list do if x.id == id then return x.name end end
	return id
end

-- Devuelve calidad ("alta" / "media" / nil) y un mensaje educativo
function Config.evaluateObservation(pkg, w, i, o)
	if w == "gamma" and o ~= "none" then
		return nil, "Los rayos gamma atraviesan o destruyen los espejos normales: se observan sin óptica y con un centelleador."
	end
	if w == "xray" and o == "single" then
		return nil, "Los rayos X no se reflejan en un espejo normal: requieren espejos anidados en ángulo rasante (como Chandra) o un contador proporcional sin óptica."
	end
	if i == "scint" and w ~= "gamma" then return nil, "El centelleador detecta rayos gamma; no sirve para esta longitud de onda." end
	if i == "propcounter" and w ~= "xray" then return nil, "El contador proporcional cuenta fotones de rayos X; no sirve para esta longitud de onda." end
	if w == "micro" and i ~= "radiometer" then return nil, "Las microondas del Fondo Cósmico se miden con un radiómetro." end
	if i == "radiometer" and w ~= "micro" then return nil, "En este kit el radiómetro está calibrado para microondas." end
	local t = Config.Targets[pkg]
	if not t then return nil, "Selecciona un objetivo científico." end
	local function same(c) return c[1] == w and c[2] == i and c[3] == o end
	if same(t.ideal) then return "alta", "Configuración ideal." end
	for _, c in t.alt do if same(c) then return "media", "Configuración válida, aunque no la ideal: los datos tendrán calidad media." end end
	local wOk = t.ideal[1] == w
	for _, c in t.alt do if c[1] == w then wOk = true end end
	if not wOk then return nil, "Ese objetivo no se estudia en esa longitud de onda. Pista: " .. t.hint end
	return nil, "La longitud de onda es correcta, pero el instrumento o la óptica no sirven para este objetivo. Pista: " .. t.hint
end

-- Día 3: órbita comprimida (90 min → 60 s) y enlace
Config.ORBIT_PERIOD = 60
Config.SUN_SECONDS = 36       -- 55 min de sol / 35 de sombra
Config.CONTACT_START = 26     -- ventana de contacto de 20 s que cruza a la sombra
Config.CONTACT_END = 46
Config.SUN_RECHARGE = 0.5     -- % por segundo al sol
Config.RATE = 5               -- GB/s sin filtro
Config.RATE_FILTER = 3.5      -- GB/s con filtro de calidad
Config.LINK_REQUIRED_DB = 3
Config.LOSS_MIN, Config.LOSS_MAX = 0.2, 0.4

function Config.linkMargin(az, el, taz, tel)
	return math.floor((9 - 0.2 * (math.abs(az - taz) + math.abs(el - tel))) * 10 + 0.5) / 10
end

------------------------------------------------------------------ v3: textos concisos y ayuda
Config.Targets.A.hint = "usa luz Óptica";     Config.Targets.A.card = "TESS · encontró el planeta TOI 700 d en la zona habitable."
Config.Targets.B.hint = "usa Microondas";     Config.Targets.B.card = "COBE / WMAP · mapearon la luz más antigua del universo."
Config.Targets.C.hint = "usa Ultravioleta";   Config.Targets.C.card = "PUNCH · 4 satélites que siguen el viento solar en 3D."
Config.Targets.D.hint = "usa Infrarrojo";     Config.Targets.D.card = "JWST · espejo de 6.5 m que ve las primeras galaxias."

function Config.evaluateObservation(pkg, w, i, o)
	if w == "gamma" and o ~= "none" then return nil, "Los rayos gamma atraviesan los espejos: usa Sin óptica + Centelleador." end
	if w == "xray" and o == "single" then return nil, "Los rayos X no rebotan en un espejo normal." end
	if i == "scint" and w ~= "gamma" then return nil, "El centelleador solo sirve para rayos gamma." end
	if i == "propcounter" and w ~= "xray" then return nil, "El contador proporcional solo sirve para rayos X." end
	if w == "micro" and i ~= "radiometer" then return nil, "Las microondas se miden con Radiómetro." end
	if i == "radiometer" and w ~= "micro" then return nil, "El radiómetro solo sirve para microondas." end
	local t = Config.Targets[pkg]
	if not t then return nil, "Elige un objetivo." end
	local function same(x) return x[1] == w and x[2] == i and x[3] == o end
	if same(t.ideal) then return "alta", "¡Configuración ideal!" end
	for _, x in t.alt do if same(x) then return "media", "Válida, pero de calidad media." end end
	local wOk = t.ideal[1] == w
	for _, x in t.alt do if x[1] == w then wOk = true end end
	if not wOk then return nil, "Longitud de onda incorrecta." end
	return nil, "Onda correcta: cambia el instrumento o la óptica."
end

Config.Help = {
	[0] = { "Ve a los 3 paneles <b>ENLACE</b> (pared frontal de Comunicaciones).", "Pulsa <b>E</b> e iguala el número objetivo con + y −.", "Confirma antes de que se acabe la batería del panel.", "Opcional: panel <b>Inhibidores</b> (letrero amarillo)." },
	[1] = { "Riega cada cultivo cuando baje de <b>80 %</b> (E junto a la cápsula).", "Pon el termostato en <b>30 °C</b> (levadura).", "Mantén vivas 3 unidades hasta la <b>luz amarilla</b>.", "Opcional: agita en la incubadora y congela en MELFI." },
	[2] = { "Toma cajas de los estantes del Depósito (80 / 60 / 40 kg); el <b>carrito</b> lleva 3 a la vez.", "En el Muelle pide una <b>nave</b> en un pedestal y elige la trayectoria con la palanca.", "Abre la <b>escotilla</b> (E), carga las cajas (E) y ciérrala y séllala (F).", "Pulsa <b>PROBAR</b> y en la consola mantén <b>F</b> para liberar la nave." },
	[3] = { "<b>Laboratorio:</b> cambia las 4 ranuras con E (mira sus iconos) hasta que se pongan en verde, y pulsa OBSERVAR.", "Si fallas, la pantalla te da una pista (al 2.º fallo, la solución).", "<b>Comunicaciones:</b> apunta la antena en ENLACE 03 hasta ≥ 3 dB (las flechas te guían).", "Espera la ventana <b>📡</b>: el paquete se envía solo." },
}

------------------------------------------------------------------ v4: iconos del telescopio y manual de misión
Config.Icons = {
	target = { A = "🪐", B = "🌌", C = "☀️", D = "🌀" },
	w = { xray = "☢️", gamma = "⚡", optical = "👁️", uv = "🟣", ir = "🔥", micro = "📶" },
	i = { camera = "📷", spectro = "🌈", radiometer = "🌡️", propcounter = "🔢", scint = "✨" },
	o = { single = "🔵", segmented = "💠", none = "🚫" },
}
Config.TargetShort = { A = "Exoplanetas", B = "Fondo cósmico", C = "Viento solar", D = "Galaxias lejanas" }

Config.Manual = {
	[0] = { objetivo = "Restablecer el enlace con la Tierra reparando los 3 paneles de comunicaciones.",
		datos = { "TNC: empaqueta la telemetría en paquetes de radio a 9600 bps.", "UHF 437 MHz: banda de balizas de los satélites pequeños.",
			"TLE: datos que predicen la órbita; la antena se calibra a 45° de elevación.", "Inhibidores: tras el despliegue se esperan 45 min antes de transmitir." } },
	[1] = { objetivo = "Cultivar la levadura del proyecto BioNutrients-2, que produce betacaroteno para misiones largas.",
		datos = { "La levadura se incuba a 30 °C (el yogur a 42 °C y el kéfir a temperatura ambiente).", "El agua sale del dispensador PWD: regar de más la desperdicia.",
			"El lote se agita a las 6 h y se congela en MELFI para volver a la Tierra.", "Meta: ≥ 3 µg/mL de betacaroteno y ≥ 12 muestras de ≥ 30 mL." } },
	[2] = { objetivo = "Enviar al menos 180 kg de suministros a la base lunar en una nave de carga, sin pasarte del presupuesto.",
		datos = { "Las estaciones reales reciben y despiden naves de carga (Cygnus, Dragon) con un brazo robótico como el Canadarm2.", "Una trayectoria rápida gasta más combustible: resta 30 % de capacidad, pero da +200 pts.",
			"La NASA vigila las tormentas solares: sus partículas pueden dañar la electrónica de las naves.", "Revisión previa al desacople: 80 % en verde y ningún rojo; guarda 10 % del presupuesto y 15 % de la capacidad." } },
	[3] = { objetivo = "Observar el universo con el telescopio y transmitir la ciencia a la Tierra.",
		datos = { "Cada objetivo se ve en una longitud de onda: combina onda, instrumento y óptica.", "Los rayos gamma atraviesan los espejos; las microondas se miden con radiómetro.",
			"La antena necesita ≥ 3 dB de margen (checklist CML 4).", "Solo se transmite durante la ventana de contacto 📡." } },
}

return Config
