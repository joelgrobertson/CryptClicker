# Crypt Clicker — Project Context for Claude Code

## What This Project Is

Crypt Clicker is a 2D top-down endless survival game built in **Godot 4.x with GDScript**. The player defends a crypt (center of the map) against waves of invading heroes. The twist: you play as the monsters. You command an army of undead/monsters AND your mouse cursor is a weapon that directly damages enemies.

**Target:** Small, polished game for Steam at $6.99. Solo dev project, 6-8 week timeline.

**Inspirations:** Vampire Survivors, Brotato, and tower defense — but with a novel cursor-as-weapon mechanic and a grid-based unit deployment system.

---

## Core Gameplay Loop

```
WAVE STARTS
  → Heroes (enemies) spawn from map edges, march toward crypt
  → Player's monsters auto-fight in their assigned grid cells
  → Player LEFT-CLICKs to deal cursor damage directly to enemies
  → Mid-wave: pick-1-of-3 upgrade popups (not yet implemented)
  → Enemies drop gold on death, gold drifts toward cursor
WAVE ENDS
  → Shop opens: buy upgrades (cursor, units, defenses, global)
  → Player adjusts unit deployment on the grid
  → Click "Start Next Wave"
```

**Game over** when crypt HP reaches 0. Score = wave number reached.

---

## Two Input Layers

- **Left click** = Cursor weapon. Always active during waves. Damages enemies near click point. Will eventually have abilities (meteor strike, chain lightning, frost trail, etc.)
- **Right click** = Grid management. Opens a cell assignment panel to set standing orders for units.

---

## The Grid System

- **7x7 grid** covering the battlefield. Crypt occupies center cell [3,3].
- Each cell can hold units AND one defense structure.
- Grid is drawn via `_draw()` on the GridManager node with hover highlighting.
- Cell size is 160px (configurable in GameManager).

## Unit Requisition System

Players don't control units directly. They set **standing orders** on grid cells:
1. Right-click a cell → popup shows +/- buttons per unit type
2. Setting "3 Skeletons" on a cell means the system will auto-spawn skeletons at the crypt and march them to that cell
3. Dead units auto-replace as long as the standing order exists
4. Global unit cap limits total deployable units

## Monster Roster (planned)

In order of power:
- Rats/Bats (passive cell hazard, not a real "unit" — future feature)
- **Skeleton Melee** (unlocked by default) — basic frontline
- **Skeleton Ranged** (unlock in shop) — can hit adjacent cells
- **Goblin** (unlock in shop) — fast melee hybrid
- Imps, Zombies, Ghouls, Giant Spider, Wizards, Minotaur, Dragon — future unlocks

Each fits a gameplay niche (tank, DPS, AOE, status effects, etc.)

## Enemies (Heroes attacking you)

Currently only one generic enemy type. Planned:
- Knights (basic melee)
- Paladins (tanky)
- Rogues (fast, bypass units)
- Clerics (heal other heroes)
- Mages (ranged AOE)
- Bosses every 5 waves

---

## Current State of the Codebase

### What's Working (Week 1 — completed):
- 7x7 grid renders with hover highlighting
- Crypt at center with HP tracking and visual feedback
- Enemies spawn from grid edges, pathfind to crypt, attack it
- Left-click cursor weapon damages enemies (hit radius: 60px)
- Yellow damage numbers float up on hit
- Gold drops on enemy death, drifts toward cursor, auto-collects
- HUD shows wave number, gold, crypt HP, unit count
- Waves escalate (more enemies per wave, scaling HP/damage)
- Wave banner and intermission text
- Camera zoom/pan (WASD + scroll wheel + middle mouse drag)
- Game over on crypt destruction

### What's Being Added (Week 2 — in progress):
- Cell assignment panel (right-click popup with +/- per unit type)
- RequisitionManager (spawn queue based on standing orders)
- Auto-units that path from crypt to assigned cell, patrol, and fight
- Between-wave shop UI (tabbed: Cursor, Units, Global)
- Basic upgrades (smite damage, unit HP/damage, spawn rate, unit cap, gold bonus, crypt repair)
- Unit type unlocks (skeleton ranged, goblin)

### Not Yet Built:
- Cursor abilities (meteor strike, chain lightning, frost trail, flame sweep)
- Defense structures (arrow tower, cannon tower, frost tower, barricade)
- Mid-wave pick-1-of-3 system (Brotato-style)
- Enemy variety (different hero types)
- Boss enemies
- Points of interest on the grid (stretch goal)
- Main menu, game over screen, settings
- SFX, music, particles, polish
- Steam integration

---

## Project Structure

```
CryptClicker/
├── project.godot
├── scenes/
│   ├── main.tscn           ← Main game scene
│   ├── enemy.tscn           ← Hero/enemy (CharacterBody2D)
│   └── auto_unit.tscn       ← Monster unit (CharacterBody2D) — Week 2
├── scripts/
│   ├── main.gd              ← Root scene controller, wires everything
│   ├── castle.gd            ← Crypt at center, HP, visual damage
│   ├── camera_controller.gd ← Zoom/pan camera
│   ├── cursor/
│   │   └── cursor_weapon.gd ← Left-click damage, follows mouse
│   ├── enemies/
│   │   └── enemy.gd         ← Hero AI: pathfind to crypt, attack, drop gold
│   ├── grid/
│   │   ├── grid_manager.gd  ← Creates 7x7 grid, hover, drawing, cell lookup
│   │   └── grid_cell.gd     ← Per-cell data: orders, stationed units, bounds
│   ├── managers/
│   │   ├── game_manager.gd  ← AUTOLOAD: game state, gold, waves, castle HP
│   │   ├── upgrade_manager.gd ← AUTOLOAD: all upgrade levels and computed values
│   │   ├── wave_manager.gd  ← Wave spawning, difficulty scaling
│   │   └── requisition_manager.gd ← Standing orders, unit spawn queue — Week 2
│   └── ui/
│       ├── hud.gd           ← Top bar: wave, gold, crypt HP, unit count
│       ├── gold_pickup.gd   ← Gold drop that drifts toward cursor
│       ├── cell_panel.gd    ← Right-click popup for cell unit assignment — Week 2
│       └── shop_ui.gd       ← Between-wave upgrade shop — Week 2
└── assets/                   ← Sprites, sounds (mostly placeholder currently)
```

## Main Scene Node Hierarchy

```
Main (Node2D) — main.gd
├── NavigationRegion2D (baked polygon covering play area)
│   └── Background (ColorRect — dark green)
├── Castle (Node2D) — castle.gd
│   ├── Sprite2D
│   └── HealthLabel (Label)
├── GridManager (Node2D) — grid_manager.gd
├── CursorWeapon (Node2D) — cursor_weapon.gd
├── WaveManager (Node) — wave_manager.gd [enemy_scene export = enemy.tscn]
├── RequisitionManager (Node) — requisition_manager.gd [Week 2]
├── Camera2D — camera_controller.gd
├── ShopUI (CanvasLayer, layer 20) — shop_ui.gd [Week 2]
└── CanvasLayer (layer 10)
    ├── HUD (Control) — hud.gd
    │   ├── TopBar (HBoxContainer)
    │   │   ├── WaveLabel
    │   │   ├── GoldLabel
    │   │   ├── CastleLabel
    │   │   └── UnitsLabel
    │   ├── WaveBanner (Label, hidden)
    │   └── IntermissionLabel (Label, hidden)
    └── CellPanel (PanelContainer) — cell_panel.gd [Week 2]
```

## Autoloads

- `GameManager` → `res://scripts/managers/game_manager.gd`
- `UpgradeManager` → `res://scripts/managers/upgrade_manager.gd`

## Input Actions

| Action | Input | Purpose |
|--------|-------|---------|
| `cursor_attack` | Left mouse button | Cursor weapon damage |
| `grid_interact` | Right mouse button | Open cell assignment panel |
| `camera_zoom_in` | Scroll wheel up | Zoom in |
| `camera_zoom_out` | Scroll wheel down | Zoom out |
| `camera_move_up/down/left/right` | WASD | Pan camera |
| `pause` | Escape | Pause game |

## Physics Layers

| Layer | Name | Used By |
|-------|------|---------|
| 1 | Units | Player's monster units |
| 2 | Enemies | Invading heroes |
| 3 | Structures | Towers, barricades |
| 4 | GridCells | (reserved) |
| 5 | Projectiles | (reserved) |
| 6 | Pickups | Gold, items |

---

## Key Design Decisions Already Made

- **Endless survival** (not roguelike runs) — single session, high score
- **All monster types unlocked from start**, gated by gold cost in shop
- **Grid size 7x7** — big enough to feel like a PC game, not mobile
- **Units walk from crypt** to assigned cell (travel time creates strategic tension)
- **Standing orders persist** — dead units auto-replace
- **Shop opens between waves** (game pauses) + mid-wave pick-1-of-3 (game doesn't pause)
- **No RTS micro** — you never select or command individual units
- **Placeholder art** throughout — using _draw() and tinted Godot icons. Will replace with asset packs later.

---

## Design Doc

The full game design document is in the project context/conversation history and covers:
- Complete cursor weapon upgrade tree (Smite, Chain Lightning, Meteor Strike, Frost Trail, Flame Sweep, Healing Touch, Gold Magnet, Wrath)
- All planned defense structures (Arrow Tower, Cannon Tower, Frost Tower, Barricade)
- Enemy scaling formulas
- Shop item definitions and cost scaling
- Full 6-8 week development plan
- UI mockups

---

## How to Help

The developer (Joel) is the sole developer. He's comfortable with Godot 4 and GDScript. When making changes:

- Follow existing code patterns and naming conventions
- Use GDScript (not C#)
- Keep placeholder visuals via `_draw()` or tinted sprites — don't worry about final art
- Test changes against the existing scene hierarchy
- Game state flows through the `GameManager` autoload singleton
- Upgrades are tracked in the `UpgradeManager` autoload singleton
- Communicate signals through GameManager rather than direct node references where possible
