-- CombatBrain.lua – Simplified Combat Logic | I would always choose you
-- Runs every frame via RunService

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")

local StateManager = _G._Modules.StateManager
local Debug = _G._Modules.Debug
local FlightController = _G._Modules.FlightController
local EnemyManager = _G._Modules.EnemyManager

local CombatBrain = {}

-- ==========================================
-- DEBUG CONFIG
-- ==========================================
local DEBUG_COMBAT = false  -- Turn off for performance

local function debugPrint(...)
    if DEBUG_COMBAT then
        print("[CombatBrain]", ...)
    end
end

-- ==========================================
-- STATE
-- ==========================================
local combatConnection = nil
local lastTargetUpdate = 0
local TARGET_UPDATE_INTERVAL = 0.1  -- Only update target every 0.1s

-- ==========================================
-- UPDATE (Called every frame)
-- ==========================================
function CombatBrain.update()
    -- Check if we're seated in a plane
    if not StateManager.get("seated") then
        return
    end
    
    -- Rate limit target updates (don't need to set target every frame)
    local now = tick()
    if now - lastTargetUpdate < TARGET_UPDATE_INTERVAL then
        return
    end
    lastTargetUpdate = now
    
    -- Get enemy list from StateManager
    local enemyList = StateManager.getEnemyList()
    if not enemyList then
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
        return
    end
    
    -- Get enemy position (already fresh from EnemyManager tracking)
    local targetPos = nearestEnemy.position
    if not targetPos then
        return
    end
    
    -- Optional: lead prediction using velocity
    local leadTime = 0.3
    local predictedPos = targetPos + (nearestEnemy.velocity or Vector3.new(0,0,0)) * leadTime
    
    -- Fly toward enemy
    FlightController.setTarget(predictedPos, "attack")
end

-- ==========================================
-- START (Called from Main)
-- ==========================================
function CombatBrain.start()
    if combatConnection then
        debugPrint("Combat loop already running")
        return
    end
    
    debugPrint("Starting combat loop (every frame)")
    
    combatConnection = RunService.Heartbeat:Connect(function()
        CombatBrain.update()
    end)
end

-- ==========================================
-- STOP
-- ==========================================
function CombatBrain.stop()
    if combatConnection then
        combatConnection:Disconnect()
        combatConnection = nil
        debugPrint("Combat loop stopped")
    end
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
