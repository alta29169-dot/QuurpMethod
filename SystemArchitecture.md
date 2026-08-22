# System Architecture – qurp v3

## Overview
qurp v3 is a modular combat bot designed for NW. It uses a heartbeat-driven architecture with state management for reliability.
   
## Module Hierarchy
BootLoader.lua
↓
Main.lua (Orchestrator)
├── StateManager.lua (State)
├── Debug.lua (Logging)
├── DockLocator.lua (Dock discovery)
├── HarbourTeleporter.lua (Teleport to harbour)
├── AirportManager.lua (Airport cache & nearest)
├── PathfindingUtils.lua (Navigation)
├── BomberManager.lua (Vehicle operations)
└── AutoSeater.lua (Movement & seating)


## Execution Flow
1. BootLoader loads all modules in order (MODULE_NAMES array)
2. Main.start() called
3. CharacterAdded:Connect(onRespawn)
4. onRespawn:
   - Debounce (StateManager:canRespawn)
   - Increment generation (StateManager:nextGeneration)
   - Wait for HRP
   - HarbourTeleporter.teleportToHarbour
   - AirportManager.cacheAirports
   - BomberManager.updatePlaneState
   - Start heartbeat loop (once, _G._heartbeatRunning flag)
5. Heartbeat loop (every 1.5s):
   - BomberManager.updatePlaneState()
   - If no plane → walk to airport → spawn
   - If plane but not seated → walk to bomber → sit
   - If seated → ready for combat (TODO)

## Module Dependencies
- Main depends on: StateManager, Debug, DockLocator, HarbourTeleporter, AirportManager, PathfindingUtils, BomberManager, AutoSeater
- BomberManager depends on: StateManager, Debug
- AutoSeater depends on: StateManager, AirportManager, BomberManager, Debug, PathfindingUtils
- AirportManager depends on: StateManager, DockLocator
- All other modules are independent

## Key Design Decisions
- Single source of truth: StateManager holds all state
- Self-correcting: Heartbeat re-evaluates conditions every cycle
- Generation safety: Each respawn increments generation to prevent stale operations
- Persistent vehicles: Bombers persist through respawns, reused when possible
- Stolen vehicle detection: Occupant check handles theft

## File Structure
QuurpMethod/
└── Modules/
├── Infrastructure/
│ └── Main.lua
├── Navigation/
│ ├── DockLocator.lua
│ ├── HarbourTeleporter.lua
│ └── AirportManager.lua
├── Vehicle/
│ ├── AutoSeater.lua
│ └── BomberManager.lua
└── Utilities/
├── Debug.lua
├── StateManager.lua
└── PathfindingUtils.lua

## Known Working Features
- [x] Module loading
- [x] State management
- [x] Respawn detection
- [x] Harbour teleport
- [x] Airport caching
- [x] Pathfinding with truss climbing
- [x] Bomber spawning
- [x] Bomber finding (by Owner)
- [x] Occupant detection
- [x] Seating
- [x] Self-correction

## TODO
- [ ] Combat logic (flying to enemies)
- [ ] Weapon systems
- [ ] Retreat/healing
- [ ] Enemy detection

