local Toggles = shared.Toggles
local Options = shared.Options
local Script = shared.Script

function Script.Functions.SetupRoomConnection(room)
    for _, child in ipairs(room:GetDescendants()) do
        task.spawn(Script.Functions.HandleAssetChild, child)
    end

    shared.Connections[room.Name .. "DescendantAdded"] = room.DescendantAdded:Connect(function(child)
        task.delay(0.1, Script.Functions.HandleAssetChild, child)
    end)
end

function Script.Functions.SetupCharacterConnection(newCharacter)
    shared.Character = newCharacter
    if not shared.Character then return end

    shared.Humanoid = shared.Character:WaitForChild("Humanoid")
    shared.RootPart = shared.Character:WaitForChild("HumanoidRootPart")
    Script.Collision = shared.Character:WaitForChild("Collision")

    if Script.Collision then
        Script.Collision.CanQuery = false
        if Script.Collision:FindFirstChild("CollisionCrouch") then
            Script.Collision.CollisionCrouch.CanQuery = false
        end

        Script.CollisionClone = Script.Collision:Clone()
        Script.CollisionClone.CanCollide = false
        Script.CollisionClone.Massless = true
        Script.CollisionClone.CanQuery = false
        Script.CollisionClone.Name = "CollisionClone"
        if Script.CollisionClone:FindFirstChild("CollisionCrouch") then
            Script.CollisionClone.CollisionCrouch:Destroy()
        end
        Script.CollisionClone.Parent = shared.Character
    end

    if shared.Humanoid then
        shared.Humanoid.Died:Connect(function()
            if Script.CollisionClone then Script.CollisionClone:Destroy() end
        end)
    end

    if Script.IsMines and shared.Character then
        shared.Connections["AnticheatBypassTheMines"] = shared.Character:GetAttributeChangedSignal("Climbing"):Connect(function()
            if not Toggles.MinesACBypass then return end
            if not Toggles.MinesACBypass.Value then return end
            if not shared.Character:GetAttribute("Climbing") then return end
            task.wait(1)
            shared.Character:SetAttribute("Climbing", false)
        end)
    end
end

function Script.Functions.SetupOtherPlayerConnection(player)
    if player.Character then
        task.spawn(Script.Functions.SetupOtherCharacterConnection, player.Character)
    end

    player.CharacterAdded:Connect(function(newCharacter)
        task.delay(1, Script.Functions.SetupOtherCharacterConnection, newCharacter)
    end)
end

function Script.Functions.SetupOtherCharacterConnection(character)
    local otherRootPart = character:WaitForChild("HumanoidRootPart", 5)
    if otherRootPart then
        shared.Connections[character.Name .. "RootChildAdded"] = otherRootPart.ChildAdded:Connect(function(child)
            if Toggles.NoVoiceActing and Toggles.NoVoiceActing.Value and child:IsA("Sound") then
                child:Destroy()
            end
        end)
    end
end
