-- AutoSeater.lua – Movement and Seating
-- Handles walking to positions and sitting in bombers

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local StateManager = _G._Modules.StateManager
local AirportManager = _G._Modules.AirportManager
local BomberManager = _G._Modules.BomberManager
local Debug = _G._Modules.Debug

local AutoSeater = {}

-- ==========================================
-- WALK TO POSITION
-- ==========================================
function AutoSeater.walkToPosition(targetPosition, tolerance)
    tolerance = tolerance or 5
    
    local character = player.Character
    if not character then
        Debug.warn("AutoSeater", "No character to move")
        return false
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not hrp then
        Debug.warn("AutoSeater", "Missing humanoid or HRP")
        return false
    end
    
    -- Check if we're close enough
    local distance = (targetPosition - hrp.Position).Magnitude
    if distance <= tolerance then
        Debug.info("AutoSeater", "Arrived at target")
        return true
    end
    
    -- Move toward target
    Debug.info("AutoSeater", string.format("Walking to target (%.2f studs away)", distance))
    humanoid:MoveTo(targetPosition)
    
    return false
end

-- ==========================================
-- WALK TO NEAREST AIRPORT
-- ==========================================
function AutoSeater.walkToNearestAirport()
    local character = player.Character
    if not character then
        Debug.warn("AutoSeater", "No character to move")
        return false
    end
    
    local airport = AirportManager.getNearestAirport(character)
    if not airport then
        Debug.warn("AutoSeater", "No airport found")
        return false
    end
    
    Debug.info("AutoSeater", "Walking to nearest airport")
    return AutoSeater.walkToPosition(airport.Position)
end

-- ==========================================
-- WALK TO BOMBER
-- ==========================================
function AutoSeater.walkToBomber(bomber)
    if not bomber then
        Debug.warn("AutoSeater", "No bomber to walk to")
        return false
    end
    
    local hrp = bomber:FindFirstChild("HumanoidRootPart")
    if not hrp then
        -- Try to find the bomber's position from its model
        local position = bomber:GetPivot()
        if not position then
            Debug.warn("AutoSeater", "Could not find bomber position")
            return false
        end
        return AutoSeater.walkToPosition(position.Position)
    end
    
    Debug.info("AutoSeater", "Walking to bomber")
    return AutoSeater.walkToPosition(hrp.Position)
end

-- ==========================================
-- TRY SIT IN BOMBER (With Arrival Check)
-- ==========================================
function AutoSeater.trySitInBomber(bomber)
    if not bomber then
        Debug.warn("AutoSeater", "No bomber to sit in")
        return false
    end
    
    local character = player.Character
    if not character then
        Debug.warn("AutoSeater", "No character")
        return false
    end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        Debug.warn("AutoSeater", "No HRP")
        return false
    end
    
    -- Get bomber position
    local bomberHrp = bomber:FindFirstChild("HumanoidRootPart")
    if not bomberHrp then
        Debug.warn("AutoSeater", "Bomber has no HRP")
        return false
    end
    
    -- Check if we're close enough to sit
    local distance = (bomberHrp.Position - hrp.Position).Magnitude
    if distance > 10 then
        Debug.info("AutoSeater", string.format("Too far to sit (%.2f studs)", distance))
        return false
    end
    
    -- Try to sit
    Debug.info("AutoSeater", "Attempting to sit in bomber")
    return BomberManager.sitInBomber(bomber)
end

return AutoSeater
