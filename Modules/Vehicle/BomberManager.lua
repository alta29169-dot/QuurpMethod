-- BomberManager.lua – Vehicle Operations
-- Handles finding, spawning, and sitting in bombers

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateManager = _G._Modules.StateManager
local Debug = _G._Modules.Debug

local BomberManager = {}

-- ==========================================
-- FIND OUR BOMBER
-- ==========================================
function BomberManager.findMyBomber()
    local playerName = player.Name
    
    for _, bomber in ipairs(Workspace:GetChildren()) do
        if bomber.Name == "Bomber" then
            local owner = bomber:FindFirstChild("Owner")
            if owner and owner.Value == playerName then
                return bomber
            end
        end
    end
    
    return nil
end

-- ==========================================
-- CHECK BOMBER OCCUPANT
-- ==========================================
function BomberManager.getBomberOccupant(bomber)
    if not bomber then return nil end
    
    local occupant = bomber:FindFirstChild("Occupant")
    if occupant then
        return occupant.Value
    end
    
    return nil
end

-- ==========================================
-- CHECK IF BOMBER IS OCCUPIED
-- ==========================================
function BomberManager.isBomberOccupied(bomber)
    if not bomber then return false end
    
    local occupant = BomberManager.getBomberOccupant(bomber)
    if occupant == nil or occupant == "" then
        return false  -- Empty
    end
    
    return true  -- Someone is in it
end

-- ==========================================
-- CHECK IF WE ARE IN THE BOMBER
-- ==========================================
function BomberManager.isUsInBomber(bomber)
    if not bomber then return false end
    
    local occupant = BomberManager.getBomberOccupant(bomber)
    return occupant == player.Name
end

-- ==========================================
-- UPDATE PLANE STATE
-- ==========================================
function BomberManager.updatePlaneState()
    local myBomber = BomberManager.findMyBomber()
    
    if myBomber then
        -- We have a plane
        StateManager.set("hasPlane", true)
        StateManager.set("targetVehicle", myBomber)
        StateManager.set("isPlaneAlive", true)
        
        -- Check if we're seated in it
        local inBomber = BomberManager.isUsInBomber(myBomber)
        StateManager.set("seated", inBomber)
        
        if inBomber then
            Debug.info("BomberManager", "We are seated in our bomber")
        else
            local occupant = BomberManager.getBomberOccupant(myBomber)
            if occupant and occupant ~= "" and occupant ~= player.Name then
                Debug.warn("BomberManager", "Our bomber is stolen by: " .. occupant)
            else
                Debug.info("BomberManager", "Our bomber is empty and waiting")
            end
        end
        
        return myBomber
    else
        -- No plane found
        StateManager.set("hasPlane", false)
        StateManager.set("targetVehicle", nil)
        StateManager.set("isPlaneAlive", false)
        StateManager.set("seated", false)
        
        return nil
    end
end

-- ==========================================
-- GET BOMBER SEAT
-- ==========================================
function BomberManager.getBomberSeat(bomber)
    if not bomber then return nil end
    
    return bomber:FindFirstChild("Seat")
end

-- ==========================================
-- SPAWN BOMBER AT AIRPORT
-- ==========================================
function BomberManager.spawnBomber(airport)
    if not airport then
        Debug.warn("BomberManager", "No airport provided for spawning")
        return false
    end
    
    -- Find the VehicleSP
    local dock = Workspace:FindFirstChild("USDock")
    if not dock then
        Debug.warn("BomberManager", "USDock not found")
        return false
    end
    
    local vehicleSP = dock:FindFirstChild("VehicleSP")
    if not vehicleSP then
        Debug.warn("BomberManager", "VehicleSP not found")
        return false
    end
    
    -- Get all children and find the airport's spawn point
    local children = vehicleSP:GetChildren()
    local spawnPoint = nil
    
    for i, child in ipairs(children) do
        if child == airport then
            -- The airport itself is the spawn point at index 8 in your example
            -- But let's use the actual airport reference
            spawnPoint = child
            break
        end
    end
    
    if not spawnPoint then
        Debug.warn("BomberManager", "Could not find spawn point for airport")
        return false
    end
    
    -- Fire the remote event to spawn
    local remote = ReplicatedStorage:FindFirstChild("Event")
    if not remote then
        Debug.warn("BomberManager", "Remote Event not found")
        return false
    end
    
    Debug.info("BomberManager", "Spawning bomber at airport: " .. airport.Name)
    remote:FireServer("VSpawn", { spawnPoint, "Bomber", 2 })
    
    -- Wait a moment for the bomber to spawn
    task.wait(2)
    
    -- Check if we have a bomber now
    local myBomber = BomberManager.findMyBomber()
    if myBomber then
        Debug.info("BomberManager", "Bomber spawned successfully!")
        StateManager.set("hasPlane", true)
        StateManager.set("targetVehicle", myBomber)
        StateManager.set("isPlaneAlive", true)
        return true
    else
        Debug.warn("BomberManager", "Bomber failed to spawn")
        return false
    end
end

-- ==========================================
-- SIT IN BOMBER
-- ==========================================
function BomberManager.sitInBomber(bomber)
    if not bomber then
        Debug.warn("BomberManager", "No bomber to sit in")
        return false
    end
    
    -- Check if someone else is in it
    local occupant = BomberManager.getBomberOccupant(bomber)
    if occupant and occupant ~= "" and occupant ~= player.Name then
        Debug.warn("BomberManager", "Bomber occupied by: " .. occupant)
        return false
    end
    
    -- Get the seat
    local seat = BomberManager.getBomberSeat(bomber)
    if not seat then
        Debug.warn("BomberManager", "No seat found in bomber")
        return false
    end
    
    -- Sit in the seat
    local character = player.Character
    if not character then
        Debug.warn("BomberManager", "No character to sit")
        return false
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then
        Debug.warn("BomberManager", "No humanoid found")
        return false
    end
    
    Debug.info("BomberManager", "Sitting in bomber...")
    humanoid.Sit = true
    character:SetPrimaryPartCFrame(seat.CFrame)
    
    -- Wait a moment for the sit to register
    task.wait(1)
    
    -- Verify we're seated
    if BomberManager.isUsInBomber(bomber) then
        Debug.info("BomberManager", "Successfully seated in bomber!")
        StateManager.set("seated", true)
        return true
    else
        Debug.warn("BomberManager", "Failed to sit in bomber")
        return false
    end
end

return BomberManager
