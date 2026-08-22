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
    
    -- Read the cached airport from StateManager
    local airport = AirportManager.getNearestAirport(player.Character, myGen)
    
    if airport then
        Debug.info("AutoSeater", "Nearest airport found at:", airport.Position)
    else
        Debug.warn("AutoSeater", "No airport found in cache!")
    end
    
    Debug.info("AutoSeater", "Bare-bones test complete.")
end

-- ==========================================
-- MODULE EXPORT
-- ==========================================
return {
    start = start,
}
