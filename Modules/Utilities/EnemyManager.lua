-- EnemyManager.lua – Enemy Detection and Tracking | Parsched

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local StateManager = _G._Modules.StateManager
local Debug = _G._Modules.Debug

local EnemyManager = {}

-- ==========================================
-- DEBUG CONFIG (Toggle here)
-- ==========================================
local DEBUG_ENEMY_DETECTION = true  -- Set to true to print enemy detection logs
local DEBUG_SCAN_SUMMARY = true     -- Set to true to print scan summary
local DEBUG_ENEMY_DETAILS = true    -- Set to true to print enemy details when detected

-- ==========================================
-- CONFIG
-- ==========================================
local SCAN_RANGE = 2200  -- Max projectile range
local PLANE_TYPES = {
    "Bomber",
    "TorpedoBomber",
    "LargeBomber"
}

-- ===== ENEMY CACHE =====
local enemyCache = {}

-- ==========================================
-- DEBUG FUNCTIONS
-- ==========================================
local function debugPrint(...)
    if DEBUG_ENEMY_DETECTION then
        print("[EnemyManager]", ...)
    end
end

local function debugDetail(...)
    if DEBUG_ENEMY_DETAILS then
        print("[EnemyManager]", ...)
    end
end

-- ==========================================
-- CLAMP HELPER
-- ==========================================
local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- ==========================================
-- GET MY TEAM
-- ==========================================
function EnemyManager.getMyTeam()
    -- Check StateManager first
    local myTeam = StateManager.get("myTeam")
    if myTeam then return myTeam end
    
    -- Fallback: Check player.Team
    if player.Team then
        local teamName = player.Team.Name
        StateManager.set("myTeam", teamName)
        debugPrint("My team set to:", teamName)
        return teamName
    end
    
    -- Default
    return "USA"
end

-- ==========================================
-- GET PLANE DATA
-- ==========================================
function EnemyManager.getPlaneData(plane)
    if not plane then return nil end
    
    -- Get MainBody (primary part)
    local mainBody = plane:FindFirstChild("MainBody")
    if not mainBody then
        -- Fallback: use PrimaryPart if set
        mainBody = plane.PrimaryPart
    end
    if not mainBody then
        -- Last resort: find any BasePart
        mainBody = plane:FindFirstChildWhichIsA("BasePart")
    end
    if not mainBody then return nil end
    
    -- Get properties
    local hp = plane:FindFirstChild("HP")
    local team = plane:FindFirstChild("Team")
    local owner = plane:FindFirstChild("Owner")
    local occupant = plane:FindFirstChild("Occupant")
    local ammo = plane:FindFirstChild("Ammo")
    local fuel = plane:FindFirstChild("Fuel")
    local lookAt = plane:FindFirstChild("LookAt")
    
    local position = mainBody.Position
    
    return {
        instance = plane,
        type = plane.Name,
        position = position,
        altitude = position.Y,
        cframe = mainBody.CFrame,
        mainBody = mainBody,
        velocity = mainBody.AssemblyLinearVelocity or Vector3.new(0,0,0),
        health = hp and hp.Value or 0,
        team = team and team.Value or "Unknown",
        owner = owner and owner.Value or "",
        occupant = occupant and occupant.Value or "",
        ammo = ammo and ammo.Value or 0,
        fuel = fuel and fuel.Value or 0,
        lookAt = lookAt and lookAt.Value or nil,
        isAlive = hp and hp.Value > 0 or false,
        isOccupied = occupant and occupant.Value ~= "" and occupant.Value ~= nil or false,
        lastSeen = tick(),
    }
end

-- ==========================================
-- CHECK IF PLANE IS ENEMY
-- ==========================================
function EnemyManager.isEnemy(plane)
    if not plane then return false end
    
    -- Must be a plane type
    if not table.find(PLANE_TYPES, plane.Name) then
        return false
    end
    
    -- Get team
    local team = plane:FindFirstChild("Team")
    if not team then return false end
    if team.Value == "" or team.Value == nil then return false end
    
    -- Get our team
    local myTeam = EnemyManager.getMyTeam()
    
    -- Different team = enemy
    return team.Value ~= myTeam
end

-- ==========================================
-- SCAN FOR ENEMIES
-- ==========================================
function EnemyManager.scan(scanRange)
    scanRange = scanRange or SCAN_RANGE
    local myPosition = EnemyManager.getMyPosition()
    if not myPosition then
        debugPrint("Cannot scan: no player position")
        return {}
    end
    
    local enemies = {}
    local myTeam = EnemyManager.getMyTeam()
    
    for _, plane in ipairs(Workspace:GetChildren()) do
        -- Skip if not a plane type
        if not table.find(PLANE_TYPES, plane.Name) then
            continue
        end
        
        -- Skip if not enemy
        if not EnemyManager.isEnemy(plane) then
            continue
        end
        
        -- Get plane data
        local data = EnemyManager.getPlaneData(plane)
        if not data then continue end
        
        -- Skip if dead
        if not data.isAlive then 
            continue
        end
        
        -- Check distance
        local distance = (data.position - myPosition).Magnitude
        if distance > scanRange then
            continue
        end
        
        -- Add distance and angles to data
        data.distance = distance
        
        -- Bearing: horizontal angle to enemy (degrees, -180 to 180)
        local direction = (data.position - myPosition).Unit
        data.bearing = math.deg(math.atan2(direction.X, direction.Z))
        
        -- Elevation: vertical angle to enemy (degrees, -90 to 90)
        local horizontalDist = (direction.X^2 + direction.Z^2)^0.5
        data.elevation = math.deg(math.atan2(direction.Y, horizontalDist))
        
        -- LookAt direction (where enemy is facing)
        if data.lookAt then
            data.enemyHeading = data.lookAt
        end
        
        -- DEBUG: Print enemy details when detected
        if DEBUG_ENEMY_DETAILS then
            debugDetail("═══ ENEMY DETECTED ═══")
            debugDetail("  Type:", data.type)
            debugDetail("  Team:", data.team, "(My team:", myTeam, ")")
            debugDetail("  Health:", data.health)
            debugDetail("  Distance:", math.floor(data.distance), "studs")
            debugDetail("  Altitude:", math.floor(data.altitude))
            debugDetail("  Bearing:", math.floor(data.bearing), "°")
            debugDetail("  Elevation:", math.floor(data.elevation), "°")
            debugDetail("  Occupant:", data.occupant ~= "" and data.occupant or "Empty")
            debugDetail("  Owner:", data.owner ~= "" and data.owner or "None")
            debugDetail("  Position:", string.format("(%.0f, %.0f, %.0f)", 
                        data.position.X, data.position.Y, data.position.Z))
            if data.ammo then
                debugDetail("  Ammo:", data.ammo)
            end
            if data.fuel then
                debugDetail("  Fuel:", data.fuel)
            end
            debugDetail("═══════════════════════")
        end
        
        table.insert(enemies, data)
    end
    
    -- Sort by distance (nearest first)
    table.sort(enemies, function(a, b)
        return a.distance < b.distance
    end)
    
    enemyCache = enemies
    
    -- DEBUG: Print scan summary
    if DEBUG_SCAN_SUMMARY then
        local count = #enemies
        if count > 0 then
            local nearest = enemies[1]
            debugPrint(string.format("✅ Scanned %d enemies within %d studs | Nearest: %s at %.0f studs, alt: %.0f",
                        count, scanRange, nearest.type, nearest.distance, nearest.altitude))
        else
            debugPrint(string.format("🔍 No enemies found within %d studs", scanRange))
        end
    end
    
    return enemies
end

-- ==========================================
-- GET MY POSITION
-- ==========================================
function EnemyManager.getMyPosition()
    local character = player.Character
    if not character then return nil end
    
    -- Check if we're in a plane
    local plane = StateManager.get("targetVehicle")
    if plane and StateManager.get("seated") then
        local mainBody = plane:FindFirstChild("MainBody")
        if mainBody then
            return mainBody.Position
        end
    end
    
    -- Fallback: character position
    local primaryPart = character.PrimaryPart
    if primaryPart then
        return primaryPart.Position
    end
    
    -- Last resort: find any BasePart
    local part = character:FindFirstChildWhichIsA("BasePart")
    if part then
        return part.Position
    end
    
    return nil
end

-- ==========================================
-- GET MY VELOCITY
-- ==========================================
function EnemyManager.getMyVelocity()
    local character = player.Character
    if not character then return Vector3.new(0,0,0) end
    
    -- Check if we're in a plane
    local plane = StateManager.get("targetVehicle")
    if plane and StateManager.get("seated") then
        local mainBody = plane:FindFirstChild("MainBody")
        if mainBody then
            return mainBody.AssemblyLinearVelocity or Vector3.new(0,0,0)
        end
    end
    
    -- Fallback: character velocity
    local primaryPart = character.PrimaryPart
    if primaryPart then
        return primaryPart.AssemblyLinearVelocity or Vector3.new(0,0,0)
    end
    
    return Vector3.new(0,0,0)
end

-- ==========================================
-- GET ENEMY LOOK DIRECTION (for RL)
-- ==========================================
function EnemyManager.getEnemyFacing(enemyData)
    if not enemyData or not enemyData.lookAt then
        return nil
    end
    
    -- If LookAt is a Vector3, return it
    if type(enemyData.lookAt) == "Vector3" then
        return enemyData.lookAt
    end
    
    -- If it's a number, convert to direction
    if type(enemyData.lookAt) == "number" then
        local heading = math.rad(enemyData.lookAt)
        return Vector3.new(math.sin(heading), 0, math.cos(heading))
    end
    
    return nil
end

-- ==========================================
-- GET OBSERVATION (for RL)
-- ==========================================
function EnemyManager.getObservation()
    local obs = {
        -- Default values
        health = 0,
        ammo = 0,
        fuel = 0,
        altitude = 0,
        speed = 0,
        enemyDistance = 0,
        enemyBearing = 0,
        enemyElevation = 0,
        enemyHealth = 0,
        enemyAltitude = 0,
        enemySpeed = 0,
        enemyFacingAngle = 0,
        enemyIsBomber = 0,
        enemyIsTorpedo = 0,
        enemyIsLarge = 0,
        isSeated = 0,
        isAlive = 0,
        enemiesInRange = 0,
    }
    
    -- Get self state
    local selfPos = EnemyManager.getMyPosition()
    local selfVel = EnemyManager.getMyVelocity()
    local plane = StateManager.get("targetVehicle")
    local seated = StateManager.get("seated")
    
    if not selfPos then return obs end
    
    -- Self state
    obs.altitude = selfPos.Y
    obs.speed = selfVel.Magnitude
    obs.isSeated = seated and 1 or 0
    obs.isAlive = player.Character and 1 or 0
    
    -- Get plane data if we have one
    if plane then
        local hp = plane:FindFirstChild("HP")
        local ammo = plane:FindFirstChild("Ammo")
        local fuel = plane:FindFirstChild("Fuel")
        
        obs.health = hp and hp.Value / 100 or 0
        obs.ammo = ammo and ammo.Value / 100 or 0
        obs.fuel = fuel and fuel.Value / 100 or 0
    end
    
    -- Get nearest enemy
    local nearest = EnemyManager.getNearestEnemy()
    if not nearest then return obs end
    
    -- Enemy distance (normalized)
    obs.enemyDistance = clamp(nearest.distance / 2200, 0, 1)
    obs.enemyBearing = clamp(nearest.bearing / 180, -1, 1)
    obs.enemyElevation = clamp(nearest.elevation / 90, -1, 1)
    obs.enemyHealth = clamp(nearest.health / 100, 0, 1)
    obs.enemyAltitude = nearest.altitude
    obs.enemySpeed = nearest.velocity and nearest.velocity.Magnitude or 0
    
    -- Enemy type (one-hot)
    obs.enemyIsBomber = nearest.type == "Bomber" and 1 or 0
    obs.enemyIsTorpedo = nearest.type == "TorpedoBomber" and 1 or 0
    obs.enemyIsLarge = nearest.type == "LargeBomber" and 1 or 0
    
    -- Enemy facing angle (relative to us)
    if nearest.lookAt then
        local enemyFacing = EnemyManager.getEnemyFacing(nearest)
        if enemyFacing then
            local dirToEnemy = (nearest.position - selfPos).Unit
            local facingAngle = math.deg(math.acos(enemyFacing:Dot(dirToEnemy)))
            obs.enemyFacingAngle = clamp(facingAngle / 180, -1, 1)
        end
    end
    
    -- Enemies in range count
    obs.enemiesInRange = #enemyCache
    
    return obs
end

-- ==========================================
-- QUERY FUNCTIONS
-- ==========================================

-- Get all enemies
function EnemyManager.getEnemies()
    return enemyCache
end

-- Get nearest enemy
function EnemyManager.getNearestEnemy()
    if #enemyCache == 0 then return nil end
    return enemyCache[1]
end

-- Get enemies by type
function EnemyManager.getEnemiesByType(planeType)
    local result = {}
    for _, enemy in ipairs(enemyCache) do
        if enemy.type == planeType then
            table.insert(result, enemy)
        end
    end
    return result
end

-- Get enemy count
function EnemyManager.getEnemyCount()
    return #enemyCache
end

-- Get enemy data for a specific plane
function EnemyManager.getEnemyData(plane)
    for _, enemy in ipairs(enemyCache) do
        if enemy.instance == plane then
            return enemy
        end
    end
    return nil
end

-- Get enemies in a specific direction (for RL)
function EnemyManager.getEnemiesInDirection(forwardVector, angleThreshold)
    angleThreshold = angleThreshold or 45
    
    local result = {}
    local myPos = EnemyManager.getMyPosition()
    if not myPos then return result end
    
    for _, enemy in ipairs(enemyCache) do
        local dirToEnemy = (enemy.position - myPos).Unit
        local angle = math.deg(math.acos(forwardVector:Dot(dirToEnemy)))
        if angle < angleThreshold then
            table.insert(result, enemy)
        end
    end
    
    return result
end

-- ==========================================
-- UPDATE (Called every heartbeat)
-- ==========================================
function EnemyManager.update(scanRange)
    scanRange = scanRange or SCAN_RANGE
    return EnemyManager.scan(scanRange)
end

-- ==========================================
-- CLEAR CACHE (on respawn)
-- ==========================================
function EnemyManager.clearCache()
    enemyCache = {}
    debugPrint("Cache cleared")
end

-- ==========================================
-- TOGGLE DEBUG (for runtime, optional)
-- ==========================================
function EnemyManager.setDebug(enabled)
    DEBUG_ENEMY_DETECTION = enabled
    DEBUG_SCAN_SUMMARY = enabled
    DEBUG_ENEMY_DETAILS = enabled
    debugPrint("Debug set to:", enabled)
end

return EnemyManager
