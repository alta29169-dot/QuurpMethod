-- ============================================================
--  BootLoader.lua  (QuurpMethod – Pilot Only)
--  Fetches modules from GitHub, retries on failure, boots pilot.
-- ============================================================

-- ---------- CONFIG ----------
local GITHUB_USER   = "alta29169-dot"
local GITHUB_REPO   = "QuurpMethod"
local GITHUB_BRANCH = "main"
local MODULES_PATH  = "Modules"

-- Module loading order by category (ORDER MATTERS - Utilities first)
-- Categories: Utilities → Vehicle → Navigation → Infrastructure (simplified for Phase 1)
local MODULE_CATEGORIES = {
    -- Core utilities (must load first)
    Utilities = {
        "Debug",              -- Centralized logging (load FIRST)
        "SessionManager",     -- Player session management
    },
    -- Vehicle-related modules
    Vehicle = {
        "AutoSeater",         -- Vehicle seating logic
        "VehicleSpawner",     -- Vehicle spawning
        "VehicleSeeder",      -- Vehicle seeding
    },
    -- Navigation & pathfinding
    Navigation = {
        "PathfindingUtils",   -- Pathfinding helpers
        "PathWalker",         -- Path following
    },
    -- Infrastructure (loads last)
    Infrastructure = {
        "Main",               -- Entry point & lifecycle
    },
}

-- Flatten categories into ordered list
local MODULE_NAMES = {}
local categoryOrder = {"Utilities", "Vehicle", "Navigation", "Infrastructure"}

for _, categoryName in ipairs(categoryOrder) do
    local category = MODULE_CATEGORIES[categoryName]
    if category then
        for _, name in ipairs(category) do
            table.insert(MODULE_NAMES, name)
        end
    end
end

-- ---------- LOADER ----------
local RAW_BASE = string.format(
    "https://raw.githubusercontent.com/%s/%s/refs/heads/%s/%s/",
    GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH, MODULES_PATH
)

_G._Modules = _G._Modules or {}

local function fetchModule(name, retries)
    retries = retries or 3
    
    -- Determine category for path construction
    local category = nil
    for catName, modules in pairs(MODULE_CATEGORIES) do
        for _, modName in ipairs(modules) do
            if modName == name then
                category = catName
                break
            end
        end
        if category then break end
    end
    
    -- Build URL with category subfolder
    local url = string.format(
        "https://raw.githubusercontent.com/%s/%s/refs/heads/%s/%s/%s/%s.lua",
        GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH, MODULES_PATH, category, name
    )
    print("[Boot] Fetching:", name, "from", category)

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

-- CRITICAL: Load Debug FIRST before any other module tries to use it
local debugLoaded = false
for i, name in ipairs(MODULE_NAMES) do
    if name == "Debug" then
        local success, err = pcall(fetchModule, name, 3)
        if not success then
            error("[Boot] FATAL: Could not load Debug module: " .. tostring(err))
        end
        debugLoaded = true
        print("[Boot] ✓ Debug loaded successfully")
        break
    end
end

if not debugLoaded then
    error("[Boot] FATAL: Debug module not found in module list!")
end

-- Load remaining modules
for i, name in ipairs(MODULE_NAMES) do
    if name == "Debug" then continue end -- Skip Debug, already loaded
    
    local success, err = pcall(fetchModule, name, 3)
    if not success then
        warn("[Boot] FATAL: " .. tostring(err))
        return
    end
end

print("[Boot] All modules loaded. Starting engine...")

-- Run the Main module
if _G._Modules.Main and _G._Modules.Main.start then
    _G._Modules.Main.start()
else
    warn("[Boot] Main.start not found!")
end
