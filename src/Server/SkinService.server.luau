local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local requestEvent = ReplicatedStorage:FindFirstChild("SkinSelectionRequest")
if not requestEvent then
    requestEvent = Instance.new("RemoteEvent")
    requestEvent.Name = "SkinSelectionRequest"
    requestEvent.Parent = ReplicatedStorage
end

local astronautAssets = ServerStorage:WaitForChild("PlayerSkins"):WaitForChild("Astronaut")
local shirtTemplate = astronautAssets:WaitForChild("Shirt")
local pantsTemplate = astronautAssets:WaitForChild("Pants")
local helmetTemplate = astronautAssets:WaitForChild("Helmet")

local validSkins = {
    Default = true,
    Astronaut = true,
}
local requestsInProgress = {}

local function clearWornItems(character)
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Accessory")
            or item:IsA("Shirt")
            or item:IsA("Pants")
            or item:IsA("ShirtGraphic") then
            item:Destroy()
        end
    end
end

local function addAstronautHelmet(character, head)
    local helmet = helmetTemplate:Clone()
    local handle = helmet:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then
        helmet:Destroy()
        return
    end

    handle.Anchored = false
    handle.CanCollide = false
    handle.CanTouch = false
    handle.CanQuery = false
    handle.Massless = true
    helmet.Parent = character
    handle.CFrame = head.CFrame * CFrame.new(0, 0.8, 0)

    local weld = Instance.new("WeldConstraint")
    weld.Name = "AstronautHelmetWeld"
    weld.Part0 = head
    weld.Part1 = handle
    weld.Parent = handle
end

local function applyAstronautSkin(player, character)
    if player.Character ~= character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local head = character:FindFirstChild("Head")
    if not humanoid or not head or not head:IsA("BasePart") then
        return
    end

    clearWornItems(character)

    local shirt = shirtTemplate:Clone()
    shirt.Parent = character

    local pants = pantsTemplate:Clone()
    pants.Parent = character

    addAstronautHelmet(character, head)
end

local function configurePlayer(player)
    if player:GetAttribute("SelectedSkin") == nil then
        player:SetAttribute("SelectedSkin", "Default")
    end

    player.CharacterAppearanceLoaded:Connect(function(character)
        if player:GetAttribute("SelectedSkin") == "Astronaut" then
            applyAstronautSkin(player, character)
        end
    end)
end

Players.PlayerAdded:Connect(configurePlayer)
for _, player in ipairs(Players:GetPlayers()) do
    configurePlayer(player)
end

requestEvent.OnServerEvent:Connect(function(player, requestedSkin)
    if typeof(requestedSkin) ~= "string" or not validSkins[requestedSkin] then
        return
    end

    if requestsInProgress[player] or player:GetAttribute("SelectedSkin") == requestedSkin then
        return
    end

    requestsInProgress[player] = true
    player:SetAttribute("SelectedSkin", requestedSkin)

    task.spawn(function()
        local succeeded, errorMessage = pcall(function()
            player:LoadCharacterAsync()
        end)

        requestsInProgress[player] = nil
        if not succeeded then
            warn("Could not load selected skin for " .. player.Name .. ": " .. tostring(errorMessage))
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    requestsInProgress[player] = nil
end)
