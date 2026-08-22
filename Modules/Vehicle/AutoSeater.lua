--[[
    AutoSeater.lua – qurp v3 (Phase 1)
    Orchestrates: ensure we have a plane and are seated.
    Runs as a loop while player is alive.
    Stateless — all state stored in StateManager.
]]

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local StateManager = _G._Modules.StateManager
local VehicleSpawner = _G._Modules.VehicleSpawner
local VehicleSeeder = _G._Modules.VehicleSeeder
local AirportManager = _G._Modules.AirportManager
local Debug = _G._Modules.Debug

-- ==========================================
-- ENSURE PLANE (Main Loop)
-- ==========================================
local function ensurePlane(myGen)
    Debug.info("AutoSeater", "Starting ensurePlane loop (gen " .. myGen .. ")")
    
    while StateManager.get("isAlive") do
        -- Check generation (abort if stale)
        if StateManager.getGeneration() ~= myGen then
            Debug.info("AutoSeater", "Generation mismatch — exiting loop.")
            return
        end
        
        -- Step 1: Do we have a plane?
        local vehicle = StateManager.get("targetVehicle")
        local hasPlane = StateManager.get("hasPlane")
        
        -- Step 2: If no plane, spawn one
        if not hasPlane or not vehicle then
            Debug.info("AutoSeater", "No plane found — spawning...")
            
            local airport = AirportManager.getNearestAirport(player.Character, myGen)
            if not airport then
                Debug.warn("AutoSeater", "No airport found — waiting...")
                task.wait(1)
                continue
            end
            
            local success = VehicleSpawner.spawnVehicle(airport, myGen)
            if success then
                Debug.info("AutoSeater", "Plane spawned.")
                task.wait(0.5)
                continue
            else
                Debug.warn("AutoSeater", "Spawn failed — retrying...")
                task.wait(1)
                continue
            end
        end
        
        -- Step 3: Check if seated
        local seated = StateManager.get("seated")
        
        if not seated then
            Debug.info("AutoSeater", "Not seated — walking to vehicle...")
            
            local walkSuccess = VehicleSeeder.walkToVehicle(player.Character, myGen)
            if not walkSuccess then
                Debug.warn("AutoSeater", "Walk to vehicle failed — restarting...")
                StateManager.set("targetVehicle", nil)
                StateManager.set("hasPlane", false)
                task.wait(0.5)
                continue
            end
            
            local sitSuccess = VehicleSeeder.sitInVehicle(player.Character, myGen)
            if not sitSuccess then
                Debug.warn("AutoSeater", "Failed to sit — restarting...")
                StateManager.set("targetVehicle", nil)
                StateManager.set("hasPlane", false)
                StateManager.set("seated", false)
                task.wait(0.5)
                continue
            end
            
            Debug.info("AutoSeater", "Seated successfully!")
        end
        
        -- Step 4: If seated, wait and check again
        if StateManager.get("seated") then
            task.wait(1)
        end
        
        task.wait(0.1)
    end
    
    Debug.info("AutoSeater", "Player is no longer alive — exiting loop.")
end

-- ==========================================
-- START (Called by Main)
-- ==========================================
local function start(myGen)
    Debug.info("AutoSeater", "Starting AutoSeater (gen " .. myGen .. ")")
    
    -- Reset plane-related state
    StateManager.set("hasPlane", false)
    StateManager.set("seated", false)
    StateManager.set("targetVehicle", nil)
    StateManager.set("isPlaneAlive", false)
    
    -- Cache airports
    AirportManager.cacheAirports(myGen)
    
    -- Start the ensure loop
    task.spawn(ensurePlane, myGen)
end

-- ==========================================
-- MODULE EXPORT
-- ==========================================
return {
    start = start,
}
