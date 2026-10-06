# Titan Rampage — Player & Developer Guide

Welcome to **Titan Rampage**, a multiplayer Roblox giant-monster destruction game! Control original colossal titans, demolish cities, rack up destruction combos, upgrade your stats, and unlock larger urban metropolises.

---

## 1. Quick Start: Controls

| Action | Primary Input | Alternative Key | Description |
| :--- | :---: | :---: | :--- |
| **Move** | `W`, `A`, `S`, `D` | Arrow Keys | Full directional locomotion at colossal stride pace |
| **Jump** | `Space` | — | High-impact vertical jump scaled for colossal titans |
| **Basic Attack** | `Left Click (LMB)` | `1` | Rhythmic 3-hit melee combo against buildings in front |
| **Stomp** | `E` | `2` | Heavy ground slam with 360° area-of-effect shockwave |
| **Roar** | `R` | `3` | Thunderous intimidation roar with expanding sonic pulse |
| **Camera Orbit** | `Right Click + Drag` | — | Rotate perspective around your titan |
| **Camera Zoom** | `Scroll Wheel` | — | Zoom distance from 15 studs up to 120 studs |

---

## 2. Playable Titan: The Ravager

**The Ravager** is an original ancient titan forged from hardened basalt stone with volcanic magma conduits and glowing orange eyes. Standing approximately **24 studs tall**, Ravager towers over conventional structures.

### Base Attributes
- **Health:** 3,000 HP
- **Walk Speed:** 24–28 studs/s (upgradeable)
- **Jump Power:** 65 studs
- **Camera Offset:** 45 studs default distance, elevated shoulder viewpoint

---

## 3. Titan Abilities Breakdown

### 1. Basic Melee Attack (`LMB` or `1`)
- **Cooldown:** ~1.0 second (reduces with upgrades)
- **Range & Arc:** 22 studs forward reach; hits all buildings within a 120° forward arc.
- **Rhythmic 3-Hit Combo Chain:**
  1. **Left Swipe:** Horizontal left claw sweep across the torso with an angled orange slash blade.
  2. **Right Swipe:** Horizontal right claw sweep across the torso with a counter-angled slash blade.
  3. **Downward Smash:** Two-handed overhead hammer slam plunging vertically into the structure with fiery impact particles and a camera thud.
- **Non-Locking Locomotion:** You can sprint, turn, and strafe continuously while attacking without stopping.
- **Zero Input Latency:** Animation and slash visuals start the instant you click.

### 2. Stomp (`E` or `2`)
- **Cooldown:** 5.0 seconds (reduces with upgrades)
- **Windup:** 0.35 seconds
- **Radius:** 30 to 48 studs (increases with upgrades)
- **Choreography:**
  - *Phase 1 (0.15s):* Ravager crouches low, gathering seismic energy.
  - *Phase 2 (0.20s):* Right leg elevates high into the air.
  - *Phase 3 (Impact at 0.35s):* Leg hammers down into the ground! Dual Neon shockwave rings blast outward, concrete debris chunks erupt, and screen shake rumbles nearby players.
- **Distance Falloff:** Damage is 100% at the epicenter, scaling down to 35% at the perimeter edge. Excellent for leveling groups of buildings in one strike.

### 3. Roar (`R` or `3`)
- **Cooldown:** 8.0 seconds
- **Radius:** 45 studs
- **Choreography:** Ravager expands his chest, flings his arms wide, tilts his head toward the sky, and unleashes a violent sonic tremor.
- **Visual FX:** An expanding orange-red sonic pulse sphere ripples through city streets.

---

## 4. Destruction Mechanics & Building Tiers

Cities are made of destructible, multi-story structures. Buildings visually degrade as their health decreases:

### Building Tiers
| Tier | Category | Example Structures | Base HP Range | Melee Damage Multiplier |
| :---: | :--- | :--- | :---: | :---: |
| **Tier 1** | Small | Houses, corner bodegas, kiosks | 300 – 600 HP | **1.00x** (Full Damage) |
| **Tier 2** | Medium | Commercial offices, strip malls, apartments | 1,200 – 1,800 HP | **0.67x** |
| **Tier 3** | Large | Civic centers, corporate skyscrapers | 2,100 – 2,700 HP | **0.50x** |
| **Tier 4** | Landmark | Grand Metro Hotel, Metrovale Tower | 6,500 – 7,500 HP | **0.40x** |

### 4-Stage Visual Degradation
1. **100% – 75% HP (Pristine):** Normal building facade.
2. **75% – 50% HP (Light Damage):** Upper windows shatter, exterior glass hides.
3. **50% – 25% HP (Heavy Damage):** All windows broken, entrance awnings and exterior props detach, facade darkens.
4. **25% – 0% HP (Critical Damage):** Scorched basalt color, structure shudders and smokes.
5. **0% HP (Controlled Collapse):** The building sinks into the ground in a smooth non-destructive collapse, leaving a solid concrete rubble foundation and granting rewards.

### The Combo Multiplier System
- Destroying or hitting buildings within **4.5 seconds** of your last hit builds your **Combo Multiplier**.
- Multiplier increases by **+0.1x per hit**, up to a maximum of **5.0x rewards**.
- If no damage is dealt for 4.5 seconds, the combo resets to 1.0x.
- **Strategy:** Move continuously between buildings to maintain a 5.0x multiplier for maximum Cash and XP gains!

---

## 5. Progression & Titan Upgrades

Demolishing buildings earns three resources:
1. **XP (Experience Points):** Fills your level bar ($Level \times 500$ curve). Leveling up unlocks higher-tier cities.
2. **Cash:** Used to purchase basic stat enhancements.
3. **Destruction Points:** Earned through high combos and large building collapses; required for high-tier upgrades.

### Available Upgrades (Upgrade UI)
- **Basic Attack Damage:** Increases claw swipe damage by **+25** per level.
- **Stomp Damage:** Increases ground slam damage by **+60** per level.
- **Walk Speed:** Increases base movement speed by **+4 studs/s** per level (applies immediately in real time).
- **Basic Attack Cooldown:** Reduces melee attack cooldown by **-0.08s** per level.
- **Stomp Cooldown:** Reduces ground slam cooldown by **-0.40s** per level.

---

## 6. City Progression & Rebuild Loop

### 1. SmallTown (Coastal Municipality)
- **Status:** Unlocked by default (Difficulty 1).
- **Total Buildings:** 15 buildings (8 Small, 5 Medium, 2 Large).
- **Total City Health:** **16,410 HP**.
- **Objective:** Demolish all 15 buildings to trigger 100% City Completion and earn the **1,000 Cash, 500 Points, 500 XP** completion bonus.

### 2. Metrovale (Dense Metropolis)
- **Status:** Locked by default (Difficulty 2).
- **Unlock Requirements:** Reach **Player Level 5** AND achieve **2 SmallTown Clears**.
- **Total Buildings:** 27 buildings (12 Small, 8 Medium, 5 Large Skyscrapers, 2 Massive Landmarks).
- **Total City Health:** **53,380 HP**.
- **Key Landmarks:**
  - `Landmark_Grand_Metro_Hotel` (**6,500 HP**)
  - `Landmark_Metrovale_Tower` (**7,500 HP**)
- **Completion Reward:** **2,500 Cash, 1,250 Points, 1,500 XP**.

### Automated City Rebuild
Once a city reaches 100% destruction:
1. The **City Complete** victory banner appears.
2. Run statistics (Total time, Highest combo, Rewards earned) are displayed.
3. The city automatically initiates a non-destructive rebuild: all collapsed buildings restore their positions, windows, and health to 100% for another destruction run.

---

## 7. Pro Tips for Maximum Destruction

1. **Alternate Basic Attacks and Stomp:** Open combat against a cluster of buildings with **Stomp (`E`)** to soften the entire block, then finish individual buildings with **Basic Attack (`LMB`)**.
2. **Keep the Combo Alive:** Don't get stuck attacking a high-health building alone if your combo is about to expire. Hit a nearby small building to refresh the 4.5-second timer and keep your **5.0x multiplier**.
3. **Upgrade Walk Speed First:** Moving faster between buildings makes maintaining a 5.0x combo significantly easier.
4. **Tackle Landmarks with Upgraded Titans:** Metrovale's Landmarks have 6,500–7,500 HP. Upgrade your Basic Attack Damage and Stomp Damage before taking on the Metrovale Tower!
