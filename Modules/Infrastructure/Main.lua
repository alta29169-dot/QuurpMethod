-- Main.lua – qurp v3 (Phase 1)
-- I love you

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Debug = _G._Modules.Debug
local StateManager = _G._Modules.StateManager
local DockLocator = _G._Modules.DockLocator
local HarbourTeleporter = _G._Modules.HarbourTeleporter
local AirportManager = _G._Modules.AirportManager
local AutoSeater = _G._Modules.AutoSeater

local isRunning = true

-- ==========================================
-- ON RESPAWN
-- ==========================================
local function onRespawn(char)
    -- Debounce
    if not StateManager:canRespawn() then
        Debug.warn("Main", "Duplicate respawn ignored")
        return
    end

    local myGen = StateManager:nextGeneration()
    Debug.info("Main", "=== RESPAWN DETECTED (gen " .. myGen .. ") ===")

    -- Reset all state
    StateManager.resetAll()
    StateManager.set("isAlive", true)
    StateManager.set("generation", myGen)

    -- Wait for character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local waitCount = 0
    while not hrp and waitCount < 50 do
        waitCount = waitCount + 1
        hrp = char:FindFirstChild("HumanoidRootPart")
        task.wait(0.1)
    end

    if not hrp then
        Debug.warn("Main", "HRP never loaded")
        return
    end

    Debug.info("Main", "Character loaded")
    StateManager.set("characterLoaded", true)

    -- Teleport to harbour
    local teleportSuccess = HarbourTeleporter.teleportToHarbour(myGen)
    if not teleportSuccess then
        Debug.warn("Main", "Teleport failed — retrying on next spawn")
        return
    end

    Debug.info("Main", "Teleport successful")

    -- Cache airports (once per respawn)
    AirportManager.cacheAirports(myGen)

    -- Debug: Check cache
    local cache = StateManager.get("airportCache")
    Debug.info("Main", "Airport cache has " .. (#cache or 0) .. " airports")

    -- Start AutoSeater (runs in background until death)
    Debug.info("Main", "Calling AutoSeater.start with gen " .. myGen)
    AutoSeater.start(myGen)

    Debug.info("Main", "AutoSeater started")
end

-- ==========================================
-- START (Always Running)
-- ==========================================
local function start()
    Debug.info("Main", "=== qurp v3 Engine Starting ===")

    -- Connect respawn handler
    player.CharacterAdded:Connect(onRespawn)

    -- Handle initial spawn
    if player.Character then
        task.spawn(onRespawn, player.Character)
    else
        Debug.info("Main", "No character yet — waiting for spawn")
    end

    -- Keep the engine running FOREVER
    while isRunning do
        task.wait(1)
    end
end

return {
    start = start,
}
