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
local isCut = false  -- NEW: Control cut state
local constraintsInitialized = false
local cutTimer = 0
local cutDuration = 0

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
    local gyro = body:FindFirstChild("BodyGyro") or body:FindFirstChild("AlignOrientation")
    if not gyro then
        return
    end

    local dir = targetPos - body.Position
    if dir.Magnitude < 0.1 then return end

    local desired = CFrame.new(body.Position, targetPos)

    if gyro:IsA("BodyGyro") then
        gyro.CFrame = gyro.CFrame:Lerp(desired, math.clamp(lerpFactor or 0.10, 0, 1))
        gyro.D = 0.8
        gyro.MaxTorque = Vector3.new(MAX_TORQUE, MAX_TORQUE, MAX_TORQUE)
    elseif gyro:IsA("AlignOrientation") then
        gyro.CFrame = desired
        gyro.Responsiveness = math.clamp((lerpFactor or 0.10) * 200, 1, 200)
        gyro.MaxTorque = math.huge
    end
end

-- ==========================================
-- SET SPEED (Handles both BodyVelocity AND LinearVelocity)
-- ==========================================
local function setSpeed(body, speed)
    local vel = body:FindFirstChild("BodyVelocity") or body:FindFirstChild("LinearVelocity")
    if not vel then
        return
    end
    
    local moveDir = body.CFrame.LookVector * speed
    
    if vel:IsA("BodyVelocity") then
        vel.Velocity = moveDir
        vel.MaxForce = Vector3.new(MAX_FORCE, MAX_FORCE, MAX_FORCE)
    elseif vel:IsA("LinearVelocity") then
        vel.VectorVelocity = moveDir
        vel.MaxForce = MAX_FORCE
    end
end

-- ==========================================
-- CUT CONTROL (Disable all constraints)
-- ==========================================
function FlightController.cutControl(duration)
    if not duration or duration <= 0 then
        debugPrint("Cut control (indefinite)")
        isCut = true
        cutDuration = 0
        return
    end
    
    debugPrint("Cut control for", duration, "seconds")
    isCut = true
    cutTimer = 0
    cutDuration = duration
    
    -- Disable constraints immediately
    local parts = FlightController.getPlaneParts()
    if parts then
        if parts.align then
            parts.align.Enabled = false
            debugPrint("AlignOrientation disabled")
        end
        if parts.velocity then
            parts.velocity.VectorVelocity = Vector3.new(0, 0, 0)
            parts.velocity.Enabled = false
            debugPrint("LinearVelocity disabled")
        end
    end
end

-- ==========================================
-- RESTORE CONTROL (Re-enable constraints)
-- ==========================================
function FlightController.restoreControl()
    if not isCut then return end
    
    debugPrint("Restoring control")
    isCut = false
    cutDuration = 0
    cutTimer = 0
    
    local parts = FlightController.getPlaneParts()
    if parts then
        if parts.align then
            parts.align.Enabled = true
            debugPrint("AlignOrientation enabled")
        end
        if parts.velocity then
            parts.velocity.Enabled = true
            debugPrint("LinearVelocity enabled")
        end
    end
end

-- ==========================================
-- IS CONTROL CUT?
-- ==========================================
function FlightController.isControlCut()
    return isCut
end

-- ==========================================
-- CHECK HEALTH (Called from heartbeat)
-- ==========================================
function FlightController.checkHealth()
    local health = StateManager.get("myHealth")
    
    -- If health is 0 or below and we're not already cut
    if health and health <= 0 and not isCut then
        debugPrint("⚠️ Plane destroyed (HP = " .. health .. ") - cutting control")
        FlightController.cutControl()  -- Indefinite cut
        StateManager.set("isPlaneAlive", false)
        return true
    end
    
    return false
end

-- ==========================================
-- CLEANUP LEGACY CONSTRAINTS
-- ==========================================
function FlightController.cleanupConstraints(body)
    if not body then return end
    
    local bodyVel = body:FindFirstChild("BodyVelocity")
    if bodyVel then
        bodyVel:Destroy()
        debugPrint("Removed legacy BodyVelocity")
    end
    
    local bodyGyro = body:FindFirstChild("BodyGyro")
    if bodyGyro then
        bodyGyro:Destroy()
        debugPrint("Removed legacy BodyGyro")
    end
    
    local linearVel = body:FindFirstChild("LinearVelocity")
    if linearVel then
        linearVel:Destroy()
        debugPrint("Removed existing LinearVelocity")
    end
    
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
        return false
    end
    
    local body = plane:FindFirstChild("MainBody")
    if not body then
        return false
    end
    
    local existingAlign = body:FindFirstChild("AlignOrientation")
    local existingVelocity = body:FindFirstChild("LinearVelocity")
    
    if existingAlign and existingVelocity then
        return true
    end
    
    FlightController.cleanupConstraints(body)
    
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
    
    local align = body:FindFirstChild("AlignOrientation")
    local velocity = body:FindFirstChild("LinearVelocity")
    local gyro = body:FindFirstChild("BodyGyro")
    local bodyVel = body:FindFirstChild("BodyVelocity")
    
    if not align and not gyro then
        FlightController.initializeConstraints()
        align = body:FindFirstChild("AlignOrientation")
        if not align then
            return nil
        end
    end
    
    if not velocity and not bodyVel then
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
        return false
    end
    
    -- If control is cut, don't allow new targets
    if isCut then
        debugPrint("Cannot set target - control is cut")
        return false
    end
    
    targetPosition = position
    currentMode = mode or "cruise"
    isFlying = true
    
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
-- UPDATE (Called every frame by Heartbeat)
-- ==========================================
function FlightController.update()
    -- If control is cut, handle duration
    if isCut then
        if cutDuration > 0 then
            cutTimer = cutTimer + 1/60  -- Approximate, since Heartbeat is ~60fps
            if cutTimer >= cutDuration then
                FlightController.restoreControl()
            end
        end
        return  -- Skip all control updates when cut
    end
    
    if not isFlying then return end
    if not targetPosition then return end
    
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
        setSpeed(body, 0)
        isFlying = false
        return
    end
    
    local lerpFactor = 0.08
    if currentMode == "cruise" then
        lerpFactor = 0.05
    elseif currentMode == "climb" then
        lerpFactor = 0.07
    end
    
    setHeading(body, targetPosition, lerpFactor)
    setSpeed(body, SPEED)
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
