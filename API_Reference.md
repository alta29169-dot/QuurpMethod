# API Reference – qurp v3

## StateManager
### State Variables
| Variable | Type | Description |
|----------|------|-------------|
| `seated` | boolean | Is the player seated in a bomber? |
| `hasPlane` | boolean | Does the player own a bomber? |
| `targetVehicle` | Instance | Reference to the player's bomber |
| `isPlaneAlive` | boolean | Is the bomber still alive? |
| `generation` | number | Current respawn generation |
| `isRunning` | boolean | Is the bot running? |

### Methods
| Method | Description |
|--------|-------------|
| `get(key)` | Get a state value |
| `set(key, value)` | Set a state value |
| `resetAll()` | Reset all state (except generation) |
| `nextGeneration()` | Increment and return generation |

## BomberManager
### Methods
| Method | Description | Returns |
|--------|-------------|---------|
| `findMyBomber()` | Find owned bomber in Workspace | Instance or nil |
| `spawnBomber(airport)` | Spawn bomber at airport | boolean |
| `sitInBomber(bomber)` | Sit in bomber seat | boolean |
| `updatePlaneState()` | Refresh state from Workspace | bomber or nil |

## AutoSeater
### Methods
| Method | Description | Returns |
|--------|-------------|---------|
| `walkToPosition(pos, tolerance)` | Walk to position with pathfinding | boolean |
| `walkToNearestAirport()` | Walk to nearest airport | boolean |
| `walkToBomber(bomber)` | Walk to owned bomber | boolean |
| `trySitInBomber(bomber)` | Walk to and sit in bomber | boolean |

## AirportManager
### Methods
| Method | Description | Returns |
|--------|-------------|---------|
| `cacheAirports(gen)` | Cache all airports in StateManager | boolean |
| `getNearestAirport(character)` | Get nearest airport from cache | Instance or nil |

## PathfindingUtils
### Methods
| Method | Description | Returns |
|--------|-------------|---------|
| `moveTo(character, targetPos, options, abortCheck)` | Move with pathfinding | boolean |
| `moveToWithRetry(...)` | Move with retry attempts | boolean |
| `pathExists(startPos, endPos, options)` | Check if path exists | boolean |
