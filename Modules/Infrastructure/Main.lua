-- Main.lua – qurp v3 (Phase 1)
-- I love you Azzy

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
    print("[Main] 🔥 ON RESPAWN FIRED!")
    
    -- Debounce
    if not StateManager:canRespawn() then
        Debug.warn("Main", "Duplicate respawn ignored")
        print("[Main] Duplicate respawn ignored")
        return
    end

    local myGen = StateManager:nextGeneration()
    Debug.info("Main", "=== RESPAWN DETECTED (gen " .. myGen .. ") ===")
    print("[Main] === RESPAWN DETECTED (gen " .. myGen .. ") ===")

    -- Reset all state
    StateManager.resetAll()
    StateManager.set("isAlive", true)
    StateManager.set("generation", myGen)
    print("[Main] State reset")

    -- Wait for character
    print("[Main] Waiting for HRP...")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local waitCount = 0
    while not hrp and waitCount < 50 do
        waitCount = waitCount + 1
        hrp = char:FindFirstChild("HumanoidRootPart")
        task.wait(0.1)
    end

    if not hrp then
        Debug.warn("Main", "HRP never loaded")
        print("[Main] ❌ HRP never loaded!")
        return
    end

    print("[Main] ✅ HRP found!")
    Debug.info("Main", "Character loaded")
    StateManager.set("characterLoaded", true)

    -- Teleport to harbour
    print("[Main] Teleporting to harbour...")
    local teleportSuccess = HarbourTeleporter.teleportToHarbour(myGen)
    if not teleportSuccess then
        Debug.warn("Main", "Teleport failed — retrying on next spawn")
        print("[Main] ❌ Teleport failed!")
        return
    end

    print("[Main] ✅ Teleport successful!")
    Debug.info("Main", "Teleport successful")

    -- Cache airports (once per respawn)
    print("[Main] Caching airports...")
    AirportManager.cacheAirports(myGen)

    -- Debug: Check cache
    local cache = StateManager.get("airportCache")
    print("[Main] Airport cache has " .. (#cache or 0) .. " airports")
    Debug.info("Main", "Airport cache has " .. (#cache or 0) .. " airports")

    -- Start AutoSeater (runs in background until death)
    print("[Main] Calling AutoSeater.start with gen " .. myGen)
    Debug.info("Main", "Calling AutoSeater.start with gen " .. myGen)

    -- Safety check before calling AutoSeater
    if AutoSeater and AutoSeater.start then
        print("[Main] ✅ AutoSeater exists, calling start...")
        AutoSeater.start(myGen)
        print("[Main] AutoSeater.start returned")
    else
        print("[Main] ❌ AutoSeater or AutoSeater.start is nil!")
        Debug.warn("Main", "AutoSeater not available!")
    end

    Debug.info("Main", "AutoSeater started")
    print("[Main] AutoSeater started")
end

-- ==========================================
-- START (Always Running)
-- ==========================================
local function start()
    Debug.info("Main", "=== qurp v3 Engine Starting ===")
    print("[Main] === qurp v3 Engine Starting ===")

    -- Connect respawn handler
    player.CharacterAdded:Connect(onRespawn)
    print("[Main] Respawn handler connected")

    -- Handle initial spawn
    if player.Character then
        print("[Main] Initial character found, spawning onRespawn...")
        task.spawn(onRespawn, player.Character)
    else
        print("[Main] No character yet — waiting for spawn")
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
