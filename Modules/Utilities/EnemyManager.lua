-- EnemyManager.lua – Enemy Detection and Tracking | WHY DID I DO THIS ON MY PERIOD

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")

local StateManager = _G._Modules.StateManager
local Debug = _G._Modules.Debug

local EnemyManager = {}

-- ==========================================
-- DEBUG CONFIG
-- ==========================================
local DEBUG_ENEMY_DETECTION = true
local DEBUG_SCAN_SUMMARY = true
local DEBUG_TRACKING = false  -- Turn off for performance

-- ==========================================
-- CONFIG
-- ==========================================
local SCAN_RANGE = 2200
local PLANE_TYPES = {
    "Bomber",
    "TorpedoBomber",
    "LargeBomber"
}

-- ==========================================
-- STATE
-- ==========================================
local trackingConnection = nil

-- ==========================================
-- DEBUG FUNCTIONS
-- ==========================================
local function debugPrint(...)
    if DEBUG_ENEMY_DETECTION then
        print("[EnemyManager]", ...)
    end
end

local function debugTrack(...)
    if DEBUG_TRACKING then
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
    local myTeam = StateManager.get("myTeam")
    if myTeam then return myTeam end
    
    if player.Team then
        local teamName = player.Team.Name
        StateManager.set("myTeam", teamName)
        debugPrint("My team set to:", teamName)
        return teamName
    end
    
    return "USA"
end

-- ==========================================
-- GET PLANE DATA
-- ==========================================
function EnemyManager.getPlaneData(plane)
    if not plane then return nil end
    
    local mainBody = plane:FindFirstChild("MainBody")
    if not mainBody then
        mainBody = plane.PrimaryPart
    end
    if not mainBody then
        mainBody = plane:FindFirstChildWhichIsA("BasePart")
    end
    if not mainBody then return nil end
    
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
    
    if not table.find(PLANE_TYPES, plane.Name) then
        return false
    end
    
    local team = plane:FindFirstChild("Team")
    if not team then return false end
    if team.Value == "" or team.Value == nil then return false end
    
    local myTeam = EnemyManager.getMyTeam()
    return team.Value ~= myTeam
end

-- ==========================================
-- SCAN FOR NEW ENEMIES (Called by Main - ADD only)
-- ==========================================
function EnemyManager.scanForNewEnemies(scanRange)
    scanRange = scanRange or SCAN_RANGE
    local myPosition = EnemyManager.getMyPosition()
    if not myPosition then
        debugPrint("Cannot scan: no player position")
        return {}
    end
    
    local newEnemies = {}
    local existingKeys = {}
    
    local existing = StateManager.getEnemyList()
    for key, _ in pairs(existing) do
        existingKeys[key] = true
    end
    
    local myTeam = EnemyManager.getMyTeam()
    
    for _, plane in ipairs(Workspace:GetChildren()) do
        if not table.find(PLANE_TYPES, plane.Name) then
            continue
        end
        
        if not EnemyManager.isEnemy(plane) then
            continue
        end
        
        local data = EnemyManager.getPlaneData(plane)
        if not data then continue end
        
        if not data.isAlive then continue end
        
        local distance = (data.position - myPosition).Magnitude
        if distance > scanRange then continue end
        
        data.distance = distance
        
        local direction = (data.position - myPosition).Unit
        data.bearing = math.deg(math.atan2(direction.X, direction.Z))
        
        local horizontalDist = (direction.X^2 + direction.Z^2)^0.5
        data.elevation = math.deg(math.atan2(direction.Y, horizontalDist))
        
        if data.lookAt then
            data.enemyHeading = data.lookAt
        end
        
        local key = tostring(plane)
        if not existingKeys[key] then
            table.insert(newEnemies, data)
        end
    end
    
    if DEBUG_SCAN_SUMMARY and #newEnemies > 0 then
        debugPrint(string.format("✅ Found %d new enemies", #newEnemies))
    end
    
    return newEnemies
end

-- ==========================================
-- UPDATE TRACKED ENEMIES (Called every frame - SUPER FAST)
-- ==========================================
function EnemyManager.updateTrackedEnemies()
    local enemyList = StateManager.getEnemyList()
    if not enemyList then return end
    
    local toRemove = {}
    local myPos = EnemyManager.getMyPosition()
    local myTeam = EnemyManager.getMyTeam()
    
    for key, data in pairs(enemyList) do
        local plane = data.instance
        if not plane then
            table.insert(toRemove, key)
            continue
        end
        
        -- Get the main body (cheap property read)
        local mainBody = plane:FindFirstChild("MainBody")
        if not mainBody then
            mainBody = plane.PrimaryPart
        end
        if not mainBody then
            table.insert(toRemove, key)
            continue
        end
        
        -- Read properties (SUPER CHEAP - no Workspace scan)
        local hp = plane:FindFirstChild("HP")
        local ammo = plane:FindFirstChild("Ammo")
        local fuel = plane:FindFirstChild("Fuel")
        local occupant = plane:FindFirstChild("Occupant")
        local lookAt = plane:FindFirstChild("LookAt")
        
        local position = mainBody.Position
        local velocity = mainBody.AssemblyLinearVelocity or Vector3.new(0,0,0)
        
        -- Update data
        data.position = position
        data.altitude = position.Y
        data.velocity = velocity
        data.health = hp and hp.Value or 0
        data.ammo = ammo and ammo.Value or 0
        data.fuel = fuel and fuel.Value or 0
        data.occupant = occupant and occupant.Value or ""
        data.isOccupied = occupant and occupant.Value ~= "" and occupant.Value ~= nil or false
        data.lookAt = lookAt and lookAt.Value or nil
        data.isAlive = hp and hp.Value > 0 or false
        data.lastSeen = tick()
        
        -- Distance check (if we have position)
        if myPos then
            local distance = (position - myPos).Magnitude
            data.distance = distance
            data.bearing = math.deg(math.atan2((position - myPos).Unit.X, (position - myPos).Unit.Z))
            
            if distance > SCAN_RANGE then
                table.insert(toRemove, key)
                continue
            end
        end
        
        -- Check if dead
        if not data.isAlive then
            table.insert(toRemove, key)
            continue
        end
    end
    
    -- Remove dead/out-of-range enemies
    for _, key in ipairs(toRemove) do
        StateManager.removeEnemy(key)
        debugTrack("Removed enemy: " .. key)
    end
end

-- ==========================================
-- START TRACKING (Called by Main - Runs every frame)
-- ==========================================
function EnemyManager.startTracking()
    if trackingConnection then
        debugPrint("Tracking already running")
        return
    end
    
    debugPrint("Starting fast tracking (every frame)")
    
    trackingConnection = RunService.Heartbeat:Connect(function()
        EnemyManager.updateTrackedEnemies()
    end)
end

-- ==========================================
-- STOP TRACKING
-- ==========================================
function EnemyManager.stopTracking()
    if trackingConnection then
        trackingConnection:Disconnect()
        trackingConnection = nil
        debugPrint("Tracking stopped")
    end
end

-- ==========================================
-- GET MY POSITION
-- ==========================================
function EnemyManager.getMyPosition()
    local character = player.Character
    if not character then return nil end
    
    local plane = StateManager.get("targetVehicle")
    if plane and StateManager.get("seated") then
        local mainBody = plane:FindFirstChild("MainBody")
        if mainBody then
            return mainBody.Position
        end
    end
    
    local primaryPart = character.PrimaryPart
    if primaryPart then
        return primaryPart.Position
    end
    
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
    
    local plane = StateManager.get("targetVehicle")
    if plane and StateManager.get("seated") then
        local mainBody = plane:FindFirstChild("MainBody")
        if mainBody then
            return mainBody.AssemblyLinearVelocity or Vector3.new(0,0,0)
        end
    end
    
    local primaryPart = character.PrimaryPart
    if primaryPart then
        return primaryPart.AssemblyLinearVelocity or Vector3.new(0,0,0)
    end
    
    return Vector3.new(0,0,0)
end

-- ==========================================
-- GET ENEMY LOOK DIRECTION
-- ==========================================
function EnemyManager.getEnemyFacing(enemyData)
    if not enemyData or not enemyData.lookAt then
        return nil
    end
    
    if type(enemyData.lookAt) == "Vector3" then
        return enemyData.lookAt
    end
    
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
        -- === SELF STATE ===
        health = 0,
        ammo = 0,
        fuel = 0,
        altitude = 0,
        altitudeNormalized = 0,
        distanceToKillZone = 0,
        speed = 0,
        pitch = 0,                    -- NEW: plane pitch angle
        isSeated = 0,
        isAlive = 0,
        
        -- === ENEMY STATE ===
        enemyDistance = 0,
        enemyBearing = 0,
        enemyElevation = 0,
        enemyHealth = 0,
        enemyAltitude = 0,
        enemyAltitudeNormalized = 0,
        altitudeDifference = 0,       -- NEW: enemy.Y - self.Y
        enemySpeed = 0,
        enemyFacingAngle = 0,
        
        -- === ENEMY RELATIVE VELOCITY ===
        enemyRelVelX = 0,             -- NEW
        enemyRelVelY = 0,             -- NEW
        enemyRelVelZ = 0,             -- NEW
        
        -- === ENEMY TYPE ===
        enemyIsBomber = 0,
        enemyIsTorpedo = 0,
        enemyIsLarge = 0,
        
        -- === COMBAT STATE ===
        enemiesInRange = 0,
        weaponCooldown = 0,           -- NEW: RPG cooldown
        mgToggled = 0,                -- NEW: MG state
    }
    
    -- Get self state
    local selfPos = EnemyManager.getMyPosition()
    local selfVel = EnemyManager.getMyVelocity()
    local plane = StateManager.get("targetVehicle")
    local seated = StateManager.get("seated")
    
    if not selfPos then return obs end
    
    local KILL_ZONE = 80
    local MAX_ALTITUDE = 800
    
    -- Self state
    obs.altitude = selfPos.Y
    obs.altitudeNormalized = clamp(selfPos.Y / MAX_ALTITUDE, 0, 1)
    obs.distanceToKillZone = clamp((selfPos.Y - KILL_ZONE) / MAX_ALTITUDE, 0, 1)
    obs.speed = selfVel.Magnitude
    obs.isSeated = seated and 1 or 0
    obs.isAlive = player.Character and 1 or 0
    
    -- Plane pitch angle (how much we're pointing up/down)
    if plane then
        local mainBody = plane:FindFirstChild("MainBody")
        if mainBody then
            local forward = mainBody.CFrame.LookVector
            obs.pitch = clamp(math.deg(math.asin(forward.Y)) / 90, -1, 1)
        end
    end
    
    -- Get plane stats
    if plane then
        local hp = plane:FindFirstChild("HP")
        local ammo = plane:FindFirstChild("BulletC")  -- Fixed: Ammo → BulletC
        local fuel = plane:FindFirstChild("Fuel")
        
        obs.health = hp and clamp(hp.Value / 100, 0, 1) or 0
        obs.ammo = ammo and clamp(ammo.Value / 100, 0, 1) or 0
        obs.fuel = fuel and clamp(fuel.Value / 100, 0, 1) or 0
    end
    
    -- Weapon state
    local WeaponSystem = _G._Modules.WeaponSystem
    if WeaponSystem then
        local rpgStatus = WeaponSystem.getRPGStatus()
        local mgStatus = WeaponSystem.getMGStatus()
        obs.weaponCooldown = clamp(rpgStatus.cooldown / 3, 0, 1)  -- 0-1 (3s max)
        obs.mgToggled = mgStatus.toggled and 1 or 0
    end
    
    -- Get nearest enemy
    local enemyList = StateManager.getEnemyList()
    if not enemyList then return obs end
    
    local nearest = nil
    local nearestDist = math.huge
    
    for _, data in pairs(enemyList) do
        if data.distance and data.distance < nearestDist then
            nearestDist = data.distance
            nearest = data
        end
    end
    
    if not nearest then return obs end
    
    -- Enemy state
    obs.enemyDistance = clamp(nearest.distance / 2200, 0, 1)
    obs.enemyBearing = clamp(nearest.bearing / 180, -1, 1)
    obs.enemyElevation = clamp(nearest.elevation / 90, -1, 1)
    obs.enemyHealth = clamp(nearest.health / 100, 0, 1)
    obs.enemyAltitude = nearest.altitude
    obs.enemyAltitudeNormalized = clamp(nearest.altitude / MAX_ALTITUDE, 0, 1)
    obs.altitudeDifference = clamp((nearest.altitude - selfPos.Y) / MAX_ALTITUDE, -1, 1)
    obs.enemySpeed = nearest.velocity and nearest.velocity.Magnitude or 0
    
    -- Enemy relative velocity
    if nearest.velocity and selfVel then
        local relVel = nearest.velocity - selfVel
        obs.enemyRelVelX = clamp(relVel.X / 100, -1, 1)
        obs.enemyRelVelY = clamp(relVel.Y / 100, -1, 1)
        obs.enemyRelVelZ = clamp(relVel.Z / 100, -1, 1)
    end
    
    -- Enemy type
    obs.enemyIsBomber = nearest.type == "Bomber" and 1 or 0
    obs.enemyIsTorpedo = nearest.type == "TorpedoBomber" and 1 or 0
    obs.enemyIsLarge = nearest.type == "LargeBomber" and 1 or 0
    
    -- Enemy facing
    if nearest.lookAt then
        local enemyFacing = EnemyManager.getEnemyFacing(nearest)
        if enemyFacing then
            local dirToEnemy = (nearest.position - selfPos).Unit
            local facingAngle = math.deg(math.acos(enemyFacing:Dot(dirToEnemy)))
            obs.enemyFacingAngle = clamp(facingAngle / 180, -1, 1)
        end
    end
    
    obs.enemiesInRange = StateManager.getEnemyCount() or 0
    
    return obs
end

-- ==========================================
-- CLEAR CACHE (on respawn)
-- ==========================================
function EnemyManager.clearCache()
    StateManager.clearEnemies()
    debugPrint("Cache cleared")
end

-- ==========================================
-- TOGGLE DEBUG
-- ==========================================
function EnemyManager.setDebug(enabled)
    DEBUG_ENEMY_DETECTION = enabled
    DEBUG_SCAN_SUMMARY = enabled
    DEBUG_TRACKING = enabled
    debugPrint("Debug set to:", enabled)
end

return EnemyManager
