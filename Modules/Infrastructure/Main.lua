-- Main.lua – Phase 1 (Test Version)
-- Goal: Prove respawn loop works before adding AutoSeater

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Debug = _G._Modules.Debug
local StateManager = _G._Modules.StateManager

-- ===== STATE =====
local isRunning = true

-- ==========================================
-- ON RESPAWN
-- ==========================================
local function onRespawn(char)
    -- Debounce
    if not StateManager:canRespawn() then
        Debug.warn("Main", "Duplicate respawn ignored")
        return
    end
    
    -- Increment generation
    local myGen = StateManager:nextGeneration()
    Debug.info("Main", "=== RESPAWN DETECTED (gen " .. myGen .. ") ===")
    
    -- Reset all states
    StateManager.resetAll()
    
    -- Wait for character to load
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local waitCount = 0
    while not hrp and waitCount < 50 do
        waitCount = waitCount + 1
        hrp = char:FindFirstChild("HumanoidRootPart")
        task.wait(0.1)
    end
    
    if hrp then
        Debug.info("Main", "Character loaded after " .. waitCount .. " checks")
        StateManager.set("characterLoaded", true)
        StateManager.set("isAlive", true)
    else
        Debug.warn("Main", "HRP never loaded")
        return
    end
    
    -- ===== PHASE 1: Just log that we would run AutoSeater =====
    Debug.info("Main", "✅ Respawn loop works! (AutoSeater would run now)")
    
    -- Print current state for debugging
    Debug.info("Main", "State: seated=" .. tostring(StateManager.get("seated")))
end

-- ==========================================
-- START
-- ==========================================
local function start()
    Debug.info("Main", "=== qurp v3 Engine Starting (Test Mode) ===")
    
    player.CharacterAdded:Connect(onRespawn)
    Debug.info("Main", "CharacterAdded connected")
    
    -- Handle initial spawn
    if player.Character then
        Debug.info("Main", "Initial character found — triggering respawn")
        task.spawn(onRespawn, player.Character)
    else
        Debug.info("Main", "No character yet — waiting for spawn")
    end
    
    -- Keep the script alive
    while isRunning do
        task.wait(1)
    end
end

-- ==========================================
-- MODULE EXPORT
-- ==========================================
return {
    start = start,
}
