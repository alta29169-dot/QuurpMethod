-- AutoSeater.lua – Phase 1 (Bare-Bones)
-- Just reads the cached airport from StateManager and prints it.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local StateManager = _G._Modules.StateManager
local AirportManager = _G._Modules.AirportManager
local Debug = _G._Modules.Debug

-- ==========================================
-- START (Bare-Bones)
-- ==========================================
local function start(myGen)
    Debug.info("AutoSeater", "Starting (bare-bones) — gen " .. myGen)
    
    -- Check if character exists
    if not player.Character then
        Debug.warn("AutoSeater", "No character found!")
        return
    end
    
    -- Read the cached airport from StateManager
    local airport = AirportManager.getNearestAirport(player.Character, myGen)
    
    if airport then
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local distance = (airport.Position - hrp.Position).Magnitude
            Debug.info("AutoSeater", string.format("Nearest airport distance: %.2f studs", distance))
            Debug.info("AutoSeater", "Airport position:", airport.Position)
        else
            Debug.info("AutoSeater", "Nearest airport found at:", airport.Position)
        end
    else
        Debug.warn("AutoSeater", "No airport found in cache!")
        -- Print cache contents for debugging
        local cache = StateManager.get("airportCache")
        if cache then
            Debug.info("AutoSeater", "Cache has " .. #cache .. " airports total")
        else
            Debug.info("AutoSeater", "Cache is nil or doesn't exist")
        end
    end
    
    Debug.info("AutoSeater", "Bare-bones test complete.")
end

-- ==========================================
-- MODULE EXPORT
-- ==========================================
return {
    start = start,
}
