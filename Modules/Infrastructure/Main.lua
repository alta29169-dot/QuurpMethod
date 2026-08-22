-- Main.lua – Phase 1 (Test Version with Teleport)
-- Goal: Prove respawn loop + teleport work

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Debug = _G._Modules.Debug
local StateManager = _G._Modules.StateManager
local DockLocator = _G._Modules.DockLocator
local HarbourTeleporter = _G._Modules.HarbourTeleporter
local AirportManager = _G._Modules.AirportManager

-- ===== STATE =====
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
    
    StateManager.resetAll()
    
    -- Wait for character to load
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
    
    Debug.info("Main", "Character loaded after " .. waitCount .. " checks")
    StateManager.set("characterLoaded", true)
    StateManager.set("isAlive", true)
    
    -- ===== TEST: TELEPORT TO HARBOUR =====
    Debug.info("Main", "Testing HarbourTeleporter...")
    
    local dock = DockLocator.getDock()
    if dock then
        Debug.info("Main", "Dock found: " .. dock.Name)
    else
        Debug.warn("Main", "No dock found!")
    end
    
    local teleportSuccess = HarbourTeleporter.teleportToHarbour(myGen)
    if teleportSuccess then
        Debug.info("Main", "Teleport successful!")
        
        -- TEST: CACHE AIRPORTS
        Debug.info("Main", "Testing AirportManager...")
        local cacheSuccess = AirportManager.cacheAirports(myGen)
        if cacheSuccess then
            local airport = AirportManager.getNearestAirport(player.Character, myGen)
            if airport then
                Debug.info("Main", "Nearest airport found at:", airport.Position)
            else
                Debug.warn("Main", "No airports found after caching!")
            end
        else
            Debug.warn("Main", "Airport cache failed!")
        end
    else
        Debug.warn("Main", "Teleport failed!")
    end
    
    Debug.info("Main", "Respawn + Teleport + Airport test complete.")
end

-- ==========================================
-- START
-- ==========================================
local function start()
    Debug.info("Main", "=== qurp v3 Engine Starting (Test Mode) ===")
    
    player.CharacterAdded:Connect(onRespawn)
    Debug.info("Main", "CharacterAdded connected")
    
    -- Handle initial spawn
    if player.Character then
        Debug.info("Main", "Initial character found — triggering respawn")
        task.spawn(onRespawn, player.Character)
    else
        Debug.info("Main", "No character yet — waiting for spawn")
    end
    
    -- Keep the script alive
    while isRunning do
        task.wait(1)
    end
end

-- ==========================================
-- MODULE EXPORT
-- ==========================================
return {
    start = start,
}
