-- PathfindingUtils.lua – qurp v3 (Fixed)
-- No dependency on StateManager needed (keep it pure)

local PathfindingService = game:GetService("PathfindingService")

local PF = {}

-- ===== CONFIG =====
PF.defaultOptions = {
    AgentRadius = 2,
    AgentHeight = 5,
    AgentCanJump = true,
    AgentMaxSlope = 45,
    WaypointSpacing = 10,
}

-- ==========================================
-- MOVE TO POSITION USING PATHFINDING
-- ==========================================
function PF.moveTo(character, targetPos, options, abortCheck)
    if not character then return false end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return false end
    
    options = options or PF.defaultOptions
    
    -- Step 1: Try pathfinding
    local path = PathfindingService:CreatePath(options)
    local success, err = pcall(function()
        path:ComputeAsync(hrp.Position, targetPos)
    end)
    
    -- Step 2: Check if path is valid
    if not success or path.Status ~= Enum.PathStatus.Success then
        print("[PathfindingUtils] Path failed — using direct move")
        humanoid:MoveTo(targetPos)
        humanoid:MoveTo(targetPos) -- Roblox quirk: call twice
        return true
    end
    
    -- Step 3: Follow waypoints
    local waypoints = path:GetWaypoints()
    local lastWaypointIndex = #waypoints
    
    for i, waypoint in ipairs(waypoints) do
        -- Check abort condition (e.g., death, respawn, gen mismatch)
        if abortCheck and abortCheck() then
            return false
        end
        
        -- Move to waypoint
        humanoid:MoveTo(waypoint.Position)
        if i == lastWaypointIndex then
            humanoid:MoveTo(waypoint.Position) -- Double call for final destination
        end
        
        -- Wait until we reach the waypoint or get interrupted
        local reached = false
        local timeout = 0
        local dist = math.huge
        
        while not reached and timeout < 50 do
            timeout = timeout + 1
            task.wait(0.1)
            
            -- Check if we're close enough
            local currentPos = hrp.Position
            dist = (currentPos - waypoint.Position).Magnitude
            
            -- For last waypoint, use 3 studs tolerance
            if dist < 3 then
                reached = true
                break
            end
            
            -- Check abort condition mid-way
            if abortCheck and abortCheck() then
                return false
            end
        end
    end
    
    return true
end

-- ==========================================
-- MOVE TO POSITION WITH RETRY
-- ==========================================
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
        
        print("[PathfindingUtils] Retry", attempt, "failed — retrying...")
        task.wait(0.5)
    end
    
    return false
end

-- ==========================================
-- GET PATH (for debugging / visual)
-- ==========================================
function PF.getPath(startPos, endPos, options)
    options = options or PF.defaultOptions
    local path = PathfindingService:CreatePath(options)
    local success, err = pcall(function()
        path:ComputeAsync(startPos, endPos)
    end)
    
    if not success or path.Status ~= Enum.PathStatus.Success then
        return nil
    end
    
    return path:GetWaypoints()
end

-- ==========================================
-- CHECK IF PATH EXISTS
-- ==========================================
function PF.pathExists(startPos, endPos, options)
    options = options or PF.defaultOptions
    local path = PathfindingService:CreatePath(options)
    local success, err = pcall(function()
        path:ComputeAsync(startPos, endPos)
    end)
    
    return success and path.Status == Enum.PathStatus.Success
end

return PF
