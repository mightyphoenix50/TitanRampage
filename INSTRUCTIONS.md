# Titan Rampage — Player & Developer Guide

Welcome to **Titan Rampage**, a multiplayer Roblox giant-monster destruction game! Control original colossal titans, demolish cities, rack up destruction combos, upgrade your stats, and unlock larger urban metropolises.

---

## 1. Quick Start: Controls

| Action | Primary Input | Alternative Key | Description |
| :--- | :---: | :---: | :--- |
| **Move** | `W`, `A`, `S`, `D` | Arrow Keys | Full directional locomotion at colossal stride pace |
| **Jump** | `Space` | — | High-impact vertical jump scaled for colossal titans |
| **Primary Attack** | `Left Click (LMB)` | `1` | Fast melee strike (Ravager Claw Swipe / Brontara Tail Sweep) |
| **Stomp** | `E` | `2` | Heavy ground slam with 360° area-of-effect shockwave |
| **Signature Ability**| `Q` | — | Long-range head plunge (Brontara Neck Strike) |
| **Roar** | `R` | `3` | Thunderous intimidation roar with expanding sonic pulse |
| **Upgrades Menu** | `U` | — | Open/Close the persistent Titan Upgrades matrix |
| **City Selection** | `M` | — | Open/Close the City Rampage & Travel selector |
| **Titan Selection**| `T` | — | Open/Close the Titan Roster & Selection panel |
| **Camera Orbit** | `Right Click + Drag` | — | Rotate perspective around your titan |
| **Camera Zoom** | `Scroll Wheel` | — | Dynamic zoom distance (Ravager: 15–120; Brontara: 25–160) |

---

## 2. Playable Titans Roster

### Titan 1: The Ravager (Bipedal Brawler)
**The Ravager** is an original ancient titan forged from hardened basalt stone with volcanic magma conduits and glowing orange eyes. Standing approximately **24 studs tall**, Ravager excels in rapid, aggressive close-quarters brawling.

- **Class:** Bipedal Brawler
- **Status:** Unlocked by default
- **Base Health:** 3,000 HP
- **Base Walk Speed:** 24–28 studs/s (upgradeable)
- **Jump Power:** 65 studs
- **Camera Zoom:** 15 to 120 studs (Default: 45)
- **Abilities:**
  - `BasicAttack` (`LMB` / `1`): Rhythmic 3-hit claw swipe combo (0.42s animation, 22 studs range, 150 base dmg).
  - `Stomp` (`E` / `2`): Rapid ground stomp (0.35s windup, 30–48 studs radius, 400 base dmg).
  - `Roar` (`R` / `3`): Sonic chest roar (45 studs radius, 8.0s cd).

---

### Titan 2: Brontara the Earthshaker (Colossal Quadrupedal Juggernaut)
**Brontara the Earthshaker** is an original colossal prehistoric sauropod titan armored with granite dorsal plates, four immense pillar limbs, a 35-stud whip tail, and a reinforced crane-like neck with a hammer head.

- **Class:** Colossal Quadrupedal Juggernaut
- **Status:** Unlocked at **Player Level 5** AND **2 City Clears**
- **Base Health:** 4,500 HP (+50% tankier than Ravager)
- **Base Walk Speed:** 24 studs/s (heavy, deliberate siege momentum)
- **Jump Power:** 40 studs
- **Camera Zoom:** 25 to 160 studs (Default: 65, Y+8 offset for colossal perspective)
- **Abilities:**
  - `TailSweep` (`LMB` / `1`): Enormous horizontal whip sweep (1.1s cd, 26 studs reach, 200 base dmg). Clears out multiple small and medium buildings in a wide arc.
  - `HeavyStomp` (`E` / `2`): Front pillar rear-up and seismic ground slam (6.0s cd, 0.50s windup, 45 studs radius, 600 base dmg). Flattens entire city blocks.
  - `NeckStrike` (`Q`): Signature long-range overhead neck/head plunge (4.0s cd, 52 studs reach, 14 studs radius, 350 base dmg). Demolishes distant skyscrapers before you reach them.
  - `Roar` (`R` / `3`): Low-frequency seismic bellow (8.0s cd, 55 studs radius). Unleashes a massive shockwave across the metropolis.

---

## 3. Titan Abilities Breakdown

### Primary Attacks (`LMB` or `1`)
- **Ravager — Basic Claw Combo:** 3-hit choreography (`LeftSwipe` $\rightarrow$ `RightSwipe` $\rightarrow$ `DownwardSmash`). 0.42s swift recovery for aggressive mobile demolition.
- **Brontara — Tail Sweep:** Rotates torso and whips massive tail horizontally across city streets, hitting every building in a wide sweep arc.

### Stomp Attacks (`E` or `2`)
- **Ravager — Stomp:** Fast 0.35s crouch-and-stomp creating dual Neon shockwaves with distance falloff.
- **Brontara — Heavy Stomp:** Enormous front pillar rear-up (0.50s windup) followed by a devastating seismic impact that deals up to 600 damage across a massive 45-stud radius.

### Signature Ability (`Q`)
- **Brontara — Neck Strike:** Rears neck backward and plunges head vertically into structures up to 52 studs away. Allows Brontara to snipe tall buildings and landmark structures from range.

### Utility Roar (`R` or `3`)
- Unleashes an expansive sonic tremor (Ravager: 45 studs, Brontara: 55 studs) that ripples through the city with camera rumble and audio bellow.

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
1. The **City Complete** victory results screen appears.
2. Run statistics (Clear Time, Score, Pace BPM, Abilities used, Rewards earned) are displayed with personal best comparisons.
3. Clicking **🔄 REBUILD & RAMPAGE AGAIN** initiates a complete non-destructive rebuild: all collapsed buildings restore their positions, windows, and health to 100%, and starts a fresh destruction run timer!

---

## 7. Destruction Run Scoring & Personal Bests (Milestone 8)

Every city session is now formalized as a server-authoritative **Destruction Run** designed for infinite replayability and mastery.

### Destruction Score Formula
Your performance is evaluated at the end of each run with an arcade **Destruction Score**:
$$\text{Destruction Score} = \text{Base Score} + \text{Combo Bonus} + \text{Speed Bonus} + \text{Completion Bonus}$$

- **Base Score:** All destruction points earned from buildings plus $10\%$ of all raw damage dealt ($\text{Points} + \lfloor 0.1 \times \text{Damage} \rfloor$).
- **Combo Bonus:** $\text{Highest Combo achieved} \times 1,500$ points (up to $+7,500$ for a 5.0x max combo!).
- **Speed Bonus:** Clearing the city before the par target time awards $+50$ points for every second remaining:
  - *SmallTown Par Time:* 120 seconds ($2$ minutes)
  - *Metrovale Par Time:* 240 seconds ($4$ minutes)
- **Completion Bonus:** $+5,000$ points for SmallTown, $+15,000$ points for Metrovale.

> **Note:** Destruction Score is strictly a mastery and leaderboard performance score — it never replaces or converts into Cash, Points, or XP.

### Personal Bests & Badges
The server tracks your personal records individually for each city:
- **Best Clear Time:** Fastest run in seconds (lower is better).
- **Highest Combo:** Peak combo multiplier achieved (up to 5.0x).
- **High Destruction Score:** Your best recorded score.
- **Destruction Pace (BPM):** Buildings flattened per minute ($\text{Buildings} / (\text{Minutes})$).

When you beat an existing personal record on any city run, the Results Screen highlights it with a glowing **★ NEW BEST!** badge!

### Persistent Lifetime Statistics
Your player profile permanently persists your lifetime rampage career stats in DataStore:
- **Total Buildings Destroyed**
- **Total Damage Dealt**
- **Total Cities Completed**
- **Total Runs Completed**
- **Total Cash & Points Earned**
- **Lifetime Highest Combo**
- **Total Rampage Play Time**

---

## 8. Pro Tips for Maximum Destruction

1. **Alternate Basic Attacks and Stomp:** Open combat against a cluster of buildings with **Stomp (`E`)** to soften the entire block, then finish individual buildings with **Basic Attack (`LMB`)**.
2. **Watch the Combo Depletion Bar:** A small timer bar drains under your combo multiplier on the HUD. Hit another structure before it empties to preserve your **5.0x multiplier**!
3. **Pace Your Destruction for High BPM:** Minimize travel time between targets to push your Buildings-Per-Minute (BPM) above 30+ for massive Speed Bonuses.
4. **Upgrade Walk Speed Early:** Moving faster between buildings makes maintaining 5.0x combos and beating the par speed bonus substantially easier.
5. **Tackle Landmarks with Upgraded Titans:** Metrovale's Landmarks have 6,500–7,500 HP. Upgrade your Basic Attack Damage and Stomp Damage before taking on the Metrovale Tower!
