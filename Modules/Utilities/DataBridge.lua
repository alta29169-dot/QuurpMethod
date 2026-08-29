-- DataBridge.lua – Communicates with Python RL server

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
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
local PYTHON_URL = "http://localhost:5000"
local TIMEOUT = 5
local SEND_INTERVAL = 0.1  -- Send observation every 0.1s (10Hz)
local BOT_ID = nil
local isRunning = false
local loopConnection = nil

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
        return false
    end
    
    return response and response.StatusCode == 200
end

-- ==========================================
-- REQUEST ACTION ← Python
-- ==========================================
function DataBridge.requestAction()
    local observation = EnemyManager.getObservation()
    if not observation then
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
        return nil
    end
    
    local decoded = HttpService:JSONDecode(response.Body)
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
-- MAIN LOOP (Runs on Heartbeat)
-- ==========================================
local lastSendTime = 0

function DataBridge.loop()
    if not isRunning then return end
    
    local now = tick()
    if now - lastSendTime < SEND_INTERVAL then
        return
    end
    lastSendTime = now
    
    -- Only send if we're seated (in a plane)
    if not StateManager.get("seated") then
        return
    end
    
    DataBridge.sendObservation()
end

-- ==========================================
-- START (Called from Main)
-- ==========================================
function DataBridge.start()
    if isRunning then
        debugPrint("DataBridge already running")
        return
    end
    
    debugPrint("Starting DataBridge (sending every " .. SEND_INTERVAL .. "s)")
    isRunning = true
    
    loopConnection = RunService.Heartbeat:Connect(function()
        DataBridge.loop()
    end)
end

-- ==========================================
-- STOP
-- ==========================================
function DataBridge.stop()
    isRunning = false
    if loopConnection then
        loopConnection:Disconnect()
        loopConnection = nil
    end
    debugPrint("DataBridge stopped")
end

-- ==========================================
-- TEST CONNECTION (Single send)
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

return DataBridge
