-- FlightController.lua – Plane Movement Control | I just want to love

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")

local StateManager = _G._Modules.StateManager
local Debug = _G._Modules.Debug

local FlightController = {}

-- ==========================================
-- DEBUG CONFIG
-- ==========================================
local DEBUG_FLIGHT = true

-- ==========================================
-- CONFIG
-- ==========================================
local SPEED = 115
local MAX_TORQUE = 500000
local MAX_FORCE = 100000
local ARRIVAL_TOLERANCE = 5

local RESPONSIVENESS = {
    attack = 0.08,
    climb = 0.07,
    cruise = 0.05,
}

-- ==========================================
-- STATE
-- ==========================================
local targetPosition = nil
local currentMode = "cruise"
local isFlying = false
local lastUpdate = 0
local updateInterval = 0.1
local constraintsInitialized = false

-- ==========================================
-- DEBUG
-- ==========================================
local function debugPrint(...)
    if DEBUG_FLIGHT then
        print("[FlightController]", ...)
    end
end

-- ==========================================
-- SET HEADING (Handles both BodyGyro AND AlignOrientation)
-- ==========================================
local function setHeading(body, targetPos, lerpFactor)
    -- Look for either BodyGyro or AlignOrientation
    local gyro = body:FindFirstChild("BodyGyro") or body:FindFirstChild("AlignOrientation")
    if not gyro then
        debugPrint("No gyro constraint found")
        return
    end

    local dir = targetPos - body.Position
    if dir.Magnitude < 0.1 then return end

    local desired = CFrame.new(body.Position, targetPos)

    if gyro:IsA("BodyGyro") then
        gyro.CFrame = gyro.CFrame:Lerp(desired, math.clamp(lerpFactor or 0.10, 0, 1))
        gyro.D = 0.8
        gyro.MaxTorque = Vector3.new(MAX_TORQUE, MAX_TORQUE, MAX_TORQUE)
        debugPrint("BodyGyro updated")
    elseif gyro:IsA("AlignOrientation") then
        gyro.CFrame = desired
        gyro.Responsiveness = math.clamp((lerpFactor or 0.10) * 200, 1, 200)
        gyro.MaxTorque = math.huge
        debugPrint("AlignOrientation updated")
    end
end

-- ==========================================
-- SET SPEED (Handles both BodyVelocity AND LinearVelocity)
-- ==========================================
local function setSpeed(body, speed)
    local vel = body:FindFirstChild("BodyVelocity") or body:FindFirstChild("LinearVelocity")
    if not vel then
        debugPrint("No velocity constraint found")
        return
    end
    
    local moveDir = body.CFrame.LookVector * speed
    
    if vel:IsA("BodyVelocity") then
        vel.Velocity = moveDir
        vel.MaxForce = Vector3.new(MAX_FORCE, MAX_FORCE, MAX_FORCE)
        debugPrint("BodyVelocity updated")
    elseif vel:IsA("LinearVelocity") then
        vel.VectorVelocity = moveDir
        vel.MaxForce = MAX_FORCE
        debugPrint("LinearVelocity updated")
    end
end

-- ==========================================
-- CLEANUP LEGACY CONSTRAINTS
-- ==========================================
function FlightController.cleanupConstraints(body)
    if not body then return end
    
    -- Remove legacy BodyVelocity
    local bodyVel = body:FindFirstChild("BodyVelocity")
    if bodyVel then
        bodyVel:Destroy()
        debugPrint("Removed legacy BodyVelocity")
    end
    
    -- Remove legacy BodyGyro
    local bodyGyro = body:FindFirstChild("BodyGyro")
    if bodyGyro then
        bodyGyro:Destroy()
        debugPrint("Removed legacy BodyGyro")
    end
    
    -- Remove any existing LinearVelocity (we'll recreate)
    local linearVel = body:FindFirstChild("LinearVelocity")
    if linearVel then
        linearVel:Destroy()
        debugPrint("Removed existing LinearVelocity")
    end
    
    -- Remove any existing AlignOrientation (we'll recreate)
    local align = body:FindFirstChild("AlignOrientation")
    if align then
        align:Destroy()
        debugPrint("Removed existing AlignOrientation")
    end
end

-- ==========================================
-- INITIALIZE CONSTRAINTS (ONLY ONCE)
-- ==========================================
function FlightController.initializeConstraints()
    local plane = StateManager.get("targetVehicle")
    if not plane then
        debugPrint("No plane in StateManager")
        return false
    end
    
    local body = plane:FindFirstChild("MainBody")
    if not body then
        debugPrint("No MainBody found in plane")
        return false
    end
    
    -- Check if we already have our constraints
    local existingAlign = body:FindFirstChild("AlignOrientation")
    local existingVelocity = body:FindFirstChild("LinearVelocity")
    
    if existingAlign and existingVelocity then
        debugPrint("Constraints already initialized, skipping")
        return true
    end
    
    -- CLEANUP: Remove all existing constraints (only once)
    FlightController.cleanupConstraints(body)
    
    -- Create AlignOrientation
    debugPrint("Creating AlignOrientation...")
    local align = Instance.new("AlignOrientation")
    align.Name = "AlignOrientation"
    align.Parent = body
    
    local att0 = Instance.new("Attachment")
    att0.Name = "AlignOrientation_Att0"
    att0.Parent = body
    
    local att1 = Instance.new("Attachment")
    att1.Name = "AlignOrientation_Att1"
    att1.Parent = body
    
    align.Attachment0 = att0
    align.Attachment1 = att1
    align.CFrame = body.CFrame
    align.MaxTorque = math.huge
    align.Responsiveness = 50
    align.Enabled = true
    debugPrint("AlignOrientation created")
    
    -- Create LinearVelocity
    debugPrint("Creating LinearVelocity...")
    local velocity = Instance.new("LinearVelocity")
    velocity.Name = "LinearVelocity"
    velocity.Parent = body
    velocity.MaxForce = MAX_FORCE
    velocity.Enabled = true
    debugPrint("LinearVelocity created")
    
    constraintsInitialized = true
    return true
end

-- ==========================================
-- GET PLANE PARTS
-- ==========================================
function FlightController.getPlaneParts()
    local plane = StateManager.get("targetVehicle")
    if not plane then
        return nil
    end
    
    local body = plane:FindFirstChild("MainBody")
    if not body then
        return nil
    end
    
    -- Check for either type of constraint
    local align = body:FindFirstChild("AlignOrientation")
    local velocity = body:FindFirstChild("LinearVelocity")
    
    -- Also check for legacy constraints
    local gyro = body:FindFirstChild("BodyGyro")
    local bodyVel = body:FindFirstChild("BodyVelocity")
    
    if not align and not gyro then
        debugPrint("No orientation constraint found, initializing...")
        FlightController.initializeConstraints()
        align = body:FindFirstChild("AlignOrientation")
        if not align then
            return nil
        end
    end
    
    if not velocity and not bodyVel then
        debugPrint("No velocity constraint found, initializing...")
        FlightController.initializeConstraints()
        velocity = body:FindFirstChild("LinearVelocity")
        if not velocity then
            return nil
        end
    end
    
    return {
        plane = plane,
        body = body,
        align = align or gyro,
        velocity = velocity or bodyVel,
    }
end

-- ==========================================
-- SET TARGET
-- ==========================================
function FlightController.setTarget(position, mode)
    if not position then
        debugPrint("No target position provided")
        return false
    end
    
    targetPosition = position
    currentMode = mode or "cruise"
    isFlying = true
    lastUpdate = tick()
    
    local parts = FlightController.getPlaneParts()
    if not parts then
        debugPrint("Failed to get plane parts")
        isFlying = false
        return false
    end
    
    debugPrint(string.format("Target set to (%.0f, %.0f, %.0f) in %s mode", 
                position.X, position.Y, position.Z, currentMode))
    
    return true
end

-- ==========================================
-- UPDATE LOOP
-- ==========================================
function FlightController.update()
    if not isFlying then return end
    if not targetPosition then return end
    
    local now = tick()
    if now - lastUpdate < updateInterval then
        return
    end
    lastUpdate = now
    
    local parts = FlightController.getPlaneParts()
    if not parts then
        debugPrint("Lost plane parts, stopping")
        isFlying = false
        return
    end
    
    local body = parts.body
    local align = parts.align
    local velocity = parts.velocity
    
    if not body or not align or not velocity then
        debugPrint("Missing required parts, stopping")
        isFlying = false
        return
    end
    
    local currentPos = body.Position
    local direction = (targetPosition - currentPos)
    local distance = direction.Magnitude
    
    if distance < ARRIVAL_TOLERANCE then
        debugPrint(string.format("Arrived at target (%.1f studs)", distance))
        isFlying = false
        setSpeed(body, 0)
        return
    end
    
    -- Use the working script's approach
    local lerpFactor = 0.08  -- attack mode
    if currentMode == "cruise" then
        lerpFactor = 0.05
    elseif currentMode == "climb" then
        lerpFactor = 0.07
    end
    
    setHeading(body, targetPosition, lerpFactor)
    setSpeed(body, SPEED)
    
    if DEBUG_FLIGHT and math.floor(now) % 5 == 0 and math.floor(now) ~= math.floor(now - updateInterval) then
        debugPrint(string.format("Flying to target: %.0f studs away, mode: %s", distance, currentMode))
    end
end

-- ==========================================
-- STOP FLYING
-- ==========================================
function FlightController.stop()
    isFlying = false
    targetPosition = nil
    
    local parts = FlightController.getPlaneParts()
    if parts then
        setSpeed(parts.body, 0)
    end
    
    debugPrint("Stopped")
end

-- ==========================================
-- IS FLYING
-- ==========================================
function FlightController.isFlying()
    return isFlying
end

-- ==========================================
-- GET TARGET
-- ==========================================
function FlightController.getTarget()
    return targetPosition
end

-- ==========================================
-- GET CURRENT MODE
-- ==========================================
function FlightController.getMode()
    return currentMode
end

-- ==========================================
-- SET MODE
-- ==========================================
function FlightController.setMode(mode)
    if RESPONSIVENESS[mode] then
        currentMode = mode
        debugPrint("Mode set to:", mode)
        return true
    end
    return false
end

-- ==========================================
-- START FLIGHT LOOP
-- ==========================================
local heartbeatConnection = nil

function FlightController.start()
    if heartbeatConnection then
        debugPrint("Flight loop already running")
        return
    end
    
    debugPrint("Starting flight loop")
    
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        FlightController.update()
    end)
end

-- ==========================================
-- STOP FLIGHT LOOP
-- ==========================================
function FlightController.stopLoop()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
        debugPrint("Flight loop stopped")
    end
end

return FlightController
