-- Debug.lua
-- Centralized logging system for all modules

local Debug = {}

-- Set to false to silence all logs (production mode)
Debug.DEBUG_ENABLED = false

-- Log levels
Debug.LOG_LEVELS = {
    INFO = 1,
    WARN = 2,
    ERROR = 3
}

-- Current log level (show all by default when debug is enabled)
Debug.CURRENT_LEVEL = Debug.LOG_LEVELS.INFO

function Debug.log(moduleName, message, level)
    if not Debug.DEBUG_ENABLED then
        return
    end
    
    level = level or Debug.LOG_LEVELS.INFO
    if level < Debug.CURRENT_LEVEL then
        return
    end
    
    local prefix = string.format("[%s]", moduleName or "Unknown")
    local timestamp = os.date("%H:%M:%S")
    
    if level == Debug.LOG_LEVELS.WARN then
        print(string.format("%s [WARN] %s: %s", timestamp, prefix, message))
    elseif level == Debug.LOG_LEVELS.ERROR then
        warn(string.format("%s [ERROR] %s: %s", timestamp, prefix, message))
    else
        print(string.format("%s %s: %s", timestamp, prefix, message))
    end
end

function Debug.info(moduleName, message)
    Debug.log(moduleName, message, Debug.LOG_LEVELS.INFO)
end

function Debug.warn(moduleName, message)
    Debug.log(moduleName, message, Debug.LOG_LEVELS.WARN)
end

function Debug.error(moduleName, message)
    Debug.log(moduleName, message, Debug.LOG_LEVELS.ERROR)
end

return Debug
