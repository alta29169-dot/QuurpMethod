-- Main.lua – qurp v3 (Phase 1)
-- I love you Ashley

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Debug = _G._Modules.Debug
local StateManager = _G._Modules.StateManager
local DockLocator = _G._Modules.DockLocator
local HarbourTeleporter = _G._Modules.HarbourTeleporter
local AirportManager = _G._Modules.AirportManager
local AutoSeater = _G._Modules.AutoSeater
local BomberManager = _G._Modules.BomberManager
local EnemyManager = _G._Modules.EnemyManager

local isRunning = true

-- ==========================================
-- HEARTBEAT LOOP
-- ==========================================
local function heartbeat()
    Debug.info("Main", "Heartbeat started")
    
    while isRunning do
        task.wait(1.5)  -- Check every 1.5 seconds
        
        -- Check if we're alive
        if not player.Character then
            Debug.info("Main", "Waiting for character...")
            continue
        end

        -- DISCOVERY: Find new enemies (ADD only)
        local enemies = EnemyManager.scanForNewEnemies()
        for _, enemy in ipairs(enemies) do
            StateManager.addEnemy(enemy)
        end
        
        -- Update our plane status
        local myBomber = BomberManager.updatePlaneState()
        
        if not StateManager.get("hasPlane") then
            -- No plane → walk to airport and spawn
            Debug.info("Main", "No plane found, walking to airport")
            
            local character = player.Character
            if character then
                local airport = AirportManager.getNearestAirport(character)
                if airport then
                    -- Walk to airport
                    local arrived = AutoSeater.walkToPosition(airport.Position)
                    
                    if arrived then
                        -- Spawn bomber
                        Debug.info("Main", "At airport, spawning bomber...")
                        BomberManager.spawnBomber(airport)
                    end
                else
                    Debug.warn("Main", "No airport found!")
                end
            end
            
        elseif not StateManager.get("seated") then
            -- Have plane but not seated → walk and sit
            Debug.info("Main", "Have plane but not seated")
            
            local plane = StateManager.get("targetVehicle")
            if plane then
                -- Walk to bomber
                local arrived = AutoSeater.walkToBomber(plane)
                
                if arrived then
                    -- Try to sit
                    Debug.info("Main", "At bomber, trying to sit...")
                    AutoSeater.trySitInBomber(plane)
                end
            else
                Debug.warn("Main", "targetVehicle is nil but hasPlane is true!")
                -- Force state reset
                StateManager.set("hasPlane", false)
            end
            
        else
            -- We're seated in our plane
            -- TODO: Combat logic
            CombatBrain.update()
            Debug.info("Main", "Seated and ready for combat!")
            
            -- Check if we're still in the plane
            local occupant = BomberManager.getBomberOccupant(myBomber)
            if occupant ~= player.Name then
                Debug.warn("Main", "We lost our seat!")
                StateManager.set("seated", false)
            end
        end
    end
end

-- ==========================================
-- ON RESPAWN
-- ==========================================
local function onRespawn(char)
    print("[Main] ON RESPAWN FIRED!")
    
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
        print("[Main] HRP never loaded!")
        return
    end

    print("[Main] HRP found!")
    Debug.info("Main", "Character loaded")
    StateManager.set("characterLoaded", true)

    -- Teleport to harbour
    print("[Main] Teleporting to harbour...")
    local teleportSuccess = HarbourTeleporter.teleportToHarbour(myGen)
    if not teleportSuccess then
        Debug.warn("Main", "Teleport failed — retrying on next spawn")
        print("[Main] Teleport failed!")
        return
    end

    print("[Main] Teleport successful!")
    Debug.info("Main", "Teleport successful")

    -- Cache airports (once per respawn)
    print("[Main] Caching airports...")
    AirportManager.cacheAirports(myGen)

    -- Debug: Check cache
    local cache = StateManager.get("airportCache")
    print("[Main] Airport cache has " .. (#cache or 0) .. " airports")
    Debug.info("Main", "Airport cache has " .. (#cache or 0) .. " airports")

    -- Update plane state after respawn
    BomberManager.updatePlaneState()
    
    -- Start heartbeat if not already running
    if not _G._heartbeatRunning then
        _G._heartbeatRunning = true
        task.spawn(heartbeat)
        print("[Main] Heartbeat started")
    else
        print("[Main] Heartbeat already running")
    end

    Debug.info("Main", "Respawn complete")
    print("[Main] Respawn complete")
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

    -- Start EnemyManager tracking loop (runs independently)
    task.spawn(EnemyManager.startTracking)
    print("[Main] EnemyManager tracking started")

    -- Keep the engine running FOREVER
    while isRunning do
        task.wait(1)
    end
end

return {
    start = start,
}
