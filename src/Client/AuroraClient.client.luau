-- Estación Aurora: interfaz del jugador (HUD, objetivos, minijuegos, cinemática e informe).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
local Config = require(RS:WaitForChild("Aurora"):WaitForChild("AuroraConfig"))
local remote = RS.Aurora:WaitForChild("AuroraRemote")

local C = {
	bg = Color3.fromRGB(8, 16, 26), panel = Color3.fromRGB(14, 28, 42), panel2 = Color3.fromRGB(22, 42, 60),
	line = Color3.fromRGB(45, 100, 130), text = Color3.fromRGB(225, 240, 250), dim = Color3.fromRGB(140, 170, 190),
	accent = Color3.fromRGB(90, 220, 255), good = Color3.fromRGB(110, 240, 170), bad = Color3.fromRGB(255, 110, 90),
	warn = Color3.fromRGB(255, 200, 70),
}
local BOLD, MED = Enum.Font.GothamBold, Enum.Font.GothamMedium

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props or {} do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) end
local function stroke(o, c) new("UIStroke", { Color = c or C.line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o) end
local function pad(o, p)
	new("UIPadding", { PaddingTop = UDim.new(0, p), PaddingBottom = UDim.new(0, p), PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p) }, o)
end
local function list(o, gap, horiz)
	return new("UIListLayout", { Padding = UDim.new(0, gap or 6), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = horiz and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical }, o)
end
local function label(parent, text, size, color, font, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size or 16, TextColor3 = color or C.text,
		Font = font or MED, TextWrapped = true, RichText = true, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, parent)
	if props then for k, v in props do l[k] = v end end
	return l
end
local function button(parent, text, color, onClick, props)
	local b = new("TextButton", { Text = text, TextSize = 15, Font = BOLD, TextColor3 = C.bg, BackgroundColor3 = color or C.accent,
		AutoButtonColor = true, Size = UDim2.new(0, 170, 0, 38), TextWrapped = true, RichText = true }, parent)
	corner(b, 6)
	if props then for k, v in props do b[k] = v end end
	if onClick then b.MouseButton1Click:Connect(onClick) end
	return b
end
local function addX(b, color)
	b.Text = ""
	for _, r in { 45, -45 } do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.55, 0, 0, 3),
			Rotation = r, BackgroundColor3 = color or Color3.new(1, 1, 1), BorderSizePixel = 0, Name = "LineaX" }, b)
	end
	return b
end
local function row(parent, height, gap)
	local f = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height or 38) }, parent)
	list(f, gap or 8, true)
	return f
end
local function fmtTime(t) t = math.max(0, math.floor(t)) return ("%d:%02d"):format(t // 60, t % 60) end
local function mark(ok) return ok and '<font color="#6ef0aa">✔</font>' or '<font color="#ff6e5a">✖</font>' end
local function sound(id, vol)
	local s = new("Sound", { SoundId = id, Volume = vol or 0.6 }, SoundService)
	s:Play()
	s.Ended:Connect(function() s:Destroy() end)
	task.delay(10, function() if s.Parent then s:Destroy() end end)
end
local function pkgOf(id) for _, p in Config.Packages do if p.id == id then return p end end end

local gui = new("ScreenGui", { Name = "AuroraUI", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5 }, player:WaitForChild("PlayerGui"))

local S = nil
local applyPause -- definida en el menú de pausa
local UserInputService = game:GetService("UserInputService")

---------------------------------------------------------------- HUD
local EDGE = Color3.fromRGB(60, 130, 170)
local function panelFrame(props)
	local f = new("Frame", props, gui)
	f.BackgroundColor3 = C.bg
	f.BackgroundTransparency = 0.12
	corner(f, 12); stroke(f, EDGE)
	return f
end
local function minimizeBtn(parent, onClick)
	local b = button(parent, "–", C.panel2, nil, { Size = UDim2.new(0, 28, 0, 24), AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8), TextColor3 = C.accent, TextSize = 18 })
	b.MouseButton1Click:Connect(function() local min = onClick() b.Text = min and "+" or "–" end)
	return b
end
local chips = {}

-- Estado del sistema (centro superior)
local hud = panelFrame({ Size = UDim2.new(0.44, 0, 0, 66), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Visible = false })
new("UISizeConstraint", { MinSize = Vector2.new(470, 66), MaxSize = Vector2.new(680, 66) }, hud)
pad(hud, 8)
local hl = list(hud, 8, true); hl.VerticalAlignment = Enum.VerticalAlignment.Center; hl.HorizontalAlignment = Enum.HorizontalAlignment.Center
local function stat(key, icon, title, order)
	local f = new("Frame", { Size = UDim2.new(0.25, -6, 1, 0), BackgroundTransparency = 1, LayoutOrder = order }, hud)
	label(f, icon, 24, C.warn, BOLD, { Size = UDim2.new(0, 30, 1, 0), AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
	label(f, title, 11, C.dim, MED, { Position = UDim2.new(0, 34, 0, 3), Size = UDim2.new(1, -34, 0, 14),
		AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	chips[key] = label(f, "", 22, C.text, BOLD, { Position = UDim2.new(0, 34, 0, 18), Size = UDim2.new(1, -34, 0, 26),
		AutomaticSize = Enum.AutomaticSize.None, TextScaled = true })
end
stat("power", "⚡", "POTENCIA", 1)
stat("comms", "📡", "COMUNICACIONES", 2)
stat("mass", "⚖️", "MASA", 3)
stat("data", "💾", "DATOS", 4)

-- Cronómetro (derecha superior)
local timerMin = false
local timerPanel = panelFrame({ Size = UDim2.new(0, 270, 0, 90), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Visible = false })
local dayBig = label(timerPanel, "DÍA: 00", 28, C.text, BOLD, { Position = UDim2.new(0, 104, 0, 8), Size = UDim2.new(1, -144, 0, 34),
	AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Center })
local timeLbl = label(timerPanel, "", 16, C.bad, BOLD, { Position = UDim2.new(0, 10, 0, 44), Size = UDim2.new(1, -20, 0, 20),
	AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Center })
local dayLabel = label(timerPanel, "", 11, C.dim, MED, { Position = UDim2.new(0, 10, 0, 66), Size = UDim2.new(1, -20, 0, 16),
	AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
chips.time = timeLbl

-- Música de fondo (audios gratuitos del Creator Store, temática espacial); alterna entre pistas
local MUSIC = { "rbxassetid://140041908508788", "rbxassetid://140533822783920" }
local MUSIC_VOL = 0.22
local music = new("Sound", { Name = "AuroraMusica", Volume = MUSIC_VOL, Looped = false }, SoundService)
local musicIdx, musicOn = 1, true
local function playTrack(i)
	musicIdx = (i - 1) % #MUSIC + 1
	music.SoundId = MUSIC[musicIdx]
	music.TimePosition = 0
	if musicOn then music:Play() end
end
music.Ended:Connect(function() playTrack(musicIdx + 1) end)
task.spawn(function() playTrack(1) end)
local musicBtn = button(timerPanel, "🔊", C.panel2, nil, { Size = UDim2.new(0, 28, 0, 24), Position = UDim2.new(0, 8, 0, 8), TextSize = 14 })
local function setMusic(on)
	musicOn = on
	musicBtn.Text = musicOn and "🔊" or "🔇"
	if musicOn then music:Resume() if not music.IsPlaying then music:Play() end else music:Pause() end
end
musicBtn.MouseButton1Click:Connect(function() setMusic(not musicOn) end)
-- Idioma (español / inglés): lo aplica el script AuroraIdiomaCliente
local function curLang() return player:GetAttribute("AuroraIdioma") or "es" end
local function setLang(l) player:SetAttribute("AuroraIdioma", l) end
local langMini = button(timerPanel, "EN", C.panel2, function() setLang(curLang() == "es" and "en" or "es") end,
	{ Size = UDim2.new(0, 28, 0, 24), Position = UDim2.new(0, 72, 0, 8), TextSize = 12, TextColor3 = C.accent })
local langIntro = button(gui, "🌐 English", C.panel2, function() setLang(curLang() == "es" and "en" or "es") end,
	{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14), Size = UDim2.new(0, 160, 0, 42), TextSize = 16, TextColor3 = C.accent, ZIndex = 30, Visible = false })
stroke(langIntro, EDGE)
-- Botón de pausa (junto al de música); el menú se arma más abajo
local pauseBtn = button(timerPanel, "⏸", C.panel2, nil, { Size = UDim2.new(0, 28, 0, 24), Position = UDim2.new(0, 40, 0, 8), TextSize = 14, TextColor3 = C.accent })
minimizeBtn(timerPanel, function()
	timerMin = not timerMin
	timerPanel.Size = UDim2.new(0, 270, 0, timerMin and 48 or 90)
	timeLbl.Visible = not timerMin
	dayLabel.Visible = not timerMin
	return timerMin
end)

-- Columna izquierda: objetivos y estadísticas plegables
local leftCol = new("Frame", { Size = UDim2.new(0, 340, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 12, 0, 96),
	BackgroundTransparency = 1, Visible = false }, gui)
list(leftCol, 10)
-- Bajo la barra superior de Roblox (menú, chat, voz), con margen, sea cual sea su altura
local GuiService = game:GetService("GuiService")
local function placeLeft()
	local inset = 58
	pcall(function() inset = math.max(inset, GuiService.TopbarInset.Max.Y) end)
	leftCol.Position = UDim2.new(0, 12, 0, inset + 30)
end
placeLeft()
pcall(function() GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeLeft) end)
local function collapsible(title, order, width)
	local f = new("Frame", { Size = UDim2.new(width or 1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.12, LayoutOrder = order }, leftCol)
	corner(f, 12); stroke(f, EDGE)
	new("UIPadding", { PaddingBottom = UDim.new(0, 12) }, f)
	label(f, title, 20, C.accent, BOLD, { Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -60, 0, 26), AutomaticSize = Enum.AutomaticSize.None })
	local body = new("Frame", { Size = UDim2.new(1, -28, 0, 0), Position = UDim2.new(0, 14, 0, 40), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1 }, f)
	list(body, 6)
	local min = false
	minimizeBtn(f, function() min = not min body.Visible = not min return min end)
	return f, body
end
local objFrame, obj = collapsible("OBJETIVOS", 1, 1)
local openHelp
local helpBtn = button(objFrame, "📖 Manual", C.warn, function() if S and openHelp then openHelp(S.day) end end,
	{ Size = UDim2.new(0, 96, 0, 24), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -44, 0, 8), TextSize = 12 })
local statFrame, statBody = collapsible("ESTADÍSTICAS", 2, 0.8)
local function statRow(key, icon, title, order)
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = order }, statBody)
	label(r, icon, 20, C.text, BOLD, { Size = UDim2.new(0, 30, 1, 0), AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
	label(r, title, 16, C.dim, MED, { Position = UDim2.new(0, 36, 0, 0), Size = UDim2.new(0.6, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.None,
		TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = false })
	chips[key] = label(r, "", 20, C.text, BOLD, { Position = UDim2.new(0.55, 0, 0, 0), Size = UDim2.new(0.45, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center, TextScaled = true })
end
statRow("budget", "💵", "PRESUPUESTO", 1)
statRow("rep", "🛡️", "REPUTACIÓN", 2)
statRow("score", "🏆", "PUNTOS", 3)

-- Botones de fin de día (bajo el cronómetro)
local nextBtn, endBtn
nextBtn = button(gui, "Siguiente día ▶", C.good, function()
	if not S then return end
	if S.pendingOpt > 0 and not nextBtn:GetAttribute("Armed") then
		nextBtn:SetAttribute("Armed", true)
		nextBtn.Text = ("Faltan %d opcional(es) · ¿Seguir?"):format(S.pendingOpt)
		task.delay(3.5, function() nextBtn:SetAttribute("Armed", false); nextBtn.Text = "Siguiente día ▶" end)
		return
	end
	nextBtn:SetAttribute("Armed", false)
	nextBtn.Text = "Siguiente día ▶"
	remote:FireServer("nextDay")
end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 108), Size = UDim2.new(0, 270, 0, 42), Visible = false, TextSize = 16 })
endBtn = button(gui, "Terminar día", C.warn, function()
	if endBtn:GetAttribute("Armed") then
		endBtn:SetAttribute("Armed", false); endBtn.Text = "Terminar día"
		remote:FireServer("endDay")
	else
		endBtn:SetAttribute("Armed", true); endBtn.Text = "¿Sin terminar? Confirmar"
		task.delay(3, function() endBtn:SetAttribute("Armed", false); endBtn.Text = "Terminar día" end)
	end
end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 108), Size = UDim2.new(0, 270, 0, 36), Visible = false })

-- Botón TRAJES (abre el selector de trajes del equipo)
local function skinParts()
	local sg = player.PlayerGui:FindFirstChild("SkinSelector")
	if not sg then return nil, nil end
	return sg:FindFirstChild("SkinPanel", true), sg:FindFirstChild("OpenSkinSelector", true)
end
local trajesBtn = button(gui, "TRAJES", C.bg, function()
	local panel = skinParts()
	if panel then panel.Visible = not panel.Visible else warn("[Aurora] El selector de trajes aún no está disponible.") end
end, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -14), Size = UDim2.new(0, 230, 0, 56),
	TextColor3 = C.accent, TextSize = 22, BackgroundTransparency = 0.12, Visible = false })
stroke(trajesBtn, EDGE)
local function hideSkinButton()
	local _, open = skinParts()
	if open then open.Visible = false end
end
task.spawn(function()
	player.PlayerGui:WaitForChild("SkinSelector", 30)
	hideSkinButton()
end)
player.PlayerGui.ChildAdded:Connect(function(c) if c.Name == "SkinSelector" then task.wait(0.2) hideSkinButton() end end)

-- barra de órbita (día 3)
-- Va abajo al centro, entre TRAJES y el minimapa, para no tapar OBJETIVOS ni el cronómetro.
local orbitBar = new("Frame", { Size = UDim2.new(0, 560, 0, 40), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16),
	BackgroundColor3 = C.bg, BackgroundTransparency = 0.12, Visible = false }, gui)
corner(orbitBar, 10); stroke(orbitBar, EDGE)
local orbitText = label(orbitBar, "", 14, C.text, BOLD, { Size = UDim2.new(1, -16, 1, -6), Position = UDim2.new(0, 8, 0, 3),
	AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, TextScaled = true })
new("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 9 }, orbitText)

-- cuenta regresiva
local countdown = label(gui, "", 120, C.warn, BOLD, { Size = UDim2.new(0, 400, 0, 140), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.42, 0), AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Center, Visible = false, TextStrokeTransparency = 0.3 })

-- avisos
local toasts = new("Frame", { Size = UDim2.new(0, 480, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -72), BackgroundTransparency = 1 }, gui)
-- Ancho adaptable: el centro inferior queda libre entre TRAJES (izq.) y el minimapa (der.)
local function layoutBottom()
	local w = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or 1280
	local free = math.max(320, w - 2 * 272)
	orbitBar.Size = UDim2.new(0, math.min(600, free), 0, 40)
	toasts.Size = UDim2.new(0, math.min(480, free), 0, 0)
end
layoutBottom()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutBottom)
local tl = list(toasts, 6); tl.VerticalAlignment = Enum.VerticalAlignment.Bottom; tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
local function toast(msg, kind)
	local col = ({ good = C.good, bad = C.bad, warn = C.warn })[kind] or C.accent
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.bg, BackgroundTransparency = 0.1 }, toasts)
	corner(f, 8); stroke(f, col); pad(f, 10)
	label(f, msg, 15, col, BOLD, { TextXAlignment = Enum.TextXAlignment.Center })
	if kind == "bad" then sound("rbxasset://sounds/electronicpingshort.wav", 0.3) end
	task.delay(5, function() f:Destroy() end)
	while #toasts:GetChildren() > 5 do
		for _, c in toasts:GetChildren() do if c:IsA("Frame") then c:Destroy() break end end
	end
end

---------------------------------------------------------------- ventanas modales
local modal = nil
local function closeModal()
	if modal then modal.closed = true; modal.frame:Destroy(); modal = nil end
end
local function openModal(title, width, kind)
	closeModal()
	local frame = new("Frame", { Size = UDim2.new(0, width or 520, 0.8, 0), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.53, 0), BackgroundColor3 = C.bg, BackgroundTransparency = 0.04 }, gui)
	corner(frame, 12); stroke(frame, C.accent)
	new("UISizeConstraint", { MaxSize = Vector2.new(math.huge, 640) }, frame)
	local head = new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.panel2 }, frame)
	corner(head, 12)
	label(head, title, 18, C.accent, BOLD, { Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(1, -70, 1, 0), AutomaticSize = Enum.AutomaticSize.None, TextYAlignment = Enum.TextYAlignment.Center })
	addX(button(head, "", C.bad, closeModal, { Size = UDim2.new(0, 34, 0, 34), Position = UDim2.new(1, -42, 0, 6), Modal = true }))
	local body = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -50), Position = UDim2.new(0, 0, 0, 50), BackgroundTransparency = 1,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, BorderSizePixel = 0 }, frame)
	pad(body, 14); list(body, 8)
	modal = { frame = frame, body = body, closed = false, kind = kind }
	return modal
end

---------------------------------------------------------------- Día 0: minipuzzle
local function openPuzzle(i)
	local P = Config.Panels[i]
	local m = openModal(P.title)
	local b = m.body
	label(b, P.info, 14, C.dim)
	label(b, ("%s · objetivo: <b>%s %s</b>"):format(P.label, P.target, P.unit), 16, C.accent, BOLD)
	local value = P.start
	local big = label(b, "", 44, C.text, BOLD, { TextXAlignment = Enum.TextXAlignment.Center })
	local function refresh()
		big.Text = ("%s %s"):format(value, P.unit)
		big.TextColor3 = value == P.target and C.good or C.text
	end
	refresh()
	local r = row(b, 40)
	for _, d in { -P.steps[2], -P.steps[1], P.steps[1], P.steps[2] } do
		button(r, (d > 0 and "+" or "−") .. math.abs(d), C.panel2, function()
			value = math.clamp(value + d, P.min, P.max); refresh()
		end, { Size = UDim2.new(0.25, -6, 1, 0), TextColor3 = C.text })
	end
	label(b, "Batería del panel", 12, C.dim)
	local barBg = new("Frame", { Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = C.panel }, b); corner(barBg, 6)
	local bar = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = C.good }, barBg); corner(bar, 6)
	label(b, ("Costo al calibrar: -%d %% de potencia"):format(P.power), 13, C.dim)
	button(b, "Confirmar calibración", C.good, function()
		if value ~= P.target then toast("El valor no coincide con el objetivo.", "bad") return end
		remote:FireServer("puzzle", { panel = i, value = value })
		closeModal()
	end, { Size = UDim2.new(1, 0, 0, 42) })
	local t0 = os.clock()
	task.spawn(function()
		while not m.closed do
			local f = 1 - (os.clock() - t0) / Config.PUZZLE_SECONDS
			bar.Size = UDim2.new(math.max(f, 0), 0, 1, 0)
			bar.BackgroundColor3 = f < 0.3 and C.bad or (f < 0.6 and C.warn or C.good)
			if f <= 0 then remote:FireServer("puzzleFail", { panel = i }); closeModal() break end
			task.wait(0.1)
		end
	end)
end

---------------------------------------------------------------- Día 1
local function openThermostat()
	local m = openModal("Termostato de incubación")
	label(m.body, "Proyecto BioNutrients-2: la levadura modificada produce betacaroteno solo con su perfil de incubación correcto.", 14, C.dim)
	label(m.body, "Temperatura actual: " .. ((S and S.thermostat ~= "") and S.thermostat or "sin ajustar"), 15, C.accent, BOLD)
	local r = row(m.body, 46)
	for _, o in Config.Greenhouse.tempOptions do
		button(r, o.text, C.panel2, function()
			remote:FireServer("thermostat", { value = o.id }); closeModal()
		end, { Size = UDim2.new(0.333, -6, 1, 0), TextColor3 = C.text, TextSize = 18 })
	end
end

local function openFreezeQuiz()
	local m = openModal("Congelador MELFI · Validación del lote", 560)
	label(m.body, "Antes de congelar el lote para su regreso a la Tierra, confirma los requisitos de éxito de BioNutrients-2.", 14, C.dim)
	local answers = {}
	for i, q in Config.FreezeQuiz do
		label(m.body, q.q, 15, C.text, BOLD)
		local r = row(m.body, 36)
		local btns = {}
		for j, opt in q.options do
			btns[j] = button(r, opt, C.panel2, function()
				answers[i] = j
				for k, bb in btns do bb.BackgroundColor3 = k == j and C.accent or C.panel2; bb.TextColor3 = k == j and C.bg or C.text end
			end, { Size = UDim2.new(0.5, -4, 1, 0), TextColor3 = C.text })
		end
	end
	button(m.body, "Congelar y validar", C.good, function()
		for i = 1, #Config.FreezeQuiz do if not answers[i] then toast("Responde todos los requisitos.", "warn") return end end
		remote:FireServer("quiz", answers); closeModal()
	end, { Size = UDim2.new(1, 0, 0, 42) })
end

---------------------------------------------------------------- Día 2: tormenta y cinemática
local function openStorm()
	local m = openModal("⚠ Tormenta solar antes del desacople", 560)
	label(m.body, "El control de misión detecta una eyección de masa coronal. Las partículas cargadas pueden dañar la electrónica de la nave de carga.", 15, C.text)
	label(m.body, "• <b>Esperar</b>: la tormenta pasa, pero pierdes 30 segundos del día.\n• <b>Liberar igual</b>: 25 % de riesgo de perder la nave y el cargamento.", 15, C.dim)
	local r = row(m.body, 48)
	button(r, "Esperar (−30 s)", C.good, function() remote:FireServer("storm", { choice = "wait" }); closeModal() end, { Size = UDim2.new(0.5, -4, 1, 0) })
	button(r, "Liberar igual (25 % riesgo)", C.bad, function() remote:FireServer("storm", { choice = "risk" }); closeModal() end, { Size = UDim2.new(0.5, -4, 1, 0) })
end

local function playLaunch(info)
	closeModal()
	countdown.Visible = true
	countdown.Text = info.ignite and "¡DESACOPLE!" or "¡DESPEGUE!"
	task.delay(1.5, function() countdown.Visible = false end)
	if info.ignite then task.delay(info.ignite, function() sound("rbxasset://sounds/Rocket shot.wav", 0.8) end) else sound("rbxasset://sounds/Rocket shot.wav", 1) end
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local model = info.model
	local camPos = info.cam
	local last = model and model.Parent and model:GetPivot().Position or camPos + Vector3.new(0, 0, -60)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if model and model.Parent then last = model:GetPivot().Position + Vector3.new(0, info.lookUp or 12, 0) end
		local k = info.ignite and math.max(0, 1 - math.abs(t - info.ignite) / 1.5) * 0.4 or math.max(0, 1 - t / 5)
		local shake = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.2 * k
		cam.CFrame = CFrame.lookAt(camPos + shake, last)
		if t > (info.dur or (info.abort and 5.5 or 9.5)) then
			conn:Disconnect()
			cam.CameraType = Enum.CameraType.Custom
		end
	end)
end

---------------------------------------------------------------- Día 3
local function openCard(info)
	local m = openModal("✔ Paquete " .. info.pkg .. " listo", 520)
	label(m.body, ("<b>%s</b> · calidad %s · %d GB"):format(info.name, info.quality, info.gb), 17, info.quality == "alta" and C.good or C.warn, BOLD)
	label(m.body, "🛰  " .. info.card, 15, C.text)
	label(m.body, info.queued and "Ya está en la cola. Ahora apunta la antena en <b>Comunicaciones · ENLACE 03</b>." or "Ve a <b>Comunicaciones</b> y apunta la antena (ENLACE 03).", 14, C.dim)
	button(m.body, "Entendido", C.good, closeModal, { Size = UDim2.new(1, 0, 0, 42) })
end

local function openAntenna(info)
	local m = openModal("Apuntar antena", 520)
	local b = m.body
	label(b, "<b>1.</b> Pulsa los botones de <b>Acimut</b> y <b>Elevación</b> según indican las flechas ⬆️⬇️.\n<b>2.</b> Cuando la barra llegue a la marca amarilla y se ponga <font color=\"#6ef0aa\">verde</font> (≥ 3 dB), pulsa <b>Fijar apuntado</b>.", 15, C.text)
	local az, el = info.az, info.el
	local readout = label(b, "", 22, C.text, BOLD, { TextXAlignment = Enum.TextXAlignment.Center })
	local meterBg = new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = C.panel }, b); corner(meterBg, 6)
	local meter = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.bad }, meterBg); corner(meter, 6)
	new("Frame", { Size = UDim2.new(0, 3, 1, 6), Position = UDim2.new(3 / 9, 0, 0, -3), BackgroundColor3 = C.warn, BorderSizePixel = 0 }, meterBg)
	local dbText = label(b, "", 16, C.text, BOLD, { TextXAlignment = Enum.TextXAlignment.Center })
	local guide = label(b, "", 16, C.warn, BOLD, { TextXAlignment = Enum.TextXAlignment.Center })
	local function arrow(diff, up, down)
		if math.abs(diff) <= 2 then return "✔" end
		return diff > 0 and up or down
	end
	local function refresh()
		local margin = Config.linkMargin(az, el, info.taz, info.tel)
		readout.Text = ("Acimut <b>%d°</b> · Elevación <b>%d°</b>"):format(az, el)
		meter.Size = UDim2.new(math.clamp(margin / 9, 0, 1), 0, 1, 0)
		meter.BackgroundColor3 = margin >= 3 and C.good or (margin >= 0 and C.warn or C.bad)
		dbText.Text = ("Señal: %.1f dB %s"):format(margin, margin >= 3 and "✔ ¡Listo, fija el apuntado!" or "")
		dbText.TextColor3 = margin >= 3 and C.good or C.text
		guide.Text = ("Acimut %s    ·    Elevación %s"):format(arrow(info.taz - az, "⬆️ sube", "⬇️ baja"), arrow(info.tel - el, "⬆️ sube", "⬇️ baja"))
	end
	label(b, "Acimut", 14, C.accent, BOLD)
	local r1 = row(b, 38)
	for _, d in { -15, -5, -1, 1, 5, 15 } do
		button(r1, (d > 0 and "+" or "−") .. math.abs(d), C.panel2, function() az = (az + d) % 360; refresh() end, { Size = UDim2.new(1 / 6, -7, 1, 0), TextColor3 = C.text })
	end
	label(b, "Elevación", 14, C.accent, BOLD)
	local r2 = row(b, 38)
	for _, d in { -15, -5, -1, 1, 5, 15 } do
		button(r2, (d > 0 and "+" or "−") .. math.abs(d), C.panel2, function() el = math.clamp(el + d, 0, 90); refresh() end, { Size = UDim2.new(1 / 6, -7, 1, 0), TextColor3 = C.text })
	end
	refresh()
	button(b, "Fijar apuntado", C.good, function() remote:FireServer("antenna", { az = az, el = el }); closeModal() end, { Size = UDim2.new(1, 0, 0, 42) })
end

local function openQueue()
	local m = openModal("Cola de transmisión a la Tierra", 620, "queue")
	local content = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, m.body)
	list(content, 8)
	m.refresh = function()
		for _, c in content:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
		local d = S.d3
		local used = d.sentGB
		for _, id in d.queue do used += pkgOf(id).gb end
		label(content, ("<b>Enlace:</b> %d / 100 GB comprometidos · <b>Batería:</b> %d %% · Antena: %s"):format(used, math.floor(S.power), d.antennaOk and "✔ apuntada" or "✖ sin apuntar"), 14, C.text)
		for _, p in Config.Packages do
			local q = d.observed[p.id]
			local inQueue = nil
			for n, x in d.queue do if x == p.id then inQueue = n end end
			local sent = d.sent[p.id]
			local status, col
			if sent then status, col = ("✔ Enviado · +%d pts%s"):format(sent.points, sent.loss > 0 and (" · pérdida " .. math.floor(sent.loss * 100) .. " %") or ""), C.good
			elseif inQueue == 1 and d.progress > 0 then status, col = ("Transmitiendo %d / %d GB"):format(d.progress, p.gb), C.accent
			elseif inQueue then status, col = ("En cola #%d"):format(inQueue), C.accent
			elseif q then status, col = ("Observado · calidad %s"):format(q), C.text
			else status, col = "No observado (Laboratorio)", C.dim end
			local f = new("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = C.panel2 }, content)
			corner(f, 8)
			label(f, ("<b>%s · %s</b>\n%d GB · −%d %% batería · %d pts base\n<font color=\"#%s\">%s</font>"):format(p.id, p.name, p.gb, p.power, p.points, col:ToHex(), status), 13, C.text, MED,
				{ Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(0.68, 0, 1, -8), AutomaticSize = Enum.AutomaticSize.None })
			if not sent and q then
				if inQueue then
					button(f, "Quitar", C.bad, function() remote:FireServer("dequeue", { id = p.id }) end, { Position = UDim2.new(0.72, 0, 0.5, -17), Size = UDim2.new(0.26, 0, 0, 34) })
				else
					button(f, "Añadir a la cola", C.good, function() remote:FireServer("enqueue", { id = p.id }) end, { Position = UDim2.new(0.72, 0, 0.5, -17), Size = UDim2.new(0.26, 0, 0, 34) })
				end
			end
		end
		button(content, (d.filter and "✔ " or "☐ ") .. "Filtro de control de calidad (cantidad, calidad, continuidad y latencia) · más lento, sin pérdidas", d.filter and C.accent or C.panel2,
			function() remote:FireServer("filter", { on = not d.filter }) end, { Size = UDim2.new(1, 0, 0, 44), TextSize = 13, TextColor3 = d.filter and C.bg or C.text })
		label(content, "Se envía solo durante la ventana 📡. Sin filtro y con más de 85 GB puedes perder datos.", 13, C.dim)
	end
	m.refresh()
end

openHelp = function(day, section)
	local man = (Config.Manual and Config.Manual[day]) or {}
	local m = openModal("📖 Manual · " .. (S and S.dayName or ""), 600)
	local function header(t) label(m.body, t, 18, C.accent, BOLD) end
	local function symbols()
		header("🔣 Guía de símbolos del telescopio")
		local groups = {
			{ "Objetivo", Config.Icons.target, function(k) return k .. " · " .. Config.TargetShort[k] end, { "A", "B", "C", "D" } },
			{ "Longitud de onda", Config.Icons.w, function(k) return Config.nameOf(Config.Wavelengths, k) end, { "xray", "gamma", "optical", "uv", "ir", "micro" } },
			{ "Instrumento", Config.Icons.i, function(k) return Config.nameOf(Config.Instruments, k) end, { "camera", "spectro", "radiometer", "propcounter", "scint" } },
			{ "Óptica", Config.Icons.o, function(k) return Config.nameOf(Config.Optics, k) end, { "single", "segmented", "none" } },
		}
		for _, g in groups do
			label(m.body, g[1], 14, C.dim, BOLD)
			local grid = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, m.body)
			new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 40), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
			for i, k in g[4] do
				local cell = new("Frame", { BackgroundColor3 = C.panel, LayoutOrder = i }, grid)
				corner(cell, 8)
				label(cell, g[2][k] or "", 22, C.text, BOLD, { Size = UDim2.new(0, 42, 1, 0), AutomaticSize = Enum.AutomaticSize.None,
					TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
				label(cell, g[3](k), 14, C.text, MED, { Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -52, 1, 0),
					AutomaticSize = Enum.AutomaticSize.None, TextYAlignment = Enum.TextYAlignment.Center })
			end
		end
		label(m.body, "Cuando la combinación es correcta, las ranuras se iluminan en <font color=\"#6ef0aa\">verde</font>.", 13, C.dim)
	end
	if section == "symbols" and day == 3 then symbols() end
	if man.objetivo then header("🎯 Objetivo"); label(m.body, man.objetivo, 15, C.text) end
	header("🧭 Pasos")
	for i, t in Config.Help[day] or {} do label(m.body, ("<b>%d.</b> %s"):format(i, t), 15, C.text) end
	if man.datos then
		header("🛰 Datos de la NASA")
		for _, t in man.datos do label(m.body, "• " .. t, 14, C.dim) end
	end
	if day == 3 and section ~= "symbols" then symbols() end
	button(m.body, "Entendido", C.good, closeModal, { Size = UDim2.new(1, 0, 0, 42) })
end

---------------------------------------------------------------- pantallas completas
local overlay = nil
local ACCENTS = { ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú", ["ñ"] = "Ñ", ["ü"] = "Ü" }
local function upperEs(t)
	t = t:upper()
	for low, up in ACCENTS do t = t:gsub(low, up) end
	return t
end
local function showOverlay(title, lines, btnText, onBtn, accent, opts)
	opts = opts or {}
	accent = accent or C.accent
	if overlay then overlay:Destroy() end
	closeModal()
	overlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, ZIndex = 10 }, gui)
	local card = new("Frame", { Size = UDim2.new(0, 640, 0.84, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = C.bg, ZIndex = 11 }, overlay)
	new("UISizeConstraint", { MaxSize = Vector2.new(math.huge, 640), MinSize = Vector2.new(0, 380) }, card)
	corner(card, 14); stroke(card, accent)

	-- encabezado: título principal y subtítulo separados
	local main, sub = title:match("^(.-)%s*·%s*(.+)$")
	main = main or title
	local y = 24
	label(card, upperEs(main), 28, accent, BOLD, { Position = UDim2.fromOffset(24, y), Size = UDim2.new(1, -48, 0, 36),
		AutomaticSize = Enum.AutomaticSize.None, ZIndex = 12 })
	y += 38
	if sub then
		label(card, sub, 17, C.dim, MED, { Position = UDim2.fromOffset(24, y), Size = UDim2.new(1, -48, 0, 24),
			AutomaticSize = Enum.AutomaticSize.None, ZIndex = 12, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
		y += 28
	end
	y += 8
	new("Frame", { Size = UDim2.new(1, -48, 0, 1), Position = UDim2.fromOffset(24, y), BackgroundColor3 = C.line, BorderSizePixel = 0, ZIndex = 12 }, card)
	y += 16

	-- reputación y puntos en tarjetas
	if opts.stats and S then
		local row = new("Frame", { Size = UDim2.new(1, -48, 0, 60), Position = UDim2.fromOffset(24, y), BackgroundTransparency = 1, ZIndex = 12 }, card)
		list(row, 12, true)
		for _, st in { { "🛡️  REPUTACIÓN", S.rep }, { "🏆  PUNTOS", S.score } } do
			local f = new("Frame", { Size = UDim2.new(0.5, -6, 1, 0), BackgroundColor3 = C.panel, ZIndex = 12 }, row)
			corner(f, 10)
			label(f, st[1], 12, C.dim, MED, { Position = UDim2.fromOffset(14, 7), Size = UDim2.new(1, -28, 0, 16), AutomaticSize = Enum.AutomaticSize.None, ZIndex = 13 })
			label(f, tostring(st[2]), 24, C.text, BOLD, { Position = UDim2.fromOffset(14, 25), Size = UDim2.new(1, -28, 0, 28), AutomaticSize = Enum.AutomaticSize.None, ZIndex = 13 })
		end
		y += 60 + 16
	end

	-- contenido desplazable: una fila por resultado
	local footerH = btnText and 104 or 24
	local body = new("ScrollingFrame", { Size = UDim2.new(1, -48, 1, -(y + footerH)), Position = UDim2.fromOffset(24, y), BackgroundTransparency = 1,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5, BorderSizePixel = 0, ZIndex = 12 }, card)
	list(body, 10)
	new("UIPadding", { PaddingRight = UDim.new(0, 10) }, body)
	for i, l in lines do
		if type(l) == "table" then
			local r = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.panel,
				BackgroundTransparency = 0.25, LayoutOrder = i, ZIndex = 12 }, body)
			corner(r, 8); pad(r, 12)
			new("Frame", { Size = UDim2.new(0, 4, 1, 24), Position = UDim2.fromOffset(-12, -12), BackgroundColor3 = l.good and C.good or C.bad,
				BorderSizePixel = 0, ZIndex = 13 }, r)
			label(r, mark(l.good), 18, C.text, BOLD, { Size = UDim2.new(0, 24, 0, 22), AutomaticSize = Enum.AutomaticSize.None, ZIndex = 13 })
			label(r, l.text, 15, C.text, MED, { Position = UDim2.fromOffset(34, 1), Size = UDim2.new(1, -34, 0, 0), ZIndex = 13 })
		else
			label(body, l, 16, C.text, MED, { LayoutOrder = i, ZIndex = 12 })
		end
	end

	-- pie con el botón, abajo y separado del contenido
	if btnText then
		new("Frame", { Size = UDim2.new(1, -48, 0, 1), Position = UDim2.new(0, 24, 1, -(footerH - 14)), BackgroundColor3 = C.line, BorderSizePixel = 0, ZIndex = 12 }, card)
		button(card, btnText, accent, function() onBtn() end, { Size = UDim2.new(1, -48, 0, 52), AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -24), ZIndex = 12, Modal = true, TextSize = 18 })
	end
end
local function hideOverlay() if overlay then overlay:Destroy(); overlay = nil end end

local function daySummary()
	local r, d = S.res, S.day
	local lines = {}
	local x = r["d" .. d] or {}
	if d == 0 then
		table.insert(lines, { good = x.done == true, text = x.done and "Enlace de comunicaciones restablecido al 100 %" or "No completaste los 3 paneles de comunicaciones" })
		if x.done then table.insert(lines, { good = not x.late, text = x.late and "Lo lograste tarde: −5 reputación" or "A tiempo" }) end
		table.insert(lines, { good = x.optional == true, text = "Opcional: certificación de inhibidores" })
	elseif d == 1 then
		table.insert(lines, { good = (x.alive or 0) >= 3, text = ("Unidades vivas: %d de 4"):format(x.alive or 0) })
		table.insert(lines, { good = x.temp == "30", text = "Termostato en 30 °C (levadura)" })
		if x.tankEmpty then table.insert(lines, { good = false, text = "Agotaste el tanque PWD por sobrehidratar" }) end
		if x.early then table.insert(lines, { good = false, text = "Terminaste antes de la mitad de la incubación" }) end
		table.insert(lines, { good = x.optional == true, text = "Opcional: agitación y congelación en MELFI" })
	elseif d == 2 then
		if x.submitted then
			table.insert(lines, { good = x.ok == true, text = x.ok and ("Nave %s en camino a la base lunar: %d kg por %d cr"):format(string.lower(x.rocket or ""), x.total, x.cost) or "La tormenta solar dañó la nave: se perdió el cargamento" })
			table.insert(lines, { good = true, text = ("Revisiones RYG realizadas: %d"):format(x.tests or 0) })
		else
			table.insert(lines, { good = false, text = "No enviaste la nave de suministros" })
		end
		table.insert(lines, { good = x.optional == true, text = "Opcional: reserva del 10 % y margen de masa del 15 %" })
	end
	if x.bonus then table.insert(lines, { good = true, text = ("Bono de eficiencia: +%d puntos"):format(x.bonus) }) end
	return lines
end

local INTRO = {
	"Despiertas en la Sala de Comunicaciones de la Estación Aurora. Las luces están en rojo y el enlace con la Tierra está al 0 %.",
	"Cada día tiene tiempo limitado. Usa <b>E</b> (o la tecla indicada) cerca de los objetos para interactuar. Si completas lo obligatorio antes de tiempo, pulsa <b>Siguiente día ▶</b> y gana un bono de eficiencia.",
	"Tu <b>reputación</b> empieza en 50: si baja a 10 o menos, serás relevado del mando.",
	"<b>Día 0</b> · Repara los 3 paneles de enlace · <b>Día 1</b> · Invernadero BioNutrients · <b>Día 2</b> · Carga una nave de suministros por la escotilla y envíala a la base lunar · <b>Día 3</b> · Observa con el telescopio y transmite ciencia a la Tierra.",
}

---------------------------------------------------------------- objetivos
local function bar(parent, text, frac, col)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = C.panel }, parent); corner(f, 5)
	local fill = new("Frame", { Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0), BackgroundColor3 = col }, f); corner(fill, 5)
	label(f, text, 12, C.text, BOLD, { Size = UDim2.new(1, -10, 1, 0), Position = UDim2.new(0, 6, 0, 0), AutomaticSize = Enum.AutomaticSize.None, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 2 })
end

local function check(ok) return ok and '<font color="#6ef0aa">☑</font>' or '<font color="#8caabe">☐</font>' end
local function renderObjectives()
	for _, c in obj:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local d = S.day
	if d == 0 then
		for i = 1, 3 do label(obj, check(S.panels[i]) .. " " .. Config.Panels[i].title, 15) end
		label(obj, check(S.panels[4]) .. " <i>Opcional:</i> " .. Config.Panels[4].title .. " <font color=\"#ffc846\">(pared derecha)</font>", 13, C.dim)
		label(obj, "📍 Los paneles <b>ENLACE 01–03</b> están en la pared frontal de Comunicaciones. <b>Inhibidores</b> es el panel de servicio con letrero amarillo en la pared derecha. Sigue los marcadores.", 12, C.dim)
	elseif d == 1 then
		for i, u in S.units do
			local col = not u.alive and C.bad or (u.hyd < 30 and C.warn or (u.hyd > 80 and C.accent or C.good))
			bar(obj, ("Unidad %d · %s"):format(i, u.alive and (math.floor(u.hyd) .. " %") or "PERDIDA"), u.hyd / 100, col)
		end
		bar(obj, ("Tanque PWD · %d unidades de agua"):format(S.water), S.water / Config.Greenhouse.tank, Color3.fromRGB(60, 140, 220))
		label(obj, check(S.thermostat == "30") .. " Termostato: " .. (S.thermostat == "" and "sin ajustar" or (S.thermostat == "amb" and "Ambiente" or S.thermostat .. " °C")), 15)
		label(obj, "No riegues sobre 80 %: el agua se desperdicia. Mantén vivas ≥ 3 unidades hasta la luz amarilla (mitad de la incubación).", 12, C.dim)
		if S.alert then
			label(obj, check(S.agitated) .. " <i>Opcional:</i> agitar en la incubadora", 13, C.warn)
			label(obj, check(S.frozen) .. " <i>Opcional:</i> congelar en MELFI", 13, C.warn)
		end
	elseif d == 2 then
		local x = S.d2
		local kg = {}
		local minsOk = true
		for _, c in Config.Cargo do
			kg[c.id] = x.loaded[c.id] * Config.CRATE_KG
			if kg[c.id] < c.min then minsOk = false end
		end
		label(obj, "<b>Depósito de carga</b>", 13, C.accent)
		label(obj, check(minsOk) .. (" Mínimos: comida %d/80 · agua %d/60 · medicinas %d/40 kg"):format(kg.food, kg.water, kg.meds), 15)
		label(obj, check(S.mass >= 180) .. (" ≥ 180 kg en la bodega de la nave (llevas %d)"):format(S.mass), 15)
		if x.cart then label(obj, ("🛒 Carrito: %d/3 cajas · llévalas a la escotilla del muelle (E)"):format(#x.carry), 13, C.warn) elseif #x.carry > 0 then label(obj, "En mano: 1 caja · llévala a la escotilla del muelle (E)", 13, C.warn) end
		label(obj, "<b>Muelle de atraque</b> (al oeste)", 13, C.accent)
		label(obj, check(x.rocket ~= "" or x.result ~= "") .. " Pide una nave de carga en un pedestal", 15)
		label(obj, "• Trayectoria: " .. (x.orbit == "high" and "Rápida (+200 pts, −30 % capacidad)" or "Eficiente") .. " · palanca", 12, C.dim)
		label(obj, check(S.mass > 0 and not x.hatchOpen) .. " Abre la escotilla (E), carga y séllala (F)", 15)
		label(obj, check(x.tested) .. " Aprueba la revisión RYG (PROBAR)", 15)
		label(obj, check(x.result == "success") .. " Libera la nave en la consola (mantén F)", 15)
		label(obj, "<i>Opcional:</i> gasta ≤ 90 % del presupuesto y usa ≤ 85 % de la capacidad.", 12, C.dim)
	elseif d == 3 then
		local x = S.d3
		local anyObs = next(x.observed) ~= nil
		label(obj, check(anyObs) .. " 1. <b>Laboratorio:</b> arma el telescopio y OBSERVA", 15)
		label(obj, check(x.antennaOk) .. " 2. <b>Comunicaciones · ENLACE 03 (E):</b> sigue las flechas hasta que la barra esté verde y pulsa <b>Fijar</b>", 15)
		label(obj, check(x.transmitted >= 1) .. " 3. Espera la ventana 📡: se envía solo", 15)
		label(obj, check(x.filter and x.filterAll and not x.lossAny) .. " <i>Opcional:</i> filtro de calidad (ENLACE 02)", 13, C.dim)
		label(obj, "📖 Manual y guía de símbolos (tecla R en el telescopio).", 12, C.dim)
	end
end

local function renderOrbit()
	local x = S.d3
	local parts = {}
	table.insert(parts, x.sun and "☀ Sol (recarga)" or "🌑 Sombra")
	if x.contact then
		table.insert(parts, ("📡 CONTACTO · %d s"):format(Config.CONTACT_END - x.orbitT))
	else
		local wait = (Config.CONTACT_START - x.orbitT) % Config.ORBIT_PERIOD
		table.insert(parts, ("Próximo contacto en %d s"):format(wait))
	end
	table.insert(parts, x.antennaOk and ("Antena lista · %.1f dB"):format(x.margin) or "Antena sin apuntar")
	if x.current ~= "" then table.insert(parts, ("Enviando %s: %d/%d GB"):format(x.current, x.progress, pkgOf(x.current).gb)) end
	orbitText.Text = table.concat(parts, "   ·   ")
	orbitBar.BackgroundColor3 = x.contact and Color3.fromRGB(10, 50, 40) or C.bg
end

---------------------------------------------------------------- estado
---------------------------------------------------------------- marcadores de objetivos en el mundo
local markerFolder = new("Folder", { Name = "Marcadores" }, gui)
local markers = {}
local promptParts = {}
local function partFor(key)
	local p = promptParts[key]
	if p and p.Parent then return p end
	local station = workspace:FindFirstChild("EstacionAurora")
	if not station then return nil end
	for _, x in station:GetDescendants() do
		if x:IsA("ProximityPrompt") and x:GetAttribute("Key") == key then
			promptParts[key] = x.Parent
			return x.Parent
		end
	end
	return nil
end

local function wantedMarkers()
	local list = {}
	local function add(key, text, opt) table.insert(list, { key = key, text = text, opt = opt }) end
	local d = S.day
	if d == 0 then
		if not S.panels[1] then add("panel1", "ENLACE 01 · TNC") end
		if not S.panels[2] then add("panel2", "ENLACE 02 · UHF") end
		if not S.panels[3] then add("panel3", "ENLACE 03 · TLE") end
		if not S.panels[4] then add("panel4", "INHIBIDORES · opcional", true) end
	elseif d == 1 then
		for i, u in S.units do
			if u.alive and u.hyd <= Config.Greenhouse.wasteAbove then add("unit" .. i, ("CULTIVO %d · regar"):format(i)) end
		end
		if S.thermostat == "" then add("thermostat", "TERMOSTATO") end
		if S.alert and not S.agitated then add("agitate", "INCUBADORA · opcional", true) end
		if S.agitated and not S.quizDone then add("freeze", "CONGELADOR MELFI · opcional", true) end
	elseif d == 2 then
		local x = S.d2
		if x.result == "" then
			local minsOk = true
			for _, c in Config.Cargo do if x.loaded[c.id] * Config.CRATE_KG < c.min then minsOk = false end end
			if #x.carry > 0 then
				if x.rocket == "" then add("rocket_medium", "NAVES · pide una (E)")
				elseif x.docking then add("hatch", "ESCOTILLA · nave acoplándose…")
				else add("hatch", x.hatchOpen and "ESCOTILLA · cargar (E)" or "ESCOTILLA · abrir (E)") end
			elseif not minsOk then
				for _, c in Config.Cargo do
					if x.loaded[c.id] * Config.CRATE_KG < c.min then add("take_" .. c.id, Config.Crates[c.id].short:upper()) end
				end
			elseif x.rocket == "" then
				add("rocket_medium", "NAVES · pide una (E)")
			elseif x.hatchOpen then
				add("seal", "ESCOTILLA · cerrar y sellar (F)")
			elseif not x.tested then
				add("test", "PROBAR · revisión RYG")
			else
				add("launch", "CONSOLA · mantén F para liberar")
			end
		end
	elseif d == 3 then
		local x = S.d3
		local anyObs = next(x.observed) ~= nil
		if not anyObs then add("observe", "TELESCOPIO · laboratorio") end
		if not x.antennaOk then add("antenna", "ANTENA · ENLACE 03 · pulsa E") end
		if anyObs and x.antennaOk and #x.queue == 0 and x.transmitted == 0 then add("queue", "COLA DE TRANSMISIÓN") end
	end
	return list
end

local function updateMarkers()
	local want = {}
	if S and S.phase == "playing" and not S.paused and not S.userPaused then
		for _, m in wantedMarkers() do want[m.key] = m end
	end
	for key, mk in markers do
		if not want[key] or mk.text ~= want[key].text then mk.bb:Destroy() markers[key] = nil end
	end
	for key, m in want do
		if not markers[key] then
			local part = partFor(key)
			if part then
				local col = m.opt and C.warn or C.accent
				local bb = new("BillboardGui", { Name = key, Adornee = part, AlwaysOnTop = true, Size = UDim2.fromOffset(190, 44),
					StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0), MaxDistance = 250, LightInfluence = 0 }, markerFolder)
				local f = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BackgroundTransparency = 0.15 }, bb)
				corner(f, 8); stroke(f, col)
				local t = label(f, "", 13, col, BOLD, { Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None,
					TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
				markers[key] = { bb = bb, t = t, text = m.text, part = part }
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(0.25)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		for _, mk in markers do
			local dist = hrp and mk.part.Parent and math.floor((mk.part.Position - hrp.Position).Magnitude / 3.57 + 0.5) or 0
			mk.t.Text = ("📍 %s\n<font size=\"11\">%d m</font>"):format(mk.text, dist)
		end
	end
end)

local lastPhase, lastDay = nil, nil
local function render()
	local playing = S.phase == "playing"
	local showHud = S.phase ~= "intro"
	hud.Visible = showHud
	timerPanel.Visible = showHud
	leftCol.Visible = showHud
	trajesBtn.Visible = showHud
	objFrame.Visible = playing
	nextBtn.Visible = playing and S.canAdvance and not S.paused and not S.userPaused
	endBtn.Visible = playing and not S.canAdvance and not S.paused and not S.userPaused
	pauseBtn.Visible = playing
	langIntro.Visible = S.phase == "intro"
	if applyPause then applyPause(playing and S.userPaused == true) end
	orbitBar.Visible = playing and S.day == 3
	dayBig.Text = timerMin and ("DÍA %02d · %s"):format(S.day, fmtTime(S.timeLeft)) or ("DÍA: %02d"):format(S.day)
	dayBig.TextSize = timerMin and 22 or 28
	timeLbl.Text = ((S.paused or S.userPaused) and "EN PAUSA · " or "TIEMPO RESTANTE: ") .. fmtTime(S.timeLeft)
	timeLbl.TextColor3 = S.timeLeft <= 30 and C.bad or Color3.fromRGB(255, 120, 80)
	dayLabel.Text = S.dayName or ""
	chips.power.Text = math.floor(S.power) .. " %"
	chips.power.TextColor3 = S.power < 20 and C.bad or C.text
	chips.comms.Text = math.floor(S.comms) .. " %"
	chips.comms.TextColor3 = S.comms >= 100 and C.good or C.text
	if S.day == 2 and playing then
		chips.budget.Text = ("%d/%d cr"):format(S.cost, S.budget)
		chips.budget.TextColor3 = S.cost > S.budget and C.bad or C.text
	else
		chips.budget.Text = S.budget > 0 and (S.budget .. " cr") or "—"
		chips.budget.TextColor3 = C.text
	end
	chips.mass.Text = S.mass .. " kg"
	chips.data.Text = S.data .. " GB"
	chips.rep.Text = tostring(S.rep)
	chips.rep.TextColor3 = S.rep >= 70 and C.good or (S.rep >= 30 and C.text or C.bad)
	chips.score.Text = tostring(S.score)
	local mm = player.PlayerGui:FindFirstChild("AuroraMinimap")
	local sub = mm and mm:FindFirstChild("Cubierta", true)
	if sub and sub.Text ~= "PLANO DE CUBIERTA  /  11 SALAS" then sub.Text = ("COMUNICACIONES · %d %%"):format(math.floor(S.comms)) end
	if playing then renderObjectives() end
	updateMarkers()
	if playing and S.day == 3 then renderOrbit() end
	if modal and modal.kind == "queue" and modal.refresh and S.day == 3 then modal.refresh() end

	if S.phase ~= lastPhase or S.day ~= lastDay then
		lastPhase, lastDay = S.phase, S.day
		if S.phase == "intro" then
			showOverlay("ESTACIÓN AURORA", INTRO, "Comenzar Día 0", function() remote:FireServer("start") end)
		elseif S.phase == "playing" then
			hideOverlay()
			toast("📖 Consulta el Manual del día en el panel de Objetivos.")
		elseif S.phase == "dayEnd" then
			showOverlay("Fin del " .. (S.dayName or ""), daySummary(), "Continuar al Día " .. (S.day + 1) .. "  ▶", function() remote:FireServer("start") end, nil, { stats = true })
		elseif S.phase == "retired" then
			showOverlay("RELEVO DE MANDO", {
				"Tu reputación cayó a 10 o menos. El control de misión perdió la confianza en tu liderazgo y designó a un nuevo comandante para la Estación Aurora.",
			}, "Reiniciar partida", function() remote:FireServer("restart") end, C.bad, { stats = true })
		end
	end
end

---------------------------------------------------------------- menú de pausa
local pauseGui = new("ScreenGui", { Name = "AuroraPausa", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 8, Enabled = false }, player:WaitForChild("PlayerGui"))
new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Active = true }, pauseGui)
local pausePanel = new("Frame", { Size = UDim2.new(0, 380, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.bg, BackgroundTransparency = 0.04 }, pauseGui)
corner(pausePanel, 14); stroke(pausePanel, C.accent); pad(pausePanel, 22)
local ppl = list(pausePanel, 12); ppl.HorizontalAlignment = Enum.HorizontalAlignment.Center
label(pausePanel, "⏸  PAUSA", 30, C.accent, BOLD, { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 0) })
local pauseInfo = label(pausePanel, "", 14, C.dim, MED, { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 0) })
new("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = EDGE, BorderSizePixel = 0 }, pausePanel)
local function pauseButton(text, color, txtColor, onClick)
	return button(pausePanel, text, color, onClick, { Size = UDim2.new(1, 0, 0, 46), TextSize = 17, TextColor3 = txtColor or C.bg })
end
local function setPaused(on) remote:FireServer("pause", { on = on }) end
pauseButton("▶  Reanudar", C.good, nil, function() setPaused(false) end)
pauseButton("📖  Manual del día", C.warn, nil, function()
	if not (S and openHelp) then return end
	pauseGui.Enabled = false
	openHelp(S.day)
	task.spawn(function()
		while modal and not modal.closed do task.wait(0.2) end
		if S and S.userPaused then pauseGui.Enabled = true end
	end)
end)
local pauseMusic
pauseMusic = pauseButton("", C.panel2, C.text, function() setMusic(not musicOn); pauseMusic.Text = musicOn and "🔊  Música: activada" or "🔇  Música: desactivada" end)
local langPause = pauseButton("", C.panel2, C.text, function() setLang(curLang() == "es" and "en" or "es") end)
local function syncLang()
	local en = curLang() == "en"
	langMini.Text = en and "ES" or "EN"
	langIntro.Text = en and "🌐 Español" or "🌐 English"
	langPause.Text = en and "🌐  Idioma: Inglés" or "🌐  Idioma: Español"
end
syncLang()
player:GetAttributeChangedSignal("AuroraIdioma"):Connect(syncLang)
local restartBtn
restartBtn = pauseButton("🔄  Reiniciar partida", C.panel2, C.bad, function()
	if restartBtn:GetAttribute("Armed") then
		restartBtn:SetAttribute("Armed", false)
		remote:FireServer("restart")
	else
		restartBtn:SetAttribute("Armed", true); restartBtn.Text = "¿Seguro? Se pierde el progreso · Confirmar"
		task.delay(3, function() restartBtn:SetAttribute("Armed", false); restartBtn.Text = "🔄  Reiniciar partida" end)
	end
end)
label(pausePanel, "Tecla <b>P</b> para pausar o reanudar", 12, C.dim, MED, { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 0) })

-- congela al personaje mientras la partida está en pausa
local shownPause = false
local savedMove = nil
function applyPause(on)
	if on == shownPause then return end
	shownPause = on
	pauseGui.Enabled = on
	pauseBtn.Text = on and "▶" or "⏸"
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if on then
		closeModal()
		pauseInfo.Text = ("El tiempo del %s está detenido (%s restantes)."):format(S and ("Día " .. S.day) or "día", fmtTime(S and S.timeLeft or 0))
		pauseMusic.Text = musicOn and "🔊  Música: activada" or "🔇  Música: desactivada"
		music.Volume = MUSIC_VOL * 0.5
		if hum then
			savedMove = { ws = hum.WalkSpeed, jp = hum.JumpPower, jh = hum.JumpHeight }
			hum.WalkSpeed = 0; hum.JumpPower = 0; hum.JumpHeight = 0
		end
	else
		music.Volume = MUSIC_VOL
		if hum and savedMove then hum.WalkSpeed = savedMove.ws; hum.JumpPower = savedMove.jp; hum.JumpHeight = savedMove.jh end
		savedMove = nil
	end
end
pauseBtn.MouseButton1Click:Connect(function() if S and S.phase == "playing" and not S.paused then setPaused(not S.userPaused) end end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.P then return end
	if S and S.phase == "playing" and not S.paused then setPaused(not S.userPaused) end
end)

remote.OnClientEvent:Connect(function(kind, a, b)
	if kind == "state" then
		S = a
		render()
		if S.phase ~= "playing" and modal then closeModal() end
	elseif kind == "toast" then
		toast(a, b)
	elseif kind == "countdown" then
		countdown.Visible = true
		countdown.Text = "T−" .. a
		sound("rbxasset://sounds/electronicpingshort.wav", 0.5)
	elseif kind == "launch" then
		playLaunch(a)
	elseif kind == "open" and S and S.phase == "playing" then
		if a == "puzzle" then openPuzzle(b)
		elseif a == "thermostat" then openThermostat()
		elseif a == "freezeQuiz" then openFreezeQuiz()
		elseif a == "storm" then openStorm()
		elseif a == "card" then openCard(b)
		elseif a == "antenna" then openAntenna(b)
		elseif a == "queue" then openQueue()
		elseif a == "manual" then if openHelp then openHelp(S.day, b) end end
	elseif kind == "report" then
		local lines = {}
		for _, l in a do table.insert(lines, l) end
		local rating = S.rep >= 70 and "Comandante sobresaliente" or (S.rep >= 30 and "Misión cumplida" or "Misión con observaciones")
		showOverlay("INFORME FINAL · " .. rating, lines, "Jugar de nuevo", function() remote:FireServer("restart") end, C.good, { stats = true })
	end
end)

remote:FireServer("hello")
