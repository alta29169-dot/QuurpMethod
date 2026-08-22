--[[
    AirportManager.lua – qurp v3
    Handles: Caching airports and finding the nearest one
]]

local Workspace = game:GetService("Workspace")

-- ===== STATE =====
local airportCache = {}

-- ==========================================
-- CACHE AIRPORTS
-- ==========================================
local function cacheAirports(myGen)
    local DockLocator = _G._Modules.DockLocator
    local StateManager = _G._Modules.StateManager
    
    airportCache = {}
    local dock = DockLocator.getDock()
    
    if not dock then
        print("[AirportManager] Could not find dock.")
        return false
    end
    
    local vehicleSP = dock:FindFirstChild("VehicleSP")
    if not vehicleSP then
        print("[AirportManager] No VehicleSP found.")
        return false
    end
    
    for _, child in ipairs(vehicleSP:GetChildren()) do
        if child.Name == "Airport" then
            table.insert(airportCache, child)
        end
    end
    
    -- Use StateManager instead of _G._currentGen
    if myGen and StateManager and StateManager.getGeneration() ~= myGen then
        return false
    end
    
    print("[AirportManager] Cached", #airportCache, "airports.")
    return #airportCache > 0
end

-- ==========================================
-- GET NEAREST AIRPORT
-- ==========================================
local function getNearestAirport(playerChar, myGen)
    local StateManager = _G._Modules.StateManager
    
    if not playerChar or (myGen and StateManager and StateManager.getGeneration() ~= myGen) then
        return nil
    end
    
    local hrp = playerChar:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local nearest = nil
    local nearestDist = math.huge
    
    for _, airport in ipairs(airportCache) do
        if airport:IsA("BasePart") then
            local dist = (airport.Position - hrp.Position).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearest = airport
            end
        end
    end
    
    return nearest
end

return {
    cacheAirports = cacheAirports,
    getNearestAirport = getNearestAirport,
}
