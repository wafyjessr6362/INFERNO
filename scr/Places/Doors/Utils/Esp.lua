local Toggles = shared.Toggles
local Options = shared.Options
local Script = shared.Script

local ESPColors = {
    Entity  = Color3.fromRGB(255, 50, 50),
    Eyes    = Color3.fromRGB(180, 0, 255),
    A90     = Color3.fromRGB(180, 0, 255),
    Door    = Color3.fromRGB(0, 255, 0),
    Key     = Color3.fromRGB(255, 220, 0),
    Item    = Color3.fromRGB(255, 140, 0),
    Object  = Color3.fromRGB(0, 180, 255),
    Player  = Color3.fromRGB(0, 150, 255),
    Gold    = Color3.fromRGB(255, 215, 0),
}

local EntityNames = {
    RushMoving    = "Rush",
    AmbushMoving  = "Ambush",
    Eyes          = "Eyes",
    Halt          = "Halt",
    Screech       = "Screech",
    A60           = "A-60",
    A90           = "A-90",
    A120          = "A-120",
    BackdoorRush  = "Blitz",
    Snare         = "Snare",
    FigureRig     = "Figure",
    GiggleCeiling = "Giggle",
    GrumbleRig    = "Grumble",
}

local ItemDisplayNames = {
    Flashlight            = "Flashlight",
    Lighter               = "Lighter",
    Crucifix              = "Crucifix",
    Candle                = "Candle",
    Smoothie              = "Smoothie",
    Vitamins              = "Vitamins",
    LiveBreakerPolePickup = "Breaker",
    LiveHintBook          = "Book",
    FuseObtain            = "Fuse",
    GoldPile              = "Gold Pile",
    GoldPlie              = "Gold Pile",
    StrapLight            = "Strap Light",
    AlarmClock            = "Alarm Clock",
}

local KeyDisplayNames = {
    KeyObtain           = "Key",
    ElectricalKeyObtain = "Electrical Key",
    KeyBackdoorObtain   = "Backdoor Key",
    ElevatorKeyObtain   = "Elevator Key",
}

local espTagged = {}

local function getEntityColor(name)
    return ESPColors[name] or ESPColors.Entity
end

local function makeESP(object, color, display, isEntity)
    if espTagged[object] then return end
    espTagged[object] = true

    if isEntity then
        if not object:FindFirstChildOfClass("Humanoid") then
            pcall(function() Instance.new("Humanoid").Parent = object end)
        end
        for _, v in ipairs(object:GetChildren()) do
            if v:IsA("BasePart") then
                pcall(function() v.Transparency = 0.9 end)
            end
        end
    end

    local hl = Instance.new("Highlight")
    hl.Name = "_INFERNO_HL"
    hl.FillColor = color
    hl.OutlineColor = isEntity and Color3.fromRGB(255, 255, 255) or color
    hl.FillTransparency = 0.3
    hl.OutlineTransparency = 0
    hl.Adornee = object
    hl.Parent = object

    local attachPart = object:FindFirstChild("HumanoidRootPart")
        or object:FindFirstChildOfClass("BasePart")
        or object:FindFirstChildWhichIsA("BasePart", true)

    if attachPart then
        local bill = Instance.new("BillboardGui")
        bill.Name = "_INFERNO_Bill"
        bill.Size = UDim2.new(7.5, 0, 3.5, 0)
        bill.StudsOffset = Vector3.new(0, 2, 0)
        bill.AlwaysOnTop = true
        bill.LightInfluence = 0
        bill.Parent = attachPart

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = color
        label.TextStrokeTransparency = 0.2
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.Font = Enum.Font.Oswald
        label.TextScaled = true
        label.Text = display
        label.Parent = bill
    end

    object.AncestryChanged:Connect(function()
        if not object.Parent then espTagged[object] = nil end
    end)
end

function Script.Functions.ESPEntity(object)
    local displayName = EntityNames[object.Name]
    if not displayName then return end
    makeESP(object, getEntityColor(object.Name), displayName, true)
end

function Script.Functions.ItemESP(object)
    local display = ItemDisplayNames[object.Name]
    if not display then return end
    if object.Name == "Lighter" and object:FindFirstAncestor("Bookcase") then return end
    if object.Name == "Lighter" and object:FindFirstAncestor("BookcaseFake") then return end
    makeESP(object, ESPColors.Item, display, false)
end

function Script.Functions.GoldESP(object)
    makeESP(object, ESPColors.Gold, "Gold Pile", false)
end

function Script.Functions.KeyESP(object)
    local display = KeyDisplayNames[object.Name]
    if not display then return end
    makeESP(object, ESPColors.Key, display, false)
end

function Script.Functions.ClearESP()
    for inst in pairs(espTagged) do
        pcall(function()
            if inst and inst.Parent then
                local h = inst:FindFirstChild("_INFERNO_HL")
                if h then h:Destroy() end
                local b = inst:FindFirstChild("_INFERNO_Bill")
                if b then b:Destroy() end
            end
        end)
    end
    espTagged = {}
end

return {
    EntityNames    = EntityNames,
    ItemDisplayNames = ItemDisplayNames,
    KeyDisplayNames  = KeyDisplayNames,
    ESPColors      = ESPColors,
}
