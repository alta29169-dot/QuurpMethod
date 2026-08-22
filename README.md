# QurpMethod

Combat bot for Roblox.

# Loadstring
``` bash
loadstring(game:HttpGet("https://raw.githubusercontent.com/alta29169-dot/QuurpMethod/refs/heads/main/BootLoader.lua"))()
```

## Documentation
- [System Architecture](SystemArchitecture.md) - High-level overview
- [API Reference](API_Reference.md) - All module functions

## Quick Start
1. Load the script
2. BootLoader handles everything
3. Bot will: Harbour → Airport → Spawn Bomber → Seat

## Requirements
- Roblox executor with `request()` support
- Internet connection for GitHub loading

## Notes
- Bombers persist through respawns
- Self-correcting heartbeat loop
- Pathfinding with truss climbing support
