-- AirportManager.lua
local Workspace = game:GetService("Workspace")
local StateManager = _G._Modules.StateManager
local DockLocator = _G._Modules.DockLocator

local function cacheAirports(myGen)
    -- Check StateManager first
    if StateManager.get("airportsCached") then
        print("[AirportManager] Already cached for this generation")
        return true
    end
    
    local dock = DockLocator.getDock()
    if not dock then return false end
    
    local vehicleSP = dock:FindFirstChild("VehicleSP")
    if not vehicleSP then return false end
    
    local cache = {}
    for _, child in ipairs(vehicleSP:GetChildren()) do
        if child.Name == "Airport" then
            table.insert(cache, child)
        end
    end
    
    -- ✅ Store in StateManager
    StateManager.set("airportCache", cache)
    StateManager.set("airportsCached", true)
    
    print("[AirportManager] Cached", #cache, "airports.")
    return #cache > 0
end

local function getNearestAirport(playerChar)
    local cache = StateManager.get("airportCache")
    if not cache or #cache == 0 then return nil end
    
    local hrp = playerChar and playerChar:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
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
