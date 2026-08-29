-- BomberManager.lua – Vehicle Operations | I just wanted you to love me back

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
        return false
    end
    
    return true
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
-- GET PLANE DATA (with HP/Ammo/Fuel)
-- ==========================================
function BomberManager.getPlaneData(plane)
    if not plane then return nil end
    
    local mainBody = plane:FindFirstChild("MainBody")
    if not mainBody then
        mainBody = plane.PrimaryPart
    end
    if not mainBody then
        mainBody = plane:FindFirstChildWhichIsA("BasePart")
    end
    if not mainBody then return nil end
    
    local hp = plane:FindFirstChild("HP")
    local owner = plane:FindFirstChild("Owner")
    local occupant = plane:FindFirstChild("Occupant")
    local ammo = plane:FindFirstChild("Ammo")
    local fuel = plane:FindFirstChild("Fuel")
    local team = plane:FindFirstChild("Team")
    
    local position = mainBody.Position
    
    return {
        instance = plane,
        type = plane.Name,
        position = position,
        altitude = position.Y,
        mainBody = mainBody,
        health = hp and hp.Value or 0,
        ammo = ammo and ammo.Value or 0,
        fuel = fuel and fuel.Value or 0,
        team = team and team.Value or "Unknown",
        owner = owner and owner.Value or "",
        occupant = occupant and occupant.Value or "",
        isAlive = hp and hp.Value > 0 or false,
        isOccupied = occupant and occupant.Value ~= "" and occupant.Value ~= nil or false,
        lastSeen = tick(),
    }
end

-- ==========================================
-- UPDATE PLANE STATE (with HP/Ammo/Fuel)
-- ==========================================
function BomberManager.updatePlaneState()
    local myBomber = BomberManager.findMyBomber()
    
    if myBomber then
        local data = BomberManager.getPlaneData(myBomber)
        
        -- We have a plane
        StateManager.set("hasPlane", true)
        StateManager.set("targetVehicle", myBomber)
        StateManager.set("isPlaneAlive", data.isAlive)
        StateManager.set("myHealth", data.health)
        StateManager.set("myAmmo", data.ammo)
        StateManager.set("myFuel", data.fuel)
        
        -- Check if we're seated in it
        local inBomber = BomberManager.isUsInBomber(myBomber)
        StateManager.set("seated", inBomber)
        
        if inBomber then
            Debug.info("BomberManager", "We are seated in our bomber")
            Debug.info("BomberManager", "Health:", data.health, "Ammo:", data.ammo, "Fuel:", data.fuel)
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
        StateManager.set("myHealth", 0)
        StateManager.set("myAmmo", 0)
        StateManager.set("myFuel", 0)
        
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
    
    local remote = ReplicatedStorage:FindFirstChild("Event")
    if not remote then
        Debug.warn("BomberManager", "Remote Event not found")
        return false
    end
    
    Debug.info("BomberManager", "Spawning bomber at airport: " .. airport.Name)
    remote:FireServer("VSpawn", { airport, "Bomber", 2 })
    
    task.wait(2)
    
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
    
    local occupant = BomberManager.getBomberOccupant(bomber)
    if occupant and occupant ~= "" and occupant ~= player.Name then
        Debug.warn("BomberManager", "Bomber occupied by: " .. occupant)
        return false
    end
    
    local seat = BomberManager.getBomberSeat(bomber)
    if not seat then
        Debug.warn("BomberManager", "No seat found in bomber")
        return false
    end
    
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
    
    task.wait(1)
    
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
