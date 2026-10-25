# Titan Rampage — Agent Handoff & Continuity Brief

> **Source Session ID:** `e61117e8-8291-4737-8abb-736aedd82200`  
> **Workspace:** `C:\RobloxProjects\TitanRampage`  
> **Place ID:** `131002954769216`  
> **Git Baseline:** Milestone 11.1 Complete  
> **Date Updated:** October 25, 2026  

---

## 1. Project Overview & Architecture State

**Titan Rampage** is a physics-driven, multiplayer Kaiju combat and destruction game on Roblox Studio. Players choose between titans (such as **Ravager** and **Brontara**) to fight in destructible urban environments (Metrovale, SmallTown) and test abilities in the **Grand Volcanic Kaiju Sanctuary**.

### Key Architectural Pillars
- **Rojo Project Layout:** Managed via `default.project.json` mapping `src/` to `ReplicatedStorage.Shared`, `ServerScriptService.Server`, and `StarterPlayer.StarterPlayerScripts`.
- **Titan Registry & Models:** Located in `ReplicatedStorage.Assets.Models` (`Brontara` and `Ravager`).
- **Safety & Baseline Mechanism:** All model modifications require verifying in-session backups in `ServerStorage.PreHubRevamp_Backups` (`KaijuHub_PreRevamp`, `Brontara_PreRevamp`, `Ravager_PreRevamp`), plus external manifests in `C:\Tools\TitanRampage-BlenderMCP\backups\Milestone11_Hub_GrandRevamp_Production.json`.
- **Grand Volcanic Kaiju Sanctuary:** Located at high altitude `(0, 520, -5000)` spanning over $450\text{ studs}$ with 251 descendants across 4 distinct elevation tiers: Grand Central Plaza, Hall of Titans, Stargate Promontory, and Colosseum Proving Grounds.

---

## 2. Status & Recent Accomplishments

### Completed Up to Milestone 11.1
- **Milestone 9D (Production Baseline):** Full gameplay, titan combat, and custom HUDs for both Ravager and Brontara committed (`a48be85`).
- **Milestone 10.3B (Production Integration of BrowCrest & TailClub):**
  - Integrated `Brontara_BrowCrest_Mesh` and `Brontara_TailClub_Mesh` into `ReplicatedStorage.Assets.Models.Brontara`.
  - Hidden legacy block parts (`Transparency = 1`), preserving 12-motor hierarchy (`2a31801`).
- **Milestone 10.4 (3D Asset Prototyping for Brontara & Ravager Armor):**
  - Modeled, beveled, materialized, and unwrapped 5 game-ready armor assets in `C:\Tools\TitanRampage-BlenderMCP\tests\Milestone10_4\`: Carapace, MagmaSpine, ChestPlate, and Left/Right Pauldrons (`e3ebf92`).
- **Milestone 11 (Central Kaiju Hub & Cervical Spine Gap Resolution):**
  - Mounted `Brontara_CervicalSpine_Mesh` directly to `Neck1` via `WeldConstraint`. Gap reduced to **0.0144 studs** (~4 mm) (`3f805aa`).
- **Milestone 11.1 (Grand Volcanic Kaiju Sanctuary Revamp):**
  - **Issue #1 Resolved (Titan Visibility & Hero Showcase)**:
    - 1:1 scale static display statues of Ravager and Brontara mounted on elevated pedestals in the Hall of Titans.
    - Preserved all visual meshes on Brontara (BrowCrest, TailClub, seamless CervicalSpine).
    - Dual-source stage lighting (volcanic underglow + overhead spotlight) casting rim highlights.
    - 3D Holographic Stat Cards (`BillboardGui`) displaying glowing title, archetype, vital stat bars, and signature ability badges.
  - **Issue #2 Resolved (14x Spatial & Visual Expansion)**:
    - Expanded hub footprint from 120 studs to over 450 studs across 4 tiers:
      - **Tier 1: Grand Central Plaza ($Y = 520$, $220\text{ studs}$ dia)**: Basalt floor, magma ley-lines, central dais, `HubSpawnLocation`, and in-world `AltarOfAscension`.
      - **Tier 2: The Hall of Titans ($Y = 535$)**: Semicircular amphitheater with carved columns and roaring braziers housing the Titan showcases.
      - **Tier 3: The Stargate Promontory ($Y = 550$)**: Runic stargate arches for SmallTown and Metrovale deployment.
      - **Tier 4: The Colosseum Proving Grounds ($Y = 492$, $200 \times 200\text{ studs}$ sunken pit)**: Sunken arena with the Bastion Titan DPS dummy.
    - 12 perimeter basalt monoliths ($120$–$220\text{ studs}$ tall) and 4 vertical skybeams ($Y = 520 \to 1800$).
    - Atmospheric Profile: Volcanic twilight `Atmosphere` (Density 0.32, Haze 2.0), crisp magma `Bloom`, and cinematic `ColorCorrection`.
  - **High-Retention Micro-Loops**:
    - **Bastion Titan DPS Dummy**: 50,000 HP combat monolith with live overhead rolling 3-second DPS meter, combo indicator, and health bar.
    - **Titan Magma Launch Pads**: Directional jump pads applying `AssemblyLinearVelocity` impulses between Plaza $\leftrightarrow$ Colosseum and Plaza $\to$ Stargates.
  - **Services Integration**:
    - Built `HubService.luau` registered in `ServerBootstrap.server.luau`.
    - Wired `DestructionService.luau` to call `HubService.RecordDummyDamage` on dummy hit.
    - Updated `CityService.luau` and `MonsterService.luau` with recursive `HubSpawnLocation` lookup.
  - **Live In-Studio Playtest Verified**: Spawning, Titan swap to Brontara, Bastion Dummy combat (192 dmg dealt, live 64 DPS / 2.0x Combo readout, 0% city damage), launch pad boost impulse, and Stargate roundtrip travel verified with 0 errors.

---

## 3. World & Asset Specifications

| Asset / Structure | Location | Position / Anchor | Bounding Dimensions (Studs) | Properties / Settings |
| :--- | :--- | :--- | :--- | :--- |
| **`PlazaFloor`** | `KaijuHub.GrandCentralPlaza` | `(0, 517, -5000)` | $220 \times 6 \times 220$ | Basalt disc, concentric magma ley-lines |
| **`HubSpawnLocation`**| `KaijuHub` | `(0, 523.1, -5000)`| $20 \times 1.2 \times 20$ | Neutral spawn, 0 duration forcefield |
| **`Pedestal_Ravager`** | `KaijuHub.HallOfTitans` | `(-42, 534, -5085)`| $22 \times 3 \times 22$ | 1:1 Ravager Statue, Underglow, 3D Holo Card |
| **`Pedestal_Brontara`**| `KaijuHub.HallOfTitans` | `(42, 534, -5085)` | $26 \times 3 \times 26$ | 1:1 Brontara Statue, Underglow, 3D Holo Card |
| **`Portal_SmallTown`** | `KaijuHub.StargatePromontory` | `(-45, 550, -4890)`| $29 \times 38 \times 6$ | Runic Arch, Cyan Stargate, ProximityPrompt |
| **`Portal_Metrovale`** | `KaijuHub.StargatePromontory` | `(45, 550, -4890)` | $29 \times 38 \times 6$ | Runic Arch, Violet Stargate, ProximityPrompt |
| **`Bastion_Titan_Dummy`**| `KaijuHub.ColosseumProvingGrounds` | `(0, 511, -5230)`| $16 \times 38 \times 16$ | `IsTrainingDummy = true`, 50k HP, Live DPS GUI |
| **`PracticePillars`** | `KaijuHub.ColosseumProvingGrounds` | $Y = 508$ | $8 \times 32 \times 8$ | `IsTrainingDummy = true`, 10k HP each |
| **`LaunchPads` (x3)** | `KaijuHub.LaunchPads` | Various | $18 \times 1.2 \times 18$ | Magma boost pads, velocity impulse |
| **`AltarOfAscension`**| `KaijuHub.GrandCentralPlaza` | `(0, 534, -4925)` | $18 \times 27 \times 18$ | In-world titan progression shrine |

---

## 4. Immediate Next Steps / Roadmap

### Priority: Milestone 10.5 — Disposable Kinematic Simulation & Rig Stress Test
- Test full animation sequences with the Milestone 10.4 armor mounted on disposable rigs in `KaijuHub.ColosseumProvingGrounds`:
  - **Ravager Claw Combo**: 3-stage arm swing with Pauldrons mounted (verify zero shoulder clipping and zero Motor6D drift on `Left Shoulder` / `Right Shoulder`).
  - **Ravager Stomp & Roar**: Chest crouch and roar recoil with ChestPlate mounted.
  - **Brontara Heavy Stomp**: Front leg rear-up and torso pitch with Carapace & MagmaSpine mounted against the `Bastion_Titan_Dummy`.
- Once verified, proceed to **Milestone 10.6: Production Integration of Tier 2 Armor Sets**.
