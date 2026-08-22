-- AutoSeater.lua – Phase 1 (Bare-Bones)
-- I love you

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local StateManager = _G._Modules.StateManager
local AirportManager = _G._Modules.AirportManager
local Debug = _G._Modules.Debug

print("[AutoSeater] Module loaded!")

-- ==========================================
-- START (Bare-Bones)
-- ==========================================
local function start(myGen)
    print("[AutoSeater] START FUNCTION CALLED with gen: " .. tostring(myGen))
    
    -- Check if Debug is available
    if Debug and Debug.info then
        Debug.info("AutoSeater", "Starting (bare-bones) — gen " .. myGen)
    else
        print("[AutoSeater] Debug module not available!")
    end
    
    -- Check if character exists
    if not player.Character then
        print("[AutoSeater] No character found!")
        if Debug and Debug.warn then
            Debug.warn("AutoSeater", "No character found!")
        end
        return
    end
    
    print("[AutoSeater] Character found")
    
    -- Get the airport
    print("[AutoSeater] Calling AirportManager.getNearestAirport...")
    local airport = AirportManager.getNearestAirport(player.Character, myGen)
    
    if airport then
        print("[AutoSeater] Airport found!")
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local distance = (airport.Position - hrp.Position).Magnitude
            print(string.format("[AutoSeater] Distance to airport: %.2f studs", distance))
            print("[AutoSeater] Airport position: " .. tostring(airport.Position))
            if Debug and Debug.info then
                Debug.info("AutoSeater", string.format("Distance to airport: %.2f studs", distance))
            end
        else
            print("[AutoSeater] No HRP found, can't calculate distance")
            if Debug and Debug.info then
                Debug.info("AutoSeater", "Nearest airport found at: " .. tostring(airport.Position))
            end
        end
    else
        print("[AutoSeater] No airport found in cache!")
        if Debug and Debug.warn then
            Debug.warn("AutoSeater", "No airport found in cache!")
        end
        
        -- Print cache contents for debugging
        local cache = StateManager.get("airportCache")
        if cache then
            print("[AutoSeater] Cache has " .. #cache .. " airports total")
            if #cache > 0 then
                print("[AutoSeater] First airport: " .. tostring(cache[1].Name))
            end
        else
            print("[AutoSeater] Cache is nil or doesn't exist")
        end
    end
    
    print("[AutoSeater] Bare-bones test complete.")
end

-- ==========================================
-- MODULE EXPORT
-- ==========================================
return {
    start = start,
}
