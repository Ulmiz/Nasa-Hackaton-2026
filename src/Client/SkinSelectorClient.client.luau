local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local requestEvent = ReplicatedStorage:WaitForChild("SkinSelectionRequest")

local navy = Color3.fromRGB(7, 17, 35)
local panelColor = Color3.fromRGB(12, 27, 48)
local buttonColor = Color3.fromRGB(20, 43, 68)
local accent = Color3.fromRGB(56, 196, 255)
local textColor = Color3.fromRGB(235, 245, 255)
local mutedText = Color3.fromRGB(155, 181, 201)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkinSelector"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 20
screenGui.Parent = player:WaitForChild("PlayerGui")

local openButton = Instance.new("TextButton")
openButton.Name = "OpenSkinSelector"
openButton.AnchorPoint = Vector2.new(0, 1)
openButton.Position = UDim2.new(0, 24, 1, -22)
openButton.Size = UDim2.fromOffset(154, 46)
openButton.BackgroundColor3 = accent
openButton.Text = "TRAJES"
openButton.TextColor3 = navy
openButton.TextSize = 14
openButton.Font = Enum.Font.GothamBold
openButton.AutoButtonColor = true
openButton.Parent = screenGui

local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(0, 12)
openCorner.Parent = openButton

local panel = Instance.new("Frame")
panel.Name = "SkinPanel"
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 24, 1, -80)
panel.Size = UDim2.fromOffset(286, 204)
panel.BackgroundColor3 = panelColor
panel.Visible = false
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = accent
panelStroke.Transparency = 0.35
panelStroke.Thickness = 1.5
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(18, 14)
title.Size = UDim2.new(1, -68, 0, 24)
title.BackgroundTransparency = 1
title.Text = "SELECCIONA TU SKIN"
title.TextColor3 = textColor
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.Position = UDim2.new(1, -42, 0, 10)
closeButton.Size = UDim2.fromOffset(30, 30)
closeButton.BackgroundColor3 = buttonColor
closeButton.Text = ""
for _, r in { 45, -45 } do
	local line = Instance.new("Frame")
	line.Name = "LineaX"; line.AnchorPoint = Vector2.new(0.5, 0.5); line.Position = UDim2.fromScale(0.5, 0.5)
	line.Size = UDim2.new(0.5, 0, 0, 2); line.Rotation = r; line.BorderSizePixel = 0
	line.BackgroundColor3 = Color3.new(1, 1, 1); line.Parent = closeButton
end
closeButton.TextColor3 = textColor
closeButton.TextSize = 21
closeButton.Font = Enum.Font.Gotham
closeButton.Parent = panel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 9)
closeCorner.Parent = closeButton

local status = Instance.new("TextLabel")
status.Name = "EquippedStatus"
status.Position = UDim2.fromOffset(18, 48)
status.Size = UDim2.new(1, -36, 0, 22)
status.BackgroundTransparency = 1
status.Text = "En uso: Avatar original"
status.TextColor3 = mutedText
status.TextSize = 12
status.TextXAlignment = Enum.TextXAlignment.Left
status.Font = Enum.Font.Gotham
status.Parent = panel

local astronautButton = Instance.new("TextButton")
astronautButton.Name = "AstronautSkin"
astronautButton.Position = UDim2.fromOffset(18, 82)
astronautButton.Size = UDim2.new(1, -36, 0, 42)
astronautButton.BackgroundColor3 = buttonColor
astronautButton.Text = "Astronauta"
astronautButton.TextColor3 = textColor
astronautButton.TextSize = 14
astronautButton.TextXAlignment = Enum.TextXAlignment.Left
astronautButton.Font = Enum.Font.GothamSemibold
astronautButton.AutoButtonColor = true
astronautButton.Parent = panel

local astronautPadding = Instance.new("UIPadding")
astronautPadding.PaddingLeft = UDim.new(0, 14)
astronautPadding.Parent = astronautButton

local astronautCorner = Instance.new("UICorner")
astronautCorner.CornerRadius = UDim.new(0, 10)
astronautCorner.Parent = astronautButton

local defaultButton = Instance.new("TextButton")
defaultButton.Name = "DefaultSkin"
defaultButton.Position = UDim2.fromOffset(18, 134)
defaultButton.Size = UDim2.new(1, -36, 0, 42)
defaultButton.BackgroundColor3 = buttonColor
defaultButton.Text = "Avatar original"
defaultButton.TextColor3 = textColor
defaultButton.TextSize = 14
defaultButton.TextXAlignment = Enum.TextXAlignment.Left
defaultButton.Font = Enum.Font.GothamSemibold
defaultButton.AutoButtonColor = true
defaultButton.Parent = panel

local defaultPadding = Instance.new("UIPadding")
defaultPadding.PaddingLeft = UDim.new(0, 14)
defaultPadding.Parent = defaultButton

local defaultCorner = Instance.new("UICorner")
defaultCorner.CornerRadius = UDim.new(0, 10)
defaultCorner.Parent = defaultButton

local function updateStatus()
    local selectedSkin = player:GetAttribute("SelectedSkin") or "Default"
    local astronautSelected = selectedSkin == "Astronaut"

    if astronautSelected then
        status.Text = "En uso: Astronauta"
        astronautButton.BackgroundColor3 = accent
        astronautButton.TextColor3 = navy
        defaultButton.BackgroundColor3 = buttonColor
        defaultButton.TextColor3 = textColor
    else
        status.Text = "En uso: Avatar original"
        astronautButton.BackgroundColor3 = buttonColor
        astronautButton.TextColor3 = textColor
        defaultButton.BackgroundColor3 = accent
        defaultButton.TextColor3 = navy
    end
end

local function requestSkin(skinName)
    if player:GetAttribute("SelectedSkin") == skinName then
        panel.Visible = false
        return
    end

    status.Text = "Aplicando skin..."
    requestEvent:FireServer(skinName)
end

openButton.Activated:Connect(function()
    panel.Visible = not panel.Visible
end)

closeButton.Activated:Connect(function()
    panel.Visible = false
end)

astronautButton.Activated:Connect(function()
    requestSkin("Astronaut")
end)

defaultButton.Activated:Connect(function()
    requestSkin("Default")
end)

player:GetAttributeChangedSignal("SelectedSkin"):Connect(updateStatus)
updateStatus()
