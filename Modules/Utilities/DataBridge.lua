-- DataBridge.lua – Communicates with Python RL server

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local StateManager = _G._Modules.StateManager
local EnemyManager = _G._Modules.EnemyManager
local Debug = _G._Modules.Debug

local DataBridge = {}

-- ==========================================
-- DEBUG CONFIG
-- ==========================================
local DEBUG = true

local function debugPrint(...)
    if DEBUG then
        print("[DataBridge]", ...)
    end
end

-- ==========================================
-- CONFIG
-- ==========================================
local PYTHON_URL = "http://localhost:5000"  -- Termux localhost
local TIMEOUT = 5
local BOT_ID = nil

-- ==========================================
-- GET BOT ID
-- ==========================================
local function getBotId()
    if not BOT_ID then
        BOT_ID = player.Name
    end
    return BOT_ID
end

-- ==========================================
-- SEND OBSERVATION → Python
-- ==========================================
function DataBridge.sendObservation()
    local observation = EnemyManager.getObservation()
    if not observation then
        debugPrint("❌ Failed to get observation")
        return false
    end
    
    local data = {
        id = getBotId(),
        timestamp = tick(),
        observation = observation,
    }
    
    local json = HttpService:JSONEncode(data)
    
    if DEBUG then
        debugPrint(string.format("📤 Sending: Health: %.2f, EnemyDist: %.2f, Enemies: %d",
            observation.health or 0,
            observation.enemyDistance or 0,
            observation.enemiesInRange or 0
        ))
    end
    
    local success, response = pcall(function()
        return request({
            Url = PYTHON_URL .. "/observe",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["ngrok-skip-browser-warning"] = "true",
            },
            Body = json,
            Timeout = TIMEOUT,
        })
    end)
    
    if not success then
        debugPrint("❌ Failed to send observation (connection error)")
        return false
    end
    
    if response and response.StatusCode == 200 then
        debugPrint("✅ Observation sent")
        return true
    else
        debugPrint("❌ Server error:", response and response.StatusCode or "unknown")
        return false
    end
end

-- ==========================================
-- REQUEST ACTION ← Python
-- ==========================================
function DataBridge.requestAction()
    local observation = EnemyManager.getObservation()
    if not observation then
        debugPrint("❌ Failed to get observation for action")
        return nil
    end
    
    local data = {
        id = getBotId(),
        timestamp = tick(),
        observation = observation,
    }
    
    local json = HttpService:JSONEncode(data)
    
    local success, response = pcall(function()
        return request({
            Url = PYTHON_URL .. "/act",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["ngrok-skip-browser-warning"] = "true",
            },
            Body = json,
            Timeout = TIMEOUT,
        })
    end)
    
    if not success or not response or response.StatusCode ~= 200 then
        debugPrint("❌ Failed to get action")
        return nil
    end
    
    local decoded = HttpService:JSONDecode(response.Body)
    
    if DEBUG then
        debugPrint("📥 Action received")
    end
    
    return decoded.action
end

-- ==========================================
-- SEND REWARD → Python
-- ==========================================
function DataBridge.sendReward(reward, done)
    local data = {
        id = getBotId(),
        timestamp = tick(),
        reward = reward,
        done = done or false,
    }
    
    local json = HttpService:JSONEncode(data)
    
    if DEBUG then
        debugPrint(string.format("🎯 Reward: %.2f, Done: %s", reward, tostring(done)))
    end
    
    pcall(function()
        request({
            Url = PYTHON_URL .. "/reward",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["ngrok-skip-browser-warning"] = "true",
            },
            Body = json,
            Timeout = TIMEOUT,
        })
    end)
end

-- ==========================================
-- TEST CONNECTION
-- ==========================================
function DataBridge.testConnection()
    debugPrint("Testing connection to Python server...")
    debugPrint("URL:", PYTHON_URL)
    
    local success = DataBridge.sendObservation()
    
    if success then
        debugPrint("✅ Connection successful!")
    else
        debugPrint("❌ Connection failed. Is Python server running?")
        debugPrint("   Run: python3 server.py")
    end
    
    return success
end

-- ==========================================
-- START LOOP (For testing)
-- ==========================================
local testLoopRunning = false

function DataBridge.startTestLoop(interval)
    interval = interval or 2
    if testLoopRunning then
        debugPrint("Test loop already running")
        return
    end
    
    testLoopRunning = true
    debugPrint("Starting test loop (every " .. interval .. "s)")
    
    task.spawn(function()
        while testLoopRunning do
            DataBridge.sendObservation()
            task.wait(interval)
        end
    end)
end

function DataBridge.stopTestLoop()
    testLoopRunning = false
    debugPrint("Test loop stopped")
end

return DataBridge
