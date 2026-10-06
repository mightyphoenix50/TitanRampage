# Titan Rampage — Project Changelog

All prompt executions, milestones, and architectural updates for the **Titan Rampage** project are documented below in chronological order.

---

### [2026-10-05 15:30 UTC] — Prompt: MCP Write-Operation Verification
- **Goal:** Verify Roblox Studio MCP server connection, read capabilities, and Luau write execution permissions.
- **Actions Executed:**
  - Created test part `Workspace.MCP_Test` with properties: Size `4, 4, 4`, Position `0, 5, 0`, Anchored `true`, SmoothPlastic.
  - Verified property values via inspect tool.
  - Cleaned up and deleted `Workspace.MCP_Test`.
- **Status:** Complete & Verified.

---

### [2026-10-05 16:45 UTC] — Prompt: Project Architecture & Foundation Setup
- **Goal:** Establish clean, modular, server-authoritative service architecture for Titan Rampage.
- **Actions Executed:**
  - Created folder hierarchy:
    - `ReplicatedStorage`: `Shared`, `Config`, `Remotes`, `Assets` (Models, Audio).
    - `ServerScriptService`: `Services`, `ServerBootstrap`.
    - `StarterPlayer`: `StarterPlayerScripts`.
    - `StarterGui`: `UI`.
  - Created initial RemoteEvents: `TitanAction`, `TitanEffect`, `DestructionFeedback`, `ProgressionUpdate`.
  - Created baseline configurations: `TitanConfig.luau`, `DestructionConfig.luau`.
  - Built `ServerBootstrap.server.luau` orchestrating service initialization and start lifecycle.
- **Status:** Complete & Verified.

---

### [2026-10-05 18:10 UTC] — Prompt: Milestone 1 — Ravager Playable Titan Prototype
- **Goal:** Create an original, non-copyrighted colossal humanoid monster named **Ravager** and implement player control.
- **Actions Executed:**
  - Modeled 24-stud-tall original titan rig with basalt stone and glowing magma eyes.
  - Configured R6 Motor6D joints (`RootJoint`, `Neck`, `Left Shoulder`, `Right Shoulder`, `Left Hip`, `Right Hip`).
  - Implemented `MonsterService.luau` for server-authoritative spawning, character setup, and camera bounds.
  - Configured custom camera offsets (`Min: 15`, `Max: 120`, `Default: 45`) for giant monster perspective.
  - Implemented `TitanController.client.luau` handling WASD movement, jump, and action dispatch.
- **Status:** Complete & Playtested.

---

### [2026-10-05 19:25 UTC] — Prompt: Milestone 2 — SmallTown Playable City Prototype
- **Goal:** Construct a performance-conscious destructible municipality designed for Titan combat.
- **Actions Executed:**
  - Built `SmallTown` in `Workspace.Cities.SmallTown` with defined city boundaries (`270 x 80 x 252` studs).
  - Placed 15 destructible buildings across three distinct tiers:
    - 8 Small Buildings (houses, corner stores)
    - 5 Medium Buildings (commercial plazas, office blocks)
    - 2 Large Buildings (civic centers, department stores)
  - Built environment infrastructure: 2-lane roads, intersections, sidewalks, streetlights, and crosswalk markings.
  - Populated attributes on all buildings: `BuildingId`, `BuildingName`, `BuildingType`, `MaxHealth`, `CurrentHealth`, `DestructionTier`, `DestructionReward`, `DestructionPoints`.
- **Status:** Complete & Verified.

---

### [2026-10-05 20:40 UTC] — Prompt: Milestone 3 — Server-Authoritative Building Destruction System
- **Goal:** Implement the core building destruction engine with non-destructive collapse and visual degradation.
- **Actions Executed:**
  - Implemented `DestructionService.luau`:
    - Server-authoritative API `DestructionService.DamageBuilding(building, damage, player, source)`.
    - Legal hit validation, distance boundary checks, and dead-building filtering.
  - Created multi-stage visual degradation based on health ratios:
    - 100%–75%: Pristine state.
    - 75%–50%: Light damage (broken windows, weathered surface).
    - 50%–25%: Heavy damage (all windows hidden, entrance awnings lost, darkened facade).
    - 25%–0%: Critical damage (scorched basalt tint, smoking structure).
    - 0%: Controlled collapse into a solid concrete rubble remnant with dust cloud and camera shake.
  - Implemented destruction combo system (up to 5.0x multiplier with reset timer).
  - Integrated visual feedback: floating damage numbers, debris ejection, and rubble creation.
- **Status:** Complete & Verified.

---

### [2026-10-05 21:30 UTC] — Prompt: Milestone 3.1 — Player Progression & Ravager Upgrades
- **Goal:** Introduce server-authoritative progression (XP, Level, Cash, Destruction Points) and Titan stat upgrades.
- **Actions Executed:**
  - Implemented `ProgressionService.luau` with scalable XP curve ($Level \times 500$ scaling).
  - Defined 5 upgrade paths with increasing costs:
    - `BasicAttackDamage`: +25 damage per rank.
    - `StompDamage`: +60 damage per rank.
    - `WalkSpeed`: +4 studs/sec per rank (dynamically updates active Humanoid).
    - `BasicAttackCooldown`: -0.08s cooldown reduction per rank.
    - `StompCooldown`: -0.40s cooldown reduction per rank.
  - Built client `UpgradeUI` screen allowing players to spend Cash and Destruction Points.
  - Enforced server-authoritative validation for purchases and dynamic stat synchronization.
- **Status:** Complete & Verified.

---

### [2026-10-05 22:05 UTC] — Prompt: Milestone 4 — Complete SmallTown Gameplay Loop
- **Goal:** Turn SmallTown into a repeatable vertical slice with live tracking, completion, and non-destructive rebuild.
- **Actions Executed:**
  - Extended `CityService.luau` with live city statistics:
    - `TotalBuildings`, `ActiveBuildings`, `DestroyedBuildings`, `TotalHealth`, `CurrentHealth`, `DestructionPercentage`, `CityCompletionPercentage`.
  - Built `DestructionHUD` showing real-time city destruction progress bar and run timer.
  - Implemented 100% city completion detection, celebratory completion banner, and bonus payout.
  - Built automated, non-destructive city rebuild engine: restores all 15 building CFrame positions, body colors, window transparencies, and colliders to pristine state.
- **Status:** Complete & Playtested.

---

### [2026-10-05 22:18 UTC] — Prompt: Milestone 5 — Combat Feel, Economy Balancing & Progression Tuning
- **Goal:** Refine combat responsiveness, balance the reward economy, and enhance audio-visual weight.
- **Actions Executed:**
  - Audited economy baseline across all building tiers to ensure balanced leveling pacing.
  - Stomp tuning: added 0.35s windup anticipation ring, distance damage falloff from epicenter (1.0 to 0.35 factor), and dual Neon shockwave rings.
  - Roar tuning: added expanding sonic pulse sphere and camera shake.
  - Combat responsiveness: added directional camera recoil on claw strikes.
  - Enhanced floating damage indicators and particle debris bursts.
- **Status:** Complete & Verified.

---

### [2026-10-05 22:35 UTC] — Prompt: Milestone 6 — City Selection, Unlock Progression & Metrovale
- **Goal:** Make city configuration data-driven, implement unlock progression, and build a second playable city: **Metrovale**.
- **Actions Executed:**
  - Created `CityConfig.luau` supporting arbitrary cities with spawn coordinates, bounds, rewards, and unlock criteria.
  - Built **Metrovale** (`Workspace.Cities.Metrovale`) with 27 buildings:
    - 12 Small Buildings (urban retail, cafes, bodegas)
    - 8 Medium Buildings (office complexes, mid-rise commercial)
    - 5 Large Buildings (towering corporate skyscrapers)
    - 2 Massive Landmarks: `Landmark_Grand_Metro_Hotel` (6,500 HP) and `Landmark_Metrovale_Tower` (7,500 HP)
  - Implemented city unlock requirements for Metrovale: **Player Level 5** and **2 SmallTown Clears**.
  - Built `CitySelectUI` and server teleportation pipeline allowing players to transition between cities.
  - Supported multi-city tracking, independent run timers, and city-specific rebuild systems.
- **Status:** Complete & Playtested.

---

### [2026-10-06 00:52 UTC] — Prompt: Milestone 6.1 — Combat Feel & Destruction Tuning
- **Goal:** Fine-tune large building durability, implement a dedicated animation controller with 3 attack variants, and sync abilities.
- **Actions Executed:**
  - **Reduced Large Building Durability (-40%)**:
    - SmallTown: `Building_Large_01` (3,500 $\to$ 2,100 HP), `Building_Large_02` (3,800 $\to$ 2,280 HP). Total HP: 16,410 HP.
    - Metrovale: `Metrovale_Large_01`–`05` reduced by 40% (2,280–2,700 HP). Total HP: 53,380 HP.
    - Landmark durability preserved: Hotel (6,500 HP) and Tower (7,500 HP) untouched.
  - Built `TitanAnimationController.luau` in `ReplicatedStorage.Shared`:
    - Dual-layer pipeline: Roblox `AnimationTrack`s with procedural `Motor6D` C0 tweening fallback.
    - Non-locking locomotion: only torso and arms animate; legs move freely during attacks.
    - Zero joint drift: restored to exact neutral C0 (0.000 studs deviation).
  - Implemented 3 Basic Attack variants with automatic cycling:
    - `LeftSwipe`: Horizontal left-arm sweep across chest with left-to-right tilted slash FX.
    - `RightSwipe`: Horizontal right-arm sweep across chest with right-to-left tilted slash FX.
    - `DownwardSmash`: Two-handed overhead hammer slam with plunging vertical cleave FX.
  - Synchronized Stomp sequence: 0.15s crouch $\to$ 0.20s leg raise (0.35s total) $\to$ earth slam impact aligned with server damage and shockwave.
  - Synchronized Roar sequence: 0.30s chest expansion $\to$ 0.45s tremor hold $\to$ 0.25s recovery.
  - Zero-latency client response on LMB/`1` with 100% server damage authority preserved.
- **Status:** Complete, Verified & Returned to Edit Mode.

---

### [2026-10-06 09:15 UTC] — Prompt: Milestone 6.2 — Audio & Final Combat Polish
- **Goal:** Implement centralized, modular audio architecture across all combat, destruction, progression, UI, and city events.
- **Actions Executed:**
  - Audited audio baseline: clean initial state (0 legacy sound objects).
  - Configured `SoundGroups` in `SoundService`: `Master` (1.0), `Combat` (0.9), `Destruction` (0.9), `UI` (0.5), `Music` (0.6).
  - Created `AudioConfig.luau` in `ReplicatedStorage.Config`:
    - Structured sound definitions with volume, base pitch, pitch variation, roll-off distances, and production asset placeholders (`rbxassetid://0`).
    - Robust built-in engine audio fallbacks (`rbxasset://sounds/...`) for zero-asset-failure execution.
  - Created `AudioController.luau` in `ReplicatedStorage.Shared`:
    - 3D spatial audio playback (inverse tapered roll-off) and 2D HUD sound presentation.
    - Organic pitch jitter on every sound trigger to eliminate mechanical repetition.
    - Intelligent audio throttling engine (e.g. max 1 glass break per 0.15s, max 3 concurrent impacts per 80ms) preventing cacophony during AoE Stomp mass destruction.
    - Zero-latency local playback on LMB/`1` with duplicate prevention for remote multiplayer events.
  - Basic Attack Audio: unique whoosh variations for `LeftSwipe`, `RightSwipe`, and `DownwardSmash` (deep bass cleave).
  - Building Impact Audio: tiered scaling across Small (crisp concrete), Medium (heavy stone), Large (deep structural bass), and Landmark (colossal reverberating shock).
  - Progressive Structural Damage Audio: 75% Window Break, 50% Structural Groan, 25% Critical Strain.
  - Multi-Stage Collapse Audio: Phase 1 Shear Initiate $\to$ Phase 2 Heavy Descent Rumble $\to$ Phase 3 Rubble Settling Impact.
  - Synchronized Stomp Audio: 0.0s Anticipation tension $\to$ exact 0.35s Seismic Ground Slam & Shockwave $\to$ 0.45s Rubble settling.
  - Synchronized Roar Audio: Sub-bass monster roar resonance during sonic tremor phase.
  - Progression Audio: Dynamic reward chimes (pitch-scaled by combo), distinct Level Up fanfare, and Combo progression cues (2x, 3x, 4x, 5x MAX INFERNO).
  - UI Audio: Subtle clicks, card select, deploy whoosh, rebuild tone, upgrade success ding, and upgrade rejection buzz.
  - City Completion Audio: Celebratory victory stinger.
  - Regression tested 100% destruction and rebuild loops for SmallTown and Metrovale. Studio returned to clean Edit Mode.
- **Status:** Complete, Verified & Returned to Edit Mode.
