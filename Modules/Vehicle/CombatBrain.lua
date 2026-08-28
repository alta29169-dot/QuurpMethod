-- CombatBrain.lua – Simplified Combat Logic
-- Flies toward the nearest enemy from StateManager

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local StateManager = _G._Modules.StateManager
local Debug = _G._Modules.Debug
local FlightController = _G._Modules.FlightController
local EnemyManager = _G._Modules.EnemyManager

local CombatBrain = {}

-- ==========================================
-- DEBUG CONFIG
-- ==========================================
local DEBUG_COMBAT = true

local function debugPrint(...)
    if DEBUG_COMBAT then
        print("[CombatBrain]", ...)
    end
end

-- ==========================================
-- UPDATE (Called every heartbeat)
-- ==========================================
function CombatBrain.update()
    -- Check if we're seated in a plane
    if not StateManager.get("seated") then
        debugPrint("Not seated, skipping combat")
        return
    end
    
    -- Get enemy list from StateManager
    local enemyList = StateManager.getEnemyList()
    if not enemyList then
        debugPrint("No enemy list in StateManager")
        return
    end
    
    -- Find nearest enemy from StateManager
    local nearestEnemy = nil
    local nearestDist = math.huge
    
    for key, data in pairs(enemyList) do
        if data.distance and data.distance < nearestDist then
            nearestDist = data.distance
            nearestEnemy = data
        end
    end
    
    if not nearestEnemy then
        debugPrint("No enemies found")
        -- Optional: fly to a default position or hold
        return
    end
    
    -- Get enemy position
    local targetPos = nearestEnemy.position
    if not targetPos then
        debugPrint("Enemy has no position")
        return
    end
    
    -- Calculate distance
    local myPos = EnemyManager.getMyPosition()
    if myPos then
        local dist = (targetPos - myPos).Magnitude
        debugPrint(string.format("Nearest enemy: %s at %.0f studs", 
                    nearestEnemy.type or "Unknown", dist))
    end
    
    -- Fly toward enemy
    FlightController.setTarget(targetPos, "attack")
    debugPrint(string.format("Flying to enemy at (%.0f, %.0f, %.0f)", 
                targetPos.X, targetPos.Y, targetPos.Z))
end

-- ==========================================
-- GET STATUS
-- ==========================================
function CombatBrain.getStatus()
    local enemyList = StateManager.getEnemyList()
    local count = 0
    for _ in pairs(enemyList or {}) do
        count = count + 1
    end
    
    return {
        enemiesInRange = count,
        isFlying = FlightController.isFlying(),
        target = FlightController.getTarget(),
    }
end

return CombatBrain
