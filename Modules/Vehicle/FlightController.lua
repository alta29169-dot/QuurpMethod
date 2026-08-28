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

-- ==========================================
-- DEBUG
-- ==========================================
local function debugPrint(...)
    if DEBUG_FLIGHT then
        print("[FlightController]", ...)
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
-- GET PLANE PARTS (With Cleanup)
-- ==========================================
function FlightController.getPlaneParts()
    local plane = StateManager.get("targetVehicle")
    if not plane then
        debugPrint("No plane in StateManager")
        return nil
    end
    
    local body = plane:FindFirstChild("MainBody")
    if not body then
        debugPrint("No MainBody found in plane")
        return nil
    end
    
    -- CLEANUP: Remove all existing constraints first
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
    align.MaxTorque = MAX_TORQUE
    align.Responsiveness = RESPONSIVENESS.cruise
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
    
    return {
        plane = plane,
        body = body,
        align = align,
        velocity = velocity,
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
    
    local resp = RESPONSIVENESS[currentMode] or RESPONSIVENESS.cruise
    if parts.align then
        parts.align.Responsiveness = resp
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
        velocity.VectorVelocity = Vector3.new(0, 0, 0)
        return
    end
    
    local dirUnit = direction.Unit
    
    -- Set rotation target
    local targetCFrame = CFrame.lookAt(currentPos, currentPos + dirUnit)
    align.CFrame = targetCFrame
    
    -- Move forward at fixed speed
    local forward = body.CFrame.LookVector
    velocity.VectorVelocity = forward * SPEED
    
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
    if parts and parts.velocity then
        parts.velocity.VectorVelocity = Vector3.new(0, 0, 0)
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
        local parts = FlightController.getPlaneParts()
        if parts and parts.align then
            parts.align.Responsiveness = RESPONSIVENESS[mode]
        end
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
