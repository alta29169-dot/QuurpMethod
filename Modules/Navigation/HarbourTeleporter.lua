--[[
    HarbourTeleporter.lua – qurp v3
    Handles: Teleporting player to harbour
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Event = ReplicatedStorage:WaitForChild("Event")

-- ==========================================
-- TELEPORT TO HARBOUR
-- ==========================================
local function teleportToHarbour(myGen)
    print("[HarbourTeleporter] Teleporting to harbour...")
    Event:FireServer("Teleport", { "Harbour", "" })
    
    -- Wait for teleport to complete
    for i = 1, 20 do
        -- Use StateManager for generation check
        local StateManager = _G._Modules.StateManager
        if StateManager and myGen and StateManager.getGeneration() ~= myGen then
            return false
        end
        
        local char = player.Character
        if not char then return false end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        
        task.wait(0.1)
    end
    
    return true
end

return {
    teleportToHarbour = teleportToHarbour,
}
