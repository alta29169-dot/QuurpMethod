# API Reference - qurp v3

## StateManager.lua

### State Variables
| Variable | Type | Description |
|----------|------|-------------|
| seated | boolean | Is player sitting in vehicle? |
| setupRunning | boolean | Is setup in progress? |
| recovering | boolean | Is recovery in progress? |
| hasPlane | boolean | Does player own a plane? |
| targetVehicle | Instance | Reference to owned plane |
| isPlaneAlive | boolean | Is owned plane still alive? |
| generation | number | Respawn counter (increments each spawn) |
| isRunning | boolean | Is engine running? |

### Locks (Race Conditions)
| Lock | Description |
|------|-------------|
| setup | Prevents duplicate setup runs |
| recovery | Prevents duplicate recovery runs |
| spawn | Prevents duplicate spawn attempts |

### Methods
| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| tryLockSetup | none | boolean | Claim setup lock |
| unlockSetup | none | nil | Release setup lock |
| tryLockRecovery | none | boolean | Claim recovery lock (3s cooldown) |
| unlockRecovery | none | nil | Release recovery lock |
| nextGeneration | none | number | Increment and return generation |
| getGeneration | none | number | Current generation |
| canRespawn | none | boolean | Check respawn debounce (2s) |
| get | key: string | any | Get state value |
| set | key: string, value: any | any | Set state value |
| isSeated | none | boolean | Get seated status |
| hasPlane | none | boolean | Get hasPlane status |
| isSetupRunning | none | boolean | Get setupRunning status |
| isRecovering | none | boolean | Get recovering status |
| getVehicle | none | Instance | Get targetVehicle |
| resetAll | none | nil | Reset all state (keeps generation) |

---

## BomberManager.lua

### Methods
| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| findMyBomber | none | Instance/nil | Find bomber with Owner == player.Name |
| getBomberOccupant | bomber: Instance | string/nil | Get Occupant value |
| isBomberOccupied | bomber: Instance | boolean | Is anyone in the bomber? |
| isUsInBomber | bomber: Instance | boolean | Is player in this bomber? |
| updatePlaneState | none | Instance/nil | Refresh StateManager plane data |
| getBomberSeat | bomber: Instance | Instance/nil | Get bomber's Seat |
| spawnBomber | airport: Instance | boolean | Fire RemoteEvent to spawn bomber |
| sitInBomber | bomber: Instance | boolean | Attempt to sit in bomber |

### Remote Event Format]
ReplicatedStorage.Event:FireServer("VSpawn", { airport, "Bomber", 2 })

- airport: Instance from VehicleSP child
- "Bomber": String vehicle name
- 2: Price (server verified)

---

## AutoSeater.lua

### Methods
| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| walkToPosition | targetPos: Vector3, tolerance: number | boolean | Walk to position with pathfinding |
| walkToNearestAirport | none | boolean | Walk to nearest airport |
| walkToBomber | bomber: Instance | boolean | Walk to a specific bomber |
| trySitInBomber | bomber: Instance | boolean | Walk near and attempt to sit |

### Movement Notes
- Uses PathfindingUtils internally
- Aborts on death or generation change
- Returns true only when target is reached
- Sitting requires being within 10 studs

---

## AirportManager.lua

### Methods
| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| cacheAirports | myGen: number | boolean | Cache all airports from VehicleSP |
| getNearestAirport | playerChar: Instance, myGen: number | Instance/nil | Get nearest cached airport |

### Cached Data (StateManager)
- `airportCache`: table of airport instances
- `airportsCached`: boolean

---

## HarbourTeleporter.lua

### Methods
| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| teleportToHarbour | myGen: number | boolean | Teleport player to harbour |

---

## DockLocator.lua

### Methods
| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| getDock | none | Instance/nil | Get USDock instance |
| getVehicleSP | none | Instance/nil | Get VehicleSP from dock |

---

## PathfindingUtils.lua

### Configuration
| Option | Default | Description |
|--------|---------|-------------|
| AgentRadius | 2 | Agent size |
| AgentHeight | 5 | Agent height |
| AgentCanJump | true | Can jump |
| AgentCanClimb | true | Can climb trusses |
| AgentMaxSlope | 45 | Max walkable slope |
| WaypointSpacing | 10 | Distance between waypoints |

### Methods
| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| moveTo | character, targetPos, options, abortCheck | boolean | Move with pathfinding |
| moveToWithRetry | character, targetPos, maxRetries, options, abortCheck | boolean | Move with retries |
| getPath | startPos, endPos, options | table/nil | Get waypoints (debug) |
| pathExists | startPos, endPos, options | boolean | Check if path exists |

### Abort Check Function
```lua
function abortCheck()
    return not player.Character or not StateManager.get("isAlive")
end
