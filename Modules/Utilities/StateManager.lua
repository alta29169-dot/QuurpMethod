-- StateManager.luau | looks like love
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

-- ==========================================
-- STATE VARIABLES (Complete List)
-- ==========================================
local state = {
    -- ===== VEHICLE STATE =====
    seated = false,           -- Are we sitting in a plane?
    hasPlane = false,         -- Do we own a plane?
    targetVehicle = nil,      -- Reference to our plane
    isPlaneAlive = false,     -- Is our plane still alive?
    
    -- ===== PLAYER STATE =====
    generation = 0,           -- Respawn counter
    isRunning = true,         -- Engine running?
    characterLoaded = false,  -- Is character loaded?
    isAlive = false,          -- Is player alive?
    
    -- ===== PLANE STATS (OURS) =====
    myHealth = 0,             -- Our plane's HP
    myAmmo = 0,               -- Our plane's ammo
    myFuel = 0,               -- Our plane's fuel
    myTeam = nil,             -- Our team name (USA/Japan)
    
    -- ===== ENEMY TRACKING =====
    enemyList = {},           -- Table of enemy data keyed by instance
    enemyCount = 0,           -- Number of tracked enemies
    lastEnemyUpdate = 0,      -- Timestamp of last enemy update
    
    -- ===== AIRPORT CACHE =====
    airportCache = {},        -- Cached airport instances
    airportsCached = false,   -- Are airports cached?
    
    -- ===== SETUP/RECOVERY STATE =====
    setupRunning = false,     -- Is setup in progress?
    recovering = false,       -- Is recovery in progress?
}

-- ==========================================
-- LOCKS (for race conditions)
-- ==========================================
local locks = {
    setup = false,
    recovery = false,
    spawn = false,
}

-- ==========================================
-- COOLDOWN TRACKING
-- ==========================================
local lastRespawnTime = 0
local lastRecoveryTime = 0

-- ==========================================
-- ATOMIC OPERATIONS
-- ==========================================

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

function StateManager:tryLockRecovery()
    local now = tick()
    if locks.recovery or state.recovering then
        return false
    end
    if now - lastRecoveryTime < 3 then
        return false
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

function StateManager:nextGeneration()
    state.generation = state.generation + 1
    return state.generation
end

function StateManager:getGeneration()
    return state.generation
end

function StateManager:canRespawn()
    local now = tick()
    if now - lastRespawnTime < 2 then
        return false
    end
    lastRespawnTime = now
    return true
end

-- ==========================================
-- ENEMY LIST METHODS
-- ==========================================

function StateManager.addEnemy(enemyData)
    if not enemyData or not enemyData.instance then return end
    
    local key = tostring(enemyData.instance)
    state.enemyList[key] = enemyData
    state.enemyCount = state.enemyCount + 1
    
    safePrint("Added enemy: " .. key .. " (" .. enemyData.type .. ")")
end

function StateManager.removeEnemy(key)
    if state.enemyList[key] then
        state.enemyList[key] = nil
        state.enemyCount = state.enemyCount - 1
        safePrint("Removed enemy: " .. key)
    end
end

function StateManager.getEnemyList()
    return state.enemyList
end

function StateManager.getEnemyCount()
    return state.enemyCount
end

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
function StateManager:getHealth() return state.myHealth end
function StateManager:getAmmo() return state.myAmmo end
function StateManager:getFuel() return state.myFuel end
function StateManager:getTeam() return state.myTeam end

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
    state.myHealth = 0
    state.myAmmo = 0
    state.myFuel = 0
    state.characterLoaded = false
    state.isAlive = false
    -- Generation stays (don't reset it)
    -- Enemy list stays (don't reset it - EnemyManager handles cleanup)
    -- Airport cache stays (don't reset it - persists through respawns)
end

return StateManager
