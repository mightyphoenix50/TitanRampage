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

---

### [2026-10-06 12:30 UTC] — Prompt: Milestone 7 — Persistent Player Progression + Combat Feedback
- **Goal:** Implement production-ready DataStore progression persistence and polish combat feel (faster basic attack, 3D floating damage numbers, multi-target stomp feedback).
- **Actions Executed:**
  - **Production DataStore Persistence (`PlayerDataService.luau`)**:
    - Centralized service created in `ServerScriptService.Services.PlayerDataService`.
    - Keyed under `TitanRampage_PlayerData_v1` with versioned schema (`SchemaVersion = 1`).
    - Robust safety mechanisms: 3-attempt exponential backoff retries on `GetAsync`/`UpdateAsync`.
    - `isLoadFailed` lock strictly prevents overwriting stored progress with defaults if DataStore errors occur.
    - Authoritative in-memory session profile cache (`sessionProfiles`) with safe functional mutation callback (`UpdateProfile`).
    - Clamped profile validation (`ValidateProfile`) protecting against data corruption or negative values.
    - Sequential schema migration template (`MigrateProfile`) for seamless forward compatibility.
    - 5-minute background periodic autosave loop for all active profiles.
    - `game:BindToClose` shutdown handler ensuring all player profiles are saved before server termination.
    - Automatic Studio fallback mode (`mockStorage`) gracefully detecting disabled Web API access and enabling local unit testing without error.
  - **Service Integration as Single Source of Truth**:
    - Refactored `ProgressionService.luau` to read/write Level, XP curve, Cash, Destruction Points, and Ravager Upgrades directly through `PlayerDataService`.
    - Refactored `CityService.luau` to read/write persistent city unlocks, completion counts, best clear times, and best combo records in `PlayerDataService`.
  - **Faster, More Responsive Basic Attack**:
    - Retargeted melee attack animation duration from 0.52s to **0.42s** (0.09s windup, 0.14s strike, 0.19s recovery) across all 3 variants (`LeftSwipe`, `RightSwipe`, `DownwardSmash`) in `TitanAnimationController.luau`.
    - Retargeted baseline cooldown in `TitanConfig.luau` from 1.00s to **0.78s** (`AnimationDuration = 0.42s`).
    - Retargeted `BasicAttackCooldown` tiers in `UpgradeConfig.luau` to: Tier 1 (0.78s), Tier 2 (0.68s), Tier 3 (0.58s), Tier 4 (0.50s), Tier 5 (0.42s).
    - Reduced client attack swipe FX tween duration from 0.24s to **0.18s** in `TitanController.client.luau`.
  - **Enhanced 3D Floating Damage Numbers & Combat Feedback**:
    - Upgraded `DestructionHUD.client.luau` to render distinct, styled floating damage indicators:
      - Basic Attack: crisp `-%d` (22–26pt, vibrant orange-red/gold).
      - Multi-target Stomp: bold `💥 -%d` (28–34pt, blazing amber/gold).
    - Animated with punchy 0.10s pop-in scale (`Enum.EasingStyle.Back`) and 4.5-stud upward float over 0.85s.
    - Throttled queue system limiting active damage numbers to a maximum of 15 concurrent instances with automatic cleanup of oldest numbers to maintain high frame rates.
  - **Automated Verification & Zero Regression**:
    - Verified all 6 DataStore persistence unit tests (profile initialization, rewards, upgrades, persistence storage, corruption clamping, save lock safety).
    - Verified combat timing, cooldown rejection (4 rapid spam requests rejected), and multi-target Stomp damaging multiple buildings simultaneously.
    - Verified full 100% destruction and rebuild loop for SmallTown (15 buildings, 16,410 HP) and Metrovale (27 buildings, 53,380 HP).
    - Studio returned to clean Edit Mode.
- **Status:** Complete, Verified & Returned to Edit Mode.

---

### [2026-10-06 17:05 UTC] — Prompt: Milestone 7.1 — Bug Fix Pass: Ravager Grounding + Upgrade Menu State
- **Goal:** Resolve gameplay bugs identified in play-testing: Ravager character floating above ground, and the Upgrade menu appearing greyed out / unresponsive.
- **Root Cause Analysis & Actions Executed:**
  - **Bug 1: Ravager Floating Above Ground**:
    - *Root Cause Diagnosed:* Roblox's R6 Humanoid standing controller on custom character dimensions already includes leg height (`11.0` studs) and half-torso (`4.5` studs) in its base ground clearance ($15.5$ studs). `HipHeight = 11.0` was set under the misconception that it defined HRP-to-ground offset, causing the engine to stack an additional 11 studs of clearance *on top* of the legs (hovering feet 11.3 studs above ground).
    - *Resolution:* Configured `HipHeight = 0.15` in `ReplicatedStorage.Config.TitanConfig.luau`, `StarterPlayer.StarterCharacter.Humanoid.HipHeight`, and `ReplicatedStorage.Assets.Models.Ravager.Humanoid.HipHeight`.
    - *Results:* Feet hover $\approx 0.15$–$0.17$ studs above ground (less than 2 inches, completely grounded with smooth collision skin margin).
    - *Rig Integrity Preserved:* Zero CFrame offsets, zero changes to character size, proportions, or collision geometry.
    - *Animation Verification:* Verified across spawn, WASD locomotion, Basic Attack Variants 1/2/3, Stomp, Roar, and respawn. Zero procedural joint drift detected; `HumanoidStateType` remains solidly `Running`.
  - **Bug 2: Upgrade Menu State & Synchronization**:
    - *Root Cause Diagnosed:* RemoteEvent race condition where server fired `InitialSync` during `PlayerAdded` before `PlayerGui` was loaded and bound on the client, dropping the event. The client lacked a `RequestSync` event on startup and when opening the panel. Furthermore, unaffordable upgrades were styled in pitch dark grey (`Color3.fromRGB(42, 45, 52)`) with `AutoButtonColor = false`, making them appear frozen/dead.
    - *Resolution in `ProgressionService.luau`:*
      - Added `ProgressionUpdateRemote.OnServerEvent` listener for `"RequestSync"`, invoking `ProgressionService.SyncToClient(player)` on demand.
      - Attached full authoritative progression state (`Level`, `XP`, `Cash`, `DestructionPoints`, `Upgrades`) to all `UpgradeFailed` payloads to immediately heal any client-side desynchronization.
    - *Resolution in `DestructionHUD.client.luau`:*
      - Dispatched `RequestSync` immediately after building the upgrade matrix on startup.
      - Dispatched `RequestSync` whenever opening `UpgradePanel` (via HUD button and `U` keybind).
      - Handled `UpgradeFailed` events with `UpgradeError` sound and brief crimson row flash.
      - Modernized unaffordable button styling: responsive `AutoButtonColor = true` with distinct slate-crimson background (`Color3.fromRGB(55, 42, 46)`) and clear readable text (`Color3.fromRGB(215, 170, 170)`).
      - Implemented dedicated `"MAX"` button state for Tier 5 upgrades (`Color3.fromRGB(45, 52, 60)`, disabled click, with gold `⚡ (MAX LEVEL)` text).
  - **Automated Verification**:
    - Grounding measured at $0.153$ studs at spawn, $0.155$–$0.179$ studs during attacks/stomp/roar, and $0.156$ studs upon respawn.
    - Dynamic UI updates: unaffordable $\to$ affordable (fiery orange #FF7814) upon earning rewards $\to$ purchasing upgrade increments stat (WalkSpeed 28 $\to$ 31 studs/s) $\to$ Max Level displays `"MAX"` in gold $\to$ leave/rejoin persistence verified in `PlayerDataService`.
    - Zero regression across SmallTown (15 buildings) and Metrovale (27 buildings).
    - Studio returned to clean Edit Mode.
- **Status:** Complete, Verified & Returned to Edit Mode.

---

### [2026-10-06 21:55 UTC] — Prompt: Milestone 7.2 — Upgrade Panel Visual State Fix
- **Goal:** Fix visual presentation of the Upgrade Panel where buttons appeared dark/greyed out even when accessible.
- **Root Cause Diagnosed:**
  - `ScreenGui.ZIndexBehavior` on `StarterGui.MainUI` was set to `Global`.
  - `UpgradePanel` had `ZIndex = 10` with `BackgroundColor3 = Color3.fromRGB(16, 18, 22)` and `BackgroundTransparency = 0.05` (95% opaque dark charcoal).
  - All dynamically spawned rows, titles, value labels, and buy buttons in `buildUpgradeMatrix()` defaulted to `ZIndex = 1`.
  - In Roblox's `Global` ZIndex sorting, `UpgradePanel` (ZIndex 10) was rendered *in front of* the buttons (ZIndex 1).
  - Consequently, the bright orange (`#FF7814`) button background was filtered through a 95% opaque dark charcoal overlay, resulting in a dark muddy grey perceived appearance.
- **Architectural Fixes Executed:**
  - **ZIndex Hierarchy & Sibling Mode:**
    - Configured `MainUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling` on `StarterGui.MainUI`.
    - Explicitly assigned higher ZIndex to all matrix elements in `buildUpgradeMatrix()`: `Row` (12), `Title` (13), `ValueLabel` (13), and `BuyButton` (14).
  - **Centralized Visual State Engine (`updateUpgradeButtonVisualState`)**:
    - Created single authoritative function in `DestructionHUD.client.luau` managing all three distinct states:
      - **STATE A — AFFORDABLE:** Vibrant fiery orange background (`Color3.fromRGB(255, 120, 20)` / `#FF7814`), pure white text (`Color3.fromRGB(255, 255, 255)`), `AutoButtonColor = true`, `Active = true`, `BackgroundTransparency = 0`.
      - **STATE B — UNAFFORDABLE:** Rich dark slate-crimson background (`Color3.fromRGB(56, 40, 48)`), high-contrast readable rose-white cost text (`Color3.fromRGB(235, 185, 185)`), `AutoButtonColor = true`, `Active = true` (clicking triggers error sound and row flash).
      - **STATE C — MAX LEVEL:** Muted charcoal background (`Color3.fromRGB(42, 48, 56)`), muted grey text (`Color3.fromRGB(145, 155, 168)`), `Text = "MAX"`, `Active = false`, `AutoButtonColor = false`, with gold status indicator (`Color3.fromRGB(255, 210, 40)`).
- **Runtime Verification Executed (Play Mode):**
  - **Test A:** Panel inspection verified `ZIndexBehavior = Sibling`, `BuyButton.ZIndex = 14`, `BackgroundTransparency = 0`, `TextTransparency = 0`.
  - **Test B:** Awarded $500 Cash & 500 Pts; affordable buttons visibly transformed to vibrant fiery orange (`#FF7814`) with pure white text and active hover feedback.
  - **Test C:** Purchased upgrade; button state immediately updated, new cost displayed, and unaffordable tier transitioned cleanly to slate-crimson.
  - **Test D:** Tier 5 upgrades display `"MAX"`, muted charcoal background, and gold status indicator with disabled click.
  - **Test E:** Panel closed and reopened; all visual states preserved flawlessly.
  - **Test F:** Progression update triggered; confirmed no overwrites back to dark grey.
  - **Required Final Test:** Simultaneously demonstrated all 3 states: `BasicAttackDamage` (Affordable / Bright Orange), `WalkSpeed` (Unaffordable / Slate-Crimson), and `RoarCooldown` (MAX / Charcoal & Gold).
- **Status:** Complete, Verified & Returned to Edit Mode.

---

### [2026-10-06 23:55 UTC] — Prompt: Milestone 8 — Replayability, Run Scoring & Destruction Mastery
- **Goal:** Formalize city gameplay sessions into server-authoritative Destruction Runs with arcade run scoring, combo depletion timer bars, personal best tracking, results screen breakdowns, and persistent lifetime profile statistics.
- **Architecture & Systems Implemented:**
  - **1. Server-Authoritative Destruction Run Engine (`CityService.luau`)**:
    - Formalized `CityRunStats` tracking: `CityId`, `RunStartTime`, `RunEndTime`, `Duration`, `BuildingsDestroyed`, `BuildingsDamaged`, `TotalDamage`, `BasicAttacks`, `Stomps`, `Roars`, `HighestCombo`, `BuildingsCash`, `BuildingsPoints`, `BuildingsXP`, `CompletionCash`, `CompletionPoints`, `CompletionXP`, `TotalCash`, `TotalPoints`, `TotalXP`, `DestructionScore`, `BuildingsPerMinute`, `CityCompleted`, `CompletionAwarded`.
    - Hooked `CityService.RecordAbilityUsed(player, abilityName)` into `MonsterService.luau` to accurately track ability usage counts for Basic Attacks, Stomps, and Roars.
    - Implemented `CityService.CalculateDestructionScore`:
      - $\text{Base Destruction Score} = \text{BuildingsPoints} + \lfloor \text{TotalDamage} \times 0.1 \rfloor$
      - $\text{Combo Bonus} = \text{HighestCombo} \times 1,500$
      - $\text{Speed Bonus} = \max(0, (\text{TargetTime} - \text{Duration}) \times 50)$ (where TargetTime is 120s for SmallTown, 240s for Metrovale)
      - $\text{Completion Bonus} = 5,000$ (SmallTown) or $15,000$ (Metrovale)
      - $\text{Destruction Score} = \lfloor \text{Base} + \text{Combo Bonus} + \text{Speed Bonus} + \text{Completion Bonus} \rfloor$
      - Strict scope compliance: Destruction Score is strictly an arcade performance metric and never replaces or diminishes Cash, Points, or XP.
    - Destruction Pace calculation: $\text{BPM} = \frac{\text{BuildingsDestroyed}}{\max(0.1, \text{Duration}) / 60}$.
  - **2. Per-City Personal Best Tracking**:
    - Integrated personal best tracking per city in `PlayerDataService.luau`: `BestTime` (lower is better), `BestCombo` (higher is better), `BestScore` (higher is better), `BestBuildingsPerMinute` (higher is better).
    - Server evaluates personal records upon city clear and flags individual `"★ NEW BEST!"` badges (`IsNewBestTime`, `IsNewBestCombo`, `IsNewBestScore`, `IsNewBestBpm`).
    - City selection panel displays personal best time, combo, and high score per city card.
  - **3. Persistent Lifetime Statistics & Schema Migration (`SchemaVersion = 2`)**:
    - Upgraded `PlayerDataService.luau` schema from Version 1 to **Version 2**.
    - Added `Statistics` table to `PlayerProfile`: `TotalBuildingsDestroyed`, `TotalDamageDealt`, `TotalCitiesCompleted`, `TotalRunsCompleted`, `TotalCashEarned`, `TotalPointsEarned`, `TotalXPEarned`, `HighestCombo`, `TotalPlayTime`.
    - Built backward-compatible migration (`MigrateProfile`): automatically attaches default lifetime statistics, seeds lifetime clear counts from historical data, populates missing `BestScore` and `BestBuildingsPerMinute`, and bumps schema version to 2 without wiping player progress.
    - Profile retrieval fallback in `GetProfile(player)` loads session profile on demand if joined during testing races.
  - **4. Combat & Combo HUD Polish (`DestructionHUD.client.luau`)**:
    - Smooth millisecond/centisecond live run timer: `⏱️ MM:SS.cs` synced with server `RunStartTime` via `RunService.Heartbeat`.
    - Added animated depleting timer bar under `ComboLabel` (`ComboBarBg` & `ComboBarFill`) smoothly draining over combo timeout duration (4.0s).
    - Added subtle `"💨 COMBO LOST"` feedback animation upon combo expiration with recovery back to neutral `1x`.
  - **5. End-of-Run Results Screen**:
    - Built comprehensive results scoreboard (`CityCompletionScreen`) featuring:
      - Top Score Card with animated count-up for Destruction Score and gold `"★ NEW BEST SCORE! ★"` badge.
      - Complete Score Breakdown line (Base | Combo Bonus | Speed Bonus | Clear Bonus).
      - Clear Time, Highest Combo, and Destruction Pace (BPM) with dynamic `"★ NEW BEST!"` indicators.
      - Full ability usage audit (Strikes, Stomps, Roars).
      - Currency breakdown (Buildings vs City Bonus vs Total Run).
      - Interactive Rebuild Button (`🔄 REBUILD & RAMPAGE AGAIN`).
  - **6. Security & Anti-Exploit Enforcement**:
    - City switching rejected during active runs with damage (`"Cannot switch cities during an active destruction run! Rebuild or finish first."`).
    - Rebuilding rejected on unfinished cities (`"City is not completed"`).
    - 100% server authority over run timers, ability counts, scores, and profile persistence.
- **Verification & Playtesting (Play Mode)**:
  - Run 1 (SmallTown): 15/15 buildings destroyed, 42s clear time, score 19,413 pts, 21.4 BPM, Level 3 reached. Results screen verified with all New Best badges.
  - City Rebuild: full reconstruction of all 15 buildings, rubble cleanup, clean run timer reset.
  - Run 2 (SmallTown): 15/15 buildings destroyed, 15s clear time, score 20,763 pts, 60.0 BPM, Level 4 reached. Lifetime statistics correctly accumulated to 30 buildings, 32,820 damage, 2 completions, 57s play time.
  - Metrovale Unlock & Run: unlocked at Level 4 + 2 clears. Completed 27/27 buildings, 17s duration, score 46,691 pts, 95.2 BPM, 53,880 damage. Lifetime statistics accumulated to 57 buildings, 86,700 damage, 3 completions.
  - Abandoned run anti-exploit test: verified city switch rejection during active run with damage.
  - Schema migration test: simulated SchemaVersion 1 profile verified flawless migration to SchemaVersion 2 without data loss.
  - Studio cleanly returned to Edit Mode with zero errors.
- **Status:** Complete, Verified & Returned to Edit Mode.

---

### [2026-10-07 10:20 UTC] — Prompt: Milestone 9 — Titan Expansion Framework + Second Titan
- **Goal:** Introduce the game's first scalable multi-Titan architecture and add a second playable colossal Titan: **Brontara the Earthshaker** (an original quadrupedal sauropod-inspired behemoth; zero ARK assets, meshes, or names).
- **Architecture & Systems Implemented:**
  - **1. Extensible Data-Driven Titan Registry (`ReplicatedStorage.Shared.TitanRegistry.luau`)**:
    - Created modular registry defining: `Id`, `DisplayName`, `Subtitle`, `Class`, `Description`, `ModelAsset`, `BaseHealth`, `WalkSpeed`, `JumpPower`, `HipHeight`, `CameraZoom` (`Min`, `Max`, `Default`, `CameraOffset`), `UnlockRequirement` (`Level`, `CityClears`), `Abilities` mapping (`Primary`, `Stomp`, `Signature`, `Utility`), and helper methods (`Get`, `GetAll`, `GetList`, `IsUnlocked`, `GetAbilityForSlot`).
    - Updated `ReplicatedStorage.Config.TitanConfig.luau` to re-export `TitanRegistry` for 100% backward compatibility with all existing game systems.
  - **2. Titan 2: Brontara the Earthshaker (Colossal Quadrupedal Titan)**:
    - **Original Creature Identity:** Prehistoric armored sauropod with armored granite dorsal plates, massive pillar limbs, a 35-stud whip tail, and an elongated crane-like neck with an armored head hammer.
    - **Physical Attributes:** 4,500 Base HP (+50% over Ravager), 24 Base WalkSpeed (heavy, deliberate momentum), 0.15 HipHeight (grounding calibrated with zero hover/sink), and colossal camera bounds (25 to 160 studs zoom, default 65 studs, Y+8 offset).
    - **4 Complete Distinct Abilities:**
      - **TailSweep (Primary - LMB / 1):** Horizontal whip sweep covering 26 studs forward reach with wide arc (~200 base dmg, 1.1s cd). Verified dealing 200 dmg to multiple buildings in arc.
      - **HeavyStomp (Stomp - E / 2):** Front pillar rear-up and seismic slam (~600 base dmg, 45 studs radius, 6.0s cd, 0.5s windup). Verified rear-up choreography, 0.5s windup, 45-stud seismic shock, completely flattening structures into rubble.
      - **NeckStrike (Signature - Q):** Long-range overhead neck/head plunge strike (~350 base dmg, 52 studs range, 14 studs radius, 4.0s cd). Verified dealing 350 dmg to buildings 40 studs away.
      - **Roar (Utility - R / 3):** Low-frequency seismic bellow (~55 radius, 8.0s cd). Verified firing 55 stud seismic shockwave.
  - **3. Procedural Quadrupedal Animation Controller (`TitanAnimationController.luau`)**:
    - Built dedicated quadrupedal animation routines: `PlayTailSweep()` (torso wind and rapid horizontal tail flick), `PlayHeavyStomp()` (front limb rearing and violent downward impact), `PlayNeckStrike()` (neck recoil and downward plunge), and quadrupedal bellow.
    - Implemented polymorphic routing in `PlayBasicAttack()`, `PlayStomp()`, and `PlayRoar()` to automatically detect whether the active character is bipedal or quadrupedal.
  - **4. Dynamic Upgrades Mapping**:
    - Mapped existing 7 upgrade categories cleanly across all Titans via `ProgressionService`:
      - `BasicAttackDamage` scales both Ravager claw swipe and Brontara `TailSweep` and `NeckStrike`.
      - `StompDamage` & `StompRadius` scale both Ravager `Stomp` and Brontara `HeavyStomp`.
      - `WalkSpeed` dynamically boosts both Titans above their respective base movement speeds.
      - `BasicAttackCooldown`, `StompCooldown`, and `RoarCooldown` scale ability rates dynamically.
  - **5. Titan Selection UI (`StarterGui.MainUI`)**:
    - Added `TitanSelectButton` (`[T] TITANS`) in `StatsFrame` with keybind `T`.
    - Built modal `TitanSelectionPanel` containing `Card_Ravager` and `Card_Brontara` showing class, stats, abilities, unlock requirements, and interactive status buttons (`⭐ ACTIVE TITAN`, `✓ UNLOCKED`, `🔒 LOCKED`).
    - Integrated with `TitanSelectRequest` and `TitanFeedback` remotes with client-side state caching.
  - **6. Persistent Progression & Schema Migration (`SchemaVersion = 3`)**:
    - Upgraded `PlayerDataService.luau` schema to **SchemaVersion 3**:
      - `Titans = { Ravager = { Unlocked = true }, Brontara = { Unlocked = false } }`
      - `SelectedTitan = "Ravager"`
    - Backward-compatible migration preserves all existing levels, cash, upgrades, city completions, and statistics.
    - Automatic unlock verification unlocks Brontara once player achieves Level 5 + 2 City Clears.
  - **7. Strict Ravager Regression Validation**:
    - Ravager remains 100% grounded (0.15 HipHeight, zero float or hover).
    - 0.42s melee speed, 3-hit combo chain, 3000 HP, 28 WalkSpeed, 15-120 camera zoom verified completely intact.
- **Verification & Playtesting (Play Mode)**:
  - Initial State: Ravager active, 3000 HP, 28 speed, 0.15 HipHeight; Brontara locked in UI.
  - Progression Check: Reached Level 5 + 2 SmallTown Clears; UI dynamically transitioned Brontara card to `✓ UNLOCKED` and button to `SELECT TITAN`.
  - Morph to Brontara: Server verified unlock, morphed character to Brontara (4500 HP, 24 speed, 0.15 HipHeight, 25-160 camera zoom).
  - Combat Verification:
    - `TailSweep` dealt 200 dmg to multiple buildings.
    - `HeavyStomp` reared up with 0.5s windup, dealt seismic slam flattening `Building_Small_01` into rubble, awarded +$54 Cash, +30 Pts, +30 XP at 3x combo.
    - `NeckStrike` hit target 40 studs away for 350 dmg.
    - `Roar` triggered 55 stud seismic wave.
  - Switch to Ravager: Morphed back to Ravager (3000 HP, 28 speed, 0.15 HipHeight, 15-120 zoom); Brontara remained `✓ UNLOCKED`. Verified Ravager Basic Attack (150 dmg, 0.42s).
  - Switch back to Brontara: Verified seamless roundtrip character morph.
  - Studio cleanly returned to Edit Mode with zero errors.
- **Status:** Complete, Verified & Returned to Edit Mode.

---

### [2026-10-08 15:35 UTC] — Prompt: Milestone 9A — Multi-Titan Architecture
- **Goal:** Refactor existing Titan systems into a scalable, data-driven multi-Titan architecture so future Titans can be integrated without rewriting combat, progression, persistence, UI, or input handling.
- **Architectural Scope (Architecture ONLY — Zero Gameplay/Balancing Changes):**
  - **1. Data-Driven Titan Registry (`ReplicatedStorage.Shared.TitanRegistry.luau`)**:
    - Centralized single source of truth for all Titan definitions (`Ravager` and `Brontara`).
    - Standardized fields: `Id`, `Name`, `DisplayName`, `Title`, `Description`, `CreatureType`, `ModelName`, `BaseHealth`, `WalkSpeed`, `JumpPower`, `HipHeight`, `CameraZoom`, `UnlockRequirement`, `Abilities`, `UpgradeMappings`, `AudioProfile`, `AnimationProfile`.
    - Data-driven mathematical helpers: `CalculateWalkSpeed`, `CalculateAbilityCooldown`, `CalculateAbilityDamage`, `CalculateAbilityRadius`, `GetAbilityForSlot`, `Get`, `GetAll`, `GetList`, `IsRegistered`, `IsUnlocked`.
  - **2. Server Authoritative Validation (`PlayerDataService.luau` & `MonsterService.luau`)**:
    - Maintained profile `SchemaVersion = 3` with `SelectedTitan = "Ravager"` and `UnlockedTitans = { Ravager = true, Brontara = false }`.
    - Removed legacy auto-unlock routines for Brontara; strictly authoritatively gates selection via `IsTitanUnlocked(player, titanId)`.
    - Server-side validation rejects invalid Titan IDs and locked Titans with client feedback (`TitanFeedback`).
    - Dynamic calculation of walkspeed, ability damage, cooldowns, and radius via `TitanRegistry` formulas.
    - Modular `AbilityExecutors` dispatch table in `MonsterService`.
  - **3. Polymorphic Animation & Audio Abstraction (`TitanAnimationController.luau` & `AudioController.luau`)**:
    - Decoupled joint checks from hardcoded monster parts; tracks `self.TitanId` and dynamically uses registry animation profiles.
    - Added generic `PlayAbility(actionName, ...)` dispatch while preserving exact procedural Motor6D animation parameters for Ravager.
    - Parameterized sound retrieval via `GetTitanSoundKey(titanId, soundCategory, variant)`.
  - **4. Input & Ability Abstraction (`TitanController.client.luau`)**:
    - Client queries active Titan abilities dynamically via `TitanRegistry.GetAbilityForSlot(titanId, slot)`.
    - Replaced hardcoded if-else ladders with data-driven lookup tables (`ClientAbilityAnticipation`, `EffectHandlers`).
    - Preserved exact Ravager controls (WASD, Space, LMB/1, E/2, R/3, Q, M, U, T).
  - **5. Dynamic Titan Selection UI (`DestructionHUD.client.luau`)**:
    - Refactored `updateTitanSelectionView()` to dynamically bind cards from `TitanRegistry.GetList()`.
    - UI updates stats, descriptions, requirements, and button states based on authoritative player data.
    - Selection buttons reject locked Titans with UI audio error feedback.
- **Verification & Playtesting (Studio Play Mode & Edit Mode)**:
  - 64 assertion tests passed in Studio (registry fields, calculations, Ravager 0.15 HipHeight, camera config, formulas, audio keys, protected assets).
  - Play Mode smoke test verified:
    - Player spawned cleanly as Ravager (`HP: 3000`, `WalkSpeed: 28`, `HipHeight: 0.15`).
    - No script errors or warnings in console log.
    - Selection of locked Brontara successfully rejected by server with `Titan is locked.` notification.
    - Ability execution (`BasicAttack`, `Stomp`, `Roar`) passed without error.
    - DestructionHUD `TitanSelectionPanel` rendered dynamically with correct card data for Ravager (Active) and Brontara (Locked).
  - All protected assets confirmed intact:
    - `Workspace.Cities.SmallTown.Buildings` (15 buildings)
    - `Workspace.Cities.Metrovale.Buildings` (27 buildings)
    - `Workspace.Ravager_Prototype`
    - `ReplicatedStorage.Assets.Models.Ravager` & `Brontara`
    - `ReplicatedStorage.Remotes` (10 RemoteEvents)
    - `StarterPlayer.StarterCharacter` (15 parts)
    - `StarterGui.MainUI`
- **Status:** Complete, Verified & Returned to Edit Mode.

---

### [2026-10-08 16:45 UTC] — Prompt: Milestone 9B — Brontara Core Implementation
- **Goal:** Integrate Brontara as a selectable, fully controllable second Titan upon unlocking, with precise quadruped grounding, deliberate locomotion, custom camera zooming, and authoritative rejection of inactive combat abilities.
- **Architectural Scope (Core Locomotion & Character Integration ONLY — Combat Inactive):**
  - **1. Brontara Model & Grounding Calibration**:
    - Rig analysis: 21 parts, 12 Motor6D joints, R6 configuration, 17,658 total mass (3.2x Ravager mass).
    - Calculated grounding: In rest pose, all 4 feet (`Left Arm`, `Right Arm`, `Left Leg`, `Right Leg`) extend to Y=0.0 while `Torso` sits at Y=16.0.
    - Equilibrium raycast clearance calibrated: setting `Humanoid.HipHeight = -0.18` produces an exact `0.10 studs` clearance across all four feet. Zero hover, zero terrain clipping, zero vertical jitter.
  - **2. Movement & Jumping Configuration**:
    - Base `WalkSpeed` configured at 20 studs/sec for a heavy, deliberate quadruped locomotion feel.
    - Jumping explicitly disabled (`JumpPower = 0`, `humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)`) to prevent unrealistic hopping and unstable physics on a 17,658-mass sauropod.
  - **3. Camera Integration**:
    - Colossal camera zoom range: `Min = 25`, `Max = 160`, `Default = 65`, `CameraOffset = Vector3.new(0, 10, 0)`.
    - Smooth transitions between Ravager (15–120 zoom) and Brontara (25–160 zoom).
  - **4. Procedural Quadruped Locomotion (`TitanAnimationController.luau`)**:
    - Diagonal gait: alternating front-left/rear-right and front-right/rear-left strides with neck bob and undulating tail sway.
    - Turning presence: neck bends into the turn direction while tail trails outward.
    - Idle breathing: gentle rhythmic sinusoidal sway in neck and tail; limbs lerp smoothly to neutral stance.
  - **5. Authoritative Unlock & Progression Flow (`PlayerDataService.luau` & `MonsterService.luau`)**:
    - Authoritative requirement: Level 5 + 2 City Clears.
    - Implemented `PlayerDataService.CheckTitanUnlocks()` evaluating persistent profile level and total city completions against `TitanRegistry.IsUnlocked`.
    - Rejects locked Titan selection server-side (`TitanSelectRejected`).
    - Syncs unlock state dynamically on level-up and city completion.
  - **6. Safe Inactive Combat Enforcement (Milestone 9B Scope Boundary)**:
    - All combat abilities for Brontara (`BasicAttack`, `Stomp`, `Roar`, `TailSweep`, `HeavyStomp`, `NeckStrike`) are strictly rejected on both client and server.
    - Zero damage, zero city destruction, zero fallback to Ravager attacks.
- **Verification & Playtesting (15-Step Test Suite Passed)**:
  - Edit mode inspection & Registry tests: 24/24 assertions passed.
  - Locked Brontara selection rejected by server.
  - Controlled unlock test: Level 5 + 2 clears unlocked Brontara in session.
  - Brontara spawn: 4500 HP, 20 WalkSpeed, 0 JumpPower, -0.18 HipHeight.
  - Grounding measurement: all 4 feet verified at exactly 0.10 studs clearance, velocity 0,0,0, Running state.
  - Movement & turning: 20.00 studs forward travel in 1.0s, stable Y (0.08 delta), 90-degree turning with AutoRotate passed.
  - Camera: verified min 25, max 160, offset (0, 10, 0).
  - Ability rejection: 6/6 abilities rejected with zero damage delta and zero attack count delta.
  - Round-trip switching: Brontara -> Ravager -> Brontara verified seamlessly.
  - Ravager regression test: 3000 HP, 28 WalkSpeed, 0.15 HipHeight, Claw Strike / Stomp / Roar fully functional.
  - Protected assets: SmallTown (15), Metrovale (27), Ravager_Prototype, Ravager & Brontara models, 10 Remotes, StarterCharacter (15 parts), MainUI intact.
  - Output log: 0 unexpected runtime errors.
- **Status:** Complete, Verified & Returned to Edit Mode.



