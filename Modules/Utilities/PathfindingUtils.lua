-- PathfindingUtils.lua – qurp v3 (Fixed) I love Ashyyy
local PathfindingService = game:GetService("PathfindingService")

local PF = {}

PF.defaultOptions = {
    AgentRadius = 2,
    AgentHeight = 5,
    AgentCanJump = true,
    AgentCanClimb = true,
    AgentMaxSlope = 45,
    WaypointSpacing = 10,
}

local function getPathOptions(options)
    options = options or {}
    return {
        AgentRadius = options.AgentRadius or PF.defaultOptions.AgentRadius,
        AgentHeight = options.AgentHeight or PF.defaultOptions.AgentHeight,
        AgentCanJump = options.AgentCanJump ~= nil and options.AgentCanJump or PF.defaultOptions.AgentCanJump,
        AgentCanClimb = options.AgentCanClimb ~= nil and options.AgentCanClimb or PF.defaultOptions.AgentCanClimb,
        AgentMaxSlope = options.AgentMaxSlope or PF.defaultOptions.AgentMaxSlope,
        WaypointSpacing = options.WaypointSpacing or PF.defaultOptions.WaypointSpacing,
    }
end

function PF.moveTo(character, targetPos, options, abortCheck)
    if not character then return false end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid or humanoid.Health <= 0 then return false end
    
    local pathOptions = getPathOptions(options)
    local path = PathfindingService:CreatePath(pathOptions)
    
    local success, err = pcall(function()
        path:ComputeAsync(hrp.Position, targetPos)
    end)
    
    if not success or path.Status ~= Enum.PathStatus.Success then
        humanoid:MoveTo(targetPos)
        return true
    end
    
    local waypoints = path:GetWaypoints()
    
    for i, waypoint in ipairs(waypoints) do
        if abortCheck and abortCheck() then
            return false
        end
        
        -- Handle Jump actions
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end
        
        -- Handle Climb actions
        local isClimb = (waypoint.Action == Enum.PathWaypointAction.Custom and waypoint.Label and string.find(waypoint.Label, "Climb"))
        if isClimb then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        end
        
        -- Move towards waypoint
        humanoid:MoveTo(waypoint.Position)
        
        -- Yield until reached or timed out (8 second safety limit per waypoint)
        local moveFinished = false
        local connection
        
        connection = humanoid.MoveToFinished:Connect(function(reached)
            moveFinished = true
        end)
        
        local timeout = 0
        while not moveFinished and timeout < 8 do
            task.wait(0.1)
            timeout += 0.1
            
            if abortCheck and abortCheck() then
                connection:Disconnect()
                return false
            end
        end
        
        connection:Disconnect()
        
        -- Break early if stuck at a waypoint for longer than timeout limit
        if not moveFinished then
            print("[PathfindingUtils] Stuck at waypoint, recalculating...")
            return false
        end
    end
    
    return true
end

function PF.moveToWithRetry(character, targetPos, maxRetries, options, abortCheck)
    maxRetries = maxRetries or 3
    
    for attempt = 1, maxRetries do
        if abortCheck and abortCheck() then
            return false
        end
        
        local success = PF.moveTo(character, targetPos, options, abortCheck)
        if success then
            return true
        end
        
        task.wait(0.2)
    end
    
    return false
end

function PF.getPath(startPos, endPos, options)
    local pathOptions = getPathOptions(options)
    local path = PathfindingService:CreatePath(pathOptions)
    
    local success = pcall(function()
        path:ComputeAsync(startPos, endPos)
    end)
    
    if not success or path.Status ~= Enum.PathStatus.Success then
        return nil
    end
    
    return path:GetWaypoints()
end

function PF.pathExists(startPos, endPos, options)
    local pathOptions = getPathOptions(options)
    local path = PathfindingService:CreatePath(pathOptions)
    
    local success = pcall(function()
        path:ComputeAsync(startPos, endPos)
    end)
    
    return success and path.Status == Enum.PathStatus.Success
end

return PF
