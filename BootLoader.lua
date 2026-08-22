-- ============================================================
--  BootLoader.lua  (Phase 1 — Only existing modules) I love you
-- ============================================================

local GITHUB_USER   = "alta29169-dot"
local GITHUB_REPO   = "QuurpMethod"
local GITHUB_BRANCH = "main"
local MODULES_PATH  = "Modules"

-- ---------- ONLY MODULES THAT EXIST ----------
local MODULE_NAMES = {
    "Debug",
    "StateManager",
    "DockLocator",
    "HarbourTeleporter",
    "AirportManager",
    "PathfindingUtils",
    "BomberManager",
    "AutoSeater",
    "Main",
}

-- ---------- LOADER ----------
local RAW_BASE = string.format(
    "https://raw.githubusercontent.com/%s/%s/refs/heads/%s/%s/",
    GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH, MODULES_PATH
)

_G._Modules = _G._Modules or {}

local function fetchModule(name, retries)
    retries = retries or 3
    
    local folder = "Utilities"
    if name == "Main" then
        folder = "Infrastructure"
    elseif name == "DockLocator" or name == "HarbourTeleporter" or name == "AirportManager" then
        folder = "Navigation"
    elseif name == "AutoSeater" or name == "BomberManager" then
        folder = "Vehicle"
    elseif name == "PathfindingUtils" then  -- ADD THIS
        folder = "Utilities"
    end
    
    local url = string.format(
        "https://raw.githubusercontent.com/%s/%s/refs/heads/%s/%s/%s/%s.lua",
        GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH, MODULES_PATH, folder, name
    )
    print("[Boot] Fetching:", name, "from", folder)

    for attempt = 1, retries do
        local ok, result = pcall(function()
            return request({ Url = url, Method = "GET" })
        end)

        if ok and result and result.StatusCode == 200 then
            local fn, err = loadstring(result.Body, name)
            if not fn then
                error("[Boot] Compile error in " .. name .. ": " .. tostring(err))
            end

            local mod = fn()
            if type(mod) ~= "table" then
                error("[Boot] " .. name .. " did not return a table.")
            end

            _G._Modules[name] = mod
            print("[Boot] Loaded:", name)
            return
        else
            if attempt < retries then
                warn("[Boot] Attempt " .. attempt .. " failed for " .. name .. ", retrying...")
                task.wait(1)
            else
                error("[Boot] Failed to load " .. name .. " after " .. retries .. " attempts.")
            end
        end
    end
end

-- ---------- MAIN ----------
print("[Boot] Loading modules...")

for _, name in ipairs(MODULE_NAMES) do
    local success, err = pcall(fetchModule, name, 3)
    if not success then
        warn("[Boot] FATAL: " .. tostring(err))
        return
    end
end

print("[Boot] All modules loaded. Starting engine...")

if _G._Modules.Main and _G._Modules.Main.start then
    _G._Modules.Main.start()
else
    warn("[Boot] Main.start not found!")
end
