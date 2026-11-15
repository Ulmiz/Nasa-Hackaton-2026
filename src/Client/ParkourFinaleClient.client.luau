local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local event=ReplicatedStorage:WaitForChild("ParkourFinaleEvent")
local screen=Instance.new("ScreenGui")
screen.Name="ParkourFinaleScreen"; screen.IgnoreGuiInset=true; screen.ResetOnSpawn=false; screen.DisplayOrder=80; screen.Enabled=false
screen.Parent=player:WaitForChild("PlayerGui")
local shade=Instance.new("Frame")
shade.Name="Sombra"; shade.Size=UDim2.fromScale(1,1); shade.BackgroundColor3=Color3.fromRGB(3,8,17); shade.BackgroundTransparency=0.16; shade.BorderSizePixel=0; shade.Parent=screen
local card=Instance.new("Frame")
card.Name="Tarjeta"; card.AnchorPoint=Vector2.new(0.5,0.5); card.Position=UDim2.fromScale(0.5,0.5); card.Size=UDim2.fromScale(0.72,0.9)
card.BackgroundColor3=Color3.fromRGB(12,24,39); card.BorderSizePixel=0; card.Parent=shade
local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,18); corner.Parent=card
local outline=Instance.new("UIStroke"); outline.Color=Color3.fromRGB(71,203,230); outline.Thickness=2; outline.Parent=card
local portrait=Instance.new("ImageLabel")
portrait.Name="Imagen"; portrait.Position=UDim2.fromScale(0.06,0.035); portrait.Size=UDim2.fromScale(0.88,0.77)
portrait.BackgroundColor3=Color3.fromRGB(5,9,14); portrait.BorderSizePixel=0; portrait.ScaleType=Enum.ScaleType.Fit; portrait.Parent=card
local imageCorner=Instance.new("UICorner"); imageCorner.CornerRadius=UDim.new(0,12); imageCorner.Parent=portrait
local caption=Instance.new("TextLabel")
caption.Name="Mensaje"; caption.Position=UDim2.fromScale(0.04,0.825); caption.Size=UDim2.fromScale(0.92,0.13)
caption.BackgroundTransparency=1; caption.Text="jasjajs , perdiste tu tiempo"
caption.TextColor3=Color3.fromRGB(255,222,96); caption.TextStrokeColor3=Color3.fromRGB(0,0,0); caption.TextStrokeTransparency=0.12
caption.Font=Enum.Font.GothamBlack; caption.TextScaled=true; caption.TextWrapped=true; caption.Parent=card
local limit=Instance.new("UITextSizeConstraint"); limit.MinTextSize=18; limit.MaxTextSize=42; limit.Parent=caption
event.OnClientEvent:Connect(function(assetId)
 if type(assetId)=="string" and assetId~="" then portrait.Image=assetId; portrait.Visible=true else portrait.Visible=false end
 screen.Enabled=true
 task.delay(4.5,function() screen.Enabled=false end)
end)
