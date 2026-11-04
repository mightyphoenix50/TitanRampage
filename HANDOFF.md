# Titan Rampage — Agent Handoff & Continuity Brief

> **Source Session ID:** `e61117e8-8291-4737-8abb-736aedd82200`  
> **Workspace:** `C:\RobloxProjects\TitanRampage`  
> **Place ID:** `131002954769216`  
> **Git Baseline:** Milestone 12.2 + maintenance PR #1 complete; Milestone 13 in progress on `feat/milestone-13-audio`  
> **Date Updated:** October 29, 2026  

---

## 1. Project Overview & Architecture State

**Titan Rampage** is a physics-driven, multiplayer Kaiju combat and destruction game on Roblox Studio. Players choose between titans (such as **Ravager** and **Brontara**) to fight in destructible urban environments (Metrovale, SmallTown) and test abilities in the **Grand Volcanic Kaiju Sanctuary**.

### Key Architectural Pillars
- **Rojo Project Layout:** Managed via `default.project.json` mapping `src/` to `ReplicatedStorage.Config`, `ReplicatedStorage.Shared`, `ServerScriptService`, `StarterGui.MainUI`, and `StarterPlayer.StarterPlayerScripts`.
- **Titan Registry & Models:** Located in `ReplicatedStorage.Assets.Models` (`Brontara` and `Ravager`).
- **Guaranteed Master Initial Spawning:** `Workspace.KaijuHub.HubSpawnLocation` at $(0, 524, -5000)$ on the Central Raised Dais is the exclusive player spawn. Stray spawns in Workspace root are permanently eliminated. `MonsterService.luau` tracks session initial spawns to enforce Hub spawn on join.
- **Grand Volcanic Kaiju Megastructure:** Located at high altitude `(0, 520, -5000)` spanning **over $850\text{–}900\text{ studs}$ across** with 539 descendants across 4 distinct elevation tiers:
  - **Tier 1: Grand Central Plaza ($Y = 520$)**: $380\text{ studs}$ dia, 4 concentric magma rings, central dais, flame core, permanent `MerchantPavilion`, and `AltarOfAscension`.
  - **Tier 2: The Hall of Titans ($Y = 540$)**: $280 \times 140\text{ studs}$ amphitheater, 8 monumental columns with Tesla lightning conductors, 1:1 display statues with dual spotlights and 3D stat cards.
  - **Tier 3: The Stargate Promontory ($Y = 560$)**: $260 \times 120\text{ studs}$ high ridge, $42\text{ studs}$ tall runic stargates (`Portal_SmallTown`, `Portal_Metrovale`) with lightning coils and electric storm fields.
  - **Tier 4: The Colosseum Proving Grounds ($Y = 480$)**: $360 \times 360\text{ studs}$ sunken arena (sunken 40 studs), 45-stud walls, 46-stud wide bridge ($170\text{ studs}$ long), Bastion Titan DPS dummy, and 5 practice monoliths.
  - **Caldera Vista & Launch Pads**: 16 towering jagged perimeter basalt spires at **$460\text{ studs}$ radius** (heights up to $320\text{ studs}$), 4 colossal cardinal skybeams ($1600\text{ studs}$ tall), and 4 scaled jump pads.
- **Volcanic Thunderstorm Engine:** Dynamic background lightning simulation in `HubService.luau` striking 27 designated caldera targets every $3.5\text{ to } 6.5\text{ seconds}$ with segmented jagged neon lightning bolts, full-sky illumination flashes (`Lighting.Brightness` spikes $2.2 \to 3.8$), contact impact spark bursts, and spatial thunder rumbles (`impact_explosion_03.mp3`).
- **Monetization Engine:** Server-authoritative `MonetizationService.luau` handling `MarketplaceService.ProcessReceipt` idempotently, caching Gamepass ownership, managing multipliers (DoubleCash, DoubleXP), and rendering tabbed `ShopHUD` alongside the physical `MerchantPavilion` kiosk in the hub.
- **Titan Sprint System:** High-impact sprint mode (WalkSpeed $28 \to 44$ for Ravager, $18 \to 28$ for Brontara) with stamina gauge, dynamic FOV punch ($70^\circ \to 82^\circ$), and mobile touch support.

---

## 2. Status & Recent Accomplishments

### Completed Up to Milestone 12.1
- **Milestone 12 (Production Monetization, City Lighting Overhaul, and Titan Sprint System):**
  - Full server-authoritative monetization (5 Gamepasses, 5 Developer Products, receipt idempotency, `ShopHUD`, and `MerchantPavilion`).
  - Lighting overhaul in SmallTown (sunny coastal afternoon $ClockTime = 14.2$) and Metrovale (golden hour $ClockTime = 16.5$).
  - Titan sprint system with stamina bar UI and camera FOV punch.
- **Milestone 12.1 (Grand Hub Megastructure, Volcanic Thunderstorm Engine, and Guaranteed Master Hub Spawning):**
  - **Guaranteed Master Initial Spawning**:
    - Deleted rogue `Workspace.SpawnLocation` at $(0, 0.5, 0)$.
    - Configured `Workspace.KaijuHub.HubSpawnLocation` as the sole active spawn in the DataModel.
    - Updated `MonsterService.luau` to enforce `HubSpawnLocation` on initial session spawn.
    - Updated `CityService.luau` to dispatch `KaijuHub` lighting profile immediately on player join.
  - **Megastructure Spatial Expansion (2x Area Expansion)**:
    - Expanded Central Plaza from 220 to 380 studs diameter.
    - Expanded Hall of Titans from 160x80 to 280x140 studs.
    - Expanded Stargate Promontory from 150x60 to 260x120 studs with 42-stud tall stargate arches.
    - Expanded Colosseum Proving Grounds from 200x200 to 360x360 studs (sunken 40 studs).
    - Expanded Caldera Vista from 12 to 16 basalt spires at 460 studs radius (up to 320 studs tall).
    - Outfitted 68 Tesla lightning conductor rods with neon cyan insulators and electric arc emitters across all columns, skybeams, stargates, and monoliths.
  - **Volcanic Thunderstorm Engine**:
    - Integrated procedural multi-segmented jagged lightning bolts striking 27 caldera targets every 3.5–6.5s.
    - Full-sky illumination brightness flashes (`Lighting.Brightness` spikes to 3.8 and decays back to 2.2).
    - Impact flash spheres, 40-spark electric particle bursts, and spatial thunder clap audio.
  - **Live In-Studio Playtest Verified**: Spawning at `(0, 540.40, -5000)` on Central Dais, thunderstorm strikes running continuously with 0 audio or script errors, and all 539 descendants intact in Edit mode.
- **Milestone 12.2 (Proving Grounds Lighting, Cinematic Lightning, Cash Drops & Combat VFX):** Colosseum floodlights and runes, reworked lightning bolts and quieter thunder, physical cash drops (`DropService`) with `AutoCollect` vacuum pull, and attack/building particle effects.
- **Maintenance (PR #1, 2026-10-28):** Closed the free-gamepass exploit (`HandleSandboxBuy` is Studio-only), fixed the titan-switch cooldown crash and Brontara `animState` scope bug, and added Rokit, selene, StyLua and GitHub Actions CI.

---

## 3. World & Asset Specifications

| Asset / Structure | Location | Position / Anchor | Bounding Dimensions (Studs) | Properties / Settings |
| :--- | :--- | :--- | :--- | :--- |
| **`PlazaFloor`** | `KaijuHub.GrandCentralPlaza` | `(0, 516, -5000)` | $380 \times 8 \times 380$ | Basalt disc, 4 concentric magma rings |
| **`HubSpawnLocation`**| `KaijuHub` | `(0, 524, -5000)`| $28 \times 1.5 \times 28$ | Exclusive master spawn, 0 duration forcefield |
| **`MagmaFlameCore`** | `KaijuHub.GrandCentralPlaza` | `(0, 532, -5000)` | $6 \times 18 \times 6$ | Crystalline magma core, flame emitter |
| **`MerchantPavilion`**| `KaijuHub.GrandCentralPlaza` | `(95, 520, -4940)` | $28 \times 20 \times 28$ | 24-part trading kiosk, ProximityPrompt, 3D Billboard |
| **`AltarOfAscension`**| `KaijuHub.GrandCentralPlaza` | `(0, 520, -4860)` | $26 \times 36 \times 26$ | Progression shrine, lightning conductor |
| **`TerraceFloor`** | `KaijuHub.HallOfTitans` | `(0, 536, -5140)` | $280 \times 8 \times 140$ | Elevated North terrace, 10 sweeping steps |
| **`Pillars` (x8)** | `KaijuHub.HallOfTitans` | Various | $12 \times 64 \times 12$ | Obsidian columns with Tesla lightning conductors |
| **`Pedestal_Ravager`** | `KaijuHub.HallOfTitans` | `(-75, 542, -5140)`| $34 \times 4 \times 34$ | 1:1 Ravager Statue, Underglow, 3D Holo Card |
| **`Pedestal_Brontara`**| `KaijuHub.HallOfTitans` | `(75, 542, -5140)` | $38 \times 4 \times 38$ | 1:1 Brontara Statue, Underglow, 3D Holo Card |
| **`PromontoryFloor`** | `KaijuHub.StargatePromontory` | `(0, 556, -4820)` | $260 \times 8 \times 120$ | Elevated South ridge, 14 ascending steps |
| **`Portal_SmallTown`** | `KaijuHub.StargatePromontory` | `(-70, 560, -4820)`| $38 \times 42 \times 8$ | 42-stud Runic Arch, Cyan Stargate, Tesla coil |
| **`Portal_Metrovale`** | `KaijuHub.StargatePromontory` | `(70, 560, -4820)` | $38 \times 42 \times 8$ | 42-stud Runic Arch, Violet Stargate, Tesla coil |
| **`ColosseumFloor`** | `KaijuHub.ColosseumProvingGrounds` | `(0, 475, -5420)` | $360 \times 10 \times 360$ | Sunken battle pit (40 studs below Plaza) |
| **`Bastion_Titan_Dummy`**| `KaijuHub.ColosseumProvingGrounds` | `(0, 480, -5420)`| $16 \times 45 \times 16$ | `IsTrainingDummy = true`, 50k HP, Live DPS GUI, Lightning Rod |
| **`PracticePillars` (x5)**| `KaijuHub.ColosseumProvingGrounds` | Various | $10 \times 38 \times 10$ | `IsTrainingDummy = true`, 10k HP each, Tesla conductors |
| **`ColosseumBridge`** | `KaijuHub.ColosseumProvingGrounds` | `(0, 500, -5215)` | $46 \times 5 \times 170$ | Grand descending bridge connecting Plaza to Arena |
| **`LaunchPads` (x4)** | `KaijuHub.LaunchPads` | Various | $22 \times 1.6 \times 22$ | Magma boost pads, scaled velocity impulses |
| **`CalderaVista` (x16)**| `KaijuHub.CalderaVista` | 460-stud radius | $24 \times (180\text{-}320) \times 24$ | Basalt spires with lightning conductor summits |

---

## 4. Immediate Next Steps / Roadmap

### Open follow-ups from Milestone 15
- **Import the boss and bag meshes:** FBX files in `C:\Tools\TitanRampage-BlenderMCP\tests\Milestone15\` (CinderWarden, StormcoilSerpent, ObsidianColossus, PunchingBag). Import with Studio's 3D Importer, then turn each into a `ReplicatedStorage.Assets.Bosses.<BossId>` template (colour the Body/Armor/Glow parts, set the PrimaryPart). `BossService` uses a part-built stand-in until then.
- **Boss audio:** roars, telegraph warning tones, victory sting, punching-bag thuds and chain rattles (licensed ProSoundEffects only).
- **Untested in a full fight:** Stormcoil Serpent lanes and the Obsidian Colossus shield phase; a two-client test of the shared rewards and the boss party.
- **Hall of Titans trophies** for first clears (titles only for now).

### Done: Milestone 15 — Boss Fights, Titan Power & Training, Cash-Only Economy
Destroying cities currently has no goal beyond upgrades. This milestone adds one: bosses in the Colosseum that only a titan built up by destroying cities can beat. It also adds hub **Titan Punching Bags** for light training power, tuned so city destruction always wins, and drops Destruction Points so cash is the only currency.

Findings behind the plan (2026-11-04):
- Points are a second upgrade currency: every `UpgradeConfig` tier has a `PointCost` (about half its `CashCost`). They are also awarded on building destruction (`DestructionService`), city completion (`CityConfig.CompletionReward.DestructionPoints` 500 / 1250), and hub dummies (`HubService`). They show in `PointsLabel` and are stored as `DestructionPoints` plus `Statistics.TotalPointsEarned` (`PlayerDataService`, schema v4).
- Nothing ever damages a titan: `Humanoid.Health` is only set on spawn. Bosses need a titan combat-health system.
- The Colosseum Proving Grounds is a DPS dummy (`Bastion_Titan_Dummy`, 50k HP) and five 10k-HP practice monoliths, with no goal or reward.
- The Altar of Ascension prompt fires `ProgressionUpdate("OpenAscensionAltar")`, but no client script handles it, so it's another dead prompt.
- Brontara unlocks at Level 5 + 2 city clears (`TitanRegistry.UnlockRequirement`).

**Design rules**
- **Titan Power** is one server-computed number per titan, shown in the HUD and on boss gates:
  - Titan base (Ravager 100, Brontara 140)
  - \+ 12 per upgrade level bought (max +336 from 7 categories × 4)
  - \+ 8 per player level above 1
  - \+ Training Power
  - It's derived from saved data and never stored, so it can't drift.
- **City destruction is the main path to Power.** Punching-bag output is capped by city progress, and the cap and rate are checked by a simulation in step 9.
- **Server authority:** boss HP, boss attacks, titan damage, training progress and all rewards are decided on the server. Clients only render and ask.

**Steps**
0. **Cash-only economy (do first; touches everything else):**
   - Remove `DestructionPoints` from rewards, `ProgressionService` costs, `UpgradeConfig` (`PointCost` fields), `CityConfig.CompletionReward`, hub dummy attributes, the HUD `PointsLabel`, and the upgrade and city cards.
   - Keep upgrade `CashCost` as is; points were a parallel half-price gate, so cash alone is the same pace.
   - Bump `CURRENT_SCHEMA_VERSION` 4 → 5 with a migration that converts leftover `DestructionPoints` to cash 1:1 and drops `TotalPointsEarned`. Respect the `isLoadFailed` lock.
0b. **Multiplayer cities (`CityService`, `DestructionService`):**
   - **Shared building rewards:** track damage per player on each building, and on collapse split its cash and XP by damage share among everyone who dealt at least 10%. The combo multiplier is applied per player. This replaces last-hit-takes-all.
   - **Both cities active at once:** replace the single `activeCityName` with per-city state (building lists, run stats, completion), so a portal trip only moves that player. Each player's run is tracked in the city they're in. Rebuilding a city resets only that city and requires the players there to agree (or the city to be fully cleared).
   - Verify with a 2-player Studio test server (Test → Clients and Servers): both players hitting one building, and players in different cities at the same time.
1. **Titan Power (`TitanPowerService` [NEW] or a `ProgressionService` helper, shared formula in `TitanRegistry`):**
   - Computes Power on demand and replicates it via a `TitanPower` player attribute.
   - HUD shows "⚡ Power 340" under the level.
   - The upgrade panel shows "+12 Power" per purchase.
2. **Titan health in combat (`MonsterService`):**
   - Boss attacks damage the titan's Humanoid (titan `BaseHealth` 3000 / 4500, scaled +5% per upgrade level).
   - At 0 HP the titan is knocked out: brief ragdoll/dust, then respawns at the hub with no cash loss.
   - Health only drops inside a boss arena; cities and the hub stay safe.
   - Health bar in the HUD while in a fight.
3. **Boss framework (`BossService` [NEW], `BossConfig` [NEW], `BossHUD` client [NEW]):**
   - One fight at a time per server in the Colosseum. Players inside the arena ring when it starts join the party.
   - Boss HP = base × (1 + 0.6 × (party size − 1)).
   - Telegraphed attacks: red ground decals with a 1.2 s wind-up, then server overlap checks for damage.
   - Phases at 66% and 33% HP, and a 3-minute enrage timer (fight fails).
   - Bosses take damage from the existing ability code through a `BossTarget` entry in `CityService.GetBuildingsInRadius`-style lookups, with no tier multiplier and per-ability caps validated like buildings.
   - Damage to the boss reuses `DebrisController`-style hit chips and camera shake.
4. **Three original bosses (`BossConfig`):**

   | Boss | Requires | HP (solo) | Signature attacks | First clear | Repeat (10-min cooldown) |
   | --- | --- | --- | --- | --- | --- |
   | **Cinder Warden** (lava golem) | Power 300 + 1 SmallTown clear | 25,000 | Slam rings, magma pools | $5,000 | $1,250 |
   | **Stormcoil Serpent** (lightning eel) | Power 550 + 1 Metrovale clear | 60,000 | Lightning lanes, coil sweep, adds | $12,000 | $3,000 |
   | **Obsidian Colossus** (armoured giant) | Power 850 + 5 total city clears | 140,000 | Shield phase (stomps only), quake waves, enrage | $25,000 | $6,000 |

   - Models built from parts or meshes in Studio under `ReplicatedStorage.Assets.Bosses`, matching the titans' blocky style.
   - Rewards are cash only. First clears also add a trophy to the Hall of Titans and a "Boss Slayer" title.
   - Defeating the Cinder Warden is an alternate Brontara unlock (alongside Level 5 + 2 clears).
   - Rewards are split evenly among party members who dealt at least 5% of the damage, so leechers get nothing.
5. **Proving Grounds overhaul (Studio + `HubService` retrofit):**
   - A boss gate in the Colosseum with a readiness board: each boss's Power and clear requirements, ticked or crossed for the viewing player, with a "Challenge" prompt (F) enabled only when the player qualifies.
   - An arena ring that marks who's in the party, and spectator terraces on the rim.
   - The Bastion dummy becomes a "Boss Readiness Test": a 20-second DPS run whose result is compared to each boss's recommended DPS.
   - Practice monoliths rebuild themselves 10 s after breaking.
   - Fix the dead Altar of Ascension: it opens the upgrade panel and shows Power.
6. **Titan Punching Bags (hub, `TrainingService` [NEW], `TrainingConfig` [NEW]):**
   - Three titan-sized punching bags hanging from chains next to the Hall of Titans: Basic / Reinforced / Magma.
   - Hitting one with your normal abilities grows **Training Power**. Each ability hit on a bag counts once, validated through the existing ability cooldowns and reach checks, so macro-spamming can't beat the cooldown.
   - The bag swings on its chain (client-side), flashes and shows "+0.4 TP" numbers.
   - Each Training Power point also gives +0.25% ability damage, so it's real strength, not just a gate.
   - **Anti-AFK and balance:**
     - Rate drops as Training Power nears the cap: rate × (1 − TP / cap).
     - **Cap** = 40 + 15 per total city clear (max 160), so only destroying cities raises it.
     - Bags need real hits, so standing still earns nothing. Hits on the same bag earn less after 60 s of continuous hitting until the titan hits something else (anti-macro).
     - It never gives cash or XP.
     - Better bags need Power 250 / 500 (from upgrades) and only raise TP per hit, not the cap.
   - Targets: Basic bag ≈ 4 Power/min of steady hitting at 0 TP; a full SmallTown clear (~2.5 min) ≈ 2–4 upgrades ≈ +24–48 Power + 15 cap.
   - Bag swing and dent animation, a heavy punch thud, and a progress meter toward the cap.
7. **Rewards wiring and data:**
   - `PlayerDataService` profile gains `TrainingPower`, `BossClears = { [bossId]: { Clears, LastClearAt } }` and `Titles`.
   - These go in the same v5 migration as step 0 (one bump, not two).
   - Boss cash goes through `ProgressionService.AddRewards`, so the `DoubleCash` gamepass applies.
7b. **Better assets (Blender first, Fab where the licence is clear):**
   - **Blender (via the Blender MCP)** for the three bosses and the punching bags. These are hero assets that should match the titans' style.
     - Budget: ≤ 10k triangles per mesh (Roblox's hard cap is ~20k), 1024² PBR maps in a `SurfaceAppearance`, PNG textures (TGA has a loading bug).
     - Export FBX/OBJ in metres, import through Studio's 3D Importer (scripts can't upload meshes), and keep `.blend` sources under `C:\Tools\TitanRampage-BlenderMCP\`.
   - **Fab.com** only for environment dressing (rocks, lava, ruins, city props), and only after checking each item's licence:
     - Read the current Fab Standard License EULA for non-Unreal engines.
     - Skip anything marked Unreal-only.
     - Check whether uploading to Roblox, where asset IDs can be reused by others, counts as distributing the raw files.
     - Record the source and licence of every imported asset in a `docs/ASSET_CREDITS.md`.
8. **Audio and VFX:** licensed ProSoundEffects only:
   - Boss roars, impacts, telegraph warning tones, a victory sting and punching-bag thuds and chain rattles.
   - Engine stand-ins where nothing licensed exists, noted in the changelog.
9. **Balance check + wrap-up:**
   - A Studio simulation script compares 10 minutes of SmallTown destruction against 10 minutes of steady hitting on the Basic punching bag, from a fresh profile and a mid profile (Power ~300).
   - Destruction must give at least 3× more Power per minute, and the bags can't reach any boss requirement on their own.
   - Play-test each boss solo at its required Power, check rewards, cooldown and data migration on an old v4 profile, then `rojo build`, `selene`, `stylua`, CHANGELOG entry and PR.

### Open follow-ups from Milestone 14
- **Sounds still on engine stand-ins:** progression (`RewardEarned`, `LevelUp`, `Combo_*`), UI clicks, `CityComplete`, `ShopPurchase`, `ShopPowerSurge`. The Creator Store search found no ProSoundEffects/Roblox-licensed matches; upload owned sounds or license some.
- **Listening pass** on every library sound (needs a human ear).
- **Ravager ChestPlate** brushes the right leg for ~0.3 s during the stomp; nudge its weld offset if it's visible.
- **Hub:** further set dressing (banners, braziers, signposts toward portals/hall/colosseum) if the new look still feels sparse in play.

### Done: Milestone 14 — First-Session Feel: Faster, Juicier Destruction + World Cleanup
The first few minutes decide whether a player stays. Right now a Tier 3 tower takes ~47 basic hits (~37 s) and a landmark ~125 hits (~98 s), a collapse is a quiet sink-and-fade, the hub's awaken prompts seem dead, and the world has leftover test geometry. This milestone fixes the pacing and payoff, then cleans up the world and the open audio follow-ups.

Findings behind each step (2026-10-31):
- `DestructionConfig.BasicAttackDamage` is 150/100/75/60 by tier against building `MaxHealth` 450–7500 (SmallTown avg 1094 over 15 buildings, Metrovale avg 1977 over 27); Ravager's basic attack cooldown is 0.78 s.
- `executeControlledCollapse` tweens `MainBody`/`Roof` down 0.85 s and fades them out; no debris is thrown.
- The pedestal prompts do reach `MonsterService.SelectTitan`, but nothing on the client handles `TitanSelectRejected` (locked, spawn in progress), and picking the titan you already are respawns you in place, so both cases look like nothing happened.
- The "giant cube" is `Workspace.Milestone10_1_TestCube`, a 200³ MeshPart at (-100, 181, 15) left from Milestone 10.1.
- Terrain under SmallTown is `Grass` right up to the street surface (y ≈ 0); grass decoration blades poke through the flat road, sidewalk and plot parts sitting on it. Metrovale's ground is `Pavement`, so it doesn't happen there.
- SmallTown (x −135…135) and Metrovale (x 1010…1390) are ~900 studs apart on the same open terrain, so towers are visible from the other city.

0. **Save + cleanup (Studio, owner approval for deletes):** save the place (the Brontara mesh fix is only in the open session); delete `Workspace.Milestone10_1_TestCube`, `Workspace.Ravager_Prototype` and `ServerStorage.PreHubRevamp_Backups` (also removes the seven dead `file://` meshes in it).
1. **Faster destruction (`DestructionConfig`, building attributes):** retune so base-level titans drop a small building in ~2 hits, medium ~4, large ~7, landmark ~15 (≈1.5 / 3 / 5.5 / 12 s of basic attacks). Do it with damage values in code rather than editing 42 `MaxHealth` attributes, so upgrades keep scaling from it. Check upgrade levels still feel meaningful and cash-per-minute in `ProgressionService` doesn't explode; adjust rewards if it does.
2. **More satisfying destruction (client VFX, no new remotes):** on `BuildingDestroyed`, break the building into 8–20 client-side debris chunks (sized from `MainBody`, coloured to match) that get an outward/upward impulse, tumble, then fade after ~4 s; bigger dust burst and screen shake scaled by tier; a short hit-stop and floating damage numbers on hits; stronger cracking/scorch stages as HP drops. Keep the server's non-destructive hide/restore so `ResetCity` still works, and cap debris count per client for performance.
3. **Awaken button (`MonsterService`, `DestructionHUD`):** show a toast for `TitanSelectRejected` with the reason (locked titans say how to unlock); if the titan is already active, say so instead of respawning; add a short awaken flash/roar so success is obvious. Confirm the preserved hub's prompts still carry the right `ObjectText`.
4. **Grass clipping (Studio terrain):** repaint terrain under SmallTown's city footprint (plus a small margin) from `Grass` to `Ground`/`Pavement`, or drop it 1 stud below the street parts; keep grass in parks and outside the town.
5. **Keep towns out of sight (Studio terrain):** done with a ~260-stud ridge between the towns at x ≈ 600 (ending in a sea headland) instead of moving Metrovale, which keeps its coast, quay and `CityConfig` untouched.
6. **Hub look pass (Studio, `HubService` retrofit):** a consistent material/colour palette, better lighting (hub `LightingProfile`, bloom, colour correction), signposting toward the portals, hall and colosseum, more set dressing (banners, braziers, rock formations, lava flows), and fixes for anything that looks unfinished up close. Screenshot before/after.
7. **Audio follow-ups (`AudioConfig`):** footsteps quieter (start at about half the current `Volume`: Ravager 0.60 → ~0.30, Brontara 0.80 → ~0.40, and a smaller sprint boost); a full listening pass on every library sound; replace the remaining engine stand-ins (progression `RewardEarned`/`LevelUp`/`Combo_*`, UI clicks, `CityComplete`, `ShopPurchase`/`ShopPowerSurge`, hub thunder) with licensed library or owned sounds; add sounds for the new debris (impacts, glass).
8. **Ravager ChestPlate:** nudge the weld offset if the ~0.3 s brush against the right leg during the stomp is visible.
9. **Wrap-up:** `rojo build`, `selene`, `stylua`, full play-test (time-to-destroy per tier, first 5 minutes of a fresh profile), CHANGELOG entry, PR.

Still blocked on the owner: monetization `AssetId`s (see Before publishing).

### Done: Milestone 13 — Sound Design + Armor Check
Every sound in `AudioConfig.luau` is still a stand-in built on 4 engine sounds (`rbxasset://sounds/...`), and the Milestone 10.4 armor is already welded onto the production titan models, so this milestone is mostly real audio plus checking the armor holds up in combat.

0. **Cleanup:** changelog entries for 12.2 and PR #1 (done); remove stray `Workspace.Ravager_Prototype` and old `ServerStorage` backup folders (only with the owner's approval).
1. **Real sound effects:** replace the stand-ins with free, Roblox-licensed **ProSoundEffects** library sounds. The real ID goes in `SoundId`; the engine sound stays as a fallback. Avoid unlicensed uploads ripped from other games.
2. **Sprint footsteps:** stride-synced steps per titan (Ravager sharper, Brontara heavier), pitch and volume scaling with speed, light camera shake for the local player. Each client plays them for nearby titans from the `IsSprinting` attribute; no new remotes.
3. **Shop sounds:** cash-register chime and power-surge hum on `ShopFeedback` `PurchaseSuccess`; clicks on shop open and tab change.
4. **City ambience:** an `Ambience` sound group and per-city `AmbientLoop` (SmallTown ocean breeze and town hum, Metrovale sirens and city drone, Hub volcanic rumble), crossfaded on `CityLightingChanged`.
5. **Armor check:** run Ravager's claw combo and stomp+roar, and Brontara's heavy stomp against `Bastion_Titan_Dummy`, with armor on; check clipping, weld breakage and physics; fix offsets if needed.
6. **Wrap-up:** `rojo build`, `selene`, `stylua`, full play-test, CHANGELOG entry, PR.

### Before publishing
- Fill in every `AssetId` in `MonetizationConfig` (all `0` until the passes and products exist on the Creator Dashboard).
