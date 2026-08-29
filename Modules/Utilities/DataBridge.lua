-- DataBridge.lua – Ultra-low latency WebSocket Client for Roblox Executors

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local StateManager = _G._Modules.StateManager
local EnemyManager = _G._Modules.EnemyManager

local DataBridge = {}

-- ==========================================
-- CONFIG
-- ==========================================
local DEBUG = true
local WS_URL = "ws://127.0.0.1:5000/ws"
local SEND_INTERVAL = 0.05 -- 20 Hz transmission rate

local socket = nil
local isRunning = false
local lastSendTime = 0
local latestAction = nil

local function debugPrint(...)
    if DEBUG then
        print("[DataBridge-WS]", ...)
    end
end

-- ==========================================
-- WEBSOCKET CONNECTION
-- ==========================================
function DataBridge.connect()
    if socket then
        pcall(function() socket:Close() end)
    end
    
    debugPrint("Connecting to WebSocket server at " .. WS_URL .. "...")
    local success, ws = pcall(function()
        return WebSocket.connect(WS_URL)
    end)
    
    if not success or not ws then
        debugPrint("❌ WebSocket connection failed. Is the Python server running?")
        return false
    end
    
    socket = ws
    
    socket.OnMessage:Connect(function(msg)
        local successDecode, decoded = pcall(function()
            return HttpService:JSONDecode(msg)
        end)
        if successDecode and decoded and decoded.action then
            latestAction = decoded.action
        end
    end)
    
    socket.OnClose:Connect(function()
        debugPrint("⚠️ WebSocket connection closed.")
        socket = nil
        isRunning = false
    end)
    
    debugPrint("✅ WebSocket connected successfully!")
    return true
end

function DataBridge.getAction()
    return latestAction
end

-- ==========================================
-- MAIN LOOP (Heartbeat Stream)
-- ==========================================
local function loop()
    if not isRunning or not socket then return end
    
    local now = tick()
    if now - lastSendTime < SEND_INTERVAL then
        return
    end
    lastSendTime = now
    
    -- Only stream data if the player is actively seated in a vehicle
    if not StateManager.get("seated") then
        return
    end
    
    local observation = EnemyManager.getObservation()
    if not observation then
        return
    end
    
    local payload = {
        id = player.Name,
        timestamp = now,
        observation = observation,
        reward = StateManager.get("currentReward") or 0,
        done = false
    }
    
    pcall(function()
        socket:Send(HttpService:JSONEncode(payload))
    end)
end

-- ==========================================
-- CONTROLS
-- ==========================================
function DataBridge.start()
    if isRunning then
        debugPrint("DataBridge already running")
        return
    end
    
    if not socket then
        if not DataBridge.connect() then
            return
        end
    end
    
    debugPrint("Starting DataBridge WebSocket loop...")
    isRunning = true
    
    RunService.Heartbeat:Connect(loop)
end

function DataBridge.stop()
    isRunning = false
    if socket then
        pcall(function() socket:Close() end)
        socket = nil
    end
    debugPrint("DataBridge stopped")
end

return DataBridge
