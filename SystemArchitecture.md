# System Architecture – qurp v3

## Overview
qurp v3 is a modular combat bot designed for NW. It uses a heartbeat-driven architecture with state management for reliability.

## Core Principles
- **Modular**: Each module has a single responsibility
- **State-Driven**: StateManager is the single source of truth
- **Self-Correcting**: Heartbeat loop continuously checks and fixes issues
- **Resilient**: Handles respawns, disconnects, and failures gracefully

## Module Dependencies
[Diagram showing module relationships]

## Execution Flow
1. BootLoader loads all modules
2. Main.start() initializes the engine
3. Respawn handler fires → teleport to harbour → cache airports
4. Heartbeat loop runs forever:
   a. Check for owned bomber → if not, walk to airport and spawn
   b. Check if seated → if not, walk to bomber and sit
   c. If seated → engage combat
