-- AirportManager.lua – qurp v3
-- Stores airport cache in StateManager (single source of truth)

local Workspace = game:GetService("Workspace")
local StateManager = _G._Modules.StateManager
local DockLocator = _G._Modules.DockLocator

-- ==========================================
-- CACHE AIRPORTS
-- ==========================================
local function cacheAirports(myGen)
    -- Check if already cached for this generation
    if StateManager.get("airportsCached") then
        print("[AirportManager] Already cached — skipping")
        return true
    end
    
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
    
    local cache = {}
    for _, child in ipairs(vehicleSP:GetChildren()) do
        if child.Name == "Airport" then
            table.insert(cache, child)
        end
    end
    
    -- Store in StateManager
    StateManager.set("airportCache", cache)
    StateManager.set("airportsCached", true)
    
    print("[AirportManager] Cached", #cache, "airports.")
    return #cache > 0
end

-- ==========================================
-- GET NEAREST AIRPORT
-- ==========================================
local function getNearestAirport(playerChar, myGen)
    -- ✅ Read from StateManager
    local cache = StateManager.get("airportCache")
    
    if not cache or #cache == 0 then
        print("[AirportManager] No airport cache found.")
        return nil
    end
    
    if not playerChar then
        print("[AirportManager] No player character.")
        return nil
    end
    
    local hrp = playerChar:FindFirstChild("HumanoidRootPart")
    if not hrp then
        print("[AirportManager] No HumanoidRootPart.")
        return nil
    end
    
    local nearest = nil
    local nearestDist = math.huge
    
    for _, airport in ipairs(cache) do
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
