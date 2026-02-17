# Keep Defender — Game Design Document

## Overview

**Title:** Keep Defender
**Engine:** Godot 4.x (GDScript)
**Genre:** Endless Survival / Castle Defense with Direct Cursor Combat
**Target Price:** $6.99 on Steam
**Session Length:** Single long session (20-60+ min), leaderboard/high score
**Dev Timeline:** 6–8 weeks

**Elevator Pitch:**
Your castle is under siege. Waves of enemies pour in from all sides. You hire defenders, build turrets, and upgrade your keep — but your most powerful weapon is your cursor. Click, drag, and unleash abilities directly on the battlefield while managing upgrades between waves. How long can you survive?

**The Hook:**
The cursor IS a weapon. While your auto-spawned units and turrets fight on their own, you're in the action — clicking to smite enemies, dragging lightning across hordes, dropping AOE blasts. You upgrade your cursor alongside your castle and army, creating build diversity and satisfying power scaling.

---

## Core Gameplay Loop

```
WAVE STARTS
   │
   ├── Enemies spawn from edges, march toward castle
   ├── Your units auto-spawn and engage enemies
   ├── Turrets/defenses fire automatically
   ├── YOU click/drag to deal cursor damage where it's needed most
   ├── Mid-wave: random "pick 1 of 3" upgrade pop-ups (Brotato-style)
   ├── Enemies drop gold on death
   │
WAVE ENDS (all enemies dead)
   │
   ├── SHOP SCREEN opens
   │   ├── Buy/upgrade cursor abilities
   │   ├── Buy/upgrade castle defenses (turrets, walls, moats)
   │   ├── Buy/upgrade unit types and spawn rates
   │   ├── Buy global buffs
   │   └── Repair castle
   │
   └── NEXT WAVE (harder)
```

**Difficulty Scaling Per Wave:**
- Enemy count increases
- Enemy health/damage scales
- New enemy types introduced at wave thresholds
- Enemy speed gradually increases
- Boss enemies every 5 (or 10) waves

**Game Over Condition:** Castle health reaches 0.

**Score:** Wave number reached (primary), total kills, total gold earned (secondary).

---

## The Cursor Weapon System (Core Differentiator)

The cursor is always active. The player's mouse is both a UI tool and their primary weapon.

### Base Cursor Attack
- **Left click** on an enemy: deals direct damage (small amount)
- Visual feedback: impact spark, damage number popup
- No cooldown on basic click, but low damage encourages upgrades

### Cursor Upgrade Tree

| Upgrade | Description | Levels |
|---------|-------------|--------|
| **Smite** | Base click damage increase | 10 |
| **Chain Lightning** | Click damage arcs to nearby enemies | 5 |
| **Meteor Strike** | Hold click to charge, release for AOE blast (cooldown) | 5 |
| **Frost Trail** | Dragging cursor leaves a slow field | 5 |
| **Flame Sweep** | Dragging cursor deals damage in a line | 5 |
| **Healing Touch** | Click on friendly units to heal them | 3 |
| **Gold Magnet** | Cursor auto-collects gold in a radius | 3 |
| **Wrath** | Cursor damage increases the lower the castle's health | 3 |

**Design Philosophy:** The cursor should feel increasingly godlike as waves progress. Early game: you're poking enemies for chip damage. Late game: you're raining fire and chain lightning across the map.

### Cursor Input Design
- **Left click (tap):** Instant damage at cursor location
- **Left click (hold + release):** Charged ability (Meteor Strike)
- **Left click (drag):** Trail ability (Frost Trail or Flame Sweep, based on what's equipped)
- **Right click:** Reserved (future: targeted unit ability, or secondary cursor attack)

**Important:** Cursor weapon uses a separate input layer from the old RTS controls. No unit selection, no unit commanding. The cursor is purely a weapon + UI tool.

---

## Castle & Defenses

### The Castle (Center Cell of Grid)
- Occupies the center cell of the 7x7 grid
- Starts with 1000 HP
- Visual degradation as health drops (cosmetic stages: pristine → damaged → crumbling)
- Can be repaired in the shop between waves
- All units spawn here and march outward

### Buildable Defenses (Grid-Based)

Each grid cell can hold **one defense structure** in addition to any units stationed there. Defenses are built via the same right-click panel used for unit assignment.

| Defense | Description | Range | Shop Cost |
|---------|-------------|-------|-----------|
| **Arrow Tower** | Fires arrows at nearest enemy, moderate damage, fast fire rate | Own cell + 1 adjacent | 100g |
| **Cannon Tower** | Slow fire rate, AOE damage | Own cell + 2 adjacent | 250g |
| **Frost Tower** | Slows enemies in radius, no damage | Own cell + 1 adjacent | 150g |
| **Barricade** | Blocks/slows enemy pathing through the cell, has HP, can be destroyed | Own cell | 75g |

**Upgrade Path:** Each defense can be upgraded 3 levels (e.g., Arrow Tower I → II → III) via the shop, increasing stats.

**Placement Rules:**
- One structure per grid cell
- Castle center cell cannot have additional structures
- Structures are built instantly when purchased (placed during shop phase or mid-wave)
- Destroyed structures must be re-purchased

---

## Grid System & Unit Deployment

### The Battlefield Grid
- **7x7 grid** covering the entire map (48 outer cells + castle center cell)
- Grid lines are subtly visible on the map (faint overlay, not obtrusive)
- Each cell can hold units AND/OR one defense structure
- Enemies spawn from map edges and walk through grid cells toward the castle center
- Grid size designed to feel like a PC strategy game, not a mobile game

### Unit Requisition System (Core Mechanic #2)

Players don't control units directly. Instead, they place **requisition orders** on grid cells, specifying what units and how many should be stationed there. Units then auto-spawn at the castle and march to their assigned cells.

**How it works:**
1. **Right-click** a grid cell → opens a small assignment panel
2. Panel shows +/- buttons per unlocked unit type (e.g., Militia: [−] 3 [+], Knight: [−] 1 [+])
3. Setting a count creates a **standing order** for that cell
4. Units spawn at the castle on a timer and auto-path to cells that have unfilled orders
5. Once at their cell, units patrol within it and fight any enemies that enter
6. If a unit dies, the standing order remains — a replacement will spawn and march out
7. Right-click the cell again to adjust orders anytime (mid-wave or between waves)

**Example:** You right-click a cell on the eastern edge → set 3 Militia and 1 Archer → close panel. Over the next 12 seconds, 4 units spawn at the castle and walk east to that cell. If 2 die during the wave, 2 replacements auto-spawn and march out.

**Strategic depth this creates:**
- **Travel time matters:** Far cells take longer to reinforce. Do you spread thin or concentrate near the castle?
- **Interception risk:** Units marching to distant cells might encounter enemies en route
- **Resource tension:** You have a global unit cap — assigning 5 to the east means 5 fewer elsewhere
- **Cursor synergy:** While waiting for reinforcements, you use your cursor weapon to hold the line

### Unit AI (Per Cell)
1. Spawn at castle
2. Path toward assigned grid cell
3. If encountering enemies en route, engage briefly then continue to destination
4. Once in assigned cell: patrol within cell boundaries
5. Attack any enemy that enters the cell (or adjacent cells for ranged units)
6. Stay in cell — units do NOT chase enemies outside their zone
7. Die → removed from cell count → replacement spawns if standing order exists

### Unit Types

| Unit | Role | Range | Unlocked |
|------|------|-------|----------|
| **Militia** | Cheap, fast, low damage/HP. Swarm unit. | Own cell only | Wave 1 |
| **Knight** | Tanky, slow, moderate damage. Frontline. | Own cell only | Wave 3 |
| **Archer** | Ranged, fragile, consistent damage. | Own cell + 1 adjacent | Wave 5 |
| **Mage** | AOE damage, slow attack speed, fragile. | Own cell + 2 adjacent | Wave 10 |

### Unit Upgrades (Shop)

| Upgrade | Effect |
|---------|--------|
| **Spawn Rate** | Reduce time between unit spawns at castle |
| **Max Units** | Increase global unit cap (starts at 8, max ~30) |
| **Unit HP** | Global HP buff to all units |
| **Unit Damage** | Global damage buff |
| **Unlock [Type]** | Add new unit type to requisition pool |
| **Unit Level** | Upgrade specific unit type stats |
| **March Speed** | Units walk faster from castle to assigned cell |

### Spawn System
- Units spawn at the castle on a timer (e.g., every 3 seconds)
- Spawn type is determined by unfilled requisition orders (priority: oldest order first)
- Global unit cap starts at 8, upgradeable to ~30
- Dead units auto-replace if their cell's standing order still has room
- If no unfilled orders exist, no units spawn (player must assign cells)

---

## Economy & Upgrades

### Gold
- Enemies drop gold on death (auto-collected or cursor-magnet)
- Gold amount scales with enemy difficulty
- Gold is spent in the between-wave shop
- Bonus gold for completing a wave quickly (time bonus)

### Between-Wave Shop
- Opens after all enemies in a wave are dead
- Grid/list of available upgrades organized by category
- Categories: Cursor, Defenses, Units, Global
- Player spends gold, then clicks "Start Next Wave"
- Shop has a "reroll" button for randomized upgrade offerings (costs gold)

### Mid-Wave Upgrade Picks (Brotato-Style)
- Every N kills (e.g., every 20 kills), a popup appears: "Pick 1 of 3"
- 3 random minor upgrades are offered
- Game does NOT pause — pressure to pick quickly
- These are smaller buffs than shop items (e.g., +5% cursor damage, +10 unit HP, +1 gold per kill)
- Picking dismisses the popup; ignoring it auto-dismisses after 5 seconds (no pick = no buff)

---

## Enemy Design

### Base Enemy Types

| Enemy | Behavior | Introduced |
|-------|----------|------------|
| **Goblin** | Basic melee, walks to castle | Wave 1 |
| **Skeleton** | Slightly faster, slightly less HP | Wave 2 |
| **Orc** | Tanky, slow, high damage | Wave 4 |
| **Wolf** | Fast, low HP, ignores units (runs past to castle) | Wave 6 |
| **Shaman** | Ranged, buffs nearby enemies | Wave 8 |
| **Siege Golem** | Very slow, very tanky, massive castle damage | Wave 10 |

### Boss Enemies (Every 5 Waves)

| Boss | Mechanic |
|------|----------|
| **Troll Chieftain** | High HP, spawns goblin adds |
| **Necromancer** | Resurrects dead enemies as skeletons |
| **Dragon** | Flies over walls, fire breath AOE |
| **Siege Engine** | Massive HP, destroys walls on contact |

### Scaling Formula
```
enemy_hp = base_hp * (1 + wave * 0.15)
enemy_damage = base_damage * (1 + wave * 0.10)
enemies_per_wave = base_count + (wave * 2)
enemy_speed = base_speed * (1 + wave * 0.02)  // gentle scaling
```

---

## Map & Visual Design

### Map Layout
- **7x7 grid** covering the full battlefield
- Castle occupies center cell [3,3] (0-indexed)
- Grid lines subtly visible (faint white/gray overlay, toggleable)
- Terrain: grass/dirt base with visual variety per cell (cosmetic only for v1)
- Enemies spawn from cells along all 4 edges
- Grid cells highlight on hover to show interactivity
- Cells with standing orders show a small icon indicator (unit count, structure type)

### Visual Grid Feedback
- **Empty cell:** Faint border only
- **Cell with units stationed:** Subtle colored tint + unit count badge
- **Cell with structure:** Structure sprite visible in cell
- **Cell under attack:** Flashing red border or pulse effect
- **Cell being hovered:** Brightened border, shows quick-info tooltip

### Art Direction
- Top-down 2D
- Medieval fantasy theme
- Asset pack-friendly (existing assets in repo are medieval-themed)
- Simple particle effects for cursor abilities (Godot GPU particles)
- Screen shake on big hits
- Damage number popups
- Grid cells ~128x128 to ~192x192 pixels depending on final resolution

### Camera
- Zoomed out enough to see full 7x7 grid (ideal)
- Optional zoom/pan for players who want to inspect cells up close
- Keep current zoom/pan controls (WASD + scroll wheel) as optional

---

## UI Layout

```
┌─────────────────────────────────────────────┐
│  Wave: 12  │  Gold: 1,450  │  Castle: 78%  │
│  Units: 14/20              │                │
├─────────────────────────────────────────────┤
│                                             │
│          7x7 GRID BATTLEFIELD               │
│     (castle center, enemies from edges)     │
│                                             │
│   Left-click = cursor weapon (attack)       │
│   Right-click cell = open assignment panel  │
│                                             │
│                    [Pick 1 of 3 popup]      │
│                                             │
├─────────────────────────────────────────────┤
│ Cursor: Smite III ⚡ | Cooldowns: ☄️ 3s    │
└─────────────────────────────────────────────┘
```

### Cell Assignment Panel (Right-Click Popup)
```
┌──────────────────────────┐
│  Cell [3, 5]             │
│                          │
│  Militia:  [−] 3 [+]    │
│  Knight:   [−] 1 [+]    │
│  Archer:   [−] 0 [+]    │
│                          │
│  Structure: Arrow Tower  │
│  [Build] [Upgrade] [Sell]│
│                          │
│  Status: 2/4 units here  │
│  (2 en route from castle)│
└──────────────────────────┘
```
- Shows current standing orders and how many units have actually arrived
- Grayed-out unit types that aren't unlocked yet
- Structure section shows what's built (or "Empty" with build options)

### Shop Screen (Between Waves)

```
┌─────────────────────────────────────────────┐
│           WAVE 12 COMPLETE!                 │
│      Kills: 47  |  Gold Earned: 320         │
├──────────┬──────────┬──────────┬────────────┤
│  CURSOR  │ DEFENSES │  UNITS   │  GLOBAL    │
├──────────┴──────────┴──────────┴────────────┤
│                                             │
│  [Smite IV - 200g]  [Chain Lightning - 150g]│
│  [Meteor Strike II - 300g]                  │
│  [Arrow Tower - 100g]  [Repair Castle - 50g]│
│                                             │
│         Gold: 1,450        [REROLL - 25g]   │
│                                             │
│            [ START WAVE 13 ]                │
└─────────────────────────────────────────────┘
```

---

## What to Keep from Current Codebase

### KEEP & REFACTOR
| System | Current State | Changes Needed |
|--------|---------------|----------------|
| **Combatant base class** | Solid foundation | Remove attacker registration, add gold drop, add cell assignment |
| **State Machine** | Works well | Add PatrolState (patrol within assigned cell) |
| **Enemy scene/script** | Good pathfinding to castle | Simplify to "path toward castle through grid" |
| **EnemySpawner** | Basic wave spawning | Refactor into WaveManager with progression, enemy variety, edge spawning |
| **Castle** | Basic HP + signal | Add visual damage stages, repair mechanic |
| **Camera** | Zoom/pan works | Keep for inspecting grid; default zoom shows full 7x7 |
| **Health bars** | Working | Keep as-is |
| **AnimatedSprite setup** | 16-direction animations | Keep as-is |
| **NavigationAgent2D** | Used for unit pathfinding | Keep for castle-to-cell pathing; switch to simple steering once in cell |

### REMOVE
| System | Reason |
|--------|--------|
| **UnitManager** | Replaced by RequisitionManager + GridManager |
| **SelectionRect** | No more drag-select |
| **Formation system** | No more player-commanded formations |
| **Top bar (formation dropdown)** | Replaced with new HUD |
| **Command input handling** | Right-click now opens cell panel instead |

### BUILD NEW
| System | Priority | Complexity |
|--------|----------|------------|
| **GridManager + GridCell** | P0 — Core structure | Medium |
| **Cursor weapon system** | P0 — Core mechanic | Medium |
| **Gold/economy system** | P0 — Core loop | Low |
| **Wave manager (progression)** | P0 — Core loop | Medium |
| **Cell assignment panel UI** | P0 — Core interaction | Medium |
| **RequisitionManager** | P0 — Unit spawning/routing | Medium |
| **Between-wave shop UI** | P0 — Core loop | Medium-High |
| **Mid-wave pick-3 system** | P1 — Key feature | Medium |
| **Defense structures (towers)** | P1 — Depth | Medium |
| **Upgrade data/balance** | P1 — Content | Medium |
| **Enemy type variety** | P1 — Content | Medium |
| **Game over / score screen** | P2 — Polish | Low |
| **Main menu** | P2 — Polish | Low |
| **Leaderboard (local)** | P2 — Retention | Low |
| **SFX & juice (particles, screenshake)** | P2 — Polish | Medium |
| **POI system (ruined towers)** | P3 — Stretch goal | Medium |
| **Alt grid sizes (game modes)** | P3 — Stretch goal | Low |
| **Steam integration** | P3 — Launch | Low |

---

## Development Plan (6–8 Weeks)

### Week 1: Core Loop Skeleton
**Goal:** Playable prototype with grid, cursor weapon, basic waves, and gold.

- [ ] Strip out UnitManager, SelectionRect, formations, command inputs
- [ ] Implement GridManager + GridCell system
  - 7x7 grid of Area2D cells
  - Visual grid overlay (faint lines)
  - Cell hover highlighting
  - Castle in center cell
- [ ] Implement basic cursor weapon (left click = damage at mouse position)
  - Area query at mouse position for enemies
  - Damage number popup
  - Simple particle effect on hit
- [ ] Implement gold system
  - Enemies drop gold on death
  - Gold drifts toward cursor position (auto-collect)
  - Gold counter in HUD
- [ ] Implement wave manager
  - Wave counter, enemy count tracker
  - Wave complete detection (all enemies dead)
  - Escalating enemy count per wave
  - Brief pause between waves
- [ ] Basic HUD (wave number, gold, castle HP, unit count)

**Milestone:** You can click enemies to kill them, collect gold, and waves escalate. Grid is visible but not yet interactive.

---

### Week 2: Grid Deployment & Shop Foundation
**Goal:** Right-click cell assignment, unit requisition system, and between-wave shop.

- [ ] Cell assignment panel (right-click popup)
  - +/- buttons per unit type
  - Shows current stationed count vs. ordered count
  - Close on click-away or Escape
- [ ] Requisition Manager
  - Tracks standing orders per cell
  - Spawn queue: determines next unit type based on unfilled orders
  - Unit spawning on timer at castle
- [ ] Unit auto-pathing from castle to assigned cell
  - Path to cell center using NavigationAgent2D
  - Once in cell, switch to simple patrol behavior
  - Units fight enemies within their cell
- [ ] Shop UI screen (opens between waves)
  - Category tabs: Cursor, Units, Defenses, Global
  - Buy button with gold cost
  - "Start Next Wave" button
- [ ] Implement upgrade data system
  - Upgrade definitions (name, description, cost, max level, effect)
  - Player upgrade state tracking
  - Cost scaling per level
- [ ] Basic cursor upgrades (Smite damage increase)
- [ ] Basic unit upgrades (spawn rate, max count, HP, damage)
- [ ] Castle repair option in shop

**Milestone:** Full loop: fight wave → earn gold → assign units to cells → buy upgrades → fight harder wave.

---

### Week 3: Cursor Abilities & Defense Structures
**Goal:** Multiple cursor abilities and grid-based defense building.

- [ ] Implement cursor ability system
  - Ability slots with cooldowns
  - Meteor Strike (hold to charge, AOE on release)
  - Frost Trail (drag to slow)
  - Flame Sweep (drag to damage)
  - Chain Lightning (click arcs to nearby enemies)
- [ ] Cooldown display in HUD
- [ ] Defense structures in grid cells
  - Arrow Tower (auto-targets nearest enemy in range)
  - Barricade (slows enemy movement through cell)
  - Build/upgrade/sell via cell assignment panel
- [ ] Defense upgrades in shop
- [ ] Visual feedback polish
  - Better particles for cursor abilities
  - Screen shake on meteor strike
  - Tower attack projectiles
  - Cell-under-attack indicator (red pulse)

**Milestone:** Multiple cursor abilities feel satisfying. Turrets shoot autonomously from grid cells.

---

### Week 4: Enemy Variety & Mid-Wave Picks
**Goal:** Multiple enemy types and the Brotato-style pick system.

- [ ] Implement enemy variants
  - Goblin (base), Orc (tanky), Wolf (fast, bypasses units), Shaman (ranged)
  - Each with different stats and sprites
  - Wave thresholds for introducing new types
- [ ] Boss enemies (every 5 waves)
  - Troll Chieftain (spawns adds)
  - Higher HP, special behavior
- [ ] Mid-wave pick-1-of-3 system
  - Triggers every N kills
  - UI popup (doesn't pause game)
  - Pool of minor buff upgrades
  - Auto-dismiss after 5 seconds
- [ ] Enemy scaling formula implementation
- [ ] Wave composition system (what types spawn when, from which edges)

**Milestone:** Waves feel varied. Mid-wave picks add exciting moments during combat.

---

### Week 5: Balance, Content & Polish
**Goal:** Make the game feel good. Tune numbers. Add remaining content.

- [ ] Remaining cursor upgrades (Healing Touch, Gold Magnet radius, Wrath)
- [ ] Remaining defenses (Cannon Tower, Frost Tower)
- [ ] Remaining enemy types (Skeleton, Siege Golem)
- [ ] Additional bosses (Necromancer, Dragon)
- [ ] Balance pass
  - Gold income vs. upgrade costs
  - Enemy scaling vs. player power curve
  - Unit cap vs. grid coverage (can't cover all 48 cells — tension is intentional)
  - Target: skilled player survives 25-35 waves; average player 10-15
- [ ] Castle visual damage stages
- [ ] Gold pickup magnet feel (satisfying drift toward cursor)
- [ ] Grid visual polish (cell status indicators, unit count badges)
- [ ] Unit march animations looking good

**Milestone:** 30+ minutes of gameplay feels balanced and escalating.

---

### Week 6: Game Over, Menus & Juice
**Goal:** Complete game experience from menu to game over.

- [ ] Main menu (Play, Settings, Quit)
- [ ] Game over screen
  - Final stats (wave, kills, gold earned, time survived)
  - Local high score table
  - "Play Again" button
- [ ] Settings (volume, resolution/window mode)
- [ ] SFX pass (cursor attacks, enemy deaths, gold pickup, wave start/end, cell assignment)
- [ ] Music (find royalty-free tracks or commission)
- [ ] Tutorial/first-wave hints (teach right-click for cells, left-click for combat)
- [ ] Pause menu

**Milestone:** Complete game loop from start to finish with audio and menus.

---

### Week 7-8: Playtest, Polish & Ship
**Goal:** Bug fixing, final balance, Steam preparation.

- [ ] Playtesting (self + friends)
- [ ] Bug fixing
- [ ] Final balance adjustments
- [ ] Performance optimization (enemy count + unit count stress test)
- [ ] Consider: POI system if ahead of schedule (ruined towers on certain cells)
- [ ] Consider: alternate grid sizes as game modes (5x5 "Outpost", 9x9 "Fortress")
- [ ] Steam page setup (screenshots, description, tags)
- [ ] Steam integration (achievements if time allows)
- [ ] Build & export for Windows/Linux
- [ ] Launch trailer (screen recording of intense late-game wave with cursor destruction)

**Milestone:** Ship it! 🚀

---

## Viral Potential & Marketing Hooks

**Why this could get attention:**

1. **"My cursor does 10,000 DPS"** — Clips of late-game cursor destruction are inherently shareable
2. **Power scaling porn** — Early game vs. late game comparison clips (weak poke → screen-clearing lightning)
3. **"One more wave" addiction** — Endless format creates natural tension moments
4. **Low barrier to entry** — Anyone can click a mouse. No complex controls to learn.
5. **Build diversity** — "I went full cursor build and melted everything" vs "I stacked turrets and AFK'd" — encourages discussion

**Content creator friendly:**
- Escalating chaos = good video content
- Natural run variety = replayability on stream
- Easy to understand watching = good for YouTube/TikTok
- "How far can you get?" = community challenge format

---

## Technical Notes

### Architecture Changes from Current Build

```
Current:                          New:
Combatant                         Combatant (simplified)
  ├── Unit (player-controlled)      ├── AutoUnit (grid-assigned, AI-only)
  └── Enemy                         └── Enemy
UnitManager (RTS controls)        GridManager (new — grid state, cell data)
EnemySpawner                      CursorWeapon (new)
                                  WaveManager (expanded spawner)
                                  RequisitionManager (new — standing orders, spawn queue)
                                  ShopManager (new)
                                  UpgradeManager (new)
                                  CellPanel UI (new — right-click popup)
                                  GoldManager (new)
                                  PickThreeUI (new)
```

### Key Godot Nodes for New Systems

- **GridManager:** Node2D that creates/manages the 7x7 grid of cells, handles cell state and hover detection
- **GridCell:** Area2D representing one cell — tracks stationed units, structure, and standing orders
- **CursorWeapon:** Node2D that follows mouse, handles left-click input, applies abilities
- **WaveManager:** Node that controls spawning, wave state, difficulty
- **RequisitionManager:** Node that manages standing orders and spawn queue — decides what unit type to spawn next based on unfilled orders
- **CellPanel:** Control node (popup UI) — opened on right-click, shows +/- per unit type and structure options
- **ShopManager:** CanvasLayer with shop UI, handles transactions between waves
- **UpgradeManager:** Autoload/singleton that tracks all upgrade states
- **Tower:** Area2D placed within a GridCell, timer-based auto-attack on enemies in range
- **GoldPickup:** Area2D that drifts toward cursor (Gold Magnet upgrade increases radius)

### Performance Considerations
- Object pooling for enemies (reuse instead of instantiate/free)
- Limit particle counts on cursor abilities
- Use `call_group()` for batch operations on enemies
- Unit pathfinding: units only need to path from castle to their assigned cell — once there, simple steering within cell bounds (no continuous NavigationAgent2D needed)
- Grid cell enemy detection: each GridCell has an Area2D — use `get_overlapping_bodies()` to know what's in each cell
- Consider simple steering behaviors instead of NavigationAgent2D for units patrolling within cells
