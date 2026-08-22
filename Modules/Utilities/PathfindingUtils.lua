-- PathfindingUtils.lua – Fixed Waypoint Following Love Love All The Way

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
        -- Check abort condition
        if abortCheck and abortCheck() then
            return false
        end
        
        -- Move to waypoint
        humanoid:MoveTo(waypoint.Position)
        if i == lastWaypointIndex then
            humanoid:MoveTo(waypoint.Position) -- Double call for final destination
        end
        
        -- === FIXED: Better waypoint detection ===
        local startPos = hrp.Position
        local dist = (startPos - waypoint.Position).Magnitude
        local stuckCheck = 0
        local lastDist = dist
        local stuckCount = 0
        
        -- If we're already close enough, skip this waypoint
        if dist < 4 then
            continue
        end
        
        -- Wait for waypoint with better logic
        while dist > 4 do
            task.wait(0.2)
            
            -- Check abort
            if abortCheck and abortCheck() then
                return false
            end
            
            -- Update distance
            local currentPos = hrp.Position
            dist = (currentPos - waypoint.Position).Magnitude
            
            -- Check if we're moving toward the waypoint
            local progress = (startPos - currentPos).Magnitude
            if progress > 2 then
                -- We've moved at least 2 studs from start position
                -- Update start position for next check
                startPos = currentPos
                stuckCount = 0
            else
                -- Not moving much
                stuckCount = stuckCount + 1
                if stuckCount > 15 then -- Stuck for 3 seconds (15 * 0.2)
                    print("[PathfindingUtils] Stuck, skipping to next waypoint")
                    break
                end
            end
            
            -- Safety timeout: if we've been trying for too long
            if stuckCount > 30 then
                print("[PathfindingUtils] Timeout, skipping waypoint")
                break
            end
        end
        
        -- If we broke out early due to stuck/timeout, move to next waypoint
    end
    
    -- Final check: Are we at the target?
    local finalDist = (hrp.Position - targetPos).Magnitude
    if finalDist > 10 then
        -- Try direct move if still far
        humanoid:MoveTo(targetPos)
        humanoid:MoveTo(targetPos)
        task.wait(2)
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
