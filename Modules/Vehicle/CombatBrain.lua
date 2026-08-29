-- CombatBrain.lua – Simplified Combat Logic | I would always choose you
-- Runs every frame via RunService

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")

local StateManager = _G._Modules.StateManager
local Debug = _G._Modules.Debug
local FlightController = _G._Modules.FlightController
local EnemyManager = _G._Modules.EnemyManager
local WeaponSystem = _G._Modules.WeaponSystem  -- ADDED

local CombatBrain = {}

-- ==========================================
-- DEBUG CONFIG
-- ==========================================
local DEBUG_COMBAT = true  -- Turn on for testing
local TEST_WEAPONS = true  -- Enable weapon testing

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
local TARGET_UPDATE_INTERVAL = 0.1
local lastMGCheck = 0
local lastRPGCheck = 0
local WEAPON_CHECK_INTERVAL = 0.5  -- Check weapons every 0.5s

-- ==========================================
-- GET MY POSITION
-- ==========================================
local function getMyPosition()
    local plane = StateManager.get("targetVehicle")
    if not plane then return nil end
    
    local mainBody = plane:FindFirstChild("MainBody")
    if mainBody then
        return mainBody.Position
    end
    
    return nil
end

-- ==========================================
-- GET ENEMY POSITION (Latest from StateManager)
-- ==========================================
local function getEnemyPosition(enemyData)
    if not enemyData then return nil end
    
    -- Try to get fresh position from instance
    local instance = enemyData.instance
    if instance then
        local mainBody = instance:FindFirstChild("MainBody")
        if mainBody then
            return mainBody.Position
        end
    end
    
    -- Fallback to cached position
    return enemyData.position
end

-- ==========================================
-- UPDATE (Called every frame)
-- ==========================================
function CombatBrain.update()
    -- Check if we're seated in a plane
    if not StateManager.get("seated") then
        return
    end
    
    local now = tick()
    
    -- Rate limit target updates
    if now - lastTargetUpdate >= TARGET_UPDATE_INTERVAL then
        lastTargetUpdate = now
        
        -- Get enemy list from StateManager
        local enemyList = StateManager.getEnemyList()
        if enemyList then
            -- Find nearest enemy
            local nearestEnemy = nil
            local nearestDist = math.huge
            
            for key, data in pairs(enemyList) do
                if data.distance and data.distance < nearestDist then
                    nearestDist = data.distance
                    nearestEnemy = data
                end
            end
            
            if nearestEnemy then
                local targetPos = getEnemyPosition(nearestEnemy)
                if targetPos then
                    -- Lead prediction
                    local leadTime = 0.3
                    local predictedPos = targetPos + (nearestEnemy.velocity or Vector3.new(0,0,0)) * leadTime
                    
                    -- Fly toward enemy
                    FlightController.setTarget(predictedPos, "attack")
                end
            end
        end
    end
    
    -- ==========================================
    -- WEAPON TESTING
    -- ==========================================
    if TEST_WEAPONS then
        if now - lastMGCheck >= WEAPON_CHECK_INTERVAL then
            lastMGCheck = now
            testMG()
        end
        
        if now - lastRPGCheck >= WEAPON_CHECK_INTERVAL then
            lastRPGCheck = now
            testRPG()
        end
    end
end

-- ==========================================
-- TEST MG
-- ==========================================
function testMG()
    local enemyList = StateManager.getEnemyList()
    if not enemyList then
        debugPrint("MG Test: No enemy list")
        return
    end
    
    -- Find nearest enemy
    local nearestEnemy = nil
    local nearestDist = math.huge
    
    for key, data in pairs(enemyList) do
        if data.distance and data.distance < nearestDist then
            nearestDist = data.distance
            nearestEnemy = data
        end
    end
    
    if not nearestEnemy then
        debugPrint("MG Test: No enemies found")
        -- Turn off MG if no enemies
        if WeaponSystem.getMGStatus().toggled then
            WeaponSystem.setMGToggle(false)
            debugPrint("MG Test: Turned off (no enemies)")
        end
        return
    end
    
    local targetPos = getEnemyPosition(nearestEnemy)
    if not targetPos then
        debugPrint("MG Test: No enemy position")
        return
    end
    
    -- Check if enemy is in MG firing arc
    local inArc = WeaponSystem.isInMGFiringArc(targetPos, 20)
    local ammo = StateManager.get("myAmmo") or 0
    
    debugPrint(string.format("MG Test: Enemy at %.0f studs, Arc: %s, Ammo: %d", 
                nearestDist, inArc and "✅" or "❌", ammo))
    
    if inArc and ammo > 0 then
        -- Turn MG on
        if not WeaponSystem.getMGStatus().toggled then
            WeaponSystem.setMGToggle(true)
            debugPrint("MG Test: FIRING! 🎯")
        end
    else
        -- Turn MG off
        if WeaponSystem.getMGStatus().toggled then
            WeaponSystem.setMGToggle(false)
            if ammo <= 0 then
                debugPrint("MG Test: No ammo - turned off")
            else
                debugPrint("MG Test: Out of arc - turned off")
            end
        end
    end
end

-- ==========================================
-- TEST RPG
-- ==========================================
function testRPG()
    local enemyList = StateManager.getEnemyList()
    if not enemyList then
        return
    end
    
    -- Find nearest enemy
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
    
    local targetPos = getEnemyPosition(nearestEnemy)
    if not targetPos then
        return
    end
    
    -- Check if RPG can fire
    local canFire = WeaponSystem.canFireRPG()
    local hasLOS = WeaponSystem.hasLineOfSight(targetPos)
    local rpgStatus = WeaponSystem.getRPGStatus()
    
    -- Only log RPG status occasionally (every 5 seconds)
    if math.floor(tick()) % 5 == 0 then
        debugPrint(string.format("RPG Status: Ready: %s, LOS: %s, Cooldown: %.1fs", 
                    canFire and "✅" or "❌", 
                    hasLOS and "✅" or "❌", 
                    rpgStatus.cooldown))
    end
    
    -- Fire RPG if ready and has LOS
    if canFire and hasLOS then
        local success = WeaponSystem.fireRPG(targetPos)
        if success then
            debugPrint("💥 RPG FIRED at enemy!")
        else
            debugPrint("RPG fire failed")
        end
    end
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
    
    -- EQUIP RPG ON START
    task.wait(1)
    WeaponSystem.equipRPG()
    debugPrint("RPG equipped on start")
    
    -- 🔍 LIVE AMMO DEBUG (ADD THIS)
    task.spawn(function()
        while true do
            task.wait(1)  -- Print every second
            local plane = StateManager.get("targetVehicle")
            if plane then
                -- Search ALL descendants for Ammo
                local found = nil
                for _, child in ipairs(plane:GetDescendants()) do
                    if child.Name == "Ammo" and child:IsA("IntValue") then
                        found = child
                        break
                    end
                end
                
                if found then
                    print(string.format("🔍 DIRECT READ: Ammo = %d (Parent: %s)", 
                        found.Value, 
                        found.Parent and found.Parent.Name or "nil"))
                else
                    print("🔍 No Ammo found in plane!")
                end
                
                -- Print what StateManager has
                print(string.format("📊 STATEMANAGER: myAmmo = %s", 
                    tostring(StateManager.get("myAmmo"))))
                
                -- Also check direct children
                local directAmmo = plane:FindFirstChild("Ammo")
                if directAmmo then
                    print(string.format("📁 DIRECT CHILD: Ammo = %d", directAmmo.Value))
                end
            else
                print("❌ No plane in StateManager")
            end
        end
    end)
    
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
    
    -- Stop all weapons
    WeaponSystem.stopAll()
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
        mgStatus = WeaponSystem.getMGStatus(),
        rpgStatus = WeaponSystem.getRPGStatus(),
    }
end

return CombatBrain
