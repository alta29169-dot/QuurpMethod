-- BomberManager.lua – Vehicle Operations | I just wanted you to love me back

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StateManager = _G._Modules.StateManager
local Debug = _G._Modules.Debug

local BomberManager = {}

-- ==========================================
-- STATE
-- ==========================================
local trackingConnection = nil
local myPlaneData = {}

-- ==========================================
-- DEBUG
-- ==========================================
local function debugPrint(...)
    print("[BomberManager]", ...)
end

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
-- GET PLANE DATA
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
    if ammo then
        print("Ammo parent name:", ammo.Parent and ammo.Parent.Name or "nil")
    emd
    local fuel = plane:FindFirstChild("Fuel")
    local team = plane:FindFirstChild("Team")
    
    local position = mainBody.Position
    
    return {
        instance = plane,
        type = plane.Name,
        position = position,
        altitude = position.Y,
        mainBody = mainBody,
        velocity = mainBody.AssemblyLinearVelocity or Vector3.new(0,0,0),
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
-- UPDATE OUR PLANE STATE (Fast - Every Frame)
-- ==========================================
function BomberManager.updateOurPlane()
    local myBomber = BomberManager.findMyBomber()
    
    if myBomber then
        local data = BomberManager.getPlaneData(myBomber)
        if data then
            -- Update StateManager with fresh data
            StateManager.set("hasPlane", true)
            StateManager.set("targetVehicle", myBomber)
            StateManager.set("isPlaneAlive", data.isAlive)
            StateManager.set("myHealth", data.health)
            StateManager.set("myAmmo", data.ammo)
            StateManager.set("myFuel", data.fuel)
            
            -- Check if we're seated
            local inBomber = BomberManager.isUsInBomber(myBomber)
            StateManager.set("seated", inBomber)

            -- HEALTH CHECK: If health is 0, cut control
            if data.health <= 0 and data.isAlive == false then
                local FlightController = _G._Modules.FlightController
                if FlightController then
                    FlightController.cutControl()
                    debugPrint("⚠️ Plane destroyed - control cut")
                end
            end
            
            myPlaneData = data
        end
    else
        -- No plane found
        StateManager.set("hasPlane", false)
        StateManager.set("targetVehicle", nil)
        StateManager.set("isPlaneAlive", false)
        StateManager.set("seated", false)
        StateManager.set("myHealth", 0)
        StateManager.set("myAmmo", 0)
        StateManager.set("myFuel", 0)
        myPlaneData = {}
    end
end

-- ==========================================
-- START FAST TRACKING (Called from Main)
-- ==========================================
function BomberManager.startTracking()
    if trackingConnection then
        return
    end
    
    debugPrint("Starting fast plane tracking (every frame)")
    
    trackingConnection = RunService.Heartbeat:Connect(function()
        BomberManager.updateOurPlane()
    end)
end

-- ==========================================
-- STOP TRACKING
-- ==========================================
function BomberManager.stopTracking()
    if trackingConnection then
        trackingConnection:Disconnect()
        trackingConnection = nil
        debugPrint("Plane tracking stopped")
    end
end

-- ==========================================
-- GET OUR PLANE DATA (Fresh)
-- ==========================================
function BomberManager.getOurPlaneData()
    return myPlaneData
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
