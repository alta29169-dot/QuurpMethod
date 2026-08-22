--[[
    StateManager.lua – qurp v3
    SINGLE SOURCE OF TRUTH for all module states.
    Every module reads/writes state through this manager.
]]

local StateManager = {}

-- ==========================================
-- STATE DEFINITION (All states in one place)
-- ==========================================
local state = {
    -- ===== AUTO SEATER =====
    seated = false,              -- Is the player seated in a vehicle?
    setupRunning = false,        -- Is AutoSeater currently running setup?
    recovering = false,          -- Is recovery currently in progress?
    
    -- ===== VEHICLE =====
    hasPlane = false,            -- Does the player own a plane?
    targetVehicle = nil,         -- Reference to the current vehicle
    isPlaneAlive = false,        -- Is the plane still alive?
    planeHealth = 100,           -- Plane health (if tracked)
    
    -- ===== PLAYER =====
    characterLoaded = false,     -- Is the player's character loaded?
    isAlive = false,            -- Is the player alive?
    playerPosition = nil,        -- Current player position (cached)
    
    -- ===== SESSION =====
    generation = 0,              -- Session generation (increments on respawn)
    isRunning = true,            -- Is the main loop running?
    
    -- ===== MOVEMENT CONTROLLER =====
    engineOn = false,            -- Is the engine running?
    physicsEnabled = false,      -- Are physics constraints enabled?
    movementController = nil,    -- Reference to MovementController instance
    
    -- ===== COMBAT =====
    combatActive = false,        -- Is CombatBrain active?
    currentTarget = nil,         -- Current enemy target
    threatLevel = 0,             -- Current threat level (0-1)
}

-- ==========================================
-- PUBLIC API
-- ==========================================

-- Get a state value
function StateManager.get(key)
    return state[key]
end

-- Set a state value (with optional debug logging)
function StateManager.set(key, value)
    local old = state[key]
    state[key] = value
    
    -- Log state changes (only if Debug is loaded)
    if _G._Modules and _G._Modules.Debug then
        local Debug = _G._Modules.Debug
        if Debug and Debug.DEBUG_ENABLED then
            Debug.info("StateManager", string.format("%s: %s → %s", 
                key, tostring(old), tostring(value)))
        end
    end
    
    return state[key]
end

-- Get the current generation
function StateManager.getGeneration()
    return state.generation
end

-- Increment generation (called on respawn)
function StateManager.nextGeneration()
    state.generation = state.generation + 1
    if _G._Modules and _G._Modules.Debug then
        _G._Modules.Debug.info("StateManager", "Generation: " .. state.generation)
    end
    return state.generation
end

-- Reset ALL states to default (called on respawn or hard reset)
function StateManager.resetAll()
    -- Keep generation incrementing
    state.generation = state.generation + 1
    
    -- Reset all boolean states to false
    state.seated = false
    state.setupRunning = false
    state.recovering = false
    state.hasPlane = false
    state.isPlaneAlive = false
    state.characterLoaded = false
    state.isAlive = false
    state.engineOn = false
    state.physicsEnabled = false
    state.combatActive = false
    
    -- Reset reference states
    state.targetVehicle = nil
    state.movementController = nil
    state.currentTarget = nil
    state.playerPosition = nil
    
    -- Reset numeric states
    state.planeHealth = 100
    state.threatLevel = 0
    state.isRunning = true
    
    print("[StateManager] All states reset (gen " .. state.generation .. ")")
end

-- ==========================================
-- CONVENIENCE GETTERS (Optional, cleaner code)
-- ==========================================
function StateManager:isSeated() return state.seated end
function StateManager:hasPlane() return state.hasPlane end
function StateManager:isSetupRunning() return state.setupRunning end
function StateManager:isRecovering() return state.recovering end
function StateManager:isAlive() return state.isAlive end
function StateManager:getVehicle() return state.targetVehicle end
function StateManager:getGeneration() return state.generation end

-- ==========================================
-- BATCH UPDATES (For respawn/reset scenarios)
-- ==========================================
function StateManager.updateBatch(updates)
    for key, value in pairs(updates) do
        state[key] = value
    end
end

-- ==========================================
-- DEBUG: Print current state
-- ==========================================
function StateManager.printState()
    print("=== StateManager Current State ===")
    for key, value in pairs(state) do
        local display = tostring(value)
        if type(value) == "table" then
            display = "table"  -- Don't print large tables
        end
        print(string.format("  %s: %s", key, display))
    end
    print("===================================")
end

return StateManager
