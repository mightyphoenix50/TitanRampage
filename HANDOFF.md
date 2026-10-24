# Titan Rampage — Agent Handoff & Continuity Brief

> **Source Session ID:** `e61117e8-8291-4737-8abb-736aedd82200`  
> **Workspace:** `C:\RobloxProjects\TitanRampage`  
> **Place ID:** `131002954769216`  
> **Git Baseline:** Milestone 10.4 Complete  
> **Date Updated:** October 24, 2026  

---

## 1. Project Overview & Architecture State

**Titan Rampage** is a physics-driven, multiplayer Kaiju combat and destruction game on Roblox Studio. Players choose between titans (such as **Ravager** and **Brontara**) to fight in destructible urban environments (Metrovale, SmallTown).

### Key Architectural Pillars
- **Rojo Project Layout:** Managed via `default.project.json` mapping `src/` to `ReplicatedStorage.Shared`, `ServerScriptService.Server`, and `StarterPlayer.StarterPlayerScripts`.
- **Titan Registry & Models:** Located in `ReplicatedStorage.Assets.Models` (`Brontara` and `Ravager`).
- **Safety & Baseline Mechanism:** All model modifications require verifying in-session backups in `ServerStorage.Milestone9D_Backups` and `ServerStorage.PreMilestone10_3B_Backups`, plus external manifests in `C:\Tools\TitanRampage-BlenderMCP\backups\`.

---

## 2. Status & Recent Accomplishments

### Completed Up to Milestone 10.4
- **Milestone 9D (Production Baseline):** Full gameplay, titan combat, and custom HUDs for both Ravager and Brontara polished and committed (`a48be85`).
- **Milestone 10.2 & 10.3A:** Generated and validated 3D prototype assets in Blender and verified 0 Motor6D drift on disposable Brontara clone.
- **Milestone 10.3B (Production Integration of BrowCrest & TailClub):**
  - Integrated `Brontara_BrowCrest_Mesh` and `Brontara_TailClub_Mesh` into `ReplicatedStorage.Assets.Models.Brontara`.
  - Hidden legacy block parts (`Transparency = 1`), preserving 12-motor hierarchy.
  - Verified live combat in SmallTown & Metrovale, 0 runtime errors (`2a31801`).
- **Milestone 10.4 (3D Asset Prototyping for Brontara & Ravager Armor):**
  - Automated headless Blender 5.2.2 LTS socket bridge on `127.0.0.1:9876`.
  - Modeled, beveled, materialized, and unwrapped 5 game-ready armor assets in `C:\Tools\TitanRampage-BlenderMCP\tests\Milestone10_4\`:
    - `Brontara_Carapace.fbx` / `.obj` (40 verts, 38 faces, $14.49 \times 2.60 \times 20.50$ studs)
    - `Brontara_MagmaSpine.fbx` / `.obj` (23 verts, 21 faces, $2.20 \times 4.40 \times 18.00$ studs)
    - `Ravager_ChestPlate.fbx` / `.obj` (48 verts, 52 faces, $9.60 \times 7.60 \times 2.10$ studs)
    - `Ravager_Pauldron_Left.fbx` / `.obj` (30 verts, 32 faces, $5.00 \times 5.62 \times 5.00$ studs)
    - `Ravager_Pauldron_Right.fbx` / `.obj` (30 verts, 32 faces, $5.00 \times 5.62 \times 5.00$ studs)
    - Master file: `Milestone10_4_Prototyping.blend` (106 KB)
  - Executed disposable in-Studio fitting test on temporary clones in `Workspace.Milestone10_4_FittingTest`: verified exact offsets, clean limb clearance, and zero collisions.
  - Test container deleted; production models pristine.

---

## 3. Prototype Armor Specs & Attachment Geometry

| Component | Target Joint / Anchor | Relative Position Offset | Bounding Dimensions (Studs) | Vert / Face Count | Physics & Query Settings |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`Brontara_Carapace`** | `Torso` | `(0, 6.10, 0.00)` | $14.49 \times 2.60 \times 20.50$ | 40 V / 38 F | `CanCollide = false`, `Massless = true` |
| **`Brontara_MagmaSpine`**| `Torso` | `(0, 9.20, 0.00)` | $2.20 \times 4.40 \times 18.00$ | 23 V / 21 F | `CanCollide = false`, `Massless = true` |
| **`Ravager_ChestPlate`** | `Torso` | `(0, 0.40, -3.75)` | $9.60 \times 7.60 \times 2.10$ | 48 V / 52 F | `CanCollide = false`, `Massless = true` |
| **`Ravager_Pauldron_Left`** | `Left Arm` | `(0, 5.90, 0.00)` | $5.00 \times 5.62 \times 5.00$ | 30 V / 32 F | `CanCollide = false`, `Massless = true` |
| **`Ravager_Pauldron_Right`**| `Right Arm` | `(0, 5.90, 0.00)` | $5.00 \times 5.62 \times 5.00$ | 30 V / 32 F | `CanCollide = false`, `Massless = true` |

---

## 4. Immediate Next Steps / Roadmap

### Priority: Milestone 10.5 — Disposable Kinematic Simulation & Rig Stress Test
- Test full animation sequences with the new armor mounted on disposable rigs:
  - **Ravager Claw Combo**: 3-stage arm swing with Pauldrons mounted (verify zero shoulder clipping and zero Motor6D drift on `Left Shoulder` / `Right Shoulder`).
  - **Ravager Stomp & Roar**: Chest crouch and roar recoil with ChestPlate mounted.
  - **Brontara Heavy Stomp**: Front leg rear-up and torso pitch with Carapace & MagmaSpine mounted.
- Once verified, proceed to **Milestone 10.6: Production Integration of Tier 2 Armor Sets**.
