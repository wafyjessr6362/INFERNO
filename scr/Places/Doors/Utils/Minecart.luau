local Toggles = shared.Toggles
local Script = shared.Script

Script.Functions.Minecart = Script.Functions.Minecart or {}
Script.Functions.Minecart.pathfindQueue = {}

local function debug(...)
    if Script.Functions.Minecart.debugEnabled then
        print("[Minecart]", ...)
    end
end
Script.Functions.Minecart.debug = debug

local function sortNodes(nodes, reversed)
    table.sort(nodes, function(a, b)
        local an = tonumber((a.Name):gsub("[^%d+]", "")) or 0
        local bn = tonumber((b.Name):gsub("[^%d+]", "")) or 0
        return reversed and (an > bn) or (an < bn)
    end)
    return nodes
end

local whitelistConfig = {
    [45] = {firstKeep = 3, lastKeep = 2},
    [46] = {firstKeep = 2, lastKeep = 2},
    [47] = {firstKeep = 2, lastKeep = 2},
    [48] = {firstKeep = 2, lastKeep = 2},
    [49] = {firstKeep = 2, lastKeep = 4},
}

local function hasNodesToPathfind(room)
    local rn = tonumber(room.Name) or 0
    return (rn >= 42 and rn <= 49) or (rn >= 95 and rn <= 100)
end

local function hasAlreadyPathfind(nodesFolder)
    return nodesFolder:GetAttribute("_mspaint_nodes_pathfind")
end

local function getNodes(room)
    if not hasNodesToPathfind(room) then return nil end
    local nodesFolder = room:WaitForChild("RunnerNodes", 5)
    if not nodesFolder then return nil end
    if not hasAlreadyPathfind(nodesFolder) then
        Script.Functions.Minecart.Pathfind(room, true)
        return nil
    end
    local real, fake = {}, {}
    for _, node in ipairs(nodesFolder:GetChildren()) do
        if node:GetAttribute("_mspaint_real_node") then table.insert(real, node)
        elseif node:GetAttribute("_mspaint_fake_node") then table.insert(fake, node) end
    end
    if #real == 0 and #fake == 0 then return nil end
    return {
        real = sortNodes(real, false),
        fake = sortNodes(fake, false),
        roomNumber = tonumber(room.Name)
    }
end

local function destroyNodes(nodesList)
    if not nodesList then return end
    local cfg = whitelistConfig[nodesList.roomNumber]
    if not cfg then return end
    local removeTotal = #nodesList.real - (cfg.firstKeep + cfg.lastKeep)
    for _ = 1, removeTotal do
        local node = nodesList.real[cfg.firstKeep + 1]
        if node then
            node:Destroy()
            table.remove(nodesList.real, cfg.firstKeep + 1)
        end
    end
    for _, node in ipairs(nodesList.fake) do node:Destroy() end
end

local function setNodes(nodes, attr)
    for i, node in ipairs(nodes) do node:SetAttribute(attr, i) end
end

function Script.Functions.Minecart.DrawNodes(room)
    local nodesList = getNodes(room)
    if not nodesList then return end
end

function Script.Functions.Minecart.Teleport(room)
    if not Toggles.MinecartTeleport or not Toggles.MinecartTeleport.Value then return end
    local rn = tonumber(room.Name) or 0
    if not (rn >= 45 and rn <= 49) then return end

    if not room:GetAttribute("_mspaint_player_teleported") then
        local nodesList = getNodes(room)
        if not nodesList then return end
        destroyNodes(nodesList)
        room:SetAttribute("_mspaint_player_teleported", false)
    end

    if rn ~= 45 or room:GetAttribute("_mspaint_player_teleported") then return end

    task.spawn(function()
        local minecartRigs = {}
        task.spawn(function()
            while not shared.Library.Unloaded do
                game:GetService("RunService").RenderStepped:Wait()
                for _, stuff in ipairs(workspace.CurrentCamera:GetChildren()) do
                    if stuff.Name ~= "MinecartRig" then continue end
                    table.insert(minecartRigs, stuff)
                    repeat task.wait() until not stuff:IsDescendantOf(workspace.CurrentCamera)
                    table.remove(minecartRigs, 1)
                end
            end
        end)

        while #minecartRigs == 0 and not shared.Library.Unloaded do task.wait(0.5) end

        task.wait(1.5)

        local currentRooms = workspace.CurrentRooms
        local startRoom = math.min(49, game.Players.LocalPlayer:GetAttribute("CurrentRoom") or 45)
        while startRoom >= 45 and startRoom <= 49 do
            if shared.Library.Unloaded then break end
            local r = currentRooms:FindFirstChild(tostring(startRoom))
            if not r then break end
            local nl = getNodes(r)
            if not nl then break end
            local lastNode = nl.real[#nl.real]
            if not lastNode then break end

            repeat
                game:GetService("RunService").RenderStepped:Wait()
                for _, mc in ipairs(minecartRigs) do
                    if mc.PrimaryPart then mc.PrimaryPart.CFrame = lastNode.CFrame end
                end
            until r:WaitForChild("Door"):GetAttribute("Opened")

            r:SetAttribute("_mspaint_player_teleported", true)
            startRoom += 1
            task.wait(1.2)
        end
    end)
end

function Script.Functions.Minecart.Pathfind(room, forcePathfind)
    if not hasNodesToPathfind(room) then return end
    local nodesFolder = room:FindFirstChild("RunnerNodes")
    if not nodesFolder then return end
    if hasAlreadyPathfind(nodesFolder) then return end

    local nodes = sortNodes(nodesFolder:GetChildren(), true)
    local numOfNodes = #nodes
    if numOfNodes <= 0 then return end

    local realNodes, fakeNodes = {}, {}
    local shortW, longW = 4, 24
    local doorModel = room:WaitForChild("Door", 5)
    local lastNode = nil
    local last = 1

    for i = last + 1, numOfNodes do
        local nodeA = nodes[last]
        local nodeB = lastNode and nodes[i] or doorModel
        local distance = (nodeA:GetPivot().Position - nodeB:GetPivot().Position).Magnitude
        local isEndNode = distance <= shortW
        local isNodeNear = distance > shortW and distance <= longW

        if (isNodeNear or isEndNode) and not lastNode then
            lastNode = nodeA
            table.insert(realNodes, nodeA)
        elseif lastNode then
            if distance > longW then
                table.insert(fakeNodes, nodeA)
            else
                table.insert(realNodes, nodeA)
            end
        end
        last = i
    end

    nodesFolder:SetAttribute("_mspaint_nodes_pathfind", true)
    setNodes(sortNodes(realNodes, false), "_mspaint_real_node")
    setNodes(sortNodes(fakeNodes, false), "_mspaint_fake_node")
    Script.Functions.Minecart.DrawNodes(room)
    Script.Functions.Minecart.Teleport(room)
end
