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

### In progress: Milestone 13 — Sound Design + Armor Check
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
