-- Estación Aurora · cambia todos los textos visibles a inglés cuando el jugador lo elige.
-- Guarda el texto original (español) de cada etiqueta, botón y aviso de interacción y muestra su traducción.
local Players = game:GetService("Players")
local I = require(game:GetService("ReplicatedStorage"):WaitForChild("Aurora"):WaitForChild("AuroraIdioma"))
local player = Players.LocalPlayer
local lang = player:GetAttribute("AuroraIdioma") or "es"

local PROPS = { TextLabel = { "Text" }, TextButton = { "Text" }, ProximityPrompt = { "ActionText", "ObjectText" } }
local tracked = setmetatable({}, { __mode = "k" })

local function show(obj, prop, rec)
	local out = lang == "en" and I.toEnglish(rec.src) or rec.src
	rec.shown = out
	if obj[prop] ~= out then obj[prop] = out end
end

local function track(obj)
	local props = PROPS[obj.ClassName]
	if not props or tracked[obj] then return end
	local t = {}
	tracked[obj] = t
	for _, prop in props do
		local rec = { src = obj[prop], shown = obj[prop] }
		t[prop] = rec
		obj:GetPropertyChangedSignal(prop):Connect(function()
			local cur = obj[prop]
			if cur == rec.shown then return end
			rec.src = cur
			show(obj, prop, rec)
		end)
		if lang == "en" then show(obj, prop, rec) end
	end
end

local function watch(root)
	for _, d in root:GetDescendants() do track(d) end
	root.DescendantAdded:Connect(track)
end
watch(player:WaitForChild("PlayerGui"))
watch(workspace)

player:GetAttributeChangedSignal("AuroraIdioma"):Connect(function()
	lang = player:GetAttribute("AuroraIdioma") or "es"
	for obj, t in tracked do
		if obj.Parent then
			for prop, rec in t do
				-- si el texto cambió y su evento aún no llegó, tomarlo como nuevo original
				local cur = obj[prop]
				if cur ~= rec.shown then rec.src = cur end
				show(obj, prop, rec)
			end
		end
	end
end)
