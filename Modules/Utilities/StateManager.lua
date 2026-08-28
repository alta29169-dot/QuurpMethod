-- StateManager.lua | looks like love
local StateManager = {}

-- Get Debug module safely
local Debug = _G._Modules and _G._Modules.Debug

-- Local safe print function
local function safePrint(...)
    if Debug and Debug.info then
        Debug.info("StateManager", ...)
    else
        print("[StateManager]", ...)
    end
end

-- ===== STATE =====
local state = {
    seated = false,
    setupRunning = false,
    recovering = false,
    hasPlane = false,
    targetVehicle = nil,
    isPlaneAlive = false,
    generation = 0,
    isRunning = true,
    enemyList = {},       
    enemyCount = 0,      
    lastEnemyUpdate = 0,  
}

-- ===== LOCKS (for race conditions) =====
local locks = {
    setup = false,
    recovery = false,
    spawn = false,
}

-- ===== COOLDOWN TRACKING =====
local lastRespawnTime = 0
local lastRecoveryTime = 0

-- ==========================================
-- ATOMIC OPERATIONS
-- ==========================================

-- Try to claim setup lock (returns true if successful)
function StateManager:tryLockSetup()
    if locks.setup or state.setupRunning then
        return false
    end
    locks.setup = true
    state.setupRunning = true
    return true
end

function StateManager:unlockSetup()
    locks.setup = false
    state.setupRunning = false
end

-- Try to claim recovery lock
function StateManager:tryLockRecovery()
    local now = tick()
    if locks.recovery or state.recovering then
        return false
    end
    if now - lastRecoveryTime < 3 then
        return false  -- Cooldown
    end
    locks.recovery = true
    state.recovering = true
    lastRecoveryTime = now
    return true
end

function StateManager:unlockRecovery()
    locks.recovery = false
    state.recovering = false
end

-- Generation management
function StateManager:nextGeneration()
    state.generation = state.generation + 1
    return state.generation
end

function StateManager:getGeneration()
    return state.generation
end

-- Respawn debounce
function StateManager:canRespawn()
    local now = tick()
    if now - lastRespawnTime < 2 then
        return false
    end
    lastRespawnTime = now
    return true
end

-- ==========================================
-- STATEMANAGER METHODS FOR ENEMY LIST
-- ==========================================

-- Add enemy to list (called by Main)
function StateManager.addEnemy(enemyData)
    if not enemyData or not enemyData.instance then return end
    
    local key = tostring(enemyData.instance)
    state.enemyList[key] = enemyData
    state.enemyCount = state.enemyCount + 1
    
    safePrint("Added enemy: " .. key .. " (" .. enemyData.type .. ")")
end

-- Remove enemy from list (called by EnemyManager)
function StateManager.removeEnemy(key)
    if state.enemyList[key] then
        state.enemyList[key] = nil
        state.enemyCount = state.enemyCount - 1
        safePrint("Removed enemy: " .. key)
    end
end

-- Get enemy list
function StateManager.getEnemyList()
    return state.enemyList
end

-- Get enemy count
function StateManager.getEnemyCount()
    return state.enemyCount
end

-- Clear all enemies (on respawn)
function StateManager.clearEnemies()
    state.enemyList = {}
    state.enemyCount = 0
    safePrint("Cleared all enemies")
end

-- ==========================================
-- STANDARD GET/SET
-- ==========================================
function StateManager.get(key)
    return state[key]
end

function StateManager.set(key, value)
    state[key] = value
    return state[key]
end

-- ==========================================
-- CONVENIENCE GETTERS
-- ==========================================
function StateManager:isSeated() return state.seated end
function StateManager:hasPlane() return state.hasPlane end
function StateManager:isSetupRunning() return state.setupRunning end
function StateManager:isRecovering() return state.recovering end
function StateManager:getVehicle() return state.targetVehicle end

-- ==========================================
-- RESET
-- ==========================================
function StateManager.resetAll()
    state.seated = false
    state.setupRunning = false
    state.recovering = false
    state.hasPlane = false
    state.isPlaneAlive = false
    state.targetVehicle = nil
    -- Generation stays (don't reset it)
end

return StateManager
