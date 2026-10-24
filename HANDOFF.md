# Titan Rampage — Agent Handoff & Continuity Brief

> **Source Session ID:** `e61117e8-8291-4737-8abb-736aedd82200`  
> **Workspace:** `C:\RobloxProjects\TitanRampage`  
> **Place ID:** `131002954769216`  
> **Git Baseline:** Milestone 11 Complete  
> **Date Updated:** October 24, 2026  

---

## 1. Project Overview & Architecture State

**Titan Rampage** is a physics-driven, multiplayer Kaiju combat and destruction game on Roblox Studio. Players choose between titans (such as **Ravager** and **Brontara**) to fight in destructible urban environments (Metrovale, SmallTown) and test abilities in the **Central Kaiju Hub**.

### Key Architectural Pillars
- **Rojo Project Layout:** Managed via `default.project.json` mapping `src/` to `ReplicatedStorage.Shared`, `ServerScriptService.Server`, and `StarterPlayer.StarterPlayerScripts`.
- **Titan Registry & Models:** Located in `ReplicatedStorage.Assets.Models` (`Brontara` and `Ravager`).
- **Safety & Baseline Mechanism:** All model modifications require verifying in-session backups in `ServerStorage.PreHub_Backups` (`Brontara_PreHub`, `Ravager_PreHub`, `SmallTown_PreHub`, `Metrovale_PreHub`), plus external manifests in `C:\Tools\TitanRampage-BlenderMCP\backups\Milestone11_Hub_Production.json`.
- **Central Kaiju Hub:** Located at high altitude `(0, 500, -5000)` with zero physical or visual bleed into battleground cities. Houses Titan pedestals, city stargates, Proving Grounds combat monoliths, and Hall of Records terminal.

---

## 2. Status & Recent Accomplishments

### Completed Up to Milestone 11
- **Milestone 9D (Production Baseline):** Full gameplay, titan combat, and custom HUDs for both Ravager and Brontara committed (`a48be85`).
- **Milestone 10.3B (Production Integration of BrowCrest & TailClub):**
  - Integrated `Brontara_BrowCrest_Mesh` and `Brontara_TailClub_Mesh` into `ReplicatedStorage.Assets.Models.Brontara`.
  - Hidden legacy block parts (`Transparency = 1`), preserving 12-motor hierarchy (`2a31801`).
- **Milestone 10.4 (3D Asset Prototyping for Brontara & Ravager Armor):**
  - Modeled, beveled, materialized, and unwrapped 5 game-ready armor assets in `C:\Tools\TitanRampage-BlenderMCP\tests\Milestone10_4\`: Carapace, MagmaSpine, ChestPlate, and Left/Right Pauldrons (`e3ebf92`).
- **Milestone 11 (Central Kaiju Hub & Cervical Spine Gap Resolution):**
  - **Unreal Engine MCP Integration**: Built and validated `/Game/Skills/KaijuHubArchitecture.KaijuHubArchitecture_C` at $1\text{ stud} \approx 28\text{ cm}$.
  - **Cervical Spine Resolution**: Solved the dorsal neck gap by mounting `Brontara_CervicalSpine_Mesh` directly to `Neck1` via `WeldConstraint` at relative offset `(0, 5.75, -3.90)`. Gap reduced to **0.0144 studs** (~4 mm), moving seamlessly with `NeckBaseJoint`.
  - **Kaiju Hub World Construction (`Workspace.KaijuHub`)**:
    - Central Plaza (`120 x 5 x 120` studs) at `(0, 500, -5000)`.
    - Persistent player spawn at `HubSpawnLocation`.
    - `Pedestal_Ravager` & `Pedestal_Brontara` with ProximityPrompts for instant monster swapping.
    - `Portal_SmallTown` & `Portal_Metrovale` runic stargates with ProximityPrompts for city deployment.
    - `ReturnToHubPortal` gateways placed at SmallTown `(0, 5.6, -30)` and Metrovale `(1200, 5.6, -50)` with `Return to Kaiju Hub` prompts.
    - Proving Grounds Arena with 3 Practice Monoliths (`Pillar_Alpha`, `Pillar_Beta`, `Pillar_Gamma`) featuring 10,000 HP, hit feedback, combo building, and auto-refresh without city destruction pollution.
    - Hall of Records leaderboard terminal.
  - **Server Services Integration**:
    - `MonsterService.luau`: Defaults spawning to `KaijuHub.HubSpawnLocation`; wired `ProximityPromptService.PromptTriggered`.
    - `CityService.luau`: Added `CityService.ReturnToHub(player)`; updated `CharacterAdded` to respect Hub spawn; added training dummy radius search in `GetBuildingsInRadius` and damage handling in `ApplyDamage`.
    - `DestructionService.luau`: Intercepted training dummies to award combo & visual feedback while skipping run damage recording.
  - **Verified in Live Playtest**: Spawning at Hub, titan swapping, Proving Grounds combat (288 dmg dealt to Pillar Alpha with 0% city damage), portal round-trip travel verified with 0 errors.

---

## 3. World & Asset Specifications

| Asset / Structure | Location | Position / Anchor | Bounding Dimensions (Studs) | Properties / Settings |
| :--- | :--- | :--- | :--- | :--- |
| **`CentralPlaza`** | `Workspace.KaijuHub` | `(0, 500, -5000)` | $120 \times 5 \times 120$ | Basalt foundation, neon perimeter runes |
| **`HubSpawnLocation`**| `Workspace.KaijuHub` | `(0, 502.5, -5000)`| $12 \times 1 \times 12$ | Neutral spawn, 0 duration forcefield |
| **`Pedestal_Ravager`** | `Workspace.KaijuHub` | `(-28, 502, -5020)`| $14 \times 2 \times 14$ | ProximityPrompt: "Select The Ravager" |
| **`Pedestal_Brontara`**| `Workspace.KaijuHub` | `(28, 502, -5020)` | $14 \times 2 \times 14$ | ProximityPrompt: "Select Brontara" |
| **`Portal_SmallTown`** | `Workspace.KaijuHub` | `(-35, 502, -4970)`| $16 \times 20 \times 4$ | ProximityPrompt: "Deploy to SmallTown" |
| **`Portal_Metrovale`** | `Workspace.KaijuHub` | `(35, 502, -4970)` | $16 \times 20 \times 4$ | ProximityPrompt: "Deploy to Metrovale" |
| **`PracticePillars`** | `Workspace.KaijuHub` | `(0, 517.5, -5135)`| $6 \times 30 \times 6$ | `IsTrainingDummy = true`, 10k HP |
| **`Brontara Cervical Spine`**| `Assets.Models.Brontara`| `Neck1` @ `(0, 5.75, -3.90)` | $2.20 \times 3.20 \times 13.50$ | `CanCollide = false`, `Massless = true`, Gap: 0.014 studs |
| **`ReturnToHubPortal (ST)`** | `Cities.SmallTown` | `(0, 5.6, -30)` | $14 \times 1.2 \times 14$ | ProximityPrompt: "Return to Kaiju Hub" |
| **`ReturnToHubPortal (MV)`** | `Cities.Metrovale` | `(1200, 5.6, -50)` | $14 \times 1.2 \times 14$ | ProximityPrompt: "Return to Kaiju Hub" |

---

## 4. Immediate Next Steps / Roadmap

### Priority: Milestone 10.5 — Disposable Kinematic Simulation & Rig Stress Test
- Test full animation sequences with the Milestone 10.4 armor mounted on disposable rigs in `KaijuHub.ProvingGroundsArena`:
  - **Ravager Claw Combo**: 3-stage arm swing with Pauldrons mounted (verify zero shoulder clipping and zero Motor6D drift on `Left Shoulder` / `Right Shoulder`).
  - **Ravager Stomp & Roar**: Chest crouch and roar recoil with ChestPlate mounted.
  - **Brontara Heavy Stomp**: Front leg rear-up and torso pitch with Carapace & MagmaSpine mounted against `Pillar_Alpha`.
- Once verified, proceed to **Milestone 10.6: Production Integration of Tier 2 Armor Sets**.
