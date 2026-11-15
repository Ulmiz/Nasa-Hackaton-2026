-- Estación Aurora · empuja el carrito del Día 2 delante del jugador (solo visual, en el cliente).
-- El carrito es un modelo aparte en Workspace, no se suelda al personaje.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local cart, current = nil, nil
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function pick(child)
	if child.Name == "CarritoJugador" and child:GetAttribute("Owner") == player.UserId and not child:GetAttribute("Parked") then
		cart = child
		current = child:GetPivot()
	end
end
for _, c in workspace:GetChildren() do pick(c) end
workspace.ChildAdded:Connect(pick)
workspace.ChildRemoved:Connect(function(c) if c == cart then cart = nil end end)

RunService.RenderStepped:Connect(function(dt)
	if not (cart and cart.Parent) then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local look = hrp.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then return end
	flat = flat.Unit
	local pos = hrp.Position + flat * 3.8
	local y = hrp.Position.Y - (cart:GetAttribute("Altura") or 3)
	params.FilterDescendantsInstances = { char, cart }
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
	if hit then y = hit.Position.Y end
	local p = Vector3.new(pos.X, y, pos.Z)
	local target = CFrame.lookAt(p, p + flat) * CFrame.Angles(0, math.pi / 2, 0)
	current = current and current:Lerp(target, math.min(1, dt * 10)) or target
	cart:PivotTo(current)
end)
