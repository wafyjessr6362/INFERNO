-- =============================================
-- ANTI DUPLICATION
-- =============================================
-- Fetch version from config
local _INFERNO_VERSION = 'v0.814'
pcall(function()
    local cfg = game:GetService('HttpService'):JSONDecode(game:HttpGet('https://raw.githubusercontent.com/wafyjessr6362/INFERNO/main/config.json'))
    if cfg and cfg.version then _INFERNO_VERSION = 'v' .. cfg.version end
end)

if getgenv().INFERNOLoaded then
    warn('INFERNO ' .. _INFERNO_VERSION .. ' is already running! Please destroy the existing instance first.')
    return
end
getgenv().INFERNOLoaded = true

-- =============================================
-- SHARED STATE
-- =============================================
local LocalPlayer = game:GetService('Players').LocalPlayer

-- =============================================
-- CLONEREF + SERVICES
-- =============================================
local cloneref = getgenv().cloneref or function(o) return o end
local Players         = cloneref(game:GetService('Players'))
local RunService      = cloneref(game:GetService('RunService'))
local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local UserInputService = cloneref(game:GetService('UserInputService'))
local Lighting        = cloneref(game:GetService('Lighting'))

-- =============================================
-- DEV MODE
-- =============================================
local Developers = {
    ['imfahd12331231'] = 'Owner',
    -- ['CO_OWNER_NAME'] = 'Co-Owner', -- reserved for later
}

local devMode = false
local devRank = nil

-- Dev mode: show for everyone for 2 days from first load, then expires
local DEV_EXPIRY_KEY = 'INFERNO_DevExpiry'
local devExpiry = nil
pcall(function()
    if isfile and isfile(DEV_EXPIRY_KEY) then
        devExpiry = tonumber(readfile(DEV_EXPIRY_KEY))
    end
    if not devExpiry then
        devExpiry = tick() + (86400 * 2) -- 2 days from now
        if writefile then writefile(DEV_EXPIRY_KEY, tostring(devExpiry)) end
    end
end)

local devExpired = devExpiry and tick() > devExpiry

if Developers[LocalPlayer.Name] then
    devMode = true
    devRank = Developers[LocalPlayer.Name]
elseif not devExpired then
    devMode = true
    devRank = 'Tester'
end

-- ESP
local espEnabled = false
local espDoorEnabled = false
local espKeyEnabled = false
local espItemEnabled = false
local espTagged = {} -- track already-esp'd instances to avoid duplication

-- Display name cleanup (strip Moving suffix)
local EntityNames = {
    RushMoving      = 'Rush',
    AmbushMoving    = 'Ambush',
    Eyes            = 'Eyes',
    Halt            = 'Halt',
    Screech         = 'Screech',
    A60             = 'A-60',
    A90             = 'A-90',
    A120            = 'A-120',
    BackdoorRush    = 'Blitz',
    Snare           = 'Snare',
    Timothy         = 'Timothy',
    Shadow          = 'Shadow',
    Void            = 'Void',
    FigureRig       = 'Figure',
    GiggleCeiling   = 'Giggle',
    GrumbleRig      = 'Grumble',
    Jack            = 'Jack',
    El_Goblino      = 'El Goblino',
    Glitch          = 'Glitch',
}

-- Entity colors: Eyes = purple, A-90 = purple, everything else = red
local EntityColors = {
    Eyes = Color3.fromRGB(180, 0, 255),
    A90  = Color3.fromRGB(180, 0, 255),
}
local function getEntityColor(name)
    return EntityColors[name] or Color3.fromRGB(255, 50, 50)
end

-- Floor detection
local currentFloor = 'Hotel'
pcall(function()
    local floorVal = game.ReplicatedStorage:WaitForChild('GameData', 5)
    if floorVal then
        floorVal = floorVal:FindFirstChild('Floor')
        if floorVal then
            currentFloor = floorVal.Value
            floorVal:GetPropertyChangedSignal('Value'):Connect(function()
                currentFloor = floorVal.Value
            end)
        end
    end
end)

-- Auto Padlock
local PadlockCode = nil
local PadlockCode_N = false

-- Anti Cheat Manip
local anticheatManipEnabled = false
local anticheatManipLoop = nil
local isAnticheatKeyHeld = false

-- Anti Eyes
local antiEyesEnabled = false
local antiEyesLoop = nil

-- Godmode
local godModeEnabled = false
local godModeConnection = nil
local godModeSaved = {}
local godModeAutoEnabled = false

-- Speed
local speedvalue = 16
local antiSpeedEnabled = false
local antiSpeedLoop = nil
local clonedCollision = nil

-- =============================================
-- LOGGING SYSTEM
-- =============================================
local _logFile = "INFERNO_LoadLog.txt"
local function _log(msg)
    pcall(function()
        local existing = ""
        if isfile and isfile(_logFile) then
            existing = readfile(_logFile)
        end
        if writefile then
            writefile(_logFile, existing .. msg .. "\n")
        end
    end)
    warn(msg)
end

-- =============================================
-- PHASE SYSTEM
-- =============================================
local _phases = {}
local _phaseNames = {}
local function _addPhase(name, fn)
    table.insert(_phases, fn)
    table.insert(_phaseNames, name)
end

-- =============================================
-- EXECUTOR SUPPORT CHECK
-- =============================================
local function _checkSupport()
    local checks = {
        { name = 'getgenv',              fn = function() return type(getgenv) == 'function' end },
        { name = 'hookfunction',         fn = function() return type(hookfunction) == 'function' end },
        { name = 'hookmetamethod',       fn = function() return type(hookmetamethod) == 'function' end },
        { name = 'fireproximityprompt',  fn = function() return type(fireproximityprompt) == 'function' end },
        { name = 'cloneref',             fn = function() return type(cloneref) == 'function' end },
        { name = 'isfile',               fn = function() return type(isfile) == 'function' end },
        { name = 'readfile',             fn = function() return type(readfile) == 'function' end },
        { name = 'writefile',            fn = function() return type(writefile) == 'function' end },
        { name = 'setclipboard',         fn = function() return type(setclipboard) == 'function' end },
        { name = 'getrawmetatable',      fn = function() return type(getrawmetatable) == 'function' end },
        { name = 'setrawmetatable',      fn = function() return type(setrawmetatable) == 'function' end },
    }

    print('=== INFERNO v0.814 | Executor Support Check ===')
    for _, check in ipairs(checks) do
        local ok, result = pcall(check.fn)
        local supported = ok and result
        print((supported and '[+]' or '[-]') .. ' ' .. check.name)
    end
    print('================================================')
end
_checkSupport()

-- =============================================
-- HOOK PROXIMITYPROMPT (fallback for executors without fireproximityprompt)
-- =============================================
if not fireproximityprompt then
    -- Hook method via __index on ProximityPrompt
    local ok = pcall(function()
        local mt = getrawmetatable(game)
        local oldIndex = mt.__index
        setrawmetatable(game, mt)
        fireproximityprompt = function(prompt)
            if prompt and prompt:IsA('ProximityPrompt') then
                local pp = game:GetService('ProximityPromptService')
                -- Trigger via InputBegan simulation
                local triggerEvent = prompt.Parent and prompt.Parent:FindFirstChild('_TriggerPrompt')
                if triggerEvent then
                    triggerEvent:Fire(prompt, game:GetService('Players').LocalPlayer)
                else
                    -- Fallback: fire the TriggerEnded signal directly
                    pcall(function()
                        prompt:InputHoldBegin()
                        task.wait(0.05)
                        prompt:InputHoldEnd()
                    end)
                end
            end
        end
    end)
    if ok then
        print('[INFERNO] Hook method active (fireproximityprompt fallback)')
    else
        print('[INFERNO] WARNING: fireproximityprompt not supported on this executor')
    end
end

local function _runPhases()

-- Queue INFERNO to re-execute after teleport (for death farm lobby reload)
pcall(function()
    if fluxus and fluxus.queue_on_teleport then
        fluxus.queue_on_teleport(game:HttpGet('https://raw.githubusercontent.com/yourusername/INFERNO/main/INFERNO.lua'))
        print('[INFERNO] Queued for re-execution after teleport.')
    end
end)
    pcall(function() if writefile then writefile(_logFile, "=== INFERNO v0.814 Load Log ===\n") end end)
    for i, fn in ipairs(_phases) do
        local name = _phaseNames[i] or ("Phase " .. i)
        _log("[Phase " .. i .. "/" .. #_phases .. "] Starting: " .. name)
        local ok, err = pcall(fn)
        if not ok then
            local msg = "[Phase " .. i .. " FAILED] " .. name .. ": " .. tostring(err)
            _log(msg)
            pcall(function()
                Library:Notify({ Title = 'Phase Error', Description = msg, Time = 10 })
            end)
        else
            _log("[Phase " .. i .. "] OK: " .. name)
        end
        task.wait()
    end
    _log("[INFERNO] All phases complete.")
end

-- =============================================
-- LIBRARY LOAD
-- =============================================
_addPhase("Load Libraries", function()
    local CONFIG_URL = 'https://raw.githubusercontent.com/wafyjessr6362/INFERNO/main/config.json'
    local HTTP = game:GetService('HttpService')

    -- Load config
    local ok, configRaw = pcall(game.HttpGet, game, CONFIG_URL)
    if ok and configRaw then
        local cfg = HTTP:JSONDecode(configRaw)
        print('[INFERNO] v' .. (cfg.version or '?') .. ' | by ' .. (cfg.author or '?'))
    end

    local repo = 'https://raw.githubusercontent.com/deividcomsono/Obsidian/main/'
    Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
    ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
    SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

    Options = Library.Options
    Toggles = Library.Toggles
    Library.ShowToggleFrameInKeybinds = true

    local base = 'https://raw.githubusercontent.com/wafyjessr6362/INFERNO/main/scr/Places/Doors/Utils/'
    local Modules = {
        Esp             = loadstring(game:HttpGet(base .. 'Esp.lua'))(),
        Padlock         = loadstring(game:HttpGet(base .. 'Padlock.luau'))(),
        Minecart        = loadstring(game:HttpGet(base .. 'Minecart.luau'))(),
        Assets          = loadstring(game:HttpGet(base .. 'Assets.luau'))(),
        BreakerBox      = loadstring(game:HttpGet(base .. 'BreakerBox.luau'))(),
        ConnectionsFuncs = loadstring(game:HttpGet(base .. 'ConnectionsFuncs.luau'))(),
    }
    getgenv().INFERNOModules = Modules
end)

-- =============================================
-- WINDOW & TABS
-- =============================================
_addPhase("Create Window & Tabs", function()
    Window = Library:CreateWindow({
        Title = 'INFERNO v0.814',
        Footer = 'Doors Script | INFERNO',
        Center = true,
        AutoShow = true,
        NotifySide = 'Right',
        ShowCustomCursor = true,
    })

    Tabs = {
        Main            = Window:AddTab('Main', 'door-open'),
        Visuals         = Window:AddTab('Visuals', 'eye'),
        Exploits        = Window:AddTab('Exploits', 'zap'),
        Floor           = Window:AddTab('Floor', 'layers'),
        Fun             = Window:AddTab('Fun', 'smile'),
        ['UI Settings'] = Window:AddTab('UI Settings', 'settings'),
    }
end)

-- =============================================
-- MAIN TAB UI
-- =============================================
-- =============================================
-- DEV PANEL
-- =============================================
_addPhase("Build Dev Panel", function()
    if not devMode then return end
    local isOwnerOrCoOwner = devRank == 'Owner' or devRank == 'Co-Owner'

    Library:Notify({
        Title       = 'INFERNO Dev Mode',
        Description = 'Welcome back, ' .. devRank .. ' ' .. LocalPlayer.Name .. '!',
        Time        = 6,
    })

    local DevTab = Window:AddTab('Dev', 'code')
    local DevGroup = DevTab:AddLeftGroupbox('Developer')

    DevGroup:AddLabel('Rank: ' .. devRank)
    DevGroup:AddLabel('User: ' .. LocalPlayer.Name)
    DevGroup:AddDivider()

    DevGroup:AddToggle('DevTestGodmode', {
        Text    = 'Testing Godmode (A-60)',
        Default = false,
        Tooltip = 'Dev-only godmode for testing A-60 behavior.',
    })

    -- Dev Testing Godmode loop
    task.spawn(function()
        while task.wait(0.1) do
            if Library.Unloaded then break end
            if not devMode then break end
            if not Toggles.DevTestGodmode or not Toggles.DevTestGodmode.Value then continue end
            local char = LocalPlayer.Character
            if not char then continue end
            pcall(function()
                local hrp = char:FindFirstChild('HumanoidRootPart')
                local hum = char:FindFirstChildOfClass('Humanoid')
                local collision = char:FindFirstChild('CollisionPart')
                if hrp and hum and collision then
                    hum.HipHeight = 0
                    hrp.CanCollide = false
                    -- Move CollisionPart -10 Y below HRP
                    collision.CFrame = CFrame.new(hrp.Position + Vector3.new(0, -10, 0))
                    -- Destroy CollisionCrouch if exists
                    local collisionCrouch = collision:FindFirstChild('CollisionCrouch')
                    if collisionCrouch then collisionCrouch:Destroy() end
                end
            end)
        end
    end)

    DevGroup:AddDivider()

    DevGroup:AddToggle('BetterGodmode', {
        Text    = 'Better Godmode',
        Default = false,
        Tooltip = 'Admin only. Moves CollisionPart -10Y and destroys CollisionCrouch. Does NOT work on A-120.',
    })

    task.spawn(function()
        while task.wait(0.1) do
            if Library.Unloaded then break end
            if not devMode then break end
            if not Toggles.BetterGodmode or not Toggles.BetterGodmode.Value then continue end
            local char = LocalPlayer.Character
            if not char then continue end
            pcall(function()
                local hrp = char:FindFirstChild('HumanoidRootPart')
                local collision = char:FindFirstChild('CollisionPart')
                if hrp and collision then
                    collision.CFrame = CFrame.new(hrp.Position + Vector3.new(0, -10, 0))
                    local collisionCrouch = collision:FindFirstChild('CollisionCrouch')
                    if collisionCrouch then collisionCrouch:Destroy() end
                end
            end)
        end
    end)

    DevGroup:AddDivider()

    DevGroup:AddButton({
        Text    = 'Unload Script',
        Tooltip = 'Unloads INFERNO and resets all settings to prevent glitches.',
        Func    = function()
            Library:Unload()
        end
    })

    DevGroup:AddDivider()

    DevGroup:AddButton({
        Text    = 'Print All Phases',
        Tooltip = 'Prints all loaded phases to output',
        Func    = function()
            for i, name in ipairs(_phaseNames) do
                print('[INFERNO Phase ' .. i .. '] ' .. name)
            end
        end
    })

    DevGroup:AddButton({
        Text    = 'Print Workspace Children',
        Tooltip = 'Prints all workspace children to output',
        Func    = function()
            for _, v in ipairs(workspace:GetChildren()) do
                print('[Workspace] ' .. v.Name .. ' (' .. v.ClassName .. ')')
            end
        end
    })

    DevGroup:AddButton({
        Text    = 'Print ReplicatedStorage',
        Tooltip = 'Prints ReplicatedStorage children to output',
        Func    = function()
            for _, v in ipairs(game.ReplicatedStorage:GetChildren()) do
                print('[RS] ' .. v.Name .. ' (' .. v.ClassName .. ')')
            end
        end
    })

    DevGroup:AddButton({
        Text    = 'Reload Script',
        Tooltip = 'Unloads and reloads INFERNO',
        Func    = function()
            Library:Unload()
            task.wait(0.5)
            getgenv().INFERNOLoaded = nil
            loadstring(game:HttpGet('https://raw.githubusercontent.com/yourusername/INFERNO/main/INFERNO_BETA.lua'))()
        end
    })

    local InfoGroup = DevTab:AddRightGroupbox('Script Info')
    InfoGroup:AddLabel('Version: v0.814')
    InfoGroup:AddLabel('Build: BETA')
    InfoGroup:AddLabel('Phases: ' .. #_phases)
    InfoGroup:AddDivider()
    InfoGroup:AddButton({
        Text = 'Copy Error Log Path',
        Func = function()
            setclipboard('INFERNO_LoadLog.txt')
            Library:Notify({ Title = 'Dev', Description = 'Log path copied!', Time = 2 })
        end
    })

end)

_addPhase("Build Main Tab", function()

    -- ==================
    -- SPEED
    -- ==================
    local SpeedGroup = Tabs.Main:AddLeftGroupbox('Speed')

    local SpeedStatusLabel = SpeedGroup:AddLabel('Speed Status: Disabled')

    SpeedGroup:AddToggle('SpeedEnabled', {
        Text = 'Enable Speed',
        Default = false,
        Tooltip = 'Increases your walkspeed beyond the default limit using a collision bypass.',
        Callback = function(Value)
            antiSpeedEnabled = Value
            SpeedStatusLabel:SetText('Speed Status: ' .. (Value and 'Enabled' or 'Disabled'))
            Options.SpeedSlider:SetDisabled(not Value)

            if Value then
                local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                local CollisionPart = Character:WaitForChild("CollisionPart")
                clonedCollision = CollisionPart:Clone()
                clonedCollision.Name = "_CollisionClone"
                clonedCollision.Massless = true
                clonedCollision.Parent = Character
                clonedCollision.CanCollide = false
                clonedCollision.CanQuery = false
                clonedCollision.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0.7, 0, 1, 1)

                antiSpeedLoop = task.spawn(function()
                    while antiSpeedEnabled do
                        task.wait(0.23)
                        if clonedCollision then
                            clonedCollision.Massless = false
                            task.wait(0.23)
                            local root = Character:FindFirstChild("HumanoidRootPart")
                            if root and root.Anchored then
                                clonedCollision.Massless = true
                                task.wait(1)
                            end
                            clonedCollision.Massless = true
                        end
                    end
                end)

                -- WalkSpeed loop
                task.spawn(function()
                    while antiSpeedEnabled do
                        task.wait(0.1)
                        local char = LocalPlayer.Character
                        if char then
                            local hum = char:FindFirstChildOfClass('Humanoid')
                            if hum then
                                hum.WalkSpeed = speedvalue
                            end
                        end
                    end
                end)
            else
                if antiSpeedLoop then
                    task.cancel(antiSpeedLoop)
                    antiSpeedLoop = nil
                end
                if clonedCollision then
                    clonedCollision:Destroy()
                    clonedCollision = nil
                end
                -- Reset walkspeed
                local char = LocalPlayer.Character
                if char then
                    local hum = char:FindFirstChildOfClass('Humanoid')
                    if hum then hum.WalkSpeed = 16 end
                end
            end
        end
    })

    SpeedGroup:AddSlider('SpeedSlider', {
        Text = 'Walk Speed',
        Default = 16,
        Min = 10,
        Max = 75,
        Rounding = 0,
        Disabled = true, -- starts disabled until Speed is enabled
        Tooltip = 'Requires Speed to be enabled',
        Callback = function(Value)
            speedvalue = Value
        end
    })

end)

-- =============================================
-- VISUALS (FOV + FULLBRIGHT)
-- =============================================
_addPhase("Build Visuals", function()

    local VisualsGroup = Tabs.Visuals:AddLeftGroupbox('Visuals')

    -- ==================
    -- FOV
    -- ==================
    local fovValue = 70
    local fovConnection = nil

    VisualsGroup:AddToggle('FovEnabled', {
        Text = 'Custom FOV',
        Default = false,
        Tooltip = 'Overrides the camera field of view',
        Callback = function(Value)
            if Value then
                fovConnection = game:GetService('RunService').RenderStepped:Connect(function()
                    workspace.CurrentCamera.FieldOfView = fovValue
                end)
            else
                if fovConnection then
                    fovConnection:Disconnect()
                    fovConnection = nil
                end
                workspace.CurrentCamera.FieldOfView = 70 -- reset to default
            end
        end
    })

    VisualsGroup:AddSlider('FovSlider', {
        Text = 'FOV',
        Default = 70,
        Min = 30,
        Max = 120,
        Rounding = 0,
        Disabled = true,
        Tooltip = 'Requires Custom FOV to be enabled',
        Callback = function(Value)
            fovValue = Value
        end
    })

    Toggles.FovEnabled:OnChanged(function()
        Options.FovSlider:SetDisabled(not Toggles.FovEnabled.Value)
    end)

    VisualsGroup:AddDivider()

    -- ==================
    -- FULLBRIGHT
    -- ==================
    if not _G.FullBrightExecuted then

        _G.FullBrightEnabled = false

        _G.NormalLightingSettings = {
            Brightness    = game:GetService('Lighting').Brightness,
            ClockTime     = game:GetService('Lighting').ClockTime,
            FogEnd        = game:GetService('Lighting').FogEnd,
            GlobalShadows = game:GetService('Lighting').GlobalShadows,
            Ambient       = game:GetService('Lighting').Ambient,
        }

        local Lighting = game:GetService('Lighting')

    end

    _G.FullBrightExecuted = true

    local brightLoop = nil
    local RunService = game:GetService('RunService')
    local Lighting = game:GetService('Lighting')

    VisualsGroup:AddToggle('FullbrightEnabled', {
        Text = 'Fullbright',
        Default = false,
        Tooltip = 'Better fullbright using RenderStepped to fight lighting changes',
        Callback = function(Value)
            _G.FullBrightEnabled = Value
            if Value then
                if brightLoop then brightLoop:Disconnect() end
                brightLoop = RunService.RenderStepped:Connect(function()
                    Lighting.Brightness      = 2
                    Lighting.ClockTime       = 14
                    Lighting.FogEnd          = 100000
                    Lighting.GlobalShadows   = false
                    Lighting.OutdoorAmbient  = Color3.fromRGB(128, 128, 128)
                end)
            else
                if brightLoop then
                    brightLoop:Disconnect()
                    brightLoop = nil
                end
                -- Restore original lighting
                Lighting.Brightness      = _G.NormalLightingSettings.Brightness
                Lighting.ClockTime       = _G.NormalLightingSettings.ClockTime
                Lighting.FogEnd          = _G.NormalLightingSettings.FogEnd
                Lighting.GlobalShadows   = _G.NormalLightingSettings.GlobalShadows
                Lighting.Ambient         = _G.NormalLightingSettings.Ambient
            end
        end
    })

end)

-- =============================================
-- ESP FEATURES
-- =============================================
_addPhase("Build ESP", function()

    local ESPGroup = Tabs.Visuals:AddRightGroupbox('ESP')

    ESPGroup:AddToggle('EntityESP', {
        Text    = 'Entity ESP',
        Default = false,
        Tooltip = 'Highlights entities through walls with a red outline so you can always see where they are.',
        Callback = function(Value)
            espEnabled = Value
            if not Value then
                for inst in pairs(espTagged) do
                    pcall(function()
                        if inst and inst.Parent then
                            local h = inst:FindFirstChild('_DRSESP_HL')
                            if h then h:Destroy() end
                            local b = inst:FindFirstChildWhichIsA('BillboardGui', true)
                            if b then b:Destroy() end
                        end
                    end)
                end
                espTagged = {}
            end
        end
    })

    ESPGroup:AddToggle('DoorESP', {
        Text    = 'Door ESP',
        Default = false,
        Tooltip = 'Highlights doors in green with open/locked status.',
        Callback = function(Value) espDoorEnabled = Value end
    })

    ESPGroup:AddToggle('KeyESP', {
        Text    = 'Key ESP',
        Default = false,
        Tooltip = 'Highlights keys in yellow.',
        Callback = function(Value) espKeyEnabled = Value end
    })

    ESPGroup:AddToggle('ItemESP', {
        Text    = 'Item ESP',
        Default = false,
        Tooltip = 'Highlights items like Flashlight, Crucifix, Vitamins etc.',
        Callback = function(Value) espItemEnabled = Value end
    })

    -- ==================
    -- UNIFIED applyESP
    -- ==================
    local function applyESP(object, color, display, isEntity)
        if espTagged[object] then return end
        espTagged[object] = true

        -- Only add Humanoid and set transparency for entities
        if isEntity then
            if not object:FindFirstChildOfClass('Humanoid') then
                pcall(function()
                    Instance.new('Humanoid').Parent = object
                end)
            end
            for _, v in ipairs(object:GetChildren()) do
                if v:IsA('BasePart') then
                    pcall(function() v.Transparency = 0.9 end)
                end
            end
        end

        -- Highlight
        local hl = Instance.new('Highlight')
        hl.Name = '_DRSESP_HL'
        hl.FillColor = color
        hl.OutlineColor = isEntity and Color3.fromRGB(255, 255, 255) or color
        hl.FillTransparency = 0.3
        hl.OutlineTransparency = 0
        hl.Adornee = object
        hl.Parent = object

        -- Billboard
        local attachPart = object:FindFirstChild('HumanoidRootPart')
            or object:FindFirstChildOfClass('BasePart')
            or object:FindFirstChildWhichIsA('BasePart', true)

        if attachPart then
            local oldBill = attachPart:FindFirstChild('_DRSESP_Bill')
            if oldBill then oldBill:Destroy() end

            local bill = Instance.new('BillboardGui')
            bill.Name = '_DRSESP_Bill'
            bill.Size = UDim2.new(7.5, 0, 3.5, 0)
            bill.StudsOffset = Vector3.new(0, 2, 0)
            bill.AlwaysOnTop = true
            bill.LightInfluence = 0
            bill.Parent = attachPart

            local label = Instance.new('TextLabel')
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

        -- Cleanup on removal
        object.AncestryChanged:Connect(function()
            if not object.Parent then espTagged[object] = nil end
        end)
    end

    -- ==================
    -- DOOR ESP (special: needs live label updates)
    -- ==================
    local KeyDisplayNames = {
        KeyObtain             = 'Key',
        ElectricalKeyObtain   = 'Electrical Key',
        KeyBackdoorObtain     = 'Backdoor Key',
        ElevatorKeyObtain     = 'Elevator Key',
    }

    local ItemDisplayNames = {
        Flashlight            = 'Flashlight',
        Lighter               = 'Lighter',
        Crucifix              = 'Crucifix',
        Candle                = 'Candle',
        Smoothie              = 'Smoothie',
        Vitamins              = 'Vitamins',
        LiveBreakerPolePickup = 'Breaker',
        LiveHintBook          = 'Book',
        FuseObtain            = 'Fuse',
        GoldPile              = 'Gold Pile',
        GoldPlie              = 'Gold Pile',
    }

    local ObjectDisplayNames = {
        LeverForGate = 'Gate Lever',
    }

    local function applyDoorESP(doorModel, roomName)
        if espTagged[doorModel] then return end
        espTagged[doorModel] = true

        -- Door number = room name as number + 1
        local doorNumber = (tonumber(roomName) or 0) + 1

        local doorPart = doorModel:FindFirstChild('Door')
        if not doorPart then return end

        -- Highlight on doorPart + clone to all BasePart children, no outline
        local function makeHL(target)
            if target:FindFirstChild('_DRSESP_HL') then return end
            local hl = Instance.new('Highlight')
            hl.Name = '_DRSESP_HL'
            hl.FillColor = Color3.fromRGB(0, 255, 0)
            hl.OutlineColor = Color3.fromRGB(0, 255, 0)
            hl.FillTransparency = 0.5
            hl.OutlineTransparency = 1 -- no outline
            hl.Adornee = target
            hl.Parent = target
        end

        makeHL(doorPart)
        for _, child in ipairs(doorPart:GetChildren()) do
            if child:IsA('BasePart') then makeHL(child) end
        end

        -- Billboard with live status
        local attachTo = doorPart:FindFirstChildOfClass('BasePart')
            or doorPart:FindFirstChildWhichIsA('BasePart', true)
        if attachTo then
            local bill = Instance.new('BillboardGui')
            bill.Name = '_DRSESP_Bill'
            bill.Size = UDim2.new(7.5, 0, 3.5, 0)
            bill.StudsOffset = Vector3.new(0, 2, 0)
            bill.AlwaysOnTop = true
            bill.LightInfluence = 0
            bill.Parent = attachTo

            local label = Instance.new('TextLabel')
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.TextStrokeTransparency = 0.2
            label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            label.Font = Enum.Font.Oswald
            label.TextScaled = true
            label.Parent = bill

            local function updateLabel()
                local isOpen   = doorPart:FindFirstChild('IsOpen')   and doorPart.IsOpen.Value   == true
                local isLocked = doorPart:FindFirstChild('IsLocked') and doorPart.IsLocked.Value == true
                if isOpen then
                    label.Text = 'Door ' .. doorNumber .. ' (Open)'
                    label.TextColor3 = Color3.fromRGB(100, 255, 100)
                elseif isLocked then
                    label.Text = 'Door ' .. doorNumber .. ' (Locked)'
                    label.TextColor3 = Color3.fromRGB(255, 80, 80)
                else
                    label.Text = 'Door ' .. doorNumber
                    label.TextColor3 = Color3.fromRGB(80, 255, 80)
                end
            end
            updateLabel()
            doorPart.DescendantAdded:Connect(updateLabel)
            doorPart.DescendantRemoving:Connect(updateLabel)
        end

        doorModel.AncestryChanged:Connect(function()
            if not doorModel.Parent then espTagged[doorModel] = nil end
        end)
    end

    -- ==================
    -- MAIN ESP LOOP
    -- ==================
    task.spawn(function()
        while task.wait(0.2) do
            if Library.Unloaded then break end

            -- Entity ESP
            if espEnabled then
                for _, inst in ipairs(workspace:GetChildren()) do
                    local displayName = EntityNames[inst.Name]
                    if displayName then
                        applyESP(inst, getEntityColor(inst.Name), displayName, true)
                    end
                end
                for _, inst in ipairs(workspace:GetDescendants()) do
                    if inst.Name == 'Snare' then
                        applyESP(inst, Color3.fromRGB(255, 50, 50), 'Snare', true)
                    end
                end
            end

            -- Door ESP
            if espDoorEnabled then
                local currentRooms = workspace:FindFirstChild('CurrentRooms')
                if currentRooms then
                    for _, room in ipairs(currentRooms:GetChildren()) do
                        local doorNumber = room.Name:match('%d+') or '?'
                        for _, obj in ipairs(room:GetChildren()) do
                            if obj.Name == 'Door' then applyDoorESP(obj, doorNumber) end
                        end
                    end
                end
            end

            -- Key ESP
            if espKeyEnabled then
                for _, inst in ipairs(workspace:GetDescendants()) do
                    local display = KeyDisplayNames[inst.Name]
                    if display then
                        applyESP(inst, Color3.fromRGB(255, 220, 0), display, false)
                    end
                end
            end

            -- Item ESP
            if espItemEnabled then
                for _, inst in ipairs(workspace:GetDescendants()) do
                    local itemDisplay = ItemDisplayNames[inst.Name]
                    if itemDisplay then
                        if inst.Name == 'Lighter' and (inst:FindFirstAncestor('Bookcase') or inst:FindFirstAncestor('BookcaseFake')) then continue end
                        applyESP(inst, Color3.fromRGB(255, 140, 0), itemDisplay, false)
                        continue
                    end
                    local objDisplay = ObjectDisplayNames[inst.Name]
                    if objDisplay then
                        applyESP(inst, Color3.fromRGB(0, 180, 255), objDisplay, false)
                    end
                end
            end
        end
    end)

end)
-- =============================================
-- AUTO PADLOCK
-- =============================================
_addPhase("Build Auto Padlock", function()

    local PadlockGroup = Tabs.Main:AddRightGroupbox('Cool Stuff')

    local function HasItem(name)
        return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild(name)
            or LocalPlayer.Backpack:FindFirstChild(name)
    end

    local function GetRoot()
        return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart')
    end

    PadlockGroup:AddToggle('AutoPadlock', {
        Text    = 'Auto Padlock',
        Default = false,
        Tooltip = 'Finds the code from LibraryHintPaper and auto solves the padlock when near door 50',
    })

    PadlockGroup:AddSlider('PadlockDistance', {
        Text     = 'Solve Distance',
        Default  = 10,
        Min      = 5,
        Max      = 50,
        Rounding = 0,
        Tooltip  = 'Distance from padlock to auto solve',
    })

    -- Loop 1: Find the code from paper
    task.spawn(function()
        while task.wait() do
            if Library.Unloaded then break end
            if PadlockCode_N then break end
            pcall(function()
                if not Toggles.AutoPadlock.Value then return end

                local Paper = HasItem('LibraryHintPaper')
                if not Paper then
                    for _, Player in pairs(game:GetService('Players'):GetPlayers()) do
                        if Player ~= LocalPlayer then
                            Paper = (Player.Character and Player.Character:FindFirstChild('LibraryHintPaper'))
                                or Player.Backpack:FindFirstChild('LibraryHintPaper')
                            if Paper then break end
                        end
                    end
                end

                local Rooms = workspace:FindFirstChild('CurrentRooms')
                if Rooms and Rooms:FindFirstChild('50') then
                    local Room50 = Rooms['50']
                    if Paper and Paper:FindFirstChild('UI') and Room50.Door:FindFirstChild('Padlock') then
                        local Code = ''
                        for _, x in pairs(Paper.UI:GetChildren()) do
                            if tonumber(x.Name) then
                                for _, y in pairs(LocalPlayer.PlayerGui.PermUI.Hints:GetChildren()) do
                                    if y.Name == 'Icon' then
                                        if y.ImageRectOffset == x.ImageRectOffset then
                                            Code = Code .. y.TextLabel.Text
                                        end
                                    end
                                end
                            end
                            if #Code == 5 then
                                Library:Notify({
                                    Title       = 'Padlock Code Found',
                                    Description = 'Code: ' .. Code,
                                    Time        = 6,
                                })
                                PadlockCode_N = true
                                PadlockCode   = Code
                            end
                            if PadlockCode then break end
                        end
                    end
                end
            end)
        end
    end)

    -- Loop 2: Solve the padlock when near
    task.spawn(function()
        while task.wait(0.5) do
            if Library.Unloaded then break end
            pcall(function()
                if not PadlockCode then return end
                if not Toggles.AutoPadlock.Value then return end

                local currentRoom = LocalPlayer:GetAttribute('CurrentRoom')
                if not currentRoom or currentRoom > 51 then return end

                local Rooms = workspace:FindFirstChild('CurrentRooms')
                if not Rooms or not Rooms:FindFirstChild('50') then return end

                local Padlock = Rooms['50'].Door:FindFirstChild('Padlock')
                if not Padlock then return end

                local root = GetRoot()
                if not root then return end

                local dist = (root.Position - Padlock.Main.Position).Magnitude
                if dist <= Options.PadlockDistance.Value then
                    game.ReplicatedStorage.RemotesFolder.PL:FireServer(PadlockCode)
                    Library:Notify({
                        Title       = 'Padlock Solved',
                        Description = 'Used code: ' .. PadlockCode,
                        Time        = 4,
                    })
                end
            end)
        end
    end)

end)

-- =============================================
-- FIGURE GODMODE
-- =============================================
_addPhase("Build Figure Godmode", function()

    local FigureGroup = Tabs.Exploits:AddLeftGroupbox('Figure Godmode')

    local figureGodModeEnabled = false
    local isFigureGodModeActive = false
    local fakeCameraConnection = nil
    local Camera = workspace.CurrentCamera
    local originalCameraType = Camera.CameraType
    local originalCameraSubject = Camera.CameraSubject

    local function getFigurePosition(figureRig)
        if not figureRig then return nil end
        local ok, pivot = pcall(function() return figureRig:GetPivot() end)
        if ok and pivot then return pivot.Position end
        local part = figureRig:FindFirstChildWhichIsA('BasePart', true)
        return part and part.Position or nil
    end

    local function enableFakeCamera(character)
        if fakeCameraConnection then return end
        local head = character:FindFirstChild('Head')
        if not head then return end
        originalCameraType    = Camera.CameraType
        originalCameraSubject = Camera.CameraSubject
        Camera.CameraType     = Enum.CameraType.Scriptable
        fakeCameraConnection  = game:GetService('RunService').RenderStepped:Connect(function()
            if not head or not head.Parent then return end
            Camera.CFrame = head.CFrame * CFrame.new(0, -10, 0)
        end)
    end

    local function disableFakeCamera()
        if fakeCameraConnection then
            fakeCameraConnection:Disconnect()
            fakeCameraConnection = nil
        end
        Camera.CameraType = originalCameraType
        if originalCameraSubject then
            Camera.CameraSubject = originalCameraSubject
        end
    end

    local function enableFigureGodMode(character)
        pcall(function()
            if isFigureGodModeActive then return end
            local humanoid = character:FindFirstChild('Humanoid')
            local hrp = character:FindFirstChild('HumanoidRootPart')
            if not (humanoid and hrp) then return end
            hrp.CFrame = hrp.CFrame + Vector3.new(0, 13, 0)
            humanoid.HipHeight = 13
            enableFakeCamera(character)
            isFigureGodModeActive = true
            Library:Notify({ Title = 'Figure Godmode', Description = 'Activated — floating above Figure', Time = 3 })
        end)
    end

    local function disableFigureGodMode(character)
        pcall(function()
            local humanoid = character:FindFirstChild('Humanoid')
            local hrp = character:FindFirstChild('HumanoidRootPart')
            if humanoid then humanoid.HipHeight = 2 end
            disableFakeCamera()
            -- Move back down
            if hrp then hrp.CFrame = hrp.CFrame - Vector3.new(0, 13, 0) end
            isFigureGodModeActive = false
            Library:Notify({ Title = 'Figure Godmode', Description = 'Deactivated', Time = 3 })
        end)
    end

    local function checkFigureDistance()
        if not figureGodModeEnabled then return end
        pcall(function()
            local character = LocalPlayer.Character
            if not character then return end
            local hrp = character:FindFirstChild('HumanoidRootPart')
            if not hrp then return end

            local figureNearby = false
            local currentRooms = workspace:FindFirstChild('CurrentRooms')
            if not currentRooms then return end

            for _, room in pairs(currentRooms:GetChildren()) do
                local setup = room:FindFirstChild('FigureSetup')
                if setup then
                    local rig = setup:FindFirstChild('FigureRig')
                    if rig then
                        local pos = getFigurePosition(rig)
                        if pos and (hrp.Position - pos).Magnitude <= 28 then
                            figureNearby = true
                            break
                        end
                    end
                end
            end

            if figureNearby and not isFigureGodModeActive then
                enableFigureGodMode(character)
            elseif not figureNearby and isFigureGodModeActive then
                disableFigureGodMode(character)
            end
        end)
    end

    -- Re-apply on respawn
    LocalPlayer.CharacterAdded:Connect(function()
        pcall(function()
            isFigureGodModeActive = false
            disableFakeCamera()
        end)
    end)

    FigureGroup:AddToggle('FigureGodmode', {
        Text    = 'Figure Godmode',
        Default = false,
        Tooltip = 'Floats you above Figure (FigureRig) so it cannot detect you — auto triggers within 28 studs',
        Callback = function(Value)
            figureGodModeEnabled = Value
            if not Value then
                local character = LocalPlayer.Character
                if character and isFigureGodModeActive then
                    disableFigureGodMode(character)
                end
            end
        end
    })

    -- Heartbeat loop to check distance
    game:GetService('RunService').Heartbeat:Connect(function()
        if Library.Unloaded then return end
        checkFigureDistance()
    end)

end)

-- =============================================
-- ANTI CHEAT MANIPULATION
-- =============================================
_addPhase("Build Anti Cheat Manip", function()

    local function safeCall(func, context)
        local success, err = pcall(func)
        if not success then
            warn("[" .. (context or "Unknown") .. "] Error:", err)
        end
    end

    local ExploitsGroup = Tabs.Exploits:AddRightGroupbox('Anti Cheat')

    ExploitsGroup:AddToggle('AntiCheatManip', {
        Text    = 'Anti Cheat Manipulation',
        Default = false,
        Tooltip = 'Hold keybind to trigger anti cheat rollback — clips you through thin walls',
        Callback = function(Value)
            anticheatManipEnabled = Value
            if Value then
                anticheatManipLoop = RunService.Heartbeat:Connect(function()
                    if not anticheatManipEnabled then return end
                    safeCall(function()
                        if isAnticheatKeyHeld and LocalPlayer.Character then
                            LocalPlayer.Character:PivotTo(
                                LocalPlayer.Character:GetPivot()
                                + workspace.CurrentCamera.CFrame.LookVector
                                * Vector3.new(1, 0, 1)
                                * -100
                            )
                        end
                    end, 'AntiCheat Manip Loop')
                end)
            else
                if anticheatManipLoop then
                    anticheatManipLoop:Disconnect()
                    anticheatManipLoop = nil
                end
                isAnticheatKeyHeld = false
            end
        end
    })

    ExploitsGroup:AddLabel('Hold to Trigger'):AddKeyPicker('AntiCheatKey', {
        Default          = 'T',
        SyncToggleState  = false,
        Mode             = 'Hold',
        Text             = 'Anti Cheat Hold Key',
        NoUI             = false,
        Callback = function(Value)
            isAnticheatKeyHeld = Value
        end,
    })

end)

_addPhase("Build Anti Eyes", function()

    local AntiGroup = Tabs.Exploits:AddLeftGroupbox('Anti Entity')
    local RS = game.ReplicatedStorage

    -- Create DisabledEntities folder once
    local DisabledEntities = RS:FindFirstChild('DisabledEntities')
        or Instance.new('Folder', RS)
    DisabledEntities.Name = 'DisabledEntities'

    -- ==================
    -- ANTI HALT
    -- ==================
    AntiGroup:AddToggle('AntiHalt', {
        Text    = 'Anti Halt',
        Default = false,
        Tooltip = 'Removes Halt from ReplicatedStorage before it can spawn, preventing the minigame entirely.',
        Callback = function(Value)
            pcall(function()
                local Entities = RS:FindFirstChild('Entities')
                if not Entities then return end
                if Value then
                    local shade = Entities:FindFirstChild('Shade')
                    if shade then shade.Parent = DisabledEntities end
                    -- Also destroy client module
                    local moduleShade = RS:FindFirstChild('ModulesClient')
                        and RS.ModulesClient:FindFirstChild('EntityModules')
                        and RS.ModulesClient.EntityModules:FindFirstChild('Shade')
                    if moduleShade then moduleShade:Destroy() end
                else
                    local shade = DisabledEntities:FindFirstChild('Shade')
                    if shade then shade.Parent = Entities end
                end
            end)
        end
    })

    -- ==================
    -- ANTI SCREECH
    -- ==================
    AntiGroup:AddToggle('AntiScreech', {
        Text    = 'Anti Screech',
        Default = false,
        Tooltip = 'Removes Screech entity and its remote from ReplicatedStorage so it cannot spawn.',
        Callback = function(Value)
            pcall(function()
                local Entities = RS:FindFirstChild('Entities')
                if not Entities then return end
                if Value then
                    local screech = Entities:FindFirstChild('Screech')
                    if screech then screech.Parent = DisabledEntities end
                    -- Also destroy the Screech remote
                    local screechRemote = RS:FindFirstChild('RemotesFolder')
                        and RS.RemotesFolder:FindFirstChild('Screech')
                    if screechRemote then screechRemote:Destroy() end
                else
                    local screech = DisabledEntities:FindFirstChild('Screech')
                    if screech then screech.Parent = Entities end
                end
            end)
        end
    })

    -- ==================
    -- ANTI EYES
    -- ==================
    AntiGroup:AddToggle('AntiEyes', {
        Text    = 'Anti Eyes',
        Default = false,
        Tooltip = 'Fires the motor remote to avoid Eyes damage.',
        Callback = function(Value)
            antiEyesEnabled = Value
            if Value then
                antiEyesLoop = task.spawn(function()
                    while antiEyesEnabled do
                        pcall(function()
                            for _, v in pairs(workspace:GetDescendants()) do
                                if v.Name == 'Eyes' and v:FindFirstChild('Core') then
                                    local core = v.Core
                                    if core:FindFirstChild('Ambience') and core.Ambience.Playing then
                                        RS.RemotesFolder.MotorReplication:FireServer(-650)
                                        break
                                    end
                                end
                            end
                        end)
                        task.wait()
                    end
                end)
            else
                if antiEyesLoop then
                    task.cancel(antiEyesLoop)
                    antiEyesLoop = nil
                end
            end
        end
    })

    -- ==================
    -- ANTI SNARE
    -- ==================
    local snareHitboxes = {}
    local snareDisabled = false

    AntiGroup:AddToggle('AntiSnare', {
        Text    = 'Anti Snare',
        Default = false,
        Tooltip = 'Disables Snare hitboxes so they cannot trap you.',
        Callback = function(Value)
            snareDisabled = Value
            if Value then
                -- Initial scan using GetDescendants (snare can spawn anywhere)
                for _, inst in ipairs(workspace:GetDescendants()) do
                    if inst.Name == 'Snare' then
                        pcall(function()
                            local hitbox = inst:FindFirstChild('Hitbox')
                            if hitbox then
                                hitbox.CanTouch = false
                                if not table.find(snareHitboxes, hitbox) then
                                    table.insert(snareHitboxes, hitbox)
                                end
                            end
                        end)
                    end
                end

                -- Loop to catch newly spawned snares
                task.spawn(function()
                    while snareDisabled do
                        task.wait(0.5)
                        pcall(function()
                            for _, inst in ipairs(workspace:GetDescendants()) do
                                if inst.Name == 'Snare' then
                                    local hitbox = inst:FindFirstChild('Hitbox')
                                    if hitbox and hitbox.CanTouch then
                                        hitbox.CanTouch = false
                                        if not table.find(snareHitboxes, hitbox) then
                                            table.insert(snareHitboxes, hitbox)
                                        end
                                    end
                                end
                            end
                        end)
                    end
                end)
            else
                for _, hitbox in pairs(snareHitboxes) do
                    pcall(function()
                        if hitbox and hitbox.Parent then
                            hitbox.CanTouch = true
                        end
                    end)
                end
                snareHitboxes = {}
            end
        end
    })

    -- Anti Giggle
    local giggleLoop = nil

    AntiGroup:AddToggle('AntiGiggle', {
        Text    = 'Anti Giggle',
        Default = false,
        Tooltip = 'Disables Giggle hitbox and removes the model from workspace so you cannot hear or see it.',
        Callback = function(Value)
            if Value then
                giggleLoop = task.spawn(function()
                    while Toggles.AntiGiggle.Value do
                        task.wait(0.2)
                        pcall(function()
                            for _, inst in ipairs(workspace:GetDescendants()) do
                                if inst.Name == 'GiggleCeiling' then
                                    -- Disable hitbox
                                    local hitbox = inst:FindFirstChild('Hitbox')
                                    if hitbox then
                                        hitbox.CanTouch = false
                                        -- Delete all TouchTransmitters inside
                                        for _, child in ipairs(hitbox:GetChildren()) do
                                            if child:IsA('TouchTransmitter') then
                                                child:Destroy()
                                            end
                                        end
                                    end
                                    -- Delete the entire model
                                    inst:Destroy()
                                end
                            end
                        end)
                    end
                end)
            else
                if giggleLoop then
                    task.cancel(giggleLoop)
                    giggleLoop = nil
                end
            end
        end
    })

    -- Anti Giggle
    local giggleLoop = nil

    AntiGroup:AddDivider()

    AntiGroup:AddToggle('AntiDupe', {
        Text    = 'Anti Dupe',
        Default = false,
        Tooltip = 'Disables dupe room traps that can send you back to a previous room.',
    })

    task.spawn(function()
        workspace.DescendantAdded:Connect(function(child)
            if not (Toggles.AntiDupe and Toggles.AntiDupe.Value) then return end
            pcall(function()
                if child:IsA('Model') and (child:GetAttribute('LoadModule') == 'DupeRoom' or child:GetAttribute('LoadModule') == 'SpaceSideroom') then
                    for _, v in pairs(child:GetDescendants()) do
                        if v:IsA('BasePart') then v.CanTouch = false end
                    end
                end
            end)
        end)
    end)

end)

-- =============================================
-- ENTITY ALERTS
-- =============================================
_addPhase("Build Entity Alerts", function()

    local AlertGroup = Tabs.Visuals:AddLeftGroupbox('Entity Alerts')

    AlertGroup:AddToggle('EntityAlerts', {
        Text    = 'Entity Alerts',
        Default = false,
        Tooltip = 'Notifies you when a dangerous entity spawns',
    })

    local alerted = {} -- track by instance, not name, to support multiple entities

    local AlertConfig = {
        -- Rush/Ambush/others: detected by Highlight existing on entity
        {
            name        = 'RushMoving',
            display     = 'Rush',
            color       = Color3.fromRGB(255, 50, 50),
            check       = function(e)
                return e:FindFirstChildOfClass('Highlight') ~= nil
            end,
            onDetect    = function(e)

            end,
        },
        {
            name        = 'AmbushMoving',
            display     = 'Ambush',
            color       = Color3.fromRGB(255, 100, 0),
            check       = function(e)
                return e:FindFirstChildOfClass('Highlight') ~= nil
            end,
            onDetect    = function(e)

            end,
        },
        {
            name        = 'Screech',
            display     = 'Screech',
            color       = Color3.fromRGB(200, 0, 255),
            check       = function(e) return e ~= nil end,
            onDetect    = function(_) end,
        },
        {
            name        = 'Halt',
            display     = 'Halt',
            color       = Color3.fromRGB(255, 200, 0),
            check       = function(e) return e ~= nil end,
            onDetect    = function(_) end,
        },
        {
            name        = 'BackdoorRush',
            display     = 'Blitz',
            color       = Color3.fromRGB(255, 50, 50),
            check       = function(e)
                return e:FindFirstChildOfClass('Highlight') ~= nil
            end,
            onDetect    = function(e)

            end,
        },
        -- A-60: detected by A60.Main existing
        {
            name        = 'A60',
            display     = 'A-60',
            color       = Color3.fromRGB(255, 0, 100),
            check       = function(e)
                return e:FindFirstChild('Main') ~= nil
            end,
            onDetect    = function(_) end,
        },
        -- A-120: detected by A120.Main existing
        {
            name        = 'A120',
            display     = 'A-120',
            color       = Color3.fromRGB(200, 0, 150),
            check       = function(e)
                return e:FindFirstChild('Main') ~= nil
            end,
            onDetect    = function(_) end,
        },

    }

    task.spawn(function()
        while task.wait(0.2) do
            if Library.Unloaded then break end
            if not Toggles.EntityAlerts.Value then continue end

            for _, cfg in ipairs(AlertConfig) do
                -- Collect all matching instances
                local entities = {}
                if cfg.descendants then
                    for _, inst in ipairs(workspace:GetDescendants()) do
                        if inst.Name == cfg.name then
                            table.insert(entities, inst)
                        end
                    end
                else
                    for _, inst in ipairs(workspace:GetChildren()) do
                        if inst.Name == cfg.name then
                            table.insert(entities, inst)
                        end
                    end
                end

                -- Alert any new instances not yet tracked
                for _, entity in ipairs(entities) do
                    if not alerted[entity] then
                        local ok = pcall(cfg.check, entity) and cfg.check(entity)
                        if ok then
                            alerted[entity] = true
                            pcall(cfg.onDetect, entity)
                            Library:Notify({
                                Title       = 'Entity Alert',
                                Description = cfg.display .. ' has spawned!',
                                Time        = 4,
                            })
                            -- Auto-cleanup when entity despawns
                            entity.AncestryChanged:Connect(function()
                                if not entity.Parent then
                                    alerted[entity] = nil
                                end
                            end)
                        end
                    end
                end
            end
        end
    end)

end)

-- =============================================
-- DOOR REACH
-- =============================================
_addPhase("Build Door Reach", function()

    local ReachGroup = Tabs.Main:AddLeftGroupbox('Door Reach')

    ReachGroup:AddToggle('DoorReach', {
        Text    = 'Door Reach',
        Default = false,
        Tooltip = 'Auto opens doors within range using ClientOpen remote',
    })

    ReachGroup:AddSlider('DoorReachDistance', {
        Text     = 'Reach Distance',
        Default  = 20,
        Min      = 10,
        Max      = 100,
        Rounding = 0,
        Tooltip  = 'Distance in studs to auto open doors',
    })

    task.spawn(function()
        while task.wait(0.2) do
            if Library.Unloaded then break end
            if not Toggles.DoorReach.Value then continue end

            local character = LocalPlayer.Character
            if not character then continue end
            local hrp = character:FindFirstChild('HumanoidRootPart')
            if not hrp then continue end

            local range = Options.DoorReachDistance.Value
            local currentRooms = workspace:FindFirstChild('CurrentRooms')
            if not currentRooms then continue end

            for _, room in ipairs(currentRooms:GetChildren()) do
                for _, obj in ipairs(room:GetChildren()) do
                    if obj.Name == 'Door' then
                        local clientOpen = obj:FindFirstChild('ClientOpen')
                        if clientOpen then
                            local doorPart = obj:FindFirstChildOfClass('BasePart')
                                or obj:FindFirstChildWhichIsA('BasePart', true)
                            if doorPart then
                                local dist = (hrp.Position - doorPart.Position).Magnitude
                                if dist <= range then
                                    pcall(function()
                                        clientOpen:FireServer()
                                    end)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

end)

-- =============================================
-- DISABLE SEEK ARMS & CHANDELIER
-- =============================================
_addPhase("Build Seek Bypass", function()

    local SeekGroup = Tabs.Exploits:AddLeftGroupbox('Seek Bypass')

    local disabledObjects = {}

    local function applySeekBypass()
        for _, room in pairs(workspace.CurrentRooms:GetChildren()) do
            pcall(function()
                local assets = room:FindFirstChild('Assets')
                if not assets then return end

                -- Disable chandeliers
                for _, chandelier in pairs(assets:GetChildren()) do
                    if chandelier.Name == 'ChandelierObstruction' then
                        local collision = chandelier:FindFirstChild('Collision')
                        if collision then
                            collision.CanTouch = false
                            collision.CanQuery = false
                            if not table.find(disabledObjects, collision) then
                                table.insert(disabledObjects, collision)
                            end
                        end
                    end
                end

                -- Disable Seek arms
                for _, object in pairs(assets:GetDescendants()) do
                    if object:IsA('Model') and object:GetAttribute('LoadModule') == 'AnimatedObstacleKill' then
                        for _, part in pairs(object:GetDescendants()) do
                            if part:IsA('BasePart') then
                                part.CanTouch = false
                                part.CanQuery = false
                                if not table.find(disabledObjects, part) then
                                    table.insert(disabledObjects, part)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end

    local function restoreSeekBypass()
        for _, part in pairs(disabledObjects) do
            pcall(function()
                part.CanTouch = true
                part.CanQuery = true
            end)
        end
        disabledObjects = {}
    end

    local seekBypassLoop = nil

    SeekGroup:AddToggle('SeekBypass', {
        Text    = 'Disable Seek Arms & Chandelier',
        Default = false,
        Tooltip = 'Removes hitboxes from Seek arms and chandeliers so they cannot kill you',
        Callback = function(Value)
            if Value then
                applySeekBypass()
                -- Also apply on new rooms loading
                seekBypassLoop = workspace.CurrentRooms.ChildAdded:Connect(function()
                    task.wait(0.2) -- wait for room assets to load
                    applySeekBypass()
                end)
            else
                if seekBypassLoop then
                    seekBypassLoop:Disconnect()
                    seekBypassLoop = nil
                end
                restoreSeekBypass()
            end
        end
    })

end)

-- =============================================
-- PLAYER ESP
-- =============================================
_addPhase("Build Player ESP", function()

    local PlayerESPGroup = Tabs.Visuals:AddLeftGroupbox('Player ESP')

    local playerESPEnabled = false
    local playerTags = {}

    local function makePlayerESP(player)
        if player == LocalPlayer then return end

        local heartbeatConn = nil

        local function applyToCharacter(character)
            if not character then return end
            -- Clear old tags so re-apply always works
            playerTags[player] = nil
            -- Disconnect old heartbeat
            if heartbeatConn then heartbeatConn:Disconnect() heartbeatConn = nil end

            pcall(function()
                -- Remove old ESP if still exists
                local oldHL = character:FindFirstChild('_DRS_PlayerHL')
                if oldHL then oldHL:Destroy() end

                local hl = Instance.new('Highlight')
                hl.Name = '_DRS_PlayerHL'
                hl.FillColor = Color3.fromRGB(0, 150, 255)
                hl.OutlineColor = Color3.fromRGB(100, 200, 255)
                hl.FillTransparency = 0.5
                hl.OutlineTransparency = 0
                hl.Adornee = character
                hl.Parent = character

                local hrp = character:WaitForChild('HumanoidRootPart', 3)
                if not hrp then return end

                local oldBB = hrp:FindFirstChild('_DRS_PlayerBB')
                if oldBB then oldBB:Destroy() end

                local bb = Instance.new('BillboardGui')
                bb.Name = '_DRS_PlayerBB'
                bb.Size = UDim2.new(0, 200, 0, 50)
                bb.StudsOffset = Vector3.new(0, 3, 0)
                bb.AlwaysOnTop = true
                bb.LightInfluence = 0
                bb.Parent = hrp

                local label = Instance.new('TextLabel')
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Font = Enum.Font.Oswald
                label.TextScaled = true
                label.TextColor3 = Color3.fromRGB(100, 200, 255)
                label.TextStrokeTransparency = 0.5
                label.Parent = bb

                playerTags[player] = { hl = hl, bb = bb }

                -- Single heartbeat connection stored so it can be disconnected on respawn
                heartbeatConn = game:GetService('RunService').Heartbeat:Connect(function()
                    if not playerESPEnabled or not hrp or not hrp.Parent then
                        if heartbeatConn then heartbeatConn:Disconnect() heartbeatConn = nil end
                        return
                    end
                    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart')
                    if myHRP then
                        local dist = math.floor((myHRP.Position - hrp.Position).Magnitude)
                        label.Text = player.Name .. ' [' .. dist .. ' studs]'
                    else
                        label.Text = player.Name
                    end
                end)
            end)
        end

        applyToCharacter(player.Character)
        player.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            if playerESPEnabled then
                applyToCharacter(char)
            end
        end)
    end

    local function removePlayerESP(player)
        if playerTags[player] then
            pcall(function()
                if playerTags[player].hl then playerTags[player].hl:Destroy() end
                if playerTags[player].bb and playerTags[player].bb.Parent then
                    playerTags[player].bb:Destroy()
                end
            end)
            playerTags[player] = nil
        end
        -- Also clean from character directly
        if player.Character then
            pcall(function()
                local hl = player.Character:FindFirstChild('_DRS_PlayerHL')
                if hl then hl:Destroy() end
                local hrp = player.Character:FindFirstChild('HumanoidRootPart')
                if hrp then
                    local bb = hrp:FindFirstChild('_DRS_PlayerBB')
                    if bb then bb:Destroy() end
                end
            end)
        end
    end

    PlayerESPGroup:AddToggle('PlayerESP', {
        Text    = 'Player ESP',
        Default = false,
        Tooltip = 'Shows all players through walls with name and distance',
        Callback = function(Value)
            playerESPEnabled = Value
            if Value then
                for _, player in ipairs(game:GetService('Players'):GetPlayers()) do
                    makePlayerESP(player)
                end
                game:GetService('Players').PlayerAdded:Connect(function(player)
                    if playerESPEnabled then makePlayerESP(player) end
                end)
            else
                for _, player in ipairs(game:GetService('Players'):GetPlayers()) do
                    removePlayerESP(player)
                end
            end
        end
    })

end)

-- =============================================
-- AUTO ELEVATOR BREAKER
-- =============================================
_addPhase("Build Auto Elevator Breaker", function()

    local EBGroup = Tabs.Main:AddLeftGroupbox('Cool Stuff')

    local finishRoom100Enabled = false
    local finishRoom100Loop = nil
    local elevatorBreakerFound = false

    local function safeCall(fn, ctx)
        local ok, err = pcall(fn)
        if not ok then warn('[' .. (ctx or '?') .. '] ' .. tostring(err)) end
    end

    EBGroup:AddToggle('AutoElevatorBreaker', {
        Text    = 'Auto Elevator Breaker',
        Default = false,
        Tooltip = 'Auto completes the Room 100 elevator breaker minigame.',
        Callback = function(Value)
            finishRoom100Enabled = Value
            elevatorBreakerFound = false

            if Value then
                Library:Notify({ Title = 'Room 100 Minigame', Description = 'Searching for ElevatorBreaker...', Time = 5 })

                finishRoom100Loop = task.spawn(function()
                    -- Phase 1: wait for ElevatorBreakerEmpty
                    local emptyFound = false
                    while finishRoom100Enabled and not emptyFound do
                        task.wait(0.1)
                        safeCall(function()
                            local currentRooms = workspace:FindFirstChild('CurrentRooms')
                            if not currentRooms then return end
                            for _, room in pairs(currentRooms:GetChildren()) do
                                if room:FindFirstChild('ElevatorBreakerEmpty', true) then
                                    emptyFound = true
                                    Library:Notify({ Title = 'Room 100 Minigame', Description = 'ElevatorBreakerEmpty found! Waiting for transformation...', Time = 3 })
                                    break
                                end
                            end
                        end, 'Room 100 - Check for Empty')
                    end

                    -- Phase 2: find ElevatorBreaker and fire prompt
                    while finishRoom100Enabled and not elevatorBreakerFound do
                        task.wait(3)
                        safeCall(function()
                            local currentRooms = workspace:FindFirstChild('CurrentRooms')
                            if not currentRooms then return end
                            for _, room in pairs(currentRooms:GetChildren()) do
                                local elevatorBreaker = room:FindFirstChild('ElevatorBreaker', true)
                                if elevatorBreaker then
                                    elevatorBreakerFound = true
                                    Library:Notify({ Title = 'Room 100 Minigame', Description = 'ElevatorBreaker found! Starting auto-complete...', Time = 3 })
                                    task.wait(0.5)
                                    local activatePrompt = elevatorBreaker:FindFirstChild('ActivateEventPrompt', true)
                                    if activatePrompt and activatePrompt:IsA('ProximityPrompt') then
                                        fireproximityprompt(activatePrompt)
                                        Library:Notify({ Title = 'Room 100 Minigame', Description = 'Activated event prompt!', Time = 2 })
                                    end
                                    break
                                end
                            end
                        end, 'Room 100 - Check for Breaker')
                    end

                    -- Phase 3: spam EBF remote until disabled
                    while finishRoom100Enabled and elevatorBreakerFound do
                        task.wait(1)
                        safeCall(function()
                            game.ReplicatedStorage:WaitForChild('RemotesFolder'):WaitForChild('EBF'):FireServer()
                        end, 'Room 100 - Fire EBF Remote')
                    end
                end)
            else
                if finishRoom100Loop then task.cancel(finishRoom100Loop) finishRoom100Loop = nil end
                elevatorBreakerFound = false
            end
        end
    })

end)

-- =============================================
-- NO ACCELERATION
-- =============================================
_addPhase("Build No Acceleration", function()

    local NoAccelGroup = Tabs.Main:AddRightGroupbox('Misc')

    local noAccelEnabled = false
    local noAccelLoop = nil
    local originalHrpProps = nil

    NoAccelGroup:AddToggle('NoAcceleration', {
        Text    = 'No Acceleration',
        Default = false,
        Tooltip = 'Removes movement acceleration so you move at full speed instantly (Useless text: 67)',
        Callback = function(Value)
            noAccelEnabled = Value
            if Value then
                local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                local hrp = character:FindFirstChild('HumanoidRootPart')
                if hrp then
                    originalHrpProps = hrp.CustomPhysicalProperties
                    hrp.CustomPhysicalProperties = PhysicalProperties.new(100, 0.7, 0, 1, 1)
                end
                noAccelLoop = task.spawn(function()
                    while noAccelEnabled do
                        task.wait(0.5)
                        pcall(function()
                            local char = LocalPlayer and LocalPlayer.Character
                            if char then
                                local h = char:FindFirstChild('HumanoidRootPart')
                                if h then
                                    local cpp = h.CustomPhysicalProperties
                                    if not cpp or cpp.Density ~= 100 then
                                        h.CustomPhysicalProperties = PhysicalProperties.new(100, 0.7, 0, 1, 1)
                                    end
                                end
                            end
                        end)
                    end
                end)
            else
                if noAccelLoop then
                    task.cancel(noAccelLoop)
                    noAccelLoop = nil
                end
                local char = LocalPlayer and LocalPlayer.Character
                if char then
                    local h = char:FindFirstChild('HumanoidRootPart')
                    if h and originalHrpProps then
                        h.CustomPhysicalProperties = originalHrpProps
                    end
                end
                originalHrpProps = nil
            end
        end
    })

end)

-- =============================================
-- AUTO INTERACT
-- =============================================

-- =============================================
-- AURA
-- =============================================
_addPhase("Build Aura", function()

    local AuraGroup = Tabs.Main:AddRightGroupbox('Aura')

    AuraGroup:AddToggle('AutoInteract', {
        Text    = 'Aura',
        Default = false,
        Tooltip = 'Auto fires all nearby proximity prompts. Skips paintings and hide prompts.',
    })

    AuraGroup:AddSlider('AutoInteractRange', {
        Text     = 'Range',
        Default  = 19,
        Min      = 5,
        Max      = 50,
        Rounding = 0,
        Tooltip  = 'Distance in studs for Aura.',
    })

    AuraGroup:AddDivider()

    AuraGroup:AddDropdown('AuraIgnoreList', {
        Text   = 'Ignore List',
        Multi  = true,
        Values = { 'Ignore Drops', 'Ignore Jeff Items' },
        Default = {},
        Tooltip = 'Blacklist certain item types from being picked up by Aura.',
    })

    AuraGroup:AddDivider()

    AuraGroup:AddToggle('InstaInteract', {
        Text    = 'Instant Interact',
        Default = false,
        Tooltip = 'Sets hold duration of all prompts to 0 so every interaction is instant.',
    })

    local function shouldAura(prompt)
        if not prompt or not prompt.Enabled then return false end
        local parent = prompt.Parent
        if not parent then return false end

        -- Use ObjectText (the actual interaction label) if available
        local objectText = prompt.ObjectText or ''
        local parentName = parent:IsA('Model') and parent.Name or ''

        -- Skip paintings
        if parentName:lower():find('paint') then return false end

        -- Skip Wardrobe hide prompt
        if parentName:lower():find('wardrobe') then return false end

        -- Skip Bed hide prompt
        if parentName:lower():find('bed') then return false end

        -- Skip Toilet
        if parentName:lower():find('toilet') then return false end

        return true
    end

    -- Cache prompts, rebuild every 2s or on room change
    local cachedPrompts = {}
    local cacheDirty = true
    local lastCacheTime = 0

    local function rebuildCache()
        cacheDirty = false
        cachedPrompts = {}
        for _, inst in ipairs(workspace:GetDescendants()) do
            if inst:IsA('ProximityPrompt') then
                -- Store original values once
                if not inst:GetAttribute('_OrigHold') then
                    inst:SetAttribute('_OrigHold', inst.HoldDuration)
                end
                -- Apply current settings
                inst.HoldDuration = Toggles.InstaInteract.Value and 0 or (inst:GetAttribute('_OrigHold') or inst.HoldDuration)
                table.insert(cachedPrompts, inst)
            end
        end
    end

    -- Re-apply when toggles change
    Toggles.InstaInteract:OnChanged(function() cacheDirty = true end)

    local currentRooms = workspace:WaitForChild('CurrentRooms', 10)
    if currentRooms then
        currentRooms.ChildAdded:Connect(function() cacheDirty = true end)
        currentRooms.ChildRemoved:Connect(function() cacheDirty = true end)
    end
    workspace.ChildAdded:Connect(function() cacheDirty = true end)

    local lastAura = 0

    RunService.Heartbeat:Connect(function()
        if Library.Unloaded then return end

        local now = tick()
        if cacheDirty or (now - lastCacheTime) >= 2 then
            rebuildCache()
            lastCacheTime = now
        end

        if not Toggles.AutoInteract.Value then return end
        if (now - lastAura) < 0.1 then return end
        lastAura = now

        local character = LocalPlayer.Character
        if not character then return end
        local hrp = character:FindFirstChild('HumanoidRootPart')
        if not hrp then return end

        local range = Options.AutoInteractRange.Value

        for _, prompt in ipairs(cachedPrompts) do
            if not prompt.Parent then continue end
            if shouldAura(prompt) then
                local part = prompt.Parent
                if not part:IsA('BasePart') then
                    part = prompt.Parent:FindFirstChildOfClass('BasePart')
                        or (prompt.Parent.Parent and prompt.Parent.Parent:FindFirstChildWhichIsA('BasePart', true))
                end
                if part and part:IsA('BasePart') then
                    local dist = (hrp.Position - part.Position).Magnitude
                    local maxDist = math.min(range, prompt.MaxActivationDistance)
                    if dist <= maxDist then
                        pcall(fireproximityprompt, prompt)
                    end
                end
            end
        end
    end)

end)

-- =============================================
-- MODIFIERS
-- =============================================
-- =============================================
-- GODMODE (GROUNDED)
-- =============================================
_addPhase("Build Godmode", function()

    local RunService = game:GetService('RunService')

    local function safeCall(fn)
        local ok, err = pcall(fn)
        if not ok then _log('[GodMode Error] ' .. tostring(err)) end
    end

    local function saveOriginalGodMode(character)
        safeCall(function()
            local humanoid  = character:WaitForChild('Humanoid')
            local root      = character:WaitForChild('HumanoidRootPart')
            local collision = character:WaitForChild('Collision', 5)
            if not collision then return end
            godModeSaved = {
                HipHeight               = humanoid.HipHeight,
                RootCanCollide          = root.CanCollide,
                RootCollisionGroup      = root.CollisionGroup,
                CollisionSize           = collision.Size,
                CollisionCanCollide     = collision.CanCollide,
                CollisionCanTouch       = collision.CanTouch,
                CollisionCanQuery       = collision.CanQuery,
                CollisionCollisionGroup = collision.CollisionGroup,
            }
        end)
    end

    local function applyGodMode(character)
        safeCall(function()
            local humanoid  = character:FindFirstChild('Humanoid')
            local root      = character:FindFirstChild('HumanoidRootPart')
            local collision = character:FindFirstChild('Collision', true)
            if not (humanoid and root and collision) then return end
            root.CanCollide          = false
            collision.Size           = Vector3.new(1, 0.1, 3)
            collision.CanCollide     = true
            collision.CollisionGroup = 'PlayerCrouching'
            humanoid.HipHeight       = 0
        end)
    end

    local function restoreOriginalGodMode(character)
        safeCall(function()
            local humanoid  = character:FindFirstChild('Humanoid')
            local root      = character:FindFirstChild('HumanoidRootPart')
            local collision = character:FindFirstChild('Collision', true)
            if not (humanoid and root and collision and godModeSaved.HipHeight) then return end
            humanoid.HipHeight              = godModeSaved.HipHeight
            root.CanCollide                 = godModeSaved.RootCanCollide
            root.CollisionGroup             = godModeSaved.RootCollisionGroup
            collision.Size                  = godModeSaved.CollisionSize
            collision.CanCollide            = godModeSaved.CollisionCanCollide
            collision.CanTouch              = godModeSaved.CollisionCanTouch
            collision.CanQuery              = godModeSaved.CollisionCanQuery
            collision.CollisionGroup        = godModeSaved.CollisionCollisionGroup
        end)
    end

    local function teleportUp(character)
        safeCall(function()
            local root = character:FindFirstChild('HumanoidRootPart')
            if not root then return end
            root.CFrame = root.CFrame + Vector3.new(0, 3, 0)
        end)
    end

    local function startGodModeLoop(character)
        safeCall(function()
            if godModeConnection then godModeConnection:Disconnect() end
            godModeConnection = RunService.Heartbeat:Connect(function()
                if godModeEnabled then applyGodMode(character) end
            end)
        end)
    end

    local function stopGodModeLoop()
        safeCall(function()
            if godModeConnection then
                godModeConnection:Disconnect()
                godModeConnection = nil
            end
        end)
    end

    local function enableGodMode()
        safeCall(function()
            local character = LocalPlayer.Character
            if not character or godModeEnabled then return end
            saveOriginalGodMode(character)
            godModeEnabled = true
            startGodModeLoop(character)
            Library:Notify({ Title = 'Grounded', Description = 'GodMode Enabled', Time = 3 })
        end)
    end

    local function disableGodMode()
        safeCall(function()
            local character = LocalPlayer.Character
            if not character or not godModeEnabled then return end
            godModeEnabled = false
            stopGodModeLoop()
            restoreOriginalGodMode(character)
            teleportUp(character)
            Library:Notify({ Title = 'Grounded', Description = 'GodMode Disabled', Time = 3 })
        end)
    end

    -- Auto detection loop
    task.spawn(function()
        while task.wait(0.1) do
            if Library.Unloaded then break end
            if not godModeAutoEnabled then continue end
            safeCall(function()
                local character = LocalPlayer.Character
                if not character then return end
                local hrp = character:FindFirstChild('HumanoidRootPart')
                if not hrp then return end

                local triggerDist = Options.GodModeDistance and Options.GodModeDistance.Value or 250
                local shouldEnable = false
                local entities = { 'RushMoving', 'AmbushMoving', 'BackdoorRush' }

                for _, entityName in ipairs(entities) do
                    local entity = workspace:FindFirstChild(entityName)
                    if entity then
                        local part = entity:FindFirstChildWhichIsA('BasePart')
                        if part then
                            if (hrp.Position - part.Position).Magnitude <= triggerDist then
                                shouldEnable = true
                                break
                            end
                        end
                    end
                end

                if shouldEnable and not godModeEnabled then
                    enableGodMode()
                elseif not shouldEnable and godModeEnabled then
                    disableGodMode()
                end
            end)
        end
    end)

    -- Re-apply on respawn
    LocalPlayer.CharacterAdded:Connect(function(character)
        safeCall(function()
            if godModeEnabled then
                task.wait(0.1)
                saveOriginalGodMode(character)
                startGodModeLoop(character)
            end
        end)
    end)

    -- UI
    local GodGroup = Tabs.Main:AddRightGroupbox('Godmode')

    GodGroup:AddToggle('GodModeEnabled', {
        Text    = 'Grounded',
        Default = false,
        Tooltip = 'Shrinks your collision box so Rush, Ambush and Blitz cannot hit you. Do not manually crouch while this is active.',
        Callback = function(Value)
            if Value then enableGodMode() else disableGodMode() end
        end
    })

    GodGroup:AddToggle('GodModeAuto', {
        Text    = 'Auto Godmode',
        Default = false,
        Tooltip = 'Auto-enables when Rush, Ambush or Blitz are nearby',
        Callback = function(Value)
            godModeAutoEnabled = Value
            if not Value and godModeEnabled then disableGodMode() end
        end
    })

    local AutoDepbox = GodGroup:AddDependencyBox()
    AutoDepbox:AddSlider('GodModeDistance', {
        Text     = 'Trigger Distance',
        Default  = 250,
        Min      = 50,
        Max      = 500,
        Rounding = 0,
        Tooltip  = 'Distance in studs at which Auto Grounded activates',
    })
    AutoDepbox:SetupDependencies({ { Toggles.GodModeAuto, true } })

    -- ==================
    -- CROUCH SPOOF
    -- ==================
    local crouchSpoofLoop = nil

    GodGroup:AddDivider()

    GodGroup:AddToggle('CrouchSpoof', {
        Text    = 'Crouch Spoof',
        Default = false,
        Tooltip = 'Continuously tells the server you are crouched so Figure hears you at a much smaller radius, even while walking.',
        Callback = function(Value)
            if Value then
                crouchSpoofLoop = task.spawn(function()
                    while Toggles.CrouchSpoof.Value do
                        task.wait(0.1)
                        pcall(function()
                            game.ReplicatedStorage.RemotesFolder.Crouch:FireServer(true, true)
                        end)
                    end
                end)
            else
                if crouchSpoofLoop then
                    task.cancel(crouchSpoofLoop)
                    crouchSpoofLoop = nil
                end
                -- Tell server we stopped crouching
                pcall(function()
                    game.ReplicatedStorage.RemotesFolder.Crouch:FireServer(false, false)
                end)
            end
        end
    })

end)


-- WATERMARK
-- =============================================
_addPhase("Setup Watermark", function()
    Library:SetWatermarkVisibility(false)

    Library.KeybindFrame.Visible = true

    Library:OnUnload(function()
        pcall(function()
            -- Reset WalkSpeed
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass('Humanoid')
                if hum then hum.WalkSpeed = 16 end
                local hrp = char:FindFirstChild('HumanoidRootPart')
                if hrp then
                    hrp.CanCollide = true
                    hrp.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0, 0, 0)
                end
            end

            -- Reset lighting
            local Lighting = game:GetService('Lighting')
            if _G.NormalLightingSettings then
                Lighting.Brightness      = _G.NormalLightingSettings.Brightness
                Lighting.ClockTime       = _G.NormalLightingSettings.ClockTime
                Lighting.FogEnd          = _G.NormalLightingSettings.FogEnd
                Lighting.GlobalShadows   = _G.NormalLightingSettings.GlobalShadows
                Lighting.Ambient         = _G.NormalLightingSettings.Ambient
            end

            -- Reset camera
            local cam = workspace.CurrentCamera
            cam.CameraType = Enum.CameraType.Custom
            cam.FieldOfView = 70

            -- Restore Screech and Shade back to Entities
            local RS = game.ReplicatedStorage
            local DisabledEntities = RS:FindFirstChild('DisabledEntities')
            local Entities = RS:FindFirstChild('Entities')
            if DisabledEntities and Entities then
                for _, v in ipairs(DisabledEntities:GetChildren()) do
                    pcall(function() v.Parent = Entities end)
                end
            end

            -- Remove all ESP highlights and billboards from workspace
            for inst in pairs(espTagged) do
                pcall(function()
                    if inst and inst.Parent then
                        local h = inst:FindFirstChild('_DRSESP_HL')
                        if h then h:Destroy() end
                        local b = inst:FindFirstChild('_DRSESP_Bill')
                        if b then b:Destroy() end
                    end
                end)
            end
            espTagged = {}

            -- Remove player ESP
            for _, player in ipairs(game:GetService('Players'):GetPlayers()) do
                pcall(function()
                    if player.Character then
                        local hl = player.Character:FindFirstChild('_DRS_PlayerHL')
                        if hl then hl:Destroy() end
                        local hrp2 = player.Character:FindFirstChild('HumanoidRootPart')
                        if hrp2 then
                            local bb = hrp2:FindFirstChild('_DRS_PlayerBB')
                            if bb then bb:Destroy() end
                        end
                    end
                end)
            end
        end)

        getgenv().INFERNOLoaded = nil
        print('INFERNO v0.814 unloaded cleanly!')
        Library.Unloaded = true
    end)
end)

-- =============================================
-- AUTO HIDE
-- =============================================
-- =============================================
-- ANTI AFK
-- =============================================
_addPhase("Build Anti AFK", function()

    local AFKGroup = Tabs.Main:AddRightGroupbox('Utility')

    local antiAFKConnection = nil

    AFKGroup:AddToggle('AntiAFK', {
        Text    = 'Anti AFK',
        Default = false,
        Tooltip = 'Prevents the game from kicking you for being idle.',
        Callback = function(Value)
            if Value then
                antiAFKConnection = game:GetService('Players').LocalPlayer.Idled:Connect(function()
                    pcall(function()
                        game:GetService('VirtualUser'):Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                        task.wait(1)
                        game:GetService('VirtualUser'):Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                    end)
                end)
            else
                if antiAFKConnection then
                    antiAFKConnection:Disconnect()
                    antiAFKConnection = nil
                end
            end
        end
    })



end)

-- =============================================
-- MINES ANTI CHEAT BYPASS
-- =============================================
-- =============================================
-- FLOOR TAB
_addPhase("Build Floor Tab", function()

    -- ==================
    -- LEFT SIDE
    -- ==================
    local SuperHardGroup = Tabs.Floor:AddLeftGroupbox('Super Hard Mode')

    SuperHardGroup:AddToggle('InfiniteRevive', {
        Text    = 'Infinite Revive',
        Default = false,
        Tooltip = 'Automatically revives you when you die by firing the revive remote.',
    })

    task.spawn(function()
        while task.wait(0.2) do
            if Library.Unloaded then break end
            if not Toggles.InfiniteRevive.Value then continue end
            local character = LocalPlayer.Character
            if not character then continue end
            local humanoid = character:FindFirstChildOfClass('Humanoid')
            if not humanoid then continue end
            if humanoid.Health <= 0 then
                pcall(function()
                    local RS = game.ReplicatedStorage
                    local EntityInfo = RS:FindFirstChild('EntityInfo')
                    if EntityInfo then
                        local Revive = EntityInfo:FindFirstChild('Revive')
                        if Revive then Revive:FireServer() return end
                    end
                    local Bricks = RS:FindFirstChild('Bricks')
                    if Bricks then
                        local Revive = Bricks:FindFirstChild('Revive')
                        if Revive then Revive:FireServer() end
                    end
                end)
            end
        end
    end)

    SuperHardGroup:AddDivider()

    SuperHardGroup:AddToggle('FoolsFigureGodmode', {
        Text    = 'Figure Godmode',
        Default = false,
        Tooltip = 'Disables FigureRagdoll collision so Figure cannot kill you in Super Hard Mode.',
    })
    if currentFloor ~= 'Fools' then Toggles.FoolsFigureGodmode:SetDisabled(true) end
    Toggles.FoolsFigureGodmode.DisabledTooltip = 'Only works in Super Hard Mode (Fools floor).'

    SuperHardGroup:AddDivider()

    SuperHardGroup:AddToggle('FoolsGodmode', {
        Text    = 'Fools Godmode',
        Default = false,
        Tooltip = 'Moves your CollisionPart up by 8 studs so entities cannot hit you. Hold the keybind to activate.',
    })
    if currentFloor ~= 'Fools' then Toggles.FoolsGodmode:SetDisabled(true) end
    Toggles.FoolsGodmode.DisabledTooltip = 'Only works in Super Hard Mode (Fools floor).'

    local foolsGodmodeActive = false
    local foolsGodmodeKeyHeld = false

    SuperHardGroup:AddLabel('Hold to Activate'):AddKeyPicker('FoolsGodmodeKey', {
        Default         = 'G',
        SyncToggleState = false,
        Mode            = 'Hold',
        Text            = 'Fools Godmode Key',
        NoUI            = false,
        Callback = function(Value)
            foolsGodmodeKeyHeld = Value
        end,
    })

    RunService.Heartbeat:Connect(function()
        if Library.Unloaded then return end
        if not Toggles.FoolsGodmode or not Toggles.FoolsGodmode.Value then
            foolsGodmodeActive = false
            return
        end
        if not foolsGodmodeKeyHeld then
            foolsGodmodeActive = false
            return
        end
        local char = LocalPlayer.Character
        if not char then return end
        local collision = char:FindFirstChild('CollisionPart')
        if not collision then return end
        pcall(function()
            collision.Position = collision.Position + Vector3.new(0, 8, 0)
        end)
        foolsGodmodeActive = true
    end)

    workspace.DescendantAdded:Connect(function(child)
        if child.Name == 'FigureRagdoll' and Toggles.FoolsGodmode and Toggles.FoolsGodmode.Value then
            for _, v in pairs(child:GetDescendants()) do
                if v:IsA('BasePart') then
                    v.CanTouch = false
                    task.spawn(function()
                        repeat task.wait() until (LocalPlayer:GetAttribute('CurrentRoom') == 50 or LocalPlayer:GetAttribute('CurrentRoom') == 100)
                        task.wait(5)
                        v.CanCollide = false
                    end)
                end
            end
        end
    end)

    local HotelPlusGroup = Tabs.Floor:AddLeftGroupbox('Hotel-')
    -- Hotel- features go here

    local TheMinesGroup = Tabs.Floor:AddLeftGroupbox('The Mines')

    TheMinesGroup:AddToggle('MinesACBypass', {
        Text    = 'Anti Cheat Bypass',
        Default = false,
        Tooltip = 'Keeps Climbing attribute false so the server anti cheat stays disabled. Notifies when a cutscene tries to break it.',
    })

    if currentFloor ~= 'Mines' then
        Toggles.MinesACBypass:SetDisabled(true)
    end
    Toggles.MinesACBypass.DisabledTooltip = 'Only works in the Mines floor.'

    local function minesDisabled() return currentFloor ~= 'Mines' end

    TheMinesGroup:AddDivider()

    TheMinesGroup:AddToggle('AntiBridgeFall', {
        Text    = 'Anti Bridge Fall',
        Default = false,
        Tooltip = 'Extends bridge barriers so you cannot fall through the gaps in The Mines.',
    })
    if minesDisabled() then Toggles.AntiBridgeFall:SetDisabled(true) end
    Toggles.AntiBridgeFall.DisabledTooltip = 'Only works in The Mines.'

    TheMinesGroup:AddToggle('AntiPipeGap', {
        Text    = 'Anti Pipe Gap',
        Default = false,
        Tooltip = 'Adds invisible platforms over pipe gaps in The Mines so you never fall through.',
    })
    if minesDisabled() then Toggles.AntiPipeGap:SetDisabled(true) end
    Toggles.AntiPipeGap.DisabledTooltip = 'Only works in The Mines.'

    TheMinesGroup:AddToggle('AntiGloomEgg', {
        Text    = 'Anti Gloom Egg',
        Default = false,
        Tooltip = 'Disables the Gloom Egg hitbox so it cannot kill you.',
    })
    if minesDisabled() then Toggles.AntiGloomEgg:SetDisabled(true) end
    Toggles.AntiGloomEgg.DisabledTooltip = 'Only works in The Mines.'

    TheMinesGroup:AddDivider()

    TheMinesGroup:AddToggle('MinecartTeleport', {
        Text    = 'Minecart Teleport',
        Default = false,
        Tooltip = 'Teleports the minecart to the last node of each room during the Seek chase (rooms 45-49). Credit: mspaint (_upio / Bacalhauz).',
    })
    if minesDisabled() then Toggles.MinecartTeleport:SetDisabled(true) end
    Toggles.MinecartTeleport.DisabledTooltip = 'Only works in The Mines.'

    local minecartFound = false

    local function sortNodes(nodes, reversed)
        table.sort(nodes, function(a, b)
            local an = tonumber((a.Name):gsub('[^%d+]', '')) or 0
            local bn = tonumber((b.Name):gsub('[^%d+]', '')) or 0
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

    local function getNodes(room)
        local rn = tonumber(room.Name) or 0
        if not ((rn >= 42 and rn <= 49) or (rn >= 95 and rn <= 100)) then return nil end
        local nodesFolder = room:WaitForChild('RunnerNodes', 5)
        if not nodesFolder then return nil end
        if not nodesFolder:GetAttribute('_mspaint_nodes_pathfind') then return nil end
        local real, fake = {}, {}
        for _, node in ipairs(nodesFolder:GetChildren()) do
            if node:GetAttribute('_mspaint_real_node') then table.insert(real, node)
            elseif node:GetAttribute('_mspaint_fake_node') then table.insert(fake, node) end
        end
        if #real == 0 and #fake == 0 then return nil end
        return { real = sortNodes(real, false), fake = sortNodes(fake, false), roomNumber = rn }
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

    task.spawn(function()
        while task.wait(0.5) do
            if Library.Unloaded then break end
            if not Toggles.MinecartTeleport.Value then continue end
            if currentFloor ~= 'Mines' then continue end

            local currentRooms = workspace:FindFirstChild('CurrentRooms')
            if not currentRooms then continue end

            for _, room in ipairs(currentRooms:GetChildren()) do
                local rn = tonumber(room.Name) or 0
                if not (rn >= 45 and rn <= 49) then continue end
                if room:GetAttribute('_mspaint_player_teleported') then continue end

                local nodesList = getNodes(room)
                if not nodesList then continue end

                destroyNodes(nodesList)
                room:SetAttribute('_mspaint_player_teleported', false)

                if rn == 45 and not minecartFound then
                    Library:Notify({ Title = 'Minecart Teleport', Description = 'Waiting for minecart...', Time = 5 })

                    local minecartRigs = {}
                    task.spawn(function()
                        while not minecartFound and not Library.Unloaded do
                            game:GetService('RunService').RenderStepped:Wait()
                            for _, stuff in ipairs(workspace.CurrentCamera:GetChildren()) do
                                if stuff.Name ~= 'MinecartRig' then continue end
                                table.insert(minecartRigs, stuff)
                                repeat task.wait() until not stuff:IsDescendantOf(workspace.CurrentCamera)
                                table.remove(minecartRigs, 1)
                            end
                        end
                    end)

                    while #minecartRigs == 0 and not Library.Unloaded do task.wait(0.5) end

                    Library:Notify({ Title = 'Minecart Teleport', Description = 'Teleporting! Enjoy the ride!', Time = 8 })
                    task.wait(1.5)

                    local startRoom = math.min(49, LocalPlayer:GetAttribute('CurrentRoom') or 45)
                    while startRoom >= 45 and startRoom <= 49 do
                        if Library.Unloaded then break end
                        local r = currentRooms:FindFirstChild(tostring(startRoom))
                        if not r then break end
                        local nl = getNodes(r)
                        if not nl then break end
                        local lastNode = nl.real[#nl.real]
                        if not lastNode then break end

                        repeat
                            game:GetService('RunService').RenderStepped:Wait()
                            for _, mc in ipairs(minecartRigs) do
                                if mc.PrimaryPart then
                                    mc.PrimaryPart.CFrame = lastNode.CFrame
                                end
                            end
                        until r:WaitForChild('Door'):GetAttribute('Opened')

                        r:SetAttribute('_mspaint_player_teleported', true)
                        minecartFound = true
                        startRoom += 1
                        task.wait(1.2)
                    end
                end
            end
        end
    end)

    -- Apply Mines features on new descendants
    workspace.DescendantAdded:Connect(function(child)
        if currentFloor ~= 'Mines' then return end
        pcall(function()
            -- Anti Bridge Fall
            if Toggles.AntiBridgeFall and Toggles.AntiBridgeFall.Value then
                if child:IsA('BasePart') and child.Name == 'PlayerBarrier' and child.Size.Y == 2.75 and (child.Rotation.X == 0 or child.Rotation.X == 180) then
                    local clone = child:Clone()
                    clone.CFrame = clone.CFrame * CFrame.new(0, 0, -5)
                    clone.Color = Color3.new(1, 1, 1)
                    clone.Name = 'AntiBridge'
                    clone.Size = Vector3.new(clone.Size.X, clone.Size.Y, 11)
                    clone.Transparency = 0
                    clone.Parent = child.Parent
                end
            end
            -- Anti Pipe Gap
            if Toggles.AntiPipeGap and Toggles.AntiPipeGap.Value then
                if child:IsA('BasePart') and child.Name == 'KillBrick' and child.Parent and child.Parent.Name == 'Assets' then
                    local clone = child:Clone()
                    clone.Color = Color3.new(1, 1, 1)
                    clone.Name = 'AntiPipeGap'
                    clone.Position += Vector3.new(0, 20, 0)
                    clone.Size = Vector3.new(9, 4, clone.Size.Z)
                    clone.Transparency = 0
                    clone.Parent = child.Parent
                end
            end
            -- Anti Gloom Egg
            if Toggles.AntiGloomEgg and Toggles.AntiGloomEgg.Value then
                if child:IsA('BasePart') and child.Name == 'Egg' then
                    child.CanTouch = false
                end
            end
        end)
    end)

    -- Re-enable mines toggles when floor changes
    pcall(function()
        game.ReplicatedStorage.GameData.Floor:GetPropertyChangedSignal('Value'):Connect(function()
            local floor = game.ReplicatedStorage.GameData.Floor.Value
            local isMines = floor == 'Mines'
            local isFools = floor == 'Fools'
            Toggles.AntiBridgeFall:SetDisabled(not isMines)
            Toggles.AntiPipeGap:SetDisabled(not isMines)
            Toggles.AntiGloomEgg:SetDisabled(not isMines)
            if Toggles.FoolsGodmode then Toggles.FoolsGodmode:SetDisabled(not isFools) end
        end)
    end)

    task.spawn(function()
        while task.wait(0.1) do
            if Library.Unloaded then break end
            if not Toggles.MinesACBypass.Value then continue end
            local character = LocalPlayer.Character
            if not character then continue end
            local climbingAttr = character:GetAttribute('Climbing')
            if climbingAttr == true then
                Library:Notify({
                    Title       = 'The Mines',
                    Description = 'Cutscene tried to break bypass — resetting...',
                    Time        = 3,
                })
                task.wait(0.5)
                pcall(function() character:SetAttribute('Climbing', false) end)
            end
        end
    end)

    pcall(function()
        game.ReplicatedStorage.GameData.Floor:GetPropertyChangedSignal('Value'):Connect(function()
            local floor = game.ReplicatedStorage.GameData.Floor.Value
            Toggles.MinesACBypass:SetDisabled(floor ~= 'Mines')
        end)
    end)

    -- ==================
    -- RIGHT SIDE: THE ROOMS
    -- ==================
    local RoomsGroup = Tabs.Floor:AddRightGroupbox('The Rooms')

    -- Auto Rooms v1
    local autoRoomsEnabled = false
    local autoRoomsLoop = nil

    RoomsGroup:AddToggle('AutoRooms', {
        Text    = 'Auto Rooms v1',
        Default = false,
        Tooltip = 'Pathfinds to the next door using tweened waypoints. Hides from A-60 and A-120 automatically.',
        Callback = function(Value)
            autoRoomsEnabled = Value
            if Value then
                autoRoomsLoop = task.spawn(function()
                    local TweenService = game:GetService('TweenService')
                    local PathfindingService = game:GetService('PathfindingService')

                    while autoRoomsEnabled do
                        task.wait(0.1)
                        pcall(function()
                            local character = LocalPlayer.Character
                            if not character then return end
                            local hrp = character:FindFirstChild('HumanoidRootPart')
                            if not hrp then return end

                            -- Check for A-60 or A-120 nearby
                            local entityPresent = workspace:FindFirstChild('A60') or workspace:FindFirstChild('A120')
                            if entityPresent then
                                -- Find nearest hide prompt and tween to it
                                local nearestPrompt = nil
                                local nearestDist = math.huge
                                for _, inst in ipairs(workspace:GetDescendants()) do
                                    if inst:IsA('ProximityPrompt') and inst.Name == 'HidePrompt' then
                                        local part = inst.Parent
                                        if part and part:IsA('BasePart') then
                                            local dist = (hrp.Position - part.Position).Magnitude
                                            if dist < nearestDist then
                                                nearestDist = dist
                                                nearestPrompt = inst
                                            end
                                        end
                                    end
                                end
                                if nearestPrompt then
                                    local hidePart = nearestPrompt.Parent
                                    local tween = TweenService:Create(hrp, TweenInfo.new(0.5), {
                                        CFrame = CFrame.new(hidePart.Position)
                                    })
                                    tween:Play()
                                    tween.Completed:Wait()
                                    pcall(fireproximityprompt, nearestPrompt)
                                end
                                return
                            end

                            -- Normal pathfind to door
                            local currentRoomNumber = LocalPlayer:GetAttribute('CurrentRoom')
                            if not currentRoomNumber then return end
                            local currentRoom = workspace.CurrentRooms:FindFirstChild(tostring(currentRoomNumber))
                            if not currentRoom then return end
                            local door = currentRoom:FindFirstChild('Door')
                            if not door then return end
                            local doorPart = door:FindFirstChildOfClass('BasePart')
                                or door:FindFirstChildWhichIsA('BasePart', true)
                            if not doorPart then return end

                            local path = PathfindingService:CreatePath({
                                AgentRadius = 2,
                                AgentHeight = 5,
                                AgentCanJump = false,
                            })

                            path:ComputeAsync(hrp.Position, doorPart.Position)
                            if path.Status == Enum.PathStatus.Success then
                                local speed = Options.SpeedSlider and Options.SpeedSlider.Value or 16
                                local duration = math.max(0.1, 0.5 * (16 / speed))
                                for _, waypoint in ipairs(path:GetWaypoints()) do
                                    if not autoRoomsEnabled then break end
                                    if workspace:FindFirstChild('A60') or workspace:FindFirstChild('A120') then break end
                                    local tween = TweenService:Create(hrp, TweenInfo.new(duration), {
                                        CFrame = CFrame.new(waypoint.Position)
                                    })
                                    tween:Play()
                                    tween.Completed:Wait()
                                end
                            end
                        end)
                    end
                end)
            else
                if autoRoomsLoop then
                    task.cancel(autoRoomsLoop)
                    autoRoomsLoop = nil
                end
            end
        end
    })

    RoomsGroup:AddDivider()

    -- Anti A-90
    local antiA90Enabled = false
    local antiA90Loop = nil

    RoomsGroup:AddToggle('AntiA90', {
        Text    = 'Anti A-90',
        Default = false,
        Tooltip = 'Watches PlayerGui for Stop Right There text — fires didnt to A-90 remote so it thinks you never moved. Works in Hotel- and The Mines.',
        Callback = function(Value)
            antiA90Enabled = Value
            if Value then
                antiA90Loop = task.spawn(function()
                    local A90Remote = game.ReplicatedStorage.RemotesFolder:FindFirstChild('A90')
                    while antiA90Enabled do
                        task.wait(0.05)
                        pcall(function()
                            for _, v in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
                                if v:IsA('TextLabel') and v.Text:find('Stop Right There') then
                                    if A90Remote then
                                        A90Remote:FireServer('didnt')
                                    end
                                    break
                                end
                            end
                        end)
                    end
                end)
            else
                if antiA90Loop then
                    task.cancel(antiA90Loop)
                    antiA90Loop = nil
                end
            end
        end
    })

end)


-- =============================================
-- FUN TAB
-- =============================================
_addPhase("Build Fun Tab", function()

    local FunGroup = Tabs.Fun:AddLeftGroupbox('Fun')

    -- Infinite Crucifix (credit: Vynixu)
    FunGroup:AddButton({
        Text    = 'Infinite Crucifix',
        Tooltip = 'Thanks Vynixu for the Infinite Crucifix script.',
        Func    = function()
            pcall(function()
                local module = loadstring(game:HttpGet('https://raw.githubusercontent.com/RegularVynixu/Utilities/refs/heads/main/Doors/Crucifix%20Everything/Source.lua'))()
                module:GiveCrucifix({
                    Type         = 1,
                    Uses         = 50000,
                    Resist       = false,
                    EntitiesOnly = false,
                    IgnoreList   = {}
                })
                Library:Notify({ Title = 'Infinite Crucifix', Description = 'Crucifix given with 50000 uses!', Time = 3 })
            end)
        end
    })

    -- Infinite Lockpicks
    local pps = game:GetService('ProximityPromptService')
    local dropRemote = game.ReplicatedStorage:WaitForChild('RemotesFolder'):WaitForChild('DropItem')
    local itemName = 'Lockpick'
    local lockpickConn = nil

    local function autoPick()
        task.wait(0.5)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        if not hrp then return end
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA('ProximityPrompt') and v.Parent then
                if v.Parent.Name == itemName or v.Parent:FindFirstChild('Handle') then
                    local dist = (hrp.Position - v.Parent:GetPivot().Position).Magnitude
                    if dist <= 12 then
                        v:InputHoldBegin()
                        v:InputHoldEnd()
                        break
                    end
                end
            end
        end
    end

    FunGroup:AddToggle('InfiniteLockpicks', {
        Text    = 'Infinite Lockpicks',
        Default = false,
        Tooltip = 'Automatically re-drops and picks up the lockpick every time you use it on a door.',
        Callback = function(Value)
            if Value then
                lockpickConn = pps.PromptTriggered:Connect(function(prompt, user)
                    if user ~= LocalPlayer then return end
                    if prompt.Parent and prompt.Parent.Name == itemName then return end
                    local bp = LocalPlayer:FindFirstChild('Backpack')
                    local item = (bp and bp:FindFirstChild(itemName))
                        or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild(itemName))
                    if item then
                        dropRemote:FireServer(item)
                        task.spawn(autoPick)
                    end
                end)
            else
                if lockpickConn then
                    lockpickConn:Disconnect()
                    lockpickConn = nil
                end
            end
        end
    })

end)

-- =============================================
-- UI SETTINGS TAB
-- =============================================
_addPhase("Build UI Settings Tab", function()

    -- [ Menu Controls ]
    local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu', 'wrench')

    MenuGroup:AddToggle('KeybindMenuOpen', {
        Default = Library.KeybindFrame.Visible,
        Text = 'Open Keybind Menu',
        Tooltip = 'Toggle the visibility of the keybind menu panel',
        Callback = function(Value)
            Library.KeybindFrame.Visible = Value
        end
    })

    MenuGroup:AddToggle('ShowCustomCursor', {
        Text = 'Custom Cursor',
        Default = true,
        Tooltip = 'Enables the Obsidian custom cursor',
        Callback = function(Value)
            Library.ShowCustomCursor = Value
        end
    })

    MenuGroup:AddDropdown('NotificationSide', {
        Values = { 'Left', 'Right' },
        Default = 'Right',
        Text = 'Notification Side',
        Callback = function(Value)
            Library:SetNotifySide(Value)
        end
    })

    MenuGroup:AddDropdown('DPIDropdown', {
        Values = { '50%', '75%', '100%', '125%', '150%', '175%', '200%' },
        Default = '100%',
        Text = 'DPI Scale',
        Callback = function(Value)
            Value = Value:gsub('%%', '')
            Library:SetDPIScale(tonumber(Value))
        end
    })

    MenuGroup:AddDivider()
    MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'RightShift', NoUI = true, Text = 'Menu keybind' })
    MenuGroup:AddButton('Unload', function() Library:Unload() end)
    Library.ToggleKeybind = Options.MenuKeybind

    -- [ Game Loader ]


    -- [ Theme & Save ]
    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
    ThemeManager:SetFolder('INFERNO')
    SaveManager:SetFolder('INFERNO/Doors')
    SaveManager:SetSubFolder('Hotel') -- Doors has multiple places
    SaveManager:BuildConfigSection(Tabs['UI Settings'])
    ThemeManager:ApplyToTab(Tabs['UI Settings'])
    SaveManager:LoadAutoloadConfig()
end)

-- =============================================
-- RUN ALL PHASES
-- =============================================
_runPhases()
