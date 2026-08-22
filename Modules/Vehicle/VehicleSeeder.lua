--[[
    VehicleSeeder.lua – qurp v3 (Phase 1)
    Handles: Walking to vehicle + sitting in it
]]

local Players = game:GetService("Players")
local StateManager = _G._Modules.StateManager
local PathWalker = _G._Modules.PathWalker
local Debug = _G._Modules.Debug

local SEAT_NAME = "Seat"

-- ==========================================
-- WALK TO VEHICLE
-- ==========================================
local function walkToVehicle(playerChar, myGen)
    local vehicle = StateManager.get("targetVehicle")
    if not vehicle then
        Debug.warn("VehicleSeeder", "No target vehicle.")
        return false
    end
    
    local seat = vehicle:FindFirstChild(SEAT_NAME)
    if not seat then
        Debug.warn("VehicleSeeder", "Vehicle has no seat.")
        return false
    end
    
    local hrp = playerChar and playerChar:FindFirstChild("HumanoidRootPart")
    if hrp then
        local dist = (hrp.Position - seat.Position).Magnitude
        if dist < 50 then
            Debug.info("VehicleSeeder", "Already near vehicle.")
            return true
        end
    end
    
    Debug.info("VehicleSeeder", "Walking to vehicle...")
    return PathWalker.walkToTarget(seat.Position, "vehicle", playerChar, myGen)
end

-- ==========================================
-- SIT IN VEHICLE
-- ==========================================
local function sitInVehicle(playerChar, myGen)
    local vehicle = StateManager.get("targetVehicle")
    if not vehicle then
        Debug.warn("VehicleSeeder", "No target vehicle.")
        return false
    end
    
    local seat = vehicle:FindFirstChild(SEAT_NAME)
    if not seat then
        Debug.warn("VehicleSeeder", "Vehicle has no seat.")
        return false
    end
    
    local hrp = playerChar and playerChar:FindFirstChild("HumanoidRootPart")
    if not hrp then
        Debug.warn("VehicleSeeder", "No HumanoidRootPart.")
        return false
    end
    
    -- Check if already seated
    local humanoid = playerChar:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.SeatPart == seat then
        Debug.info("VehicleSeeder", "Already seated.")
        StateManager.set("seated", true)
        return true
    end
    
    Debug.info("VehicleSeeder", "Sitting in vehicle...")
    hrp.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
    task.wait(0.5)
    
    -- Verify seating
    humanoid = playerChar:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.SeatPart then
        StateManager.set("seated", true)
        Debug.info("VehicleSeeder", "Seated successfully!")
        return true
    end
    
    Debug.warn("VehicleSeeder", "Failed to sit.")
    return false
end

-- ==========================================
-- MODULE EXPORT
-- ==========================================
return {
    walkToVehicle = walkToVehicle,
    sitInVehicle = sitInVehicle,
}
