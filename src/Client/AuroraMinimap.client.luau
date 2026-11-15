local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local colors = {
    panel = Color3.fromRGB(9, 17, 28),
    map = Color3.fromRGB(10, 24, 36),
    edge = Color3.fromRGB(53, 83, 104),
    text = Color3.fromRGB(229, 244, 253),
    muted = Color3.fromRGB(166, 192, 209),
    player = Color3.fromRGB(255, 255, 255),
    route = Color3.fromRGB(255, 226, 125),
    mission = Color3.fromRGB(91, 219, 255),
    view = Color3.fromRGB(129, 245, 194),
    logistics = Color3.fromRGB(226, 174, 118),
    science = Color3.fromRGB(144, 205, 216),
    service = Color3.fromRGB(186, 177, 234),
}

-- Snapshot of the room decks. All rooms remain on the map with StreamingEnabled.
local rooms = {
    {id = "DockingBay", x = -135, z = 0, w = 66, d = 58, short = "Muelle", name = "Muelle de atraque", detail = "Escotilla exterior y zona de atraque.", tone = "logistics"},
    {id = "CargoBay", x = -60, z = 0, w = 52, d = 46, short = "Carga", name = "Depósito de carga", detail = "Contenedores de suministros.", tone = "logistics"},
    {id = "CommsRoom", x = 0, z = 0, w = 40, d = 40, short = "Enlace", name = "Comunicaciones", detail = "Tres paneles de enlace con la Tierra.", tone = "mission"},
    {id = "CommandRoom", x = 44, z = 0, w = 40, d = 40, short = "Mando", name = "Centro de mando", detail = "Punto de aparición y consola de misión.", tone = "mission"},
    {id = "GreenhouseRoom", x = 88, z = 0, w = 40, d = 40, short = "Cultivo", name = "Invernadero", detail = "Cuatro cultivos y una incubadora.", tone = "mission"},
    {id = "ScienceLab", x = 147, z = 0, w = 50, d = 44, short = "Lab.", name = "Laboratorio", detail = "Mesas de instrumentos y de muestras.", tone = "science"},
    {id = "ObservationDeck", x = 222, z = 0, w = 64, d = 54, short = "Mirador", name = "Mirador orbital", detail = "Vista a la Tierra y placa sobre los 16 amaneceres.", tone = "view"},
    {id = "CrewQuarters", x = -16, z = 61, w = 48, d = 44, short = "Literas", name = "Alojamiento", detail = "Zona de descanso de la tripulación.", tone = "service"},
    {id = "ServiceHub", x = 44, z = 61, w = 40, d = 44, short = "Nodo", name = "Nodo de servicio", detail = "Cruce hacia alojamiento, reserva e ingeniería.", tone = "service"},
    {id = "ReserveModule", x = 108, z = 61, w = 48, d = 44, short = "Reserva", name = "Módulo de reserva", detail = "Sala libre para futuras ampliaciones.", tone = "service"},
    {id = "EngineeringBay", x = 44, z = 132, w = 54, d = 54, short = "Energía", name = "Ingeniería", detail = "Equipo de potencia de la estación.", tone = "logistics"},
}
local connections = {
    {"DockingBay", "CargoBay"},
    {"CargoBay", "CommsRoom"},
    {"CommsRoom", "CommandRoom"},
    {"CommandRoom", "GreenhouseRoom"},
    {"GreenhouseRoom", "ScienceLab"},
    {"ScienceLab", "ObservationDeck"},
    {"CommandRoom", "ServiceHub"},
    {"CrewQuarters", "ServiceHub"},
    {"ServiceHub", "ReserveModule"},
    {"ServiceHub", "EngineeringBay"},
}

local pointsOfInterest = {
    CommsRoom = {caption = "Paneles de enlace", glyph = "◆"},
    CommandRoom = {caption = "Consola de misión", glyph = "◆"},
    GreenhouseRoom = {caption = "Cultivos e incubadora", glyph = "◆"},
    CargoBay = {caption = "Suministros", glyph = "◆"},
    ObservationDeck = {caption = "Observación orbital", glyph = "◆"},
}
local compactNames = {
    CommsRoom = "Com.", CommandRoom = "Mdo.", GreenhouseRoom = "Cult.",
    CrewQuarters = "Lit.", ReserveModule = "Res.", EngineeringBay = "Ing.",
}

local minX, maxX = -181, 269
local minZ, maxZ = -53, 170
local function position(x, z)
    return UDim2.fromScale((x - minX) / (maxX - minX), (z - minZ) / (maxZ - minZ))
end

local function create(class, parent, properties)
    local item = Instance.new(class)
    for property, value in pairs(properties) do
        item[property] = value
    end
    item.Parent = parent
    return item
end

local function rounded(item, radius)
    create("UICorner", item, {CornerRadius = UDim.new(0, radius)})
end

local function stroke(item, name, color)
    return create("UIStroke", item, {Name = name, Color = color, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end

local function label(parent, name, body, size, color, font)
    return create("TextLabel", parent, {
        Name = name, Text = body, TextSize = size, TextColor3 = color,
        Font = font or Enum.Font.GothamMedium, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

local gui = create("ScreenGui", player:WaitForChild("PlayerGui"), {
    Name = "AuroraMinimap", ResetOnSpawn = false, DisplayOrder = 8,
})
local scrim = create("TextButton", gui, {
    Name = "Cerrar plano", Size = UDim2.fromScale(1, 1), Text = "",
    BackgroundColor3 = Color3.fromRGB(2, 8, 16), BackgroundTransparency = 0.31,
    AutoButtonColor = false, Visible = false, BorderSizePixel = 0,
    Selectable = false, ZIndex = 0,
})
local panel = create("Frame", gui, {
    Name = "Mapa", AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = colors.panel,
    BorderSizePixel = 0, Position = UDim2.new(1, -14, 0, 12),
})
rounded(panel, 10)
stroke(panel, "Contorno", colors.edge)
local cap = create("Frame", panel, {
    Name = "Acabado", BorderSizePixel = 0, BackgroundColor3 = colors.mission,
    Position = UDim2.fromOffset(15, 0), Size = UDim2.fromOffset(35, 2),
})
rounded(cap, 1)

local title = label(panel, "Título", "AURORA", 16, colors.text, Enum.Font.GothamBold)
title.Position = UDim2.fromOffset(14, 8)
title.Size = UDim2.new(1, -105, 0, 19)
title.TextTruncate = Enum.TextTruncate.AtEnd

local subtitle = label(panel, "Cubierta", "PLANO DE CUBIERTA", 9, colors.mission, Enum.Font.Code)
subtitle.Position = UDim2.fromOffset(14, 28)
subtitle.Size = UDim2.new(1, -103, 0, 11)
subtitle.TextTruncate = Enum.TextTruncate.AtEnd

local toggle = create("TextButton", panel, {
    Name = "Cambiar vista", AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -9, 0, 9), Size = UDim2.fromOffset(80, 29),
    Text = "Ampliar", TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = colors.text,
    BackgroundColor3 = Color3.fromRGB(17, 34, 50), BorderSizePixel = 0,
})
rounded(toggle, 5)
stroke(toggle, "Contorno", colors.edge)
local toggleX = {}
for _, r in { 45, -45 } do
    local line = Instance.new("Frame")
    line.Name = "LineaX"; line.AnchorPoint = Vector2.new(0.5, 0.5); line.Position = UDim2.fromScale(0.5, 0.5)
    line.Size = UDim2.new(0, 14, 0, 2); line.Rotation = r; line.BorderSizePixel = 0
    line.BackgroundColor3 = colors.text; line.Visible = false; line.Parent = toggle
    table.insert(toggleX, line)
end

local minimized = false
local minBtn = create("TextButton", panel, {
    Name = "Minimizar", AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -6, 0, 8), Size = UDim2.fromOffset(26, 23),
    Text = "–", TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = colors.text,
    BackgroundColor3 = Color3.fromRGB(17, 34, 50), BorderSizePixel = 0,
})
rounded(minBtn, 5)
stroke(minBtn, "Contorno", colors.edge)

local map = create("Frame", panel, {
    Name = "Plano", Position = UDim2.fromOffset(8, 47), BackgroundColor3 = colors.map,
    BorderSizePixel = 0, ClipsDescendants = true,
})
rounded(map, 5)
stroke(map, "Marco", Color3.fromRGB(33, 59, 77))
create("UIGradient", map, {
    Color = ColorSequence.new(Color3.fromRGB(224, 238, 255), Color3.fromRGB(131, 168, 193)),
    Rotation = 90,
})
local gridColor = Color3.fromRGB(45, 106, 132)
for x = -160, 250, 20 do
    create("Frame", map, {
        Name = "Meridiano", BackgroundColor3 = gridColor, BackgroundTransparency = 0.79,
        Position = position(x, minZ), Size = UDim2.new(0, 1, 1, 0), BorderSizePixel = 0,
    })
end
for z = -40, 160, 20 do
    create("Frame", map, {
        Name = "Paralelo", BackgroundColor3 = gridColor, BackgroundTransparency = 0.79,
        Position = position(minX, z), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0,
    })
end

local compass = label(map, "Norte", "↑ N", 11, colors.muted, Enum.Font.Code)
compass.AnchorPoint = Vector2.new(1, 1)
compass.Position = UDim2.new(1, -8, 1, -6)
compass.Size = UDim2.fromOffset(30, 15)
compass.TextXAlignment = Enum.TextXAlignment.Right
compass.ZIndex = 2

local currentLabel = label(panel, "Ubicación", "Ubicando…", 12, colors.text, Enum.Font.GothamBold)
currentLabel.TextTruncate = Enum.TextTruncate.AtEnd
local detail = label(panel, "Detalle", "◆  Punto de interés", 11, colors.muted)
detail.TextTruncate = Enum.TextTruncate.AtEnd
local description = label(panel, "Descripción", "", 13, colors.muted)
description.TextWrapped = true
description.TextYAlignment = Enum.TextYAlignment.Top
local locationDot = create("Frame", panel, {
    Name = "Indicador de ubicación", Size = UDim2.fromOffset(6, 6),
    BackgroundColor3 = colors.mission, BorderSizePixel = 0,
})
rounded(locationDot, 3)

local byId = {}
local edges = {}
local selected
local currentRoom
local lastRoom
local expanded = false
local buttons = {}
for _,room in ipairs(rooms) do
    byId[room.id] = room
    room.edges = {}
    local poi = pointsOfInterest[room.id]
    local fill = colors.map:Lerp(colors[room.tone], poi and 0.25 or 0.12)
    local cell = create("TextButton", map, {
        Name = room.name, Text = "", BorderSizePixel = 0,
        TextSize = 11, Font = Enum.Font.GothamBold, AutoButtonColor = false,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = position(room.x, room.z),
        Size = UDim2.fromScale(room.w / (maxX - minX), room.d / (maxZ - minZ)),
        BackgroundColor3 = fill, ZIndex = 3, TextTruncate = Enum.TextTruncate.AtEnd,
        SelectionOrder = #buttons + 1,
    })
    rounded(cell, 3)
    local nameLabel = label(cell, "Nombre", room.short, 11, colors.text, Enum.Font.GothamBold)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Position = UDim2.new(0, 2, poi and 0.61 or 0.5, 0)
    nameLabel.AnchorPoint = Vector2.new(0, 0.5)
    nameLabel.Size = UDim2.new(1, -4, 0, 14)
    nameLabel.ZIndex = 5
    room.nameLabel = nameLabel
    if poi then
        local glyph = label(cell, "Punto de interés", poi.glyph, 10, colors[room.tone], Enum.Font.GothamBold)
        glyph.Position = UDim2.fromScale(0.5, 0.29)
        glyph.AnchorPoint = Vector2.new(0.5, 0.5)
        glyph.Size = UDim2.fromOffset(16, 13)
        glyph.TextXAlignment = Enum.TextXAlignment.Center
        glyph.ZIndex = 5
        room.glyph = glyph
    end
    room.button = cell
    room.fill = fill
    room.outline = stroke(cell, "Zona", colors[room.tone]:Lerp(colors.edge, poi and 0.33 or 0.68))
    table.insert(buttons, cell)
end

for _,pair in ipairs(connections) do
    local a, b = byId[pair[1]], byId[pair[2]]
    local horizontal = a.z == b.z
    local gap = horizontal and (math.abs(a.x - b.x) - (a.w + b.w) / 2)
        or (math.abs(a.z - b.z) - (a.d + b.d) / 2)
    local startX, startZ, endX, endZ = a.x, a.z, b.x, b.z
    if horizontal then
        local direction = math.sign(b.x - a.x)
        startX, endX = a.x + direction * a.w / 2, b.x - direction * b.w / 2
    else
        local direction = math.sign(b.z - a.z)
        startZ, endZ = a.z + direction * a.d / 2, b.z - direction * b.d / 2
    end
    local line = create("Frame", map, {
        Name = a.short .. " a " .. b.short, BorderSizePixel = 0,
        BackgroundColor3 = colors.edge, ZIndex = 2, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = position((startX + endX) / 2, (startZ + endZ) / 2),
        Size = UDim2.fromScale((horizontal and gap + 2 or 8) / (maxX - minX),
            (horizontal and 8 or gap + 2) / (maxZ - minZ)),
    })
    local centerline = create("Frame", map, {
        Name = "Tramo de ruta", BorderSizePixel = 0, BackgroundColor3 = colors.route,
        ZIndex = 4, Visible = false, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = line.Position,
        Size = horizontal and UDim2.new((gap + 3) / (maxX - minX), 0, 0, 2)
            or UDim2.new(0, 2, (gap + 3) / (maxZ - minZ), 0),
    })
    local edge = {a = a.id, b = b.id, line = line, centerline = centerline}
    table.insert(a.edges, edge)
    table.insert(b.edges, edge)
    table.insert(edges, edge)
end

local marker = create("Frame", map, {
    Name = "Jugador", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
    BorderSizePixel = 0, Size = UDim2.fromOffset(15, 15), Visible = false, ZIndex = 7,
})
local halo = create("Frame", marker, {
    Name = "Halo", Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(10, 23, 34), BackgroundTransparency = 0.05,
    BorderSizePixel = 0, ZIndex = 7,
})
rounded(halo, 9)
stroke(halo, "Contorno", colors.player)
local arrow = label(marker, "Dirección", "▲", 11, colors.player, Enum.Font.GothamBold)
arrow.Size = UDim2.fromScale(1, 1)
arrow.Position = UDim2.fromOffset(0, -1)
arrow.TextXAlignment = Enum.TextXAlignment.Center
arrow.TextStrokeTransparency = 0.1
arrow.TextStrokeColor3 = colors.panel
arrow.ZIndex = 8

local function route(from, to)
    local path = {}
    local visited = {}
    local roomsOnRoute = {}
    local function find(id)
        if id == to then return true end
        visited[id] = true
        for _,edge in ipairs(byId[id].edges) do
            local nextId = edge.a == id and edge.b or edge.a
            if not visited[nextId] and find(nextId) then
                path[edge] = true
                roomsOnRoute[nextId] = true
                return true
            end
        end
        return false
    end
    if from and to then find(from) end
    return path, roomsOnRoute
end

local function refresh()
    local from = currentRoom or lastRoom
    local activeRoute, roomsOnRoute = route(from, selected)
    for _,edge in ipairs(edges) do
        edge.centerline.Visible = activeRoute[edge] == true
        edge.line.BackgroundColor3 = activeRoute[edge] and colors.edge:Lerp(colors.route, 0.37) or colors.edge
    end
    for _,room in ipairs(rooms) do
        local target = room.id == selected
        local here = room.id == currentRoom
        local poi = pointsOfInterest[room.id]
        room.button.BackgroundColor3 = target and colors.map:Lerp(colors.route, 0.34)
            or here and room.fill:Lerp(colors.player, 0.12) or room.fill
        room.nameLabel.TextColor3 = target and colors.route or (poi or here) and colors.text or colors.muted
        if room.glyph then room.glyph.TextColor3 = target and colors.route or colors[room.tone] end
        room.outline.Color = target and colors.route or here and colors.player
            or roomsOnRoute[room.id] and colors.route:Lerp(colors.edge, 0.47)
            or colors[room.tone]:Lerp(colors.edge, poi and 0.33 or 0.68)
        room.outline.Thickness = (target or here) and 1.5 or 1
    end
    currentLabel.Text = currentRoom and byId[currentRoom].name or (lastRoom and "En un pasillo" or "Ubicando…")
    currentLabel.Visible = expanded or selected == nil
    detail.Visible = expanded or selected ~= nil
    locationDot.BackgroundColor3 = (not expanded and selected) and colors.route or colors.mission
    if selected then
        local destination = byId[selected]
        local poi = pointsOfInterest[selected]
        detail.Text = selected == currentRoom and ("Llegaste · " .. destination.name) or ("Ruta a " .. destination.name)
        detail.TextColor3 = colors.route
        description.Text = poi and (poi.caption .. " · " .. destination.detail) or destination.detail
    else
        detail.Text = expanded and "Elige una sala para trazar la ruta." or "◆  Punto de interés"
        detail.TextColor3 = colors.muted
        description.Text = "◆  Punto de interés     ·     Flecha blanca: tu posición"
    end
end

for _,room in ipairs(rooms) do
    room.button.Activated:Connect(function()
        selected = selected ~= room.id and room.id or nil
        refresh()
    end)
end

local function layout()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = gui.AbsoluteSize
    if viewport.X < 100 or viewport.Y < 100 then viewport = camera.ViewportSize end
    local compactWidth = UserInputService.TouchEnabled and 168 or 192
    local idealWidth = expanded and 720 or compactWidth
    local footerHeight = expanded and 89 or 25
    local headerHeight = expanded and 47 or 46
    local availableHeight = viewport.Y - headerHeight - footerHeight - 36
    local heightLimit = math.max(140, availableHeight * (maxX - minX) / (maxZ - minZ) + 16)
    local width = math.floor(math.min(viewport.X - 28, idealWidth, heightLimit))
    local mapHeight = math.floor((width - 16) * (maxZ - minZ) / (maxX - minX))
    panel.AnchorPoint = expanded and Vector2.new(0.5, 0.5) or Vector2.new(1, 1)
    panel.Position = expanded and UDim2.fromScale(0.5, 0.5) or UDim2.new(1, -14, 1, -14)
    panel.Size = UDim2.fromOffset(width, headerHeight + mapHeight + footerHeight)
    minBtn.Visible = not expanded
    panel.ClipsDescendants = minimized and not expanded
    if minimized and not expanded then panel.Size = UDim2.fromOffset(width, headerHeight) end
    title.Position = UDim2.fromOffset(expanded and 14 or 10, 8)
    title.TextSize = expanded and 16 or 12
    title.Size = UDim2.new(1, expanded and -105 or -80, 0, 19)
    subtitle.Visible = true
    toggle.Size = expanded and UDim2.fromOffset(32, 29) or UDim2.fromOffset(59, 23)
    toggle.Position = UDim2.new(1, expanded and -9 or -38, 0, expanded and 9 or 8)
    toggle.TextSize = expanded and 12 or 10
    map.Position = UDim2.fromOffset(8, headerHeight)
    gui.DisplayOrder = expanded and 30 or 8
    scrim.Visible = expanded
    map.Size = UDim2.new(1, -16, 0, mapHeight)
    local footerTop = headerHeight + mapHeight
    locationDot.Position = UDim2.fromOffset(14, footerTop + 12)
    currentLabel.Position = UDim2.fromOffset(26, footerTop + (expanded and 7 or 6))
    currentLabel.Size = UDim2.new(1, -36, 0, 17)
    currentLabel.TextSize = expanded and 12 or 10
    detail.Position = expanded and UDim2.fromOffset(14, footerTop + 25) or UDim2.fromOffset(26, footerTop + 6)
    detail.TextSize = expanded and 11 or 10
    detail.Size = UDim2.new(1, expanded and -28 or -36, 0, 16)
    description.Position = UDim2.fromOffset(14, footerTop + 46)
    description.Size = UDim2.new(1, -28, 0, 38)
    description.Visible = expanded
    compass.Visible = expanded
    marker.Size = expanded and UDim2.fromOffset(15, 15) or UDim2.fromOffset(11, 11)
    arrow.TextSize = expanded and 11 or 8
    toggle.Text = expanded and "" or "AMPLIAR"
    for _, line in toggleX do line.Visible = expanded end
    subtitle.Text = expanded and "PLANO DE CUBIERTA  /  11 SALAS" or "COMUNICACIONES"
    for _,room in ipairs(rooms) do
        room.nameLabel.Visible = expanded
        room.nameLabel.Text = width < 370 and (compactNames[room.id] or room.short) or room.short
        room.nameLabel.TextSize = width < 275 and 7 or width < 370 and 8 or width >= 570 and 13 or 10
        if room.glyph then
            room.glyph.Position = UDim2.fromScale(0.5, expanded and 0.29 or 0.5)
            room.glyph.TextSize = expanded and (width >= 570 and 14 or 10) or 8
        end
    end
    refresh()
end

local cameraConnection
local function bindCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    if workspace.CurrentCamera then
        cameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
    end
    layout()
end
local function toggleSize()
    expanded = not expanded
    layout()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
toggle.Activated:Connect(toggleSize)
scrim.Activated:Connect(toggleSize)
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.M then toggleSize() end
end)
bindCamera()

local function findRoom(point)
    for _,room in ipairs(rooms) do
        if math.abs(point.X - room.x) <= room.w / 2 and math.abs(point.Z - room.z) <= room.d / 2 then
            return room.id
        end
    end
    return nil
end

local function updatePlayerMarker()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        marker.Visible = false
        if currentRoom or lastRoom then
            currentRoom = nil
            lastRoom = nil
            refresh()
        end
        return
    end
    local point = root.Position
    marker.Visible = point.X >= minX and point.X <= maxX and point.Z >= minZ and point.Z <= maxZ
        and math.abs(point.Y - 3) < 20
    if marker.Visible then
        marker.Position = position(point.X, point.Z)
        local heading = root.CFrame.LookVector
        arrow.Rotation = math.deg(math.atan2(heading.X, -heading.Z))
    end
    local id = marker.Visible and findRoom(point) or nil
    if id ~= currentRoom then
        currentRoom = id
        lastRoom = id or (marker.Visible and lastRoom or nil)
        refresh()
    elseif not marker.Visible and lastRoom then
        lastRoom = nil
        refresh()
    end
end
RunService.RenderStepped:Connect(updatePlayerMarker)

minBtn.Activated:Connect(function()
    minimized = not minimized
    minBtn.Text = minimized and "+" or "–"
    layout()
end)
