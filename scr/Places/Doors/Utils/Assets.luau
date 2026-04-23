local Toggles = shared.Toggles
local Script = shared.Script

local tempBridges = {}
local tempPipeBridges = {}

function Script.Functions.HandleAssetChild(child)
    pcall(function()
        if child:IsA("Model") then
            if child.Name == "GiggleCeiling" and Toggles.AntiGiggle and Toggles.AntiGiggle.Value then
                local hitbox = child:WaitForChild("Hitbox", 5)
                if hitbox then
                    hitbox.CanTouch = false
                    for _, v in ipairs(hitbox:GetChildren()) do
                        if v:IsA("TouchTransmitter") then v:Destroy() end
                    end
                end
                child:Destroy()
                return
            end

            if child.Name == "Snare" and Toggles.AntiSnare and Toggles.AntiSnare.Value then
                local hitbox = child:WaitForChild("Hitbox", 5)
                if hitbox then hitbox.CanTouch = false end
                return
            end

            if (child:GetAttribute("LoadModule") == "DupeRoom" or child:GetAttribute("LoadModule") == "SpaceSideroom") and Toggles.AntiDupe and Toggles.AntiDupe.Value then
                for _, v in ipairs(child:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanTouch = false end
                end
                return
            end

            if (child.Name == "ChandelierObstruction" or child.Name == "Seek_Arm") and Toggles.SeekBypass and Toggles.SeekBypass.Value then
                for _, v in ipairs(child:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanTouch = false end
                end
                return
            end

            if child.Name == "FigureRagdoll" and Toggles.FoolsFigureGodmode and Toggles.FoolsFigureGodmode.Value then
                for _, v in ipairs(child:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.CanTouch = false
                        task.spawn(function()
                            repeat task.wait() until (game.Players.LocalPlayer:GetAttribute("CurrentRoom") == 50 or game.Players.LocalPlayer:GetAttribute("CurrentRoom") == 100)
                            task.wait(5)
                            v.CanCollide = false
                        end)
                    end
                end
                return
            end

        elseif child:IsA("BasePart") then
            if child.Name == "Egg" and Toggles.AntiGloomEgg and Toggles.AntiGloomEgg.Value then
                child.CanTouch = false
                return
            end

            if child.Name == "PlayerBarrier" and child.Size.Y == 2.75 and (child.Rotation.X == 0 or child.Rotation.X == 180) and Toggles.AntiBridgeFall and Toggles.AntiBridgeFall.Value then
                local clone = child:Clone()
                clone.CFrame = clone.CFrame * CFrame.new(0, 0, -5)
                clone.Color = Color3.new(1, 1, 1)
                clone.Name = "AntiBridge"
                clone.Size = Vector3.new(clone.Size.X, clone.Size.Y, 11)
                clone.Transparency = 0
                clone.Parent = child.Parent
                table.insert(tempBridges, clone)
                return
            end

            if child.Name == "KillBrick" and child.Parent and child.Parent.Name == "Assets" and Toggles.AntiPipeGap and Toggles.AntiPipeGap.Value then
                local clone = child:Clone()
                clone.Color = Color3.new(1, 1, 1)
                clone.Name = "AntiPipeGap"
                clone.Position += Vector3.new(0, 20, 0)
                clone.Size = Vector3.new(9, 4, clone.Size.Z)
                clone.Transparency = 0
                clone.Parent = child.Parent
                table.insert(tempPipeBridges, clone)
                return
            end

            if child.Name == "SeekFloodline" and Toggles.AntiSeekFlood and Toggles.AntiSeekFlood.Value then
                child.CanCollide = true
                return
            end
        end
    end)
end

function Script.Functions.ClearBridges()
    for _, v in ipairs(tempBridges) do pcall(function() v:Destroy() end) end
    for _, v in ipairs(tempPipeBridges) do pcall(function() v:Destroy() end) end
    tempBridges = {}
    tempPipeBridges = {}
end
