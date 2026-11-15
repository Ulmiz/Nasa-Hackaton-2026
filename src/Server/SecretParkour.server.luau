local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local station=workspace:WaitForChild("EstacionAurora")
local room=station:WaitForChild("SalaSecreta")
local course=room:WaitForChild("Espacio de entrenamiento")
local plaque=station.ExpansionOrbital.ObservationDeck["Dato de la Estación Espacial Internacional"]
local button=plaque["Botón oculto de la placa"]["Pulsador secreto"]
local entryPrompt=button:WaitForChild("Señal de acceso")
local finishPrompt=course["Botón regreso final"]:WaitForChild("Volver al inicio")
local exitPrompt=course["Panel de salida"]:WaitForChild("Salir al mirador")
local entrance=room:WaitForChild("Destino del botón secreto")
local checkpoint=room:WaitForChild("Punto de reinicio")
local hazard=course:WaitForChild("Zona de reinicio")
local spinner=course:WaitForChild("Barra giratoria")
local exitPosition=CFrame.new(226,3.5,-5)*CFrame.Angles(0,math.pi,0)
local finaleEvent=ReplicatedStorage:WaitForChild("ParkourFinaleEvent")
local imageId=ReplicatedStorage:WaitForChild("ParkourFinaleImageId")
local busy={}
local function teleport(player,target)
 if busy[player] then return end
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if not character or not root then return end
 busy[player]=true
 root.AssemblyLinearVelocity=Vector3.zero
 root.AssemblyAngularVelocity=Vector3.zero
 character:PivotTo(target)
 task.delay(1.2,function() if player.Parent then busy[player]=nil end end)
end
local function tweenPart(part,offset,duration)
 local start=part.CFrame
 local tween=TweenService:Create(part,TweenInfo.new(duration,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{CFrame=start*CFrame.new(offset)})
 tween:Play()
end
tweenPart(course:WaitForChild("Plataforma 03"),Vector3.new(0,0,2.1),1.65)
tweenPart(course:WaitForChild("Plataforma 06"),Vector3.new(0,0,-2.1),1.45)
tweenPart(course:WaitForChild("Plataforma 08"),Vector3.new(1.8,0,0),1.6)
local spinnerStart=spinner.CFrame
TweenService:Create(spinner,TweenInfo.new(1.05,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1,true),{CFrame=spinnerStart*CFrame.Angles(0,math.pi,0)}):Play()
entryPrompt.Triggered:Connect(function(player)
 teleport(player,entrance.CFrame)
end)
exitPrompt.Triggered:Connect(function(player)
 teleport(player,exitPosition)
end)
finishPrompt.Triggered:Connect(function(player)
 if busy[player] then return end
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if not character or not root then return end
 busy[player]=true
 root.AssemblyLinearVelocity=Vector3.zero
 root.AssemblyAngularVelocity=Vector3.zero
 finaleEvent:FireClient(player,imageId.Value)
 task.delay(4,function()
  if player.Parent and player.Character then
   local currentRoot=player.Character:FindFirstChild("HumanoidRootPart")
   if currentRoot then
    currentRoot.AssemblyLinearVelocity=Vector3.zero
    currentRoot.AssemblyAngularVelocity=Vector3.zero
    player.Character:PivotTo(exitPosition)
   end
  end
  if player.Parent then task.delay(0.8,function() busy[player]=nil end) end
 end)
end)
hazard.Touched:Connect(function(hit)
 local character=hit:FindFirstAncestorOfClass("Model")
 local player=character and Players:GetPlayerFromCharacter(character)
 if player then teleport(player,checkpoint.CFrame) end
end)
Players.PlayerRemoving:Connect(function(player) busy[player]=nil end)
