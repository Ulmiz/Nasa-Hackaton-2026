local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local connections = workspace:WaitForChild("EstacionAurora"):WaitForChild("Conexiones")
local OPEN_DISTANCE = 10
local HOLD_DISTANCE = 13
local SLIDE_DISTANCE = 4.5
local TWEEN_INFO = TweenInfo.new(0.52, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local OPEN_COLOR = Color3.fromRGB(111, 255, 175)
local CLOSED_COLOR = Color3.fromRGB(255, 142, 74)

local doors = {}
for _, link in ipairs(connections:GetChildren()) do
    local model = link:WaitForChild("Compuerta")
    local left = model:FindFirstChild("Door Left", true)
    local right = model:FindFirstChild("Door Right", true)
    local frame = model:FindFirstChild("Frame", true)
    if left and right and frame then
        table.insert(doors, {
            frame = frame,
            indicator = link:WaitForChild("Indicador"),
            open = false,
            generation = 0,
            leaves = {
                {part = left, closed = left.CFrame, open = left.CFrame - frame.CFrame.RightVector * SLIDE_DISTANCE},
                {part = right, closed = right.CFrame, open = right.CFrame + frame.CFrame.RightVector * SLIDE_DISTANCE},
            },
        })
    end
end

local function changeDoor(door, shouldOpen)
    door.open = shouldOpen
    door.generation += 1
    local generation = door.generation
    door.indicator.Color = shouldOpen and OPEN_COLOR or CLOSED_COLOR
    for _, leaf in ipairs(door.leaves) do
        if leaf.tween then leaf.tween:Cancel() end
        leaf.part.CanCollide = false
        leaf.tween = TweenService:Create(leaf.part, TWEEN_INFO, {
            CFrame = shouldOpen and leaf.open or leaf.closed,
        })
        leaf.tween:Play()
    end
    if not shouldOpen then
        task.delay(TWEEN_INFO.Time, function()
            if generation == door.generation then
                for _, leaf in ipairs(door.leaves) do
                    leaf.part.CanCollide = true
                end
            end
        end)
    end
end

while true do
    local players = Players:GetPlayers()
    for _, door in ipairs(doors) do
        local distance = door.open and HOLD_DISTANCE or OPEN_DISTANCE
        local shouldOpen = false
        for _, player in ipairs(players) do
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root and (root.Position - door.frame.Position).Magnitude <= distance then
                shouldOpen = true
                break
            end
        end
        if shouldOpen ~= door.open then
            changeDoor(door, shouldOpen)
        end
    end
    task.wait(0.12)
end
