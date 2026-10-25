# Titan Rampage — Agent Handoff & Continuity Brief

> **Source Session ID:** `e61117e8-8291-4737-8abb-736aedd82200`  
> **Workspace:** `C:\RobloxProjects\TitanRampage`  
> **Place ID:** `131002954769216`  
> **Git Baseline:** Milestone 12 Complete  
> **Date Updated:** October 25, 2026  

---

## 1. Project Overview & Architecture State

**Titan Rampage** is a physics-driven, multiplayer Kaiju combat and destruction game on Roblox Studio. Players choose between titans (such as **Ravager** and **Brontara**) to fight in destructible urban environments (Metrovale, SmallTown) and test abilities in the **Grand Volcanic Kaiju Sanctuary**.

### Key Architectural Pillars
- **Rojo Project Layout:** Managed via `default.project.json` mapping `src/` to `ReplicatedStorage.Config`, `ReplicatedStorage.Shared`, `ServerScriptService`, `StarterGui.MainUI`, and `StarterPlayer.StarterPlayerScripts`.
- **Titan Registry & Models:** Located in `ReplicatedStorage.Assets.Models` (`Brontara` and `Ravager`).
- **Safety & Baseline Mechanism:** Pre-milestone snapshots archived in `ServerStorage.PreMilestone12_Backups` (`KaijuHub_Pre12`, `SmallTown_Pre12`, `Metrovale_Pre12`, `Brontara_Pre12`, `Ravager_Pre12`).
- **Grand Volcanic Kaiju Sanctuary:** Located at high altitude `(0, 520, -5000)` spanning over $450\text{ studs}$ across 4 distinct elevation tiers: Grand Central Plaza, Hall of Titans, Stargate Promontory, and Colosseum Proving Grounds.
- **Monetization Engine:** Server-authoritative `MonetizationService.luau` handling `MarketplaceService.ProcessReceipt` idempotently, caching Gamepass ownership, managing multipliers (DoubleCash, DoubleXP), and rendering tabbed `ShopHUD` alongside the physical `MerchantPavilion` kiosk in the hub.
- **Atmospheric & Lighting System:** Dynamic zone-based lighting profiles in `CityConfig.luau` tweened smoothly on client via `LightingController.client.luau` ($ClockTime = 14.2$ in SmallTown, $16.5$ golden hour in Metrovale, and $18.25$ volcanic twilight in Kaiju Hub).
- **Titan Sprint System:** High-impact sprint mode (WalkSpeed $28 \to 44$ for Ravager, $18 \to 28$ for Brontara) with stamina gauge, dynamic FOV punch ($70^\circ \to 82^\circ$), and mobile touch support.

---

## 2. Status & Recent Accomplishments

### Completed Up to Milestone 12
- **Milestone 11.1 (Grand Volcanic Kaiju Sanctuary Revamp):**
  - Expanded hub from a flat 120-stud disc to a 450+ stud 4-tier Sanctuary (251 descendants).
  - 1:1 scale static display statues of Ravager and Brontara mounted on elevated pedestals with dual-source lighting and 3D holographic stat cards.
  - Bastion Titan DPS dummy (50,000 HP, rolling 3-second DPS meter, combo indicator) and directional Titan Magma Launch Pads.
- **Milestone 12 (Production Monetization, City Lighting Overhaul, and Titan Sprint System):**
  - **City Lighting Overhaul**:
    - Created `LightingController.client.luau` smoothly tweening `ClockTime`, `Brightness`, `OutdoorAmbient`, and `Atmosphere` over $1.2\text{ seconds}$ upon city changes.
    - Configured bright sunny coastal afternoon in SmallTown ($ClockTime = 14.2$, $Brightness = 2.4$) and metropolitan golden hour in Metrovale ($ClockTime = 16.5$, $Brightness = 2.2$).
    - Outfitted streetlamps with warm `PointLight` fixtures (+10 in SmallTown, +40 in Metrovale).
  - **Titan Sprint & Stamina Mechanics**:
    - Configured sprint speeds in `TitanRegistry.luau`: Ravager ($28 \to 44$, $+57\%$) and Brontara ($18 \to 28$, $+55\%$).
    - Added sprint input handlers (LeftShift, RightShift, ButtonL3), stamina drain/regen on `RenderStepped`, dynamic camera FOV punch ($70^\circ \to 82^\circ$), and attribute replication in `TitanController.client.luau`.
    - Implemented `MonsterService.SetSprintState` server authority.
    - Added electric cyan/orange/crimson Stamina Bar UI to `DestructionHUD.client.luau` above the abilities bar, with exhaustion warnings and mobile touch sprint button.
  - **Server Monetization Engine**:
    - Built `MonetizationConfig.luau` defining 5 Gamepasses (DoubleCash, DoubleXP, InstantRebuild, VIPTitanAura, AutoCollect) and 5 Developer Products (CashSurge Small/Large, XPBlast, InstantCooldownReset, ComboShield).
    - Upgraded `PlayerDataService.luau` to Schema 4 with persistent `ProcessedReceipts` (idempotency) and `Gamepasses`.
    - Built `MonetizationService.luau` with `ProcessReceipt` idempotency, ownership caching, multiplier getters, VIP aura emitter attachment, and Studio sandbox testing.
    - Integrated multipliers into `ProgressionService.AddRewards` ($2.0\times$ Cash and XP).
    - Integrated `InstantRebuild` into `CityService.ResetCity`.
    - Integrated `ComboShield` into `DestructionService.luau`.
  - **Shop Interface & Hub Market Pavilion**:
    - Built `ShopHUD.client.luau` tabbed modal GUI bound to keybind `B`, `StatsFrame.ShopButton`, and ProximityPrompt.
    - Constructed physical 21-part `MerchantPavilion` trading kiosk in `Workspace.KaijuHub.GrandCentralPlaza` at $(60, 520, -4970)$ with glowing magma ring, gold goods, lantern, and 3D holographic billboard sign.
  - **Live In-Studio Playtest Verified**: Spawning, sandbox purchase of `DoubleCash` ($2\times$ multiplier), `CashSurge_Small` awarding $+50,000$ Cash ($25k \times 2$), VIP Aura attachment, Ravager sprint jump ($32 \to 44$ WalkSpeed), smooth lighting transitions across all zones, and Shop UI verified with 0 errors.

---

## 3. World & Asset Specifications

| Asset / Structure | Location | Position / Anchor | Bounding Dimensions (Studs) | Properties / Settings |
| :--- | :--- | :--- | :--- | :--- |
| **`PlazaFloor`** | `KaijuHub.GrandCentralPlaza` | `(0, 517, -5000)` | $220 \times 6 \times 220$ | Basalt disc, concentric magma ley-lines |
| **`HubSpawnLocation`**| `KaijuHub` | `(0, 523.1, -5000)`| $20 \times 1.2 \times 20$ | Neutral spawn, 0 duration forcefield |
| **`MerchantPavilion`**| `KaijuHub.GrandCentralPlaza` | `(60, 520, -4970)` | $26 \times 18 \times 26$ | 21-part trading kiosk, ProximityPrompt, 3D Billboard |
| **`Pedestal_Ravager`** | `KaijuHub.HallOfTitans` | `(-42, 534, -5085)`| $22 \times 3 \times 22$ | 1:1 Ravager Statue, Underglow, 3D Holo Card |
| **`Pedestal_Brontara`**| `KaijuHub.HallOfTitans` | `(42, 534, -5085)` | $26 \times 3 \times 26$ | 1:1 Brontara Statue, Underglow, 3D Holo Card |
| **`Portal_SmallTown`** | `KaijuHub.StargatePromontory` | `(-45, 550, -4890)`| $29 \times 38 \times 6$ | Runic Arch, Cyan Stargate, ProximityPrompt |
| **`Portal_Metrovale`** | `KaijuHub.StargatePromontory` | `(45, 550, -4890)` | $29 \times 38 \times 6$ | Runic Arch, Violet Stargate, ProximityPrompt |
| **`Bastion_Titan_Dummy`**| `KaijuHub.ColosseumProvingGrounds` | `(0, 511, -5230)`| $16 \times 38 \times 16$ | `IsTrainingDummy = true`, 50k HP, Live DPS GUI |
| **`PracticePillars`** | `KaijuHub.ColosseumProvingGrounds` | $Y = 508$ | $8 \times 32 \times 8$ | `IsTrainingDummy = true`, 10k HP each |
| **`LaunchPads` (x3)** | `KaijuHub.LaunchPads` | Various | $18 \times 1.2 \times 18$ | Magma boost pads, velocity impulse |

---

## 4. Immediate Next Steps / Roadmap

### Priority: Milestone 13 — Sound Design & Audio FX Polish + Tier 2 Armor Simulation
- **Audio Overhaul**:
  - Add customized sound effects for sprinting (heavy earth-shaking footsteps with pitch shift based on speed).
  - Add shop purchase audio cues (cash register chime, power surge hum).
  - Add environmental ambient loops for SmallTown (gentle ocean breeze/city hum) and Metrovale (distant sirens/metropolitan drone).
- **Disposable Kinematic Simulation & Rig Stress Test**:
  - Mount Milestone 10.4 armor pieces on disposable rigs in the Colosseum Proving Grounds:
    - **Ravager Claw Combo**: Arm swing with Pauldrons mounted.
    - **Ravager Stomp & Roar**: Chest crouch and roar recoil with ChestPlate mounted.
    - **Brontara Heavy Stomp**: Front leg rear-up with Carapace & MagmaSpine mounted against the `Bastion_Titan_Dummy`.
