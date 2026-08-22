--[[
    VehicleSpawner.lua – qurp v3 (Phase 1)
    Handles: Spawning planes + watching for destruction
    All state stored in StateManager — no local state.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local Event = ReplicatedStorage:WaitForChild("Event")
local StateManager = _G._Modules.StateManager
local Debug = _G._Modules.Debug

local VEHICLE_NAME = "Bomber"
local vehicleWatcher = nil

-- ==========================================
-- WATCH PLANE FOR DESTRUCTION
-- ==========================================
local function watchPlane(vehicle)
    -- Clean up old watcher
    if vehicleWatcher then
        vehicleWatcher:Disconnect()
        vehicleWatcher = nil
    end
    
    StateManager.set("targetVehicle", vehicle)
    StateManager.set("hasPlane", true)
    StateManager.set("isPlaneAlive", true)
    
    vehicleWatcher = vehicle.AncestryChanged:Connect(function()
        if not vehicle.Parent or vehicle.Parent ~= workspace then
            Debug.info("VehicleSpawner", "Plane destroyed!")
            StateManager.set("hasPlane", false)
            StateManager.set("isPlaneAlive", false)
            StateManager.set("seated", false)
            StateManager.set("targetVehicle", nil)
            
            vehicleWatcher:Disconnect()
            vehicleWatcher = nil
        end
    end)
end

-- ==========================================
-- SPAWN VEHICLE
-- ==========================================
local function spawnVehicle(airport, myGen)
    -- Check for existing owned plane first
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name == VEHICLE_NAME then
            local owner = obj:FindFirstChild("Owner")
            if owner and owner:IsA("StringValue") and owner.Value == player.Name then
                Debug.info("VehicleSpawner", "Found existing plane — reusing.")
                watchPlane(obj)
                return true
            end
        end
    end
    
    -- No existing plane — spawn a new one
    Debug.info("VehicleSpawner", "Spawning new plane...")
    
    pcall(function()
        Event:FireServer("VSpawn", { airport, VEHICLE_NAME, 2 })
    end)
    
    -- Wait for spawn to register
    task.wait(1)
    
    -- Find and watch the new plane
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name == VEHICLE_NAME then
            local owner = obj:FindFirstChild("Owner")
            if owner and owner:IsA("StringValue") and owner.Value == player.Name then
                Debug.info("VehicleSpawner", "Plane spawned successfully.")
                watchPlane(obj)
                return true
            end
        end
    end
    
    Debug.warn("VehicleSpawner", "Failed to spawn plane.")
    return false
end

-- ==========================================
-- MODULE EXPORT
-- ==========================================
return {
    spawnVehicle = spawnVehicle,
    watchPlane = watchPlane,
}
