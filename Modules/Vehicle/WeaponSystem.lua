-- WeaponSystem.lua – Pure Weapon Execution
-- No decisions, just executes commands from CombatBrain

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local StateManager = _G._Modules.StateManager
local Debug = _G._Modules.Debug

local WeaponSystem = {}

-- ==========================================
-- DEBUG CONFIG
-- ==========================================
local DEBUG_WEAPONS = true

local function debugPrint(...)
    if DEBUG_WEAPONS then
        print("[WeaponSystem]", ...)
    end
end

-- ==========================================
-- CONFIG
-- ==========================================
local RPG_COOLDOWN = 3
local RPG_SPEED = 225
local MG_SPEED = 600
local MG_MAX_RANGE = 1800  -- Based on 600 studs/sec projectile

-- ==========================================
-- STATE
-- ==========================================
local mgToggled = false
local lastRPGTime = 0
local remote = nil

-- ==========================================
-- GET REMOTE
-- ==========================================
local function getRemote()
    if not remote then
        remote = ReplicatedStorage:FindFirstChild("Event")
        if not remote then
            debugPrint("⚠️ Remote Event not found!")
        end
    end
    return remote
end

-- ==========================================
-- EQUIP TOOL (RPG)
-- ==========================================
function WeaponSystem.equipRPG()
    local character = player.Character
    if not character then
        debugPrint("No character to equip RPG")
        return false
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        debugPrint("No humanoid found")
        return false
    end
    
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then
        debugPrint("No backpack found")
        return false
    end
    
    local tool = backpack:FindFirstChild("RPG")
    if not tool then
        debugPrint("RPG tool not found in backpack")
        return false
    end
    
    humanoid:EquipTool(tool)
    debugPrint("RPG equipped")
    return true
end

-- ==========================================
-- FIRE MG (Toggle)
-- ==========================================
function WeaponSystem.setMGToggle(enabled)
    local remote = getRemote()
    if not remote then return false end
    
    -- Check ammo before enabling
    if enabled then
        local ammo = StateManager.get("myAmmo") or 0
        if ammo <= 0 then
            debugPrint("⚠️ No ammo to fire MG")
            return false
        end
    end
    
    mgToggled = enabled
    remote:FireServer("shoot", { enabled })
    debugPrint(string.format("MG %s", enabled and "ON" or "OFF"))
    return true
end

-- ==========================================
-- FIRE RPG (Single Shot)
-- ==========================================
function WeaponSystem.fireRPG(targetPosition)
    if not targetPosition then
        debugPrint("No target position provided")
        return false
    end
    
    -- Check cooldown
    local now = tick()
    if now - lastRPGTime < RPG_COOLDOWN then
        debugPrint(string.format("⚠️ RPG on cooldown (%.1fs remaining)", 
                    RPG_COOLDOWN - (now - lastRPGTime)))
        return false
    end
    
    -- Ensure RPG is equipped
    WeaponSystem.equipRPG()
    
    -- Fire
    local remote = getRemote()
    if not remote then return false end
    
    remote:FireServer("fireRPG", { targetPosition })
    lastRPGTime = now
    
    debugPrint(string.format("🔥 RPG fired at (%.0f, %.0f, %.0f)", 
                targetPosition.X, targetPosition.Y, targetPosition.Z))
    return true
end

-- ==========================================
-- CHECK IF MG CAN FIRE
-- ==========================================
function WeaponSystem.canFireMG()
    -- Check ammo
    local ammo = StateManager.get("myAmmo") or 0
    if ammo <= 0 then
        return false
    end
    
    -- Check if MG is toggled on
    if not mgToggled then
        return false
    end
    
    return true
end

-- ==========================================
-- CHECK IF RPG CAN FIRE
-- ==========================================
function WeaponSystem.canFireRPG()
    -- Check cooldown
    local now = tick()
    if now - lastRPGTime < RPG_COOLDOWN then
        return false
    end
    
    return true
end

-- ==========================================
-- GET MG STATUS
-- ==========================================
function WeaponSystem.getMGStatus()
    return {
        toggled = mgToggled,
        ammo = StateManager.get("myAmmo") or 0,
        canFire = WeaponSystem.canFireMG(),
        maxRange = MG_MAX_RANGE,
        speed = MG_SPEED,
    }
end

-- ==========================================
-- GET RPG STATUS
-- ==========================================
function WeaponSystem.getRPGStatus()
    local now = tick()
    local cooldownRemaining = math.max(0, RPG_COOLDOWN - (now - lastRPGTime))
    
    return {
        cooldown = cooldownRemaining,
        ready = cooldownRemaining <= 0,
        maxRange = 9999,  -- RPG has no range limit? or very far
        speed = RPG_SPEED,
    }
end

-- ==========================================
-- CHECK IF TARGET IS IN MG ARC
-- ==========================================
function WeaponSystem.isInMGFiringArc(targetPosition, angleThreshold)
    angleThreshold = angleThreshold or 15  -- Degrees from center
    
    local plane = StateManager.get("targetVehicle")
    if not plane then
        return false
    end
    
    local mainBody = plane:FindFirstChild("MainBody")
    if not mainBody then
        return false
    end
    
    local forward = mainBody.CFrame.LookVector
    local toTarget = (targetPosition - mainBody.Position).Unit
    
    local angle = math.deg(math.acos(forward:Dot(toTarget)))
    
    return angle < angleThreshold
end

-- ==========================================
-- CHECK LINE OF SIGHT (RPG)
-- ==========================================
function WeaponSystem.hasLineOfSight(targetPosition)
    local plane = StateManager.get("targetVehicle")
    if not plane then return false end
    
    local mainBody = plane:FindFirstChild("MainBody")
    if not mainBody then return false end
    
    local origin = mainBody.Position
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = { plane, player.Character }
    
    local result = workspace:Raycast(origin, (targetPosition - origin).Unit * 2200, rayParams)
    
    if not result then
        return true  -- Nothing blocking
    end
    
    -- Check if we hit the target or something close to it
    local hitDist = (result.Position - origin).Magnitude
    local targetDist = (targetPosition - origin).Magnitude
    
    return hitDist >= targetDist - 10  -- Allow small margin
end

-- ==========================================
-- STOP ALL WEAPONS (On respawn/death)
-- ==========================================
function WeaponSystem.stopAll()
    if mgToggled then
        WeaponSystem.setMGToggle(false)
    end
    debugPrint("All weapons stopped")
end

-- ==========================================
-- UPDATE AMMO STATE (Called by BomberManager tracking)
-- ==========================================
function WeaponSystem.updateAmmo()
    -- Ammo is already tracked in StateManager by BomberManager
    -- This just logs if ammo is low
    local ammo = StateManager.get("myAmmo") or 0
    if ammo <= 10 and ammo > 0 then
        debugPrint(string.format("⚠️ Low ammo: %d", ammo))
    end
    return ammo
end

return WeaponSystem
