local CONFIG_URL = 'https://raw.githubusercontent.com/wafyjessr6362/INFERNO/main/config.json'
local HTTP = game:GetService('HttpService')

local function fetch(url)
    local ok, result = pcall(game.HttpGet, game, url)
    if not ok then
        warn('[INFERNO Loader] Failed to fetch: ' .. url)
        return nil
    end
    return result
end

-- Load config
local configRaw = fetch(CONFIG_URL)
if not configRaw then
    warn('[INFERNO Loader] Could not load config.json')
    return
end

local config = HTTP:JSONDecode(configRaw)

print('==============================')
print('  ' .. config.name .. ' v' .. config.version)
print('  by ' .. config.author)
print('==============================')

-- Detect which script to load based on game
local PlaceId = game.PlaceId

local DOORS_PLACE_IDS = {
    [6516141723] = 'Doors-hotel',
    [7610550999] = 'Doors-hotel',
    [15532962292] = 'Doors-hotel',
}

local scriptName = DOORS_PLACE_IDS[PlaceId]

if not scriptName then
    warn('[INFERNO Loader] This game is not supported.')
    return
end

local scriptUrl = config.scripts[scriptName]

if not scriptUrl or scriptUrl == 'coming soon' then
    warn('[INFERNO Loader] ' .. scriptName .. ' is coming soon!')
    return
end

print('[INFERNO Loader] Loading ' .. scriptName .. '...')

local scriptContent = fetch(scriptUrl)
if not scriptContent then
    warn('[INFERNO Loader] Failed to load script.')
    return
end

local fn, err = loadstring(scriptContent)
if not fn then
    warn('[INFERNO Loader] Script error: ' .. tostring(err))
    return
end

fn()
