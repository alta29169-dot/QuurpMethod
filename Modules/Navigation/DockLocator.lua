--[[
    DockLocator.lua – qurp v3
    Handles: Finding the correct dock based on team
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- ==========================================
-- GET DOCK
-- ==========================================
local function getDock()
    if not player.Team then return nil end
    
    if player.Team.Name == "Japan" then
        return Workspace:FindFirstChild("JapanDock")
    elseif player.Team.Name == "USA" then
        return Workspace:FindFirstChild("USDock")
    end
    
    return nil
end

return {
    getDock = getDock,
}
