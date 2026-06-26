# Purusharthas — Full Implementation Plan (Phases 1–4)

A 2D strategy game built in **Godot 4.7** with four interlocked gameplay layers rooted in the classical Indian Purushartha framework. All work happens inside `d:\Projects\purusharthas\purusharthas\`.

---

## User Review Required

> [!IMPORTANT]
> This plan covers ~12 months of GDD scope compressed into iterative development with you. Each phase builds on the last. Please review the scope, priorities, and any open questions before we begin.

> [!WARNING]
> The GDD describes a very ambitious game. This plan prioritises **playable systems over visual polish** — we'll get mechanics working first, then layer on art and audio in Phase 4. Placeholder art (colored rectangles, simple shapes) will be used until then.

---

## Open Questions

1. **Starting scope**: The GDD says Phase 1 is Village Builder standalone. Should we build a **main menu** and **layer-switching UI** from the start, or focus purely on the Village Builder first and add navigation later?

2. **Resolution & viewport**: The project is set to `canvas_items` stretch mode. What is the target resolution? (Recommended: **1920×1080** for a 2D strategy game.)

3. **Tile size**: For the Village Builder tilemap, what tile size do you prefer? (Recommended: **32×32** or **64×64** pixels for a top-down grid. Hex tiles for Civilisation layer would be ~64px wide.)

4. **GDScript vs C#**: The GDD doesn't specify. This plan assumes **GDScript** throughout. Should we use C# for any performance-critical systems?

5. **Placeholder dynasty**: For Phase 3 Civilisation layer, should we implement **all 5 dynasties** or start with one (e.g., Maurya) and add others incrementally?

6. **Save slots**: How many save slots? Or a single auto-save + manual save system?

---

## Project Folder Structure

First step — establish the canonical directory layout defined in the GDD:

```
res://
├── core/                          # Shared systems (autoloads, managers)
│   ├── global_state.gd            # GlobalState autoload — 4 axes + layer states
│   ├── event_bus.gd               # EventBus autoload — signal relay
│   ├── save_system.gd             # SaveSystem autoload — JSON save/load
│   ├── turn_manager.gd            # Turn/Season manager — unified time
│   └── game_manager.gd            # Layer switching, scene management
│
├── layers/
│   ├── village/                   # Layer I — Village Builder (Dharma)
│   │   ├── scenes/
│   │   ├── scripts/
│   │   ├── tiles/
│   │   └── data/
│   ├── governance/                # Layer II — Dharmic Governance (Artha)
│   │   ├── scenes/
│   │   ├── scripts/
│   │   └── data/
│   ├── civilisation/              # Layer III — Civilisation-Lite (Kama)
│   │   ├── scenes/
│   │   ├── scripts/
│   │   ├── tiles/
│   │   └── data/
│   └── pilgrim/                   # Layer IV — Pilgrim Route Sim (Moksha)
│       ├── scenes/
│       ├── scripts/
│       └── data/
│
├── ui/                            # Shared UI components
│   ├── themes/
│   ├── components/
│   └── screens/
│
├── assets/                        # Art, audio, fonts
│   ├── art/
│   ├── audio/
│   ├── fonts/
│   └── shaders/
│
├── data/                          # Global JSON data files
│   ├── events/
│   ├── characters/
│   ├── dynasties/
│   ├── buildings/
│   └── goods/
│
└── project.godot
```

---

## Phase 1 — Prototype: Village Builder + Core Systems

**Goal**: A playable Village Builder with seasonal cycles, labor allocation, Panchayat, folk events, threats, and the Gram Swaraj scoring system. Plus all shared core systems.

---

### 1.1 Core Systems (Shared Foundation)

These autoloads and managers will be used by ALL four layers.

#### [NEW] [global_state.gd](file:///d:/Projects/purusharthas/purusharthas/core/global_state.gd)
- Autoload singleton holding the **four Purushartha axes** (Dharma, Artha, Kama, Moksha) as float values (0.0–100.0)
- Per-layer state dictionaries (village_state, governance_state, civilisation_state, pilgrim_state)
- Population, treasury, food, culture, morale as top-level civilisational resources
- Methods: `modify_axis(axis, delta)`, `get_axis(axis)`, `get_balance_score()`
- Cross-layer modifier system: a list of active modifiers with source, target, duration, and magnitude

#### [NEW] [event_bus.gd](file:///d:/Projects/purusharthas/purusharthas/core/event_bus.gd)
- Autoload singleton with predefined signals for cross-layer communication:
  - `village_event(event_type, data)` — emitted by Village layer
  - `governance_event(event_type, data)` — emitted by Governance layer
  - `civilisation_event(event_type, data)` — emitted by Civilisation layer
  - `pilgrim_event(event_type, data)` — emitted by Pilgrim layer
  - `season_changed(season_name, year)` — emitted by TurnManager
  - `decade_changed(decade, era)` — emitted by TurnManager
  - `axis_changed(axis_name, old_value, new_value)` — emitted by GlobalState
  - `resource_changed(resource_name, old_value, new_value)`
  - `notification(title, message, severity)` — for UI toast system

#### [NEW] [turn_manager.gd](file:///d:/Projects/purusharthas/purusharthas/core/turn_manager.gd)
- Manages a **unified global year counter** starting at a configurable year (e.g., 300 BCE)
- Each layer has its own time granularity:
  - Village: 3 seasons per year (Kharif → Rabi → Zaid)
  - Governance: decades (every 10 years)
  - Civilisation: eras (every 25 years)
  - Pilgrim Route: yearly
- Methods: `advance_season()`, `get_current_season()`, `get_current_year()`, `get_current_decade()`
- Emits signals through EventBus when time advances

#### [NEW] [game_manager.gd](file:///d:/Projects/purusharthas/purusharthas/core/game_manager.gd)
- Manages layer switching (which layer is currently active/visible)
- Loads/unloads layer scenes
- Handles the main game loop state (MENU, PLAYING, PAUSED, EVENT)
- Methods: `switch_to_layer(layer_name)`, `pause_game()`, `resume_game()`

#### [NEW] [save_system.gd](file:///d:/Projects/purusharthas/purusharthas/core/save_system.gd)
- JSON-based save/load using `FileAccess` and `JSON`
- Serializes: GlobalState snapshot, per-layer state, TurnManager state
- Save path: `user://saves/`
- Methods: `save_game(slot)`, `load_game(slot)`, `list_saves()`
- (Full implementation in Phase 4, stub with interface in Phase 1)

#### [MODIFY] [project.godot](file:///d:/Projects/purusharthas/purusharthas/project.godot)
- Register autoloads: GlobalState, EventBus, TurnManager, GameManager, SaveSystem
- Set target resolution (1920×1080)
- Configure input actions (pause, layer_switch_1/2/3/4, advance_turn, etc.)

---

### 1.2 Village Builder — Layer I (Dharma)

#### Scene Tree Structure
```
VillageLayer (Node2D)
├── TileMapLayer (village terrain — grass, water, paths, farmland)
├── BuildingLayer (Node2D — placed buildings as sprites/scenes)
├── VillageManager (script — core village logic)
├── SeasonManager (script — seasonal cycle for this layer)
├── PanchayatSystem (script — voting, disputes, trust)
├── LaborSystem (script — allocation across activities)
├── EventSystem (script — folk events, threats)
└── VillageUI (CanvasLayer)
    ├── ResourceBar (HBoxContainer — food, morale, culture, trade, trust)
    ├── SeasonDisplay (label + icon)
    ├── LaborPanel (allocation sliders)
    ├── PanchayatPanel (voting UI)
    ├── EventPopup (event cards)
    └── BuildPanel (building placement)
```

#### [NEW] Village Tilemap & Terrain
- **Tile types**: Grass, Farmland (Kharif/Rabi/Zaid), Water (well, river), Path, Forest, Sacred Grove
- Custom tile metadata: `tile_type`, `fertility`, `moisture`, `occupied_by`
- Initial map: small village area (~30×30 tiles) with a central well, surrounding farmland, and forest edges
- TileSet created programmatically or via .tres resource with placeholder colored tiles

#### [NEW] Building System
- Buildings defined in JSON data: `res://data/buildings/village_buildings.json`
- Building types from GDD: Houses, Granary, Temple, Workshop (pottery, weaving, smithing), Market, Dharamshala, School, Well
- Each building: cost, build_time, capacity, effects (on morale, culture, food, trade)
- Placement on tilemap grid, building scenes instantiated as children of BuildingLayer
- Upgrade system: buildings have 3 tiers

#### [NEW] Labor Allocation System
- Village population divided into labor units
- Allocation categories (from GDD): Farming, Craft Production, Trade Caravans, Temple Upkeep, Community Service
- Each season, player allocates labor via slider UI
- Output calculated based on allocation × skill × season modifiers × random events
- Population grows/shrinks based on food surplus/deficit and morale

#### [NEW] Seasonal Cycle
- **Kharif** (monsoon): rice, sugarcane, cotton — high rain dependency, flood risk
- **Rabi** (winter): wheat, barley, mustard — stable, lower yield
- **Zaid** (summer): watermelon, cucumber, vegetables — cash crops, water-intensive
- Each season: allocation phase → production phase → event phase → resolution
- Season transitions trigger visual changes (placeholder: palette swap on tiles)

#### [NEW] Panchayat System
- Every 3–5 years, Panchayat convenes
- Presents 2–3 issues (disputes, infrastructure priorities, resource allocation)
- Villagers vote; player can advise or override
- **Trust meter**: overriding costs trust; aligning with majority gains trust
- High trust → productivity bonus, low trust → labor strikes/migration
- Issues loaded from JSON: `res://data/events/panchayat_issues.json`

#### [NEW] Folk Events System
- Seasonal/random events: Holi, Harvest Festival, Weddings, Fairs, Sacred ceremonies
- Each event: resource cost (food, culture) → morale/culture boost
- Player chooses investment level (modest/standard/grand)
- Events loaded from JSON: `res://data/events/village_events.json`

#### [NEW] Threats System
- Random threats per season: Drought, Dacoit Raids, Debt Collectors, Disease Outbreaks, Migration Pressure
- Each threat: severity, resource impact, resolution options
- Player makes choices (e.g., fight dacoits vs. pay tribute vs. seek kingdom help)
- Threats loaded from JSON: `res://data/events/village_threats.json`

#### [NEW] Gram Swaraj Scoring
- Composite score of: Food Security (25%), Cultural Vibrancy (25%), Panchayat Trust (25%), Trade Connections (25%)
- Displayed as a radial chart in the UI
- Score ranges: Struggling (0–25), Developing (26–50), Thriving (51–75), Swaraj (76–100)
- High score unlocks boons in Governance and Civilisation layers (Phase 2+)

#### [NEW] Village Data Files
- `res://data/buildings/village_buildings.json` — building definitions
- `res://data/events/village_events.json` — folk events
- `res://data/events/village_threats.json` — threat events
- `res://data/events/panchayat_issues.json` — Panchayat decision cards
- `res://data/goods/crops.json` — crop types, seasons, yields
- `res://data/goods/crafts.json` — craft goods, materials, values

---

### 1.3 UI Foundation

#### [NEW] Game Theme
- `res://ui/themes/game_theme.tres` — base theme with the GDD palette:
  - Deep Ochre `#CC7722`, Indigo `#2E0854`, Saffron `#FF9933`, Forest Green `#228B22`, Ivory `#FFFFF0`, Gold `#FFD700`
- Font: placeholder system font (replaced with custom font in Phase 4)
- Styled buttons, panels, labels, sliders with earthy/manuscript aesthetic

#### [NEW] Shared UI Components
- `res://ui/components/resource_bar.tscn` — horizontal bar showing icon + value + trend arrow
- `res://ui/components/notification_toast.tscn` — slide-in notification for events
- `res://ui/components/event_card.tscn` — popup card with title, description, choices
- `res://ui/components/radial_chart.tscn` — for Gram Swaraj / Purushartha axis display

#### [NEW] Main Menu
- `res://ui/screens/main_menu.tscn` — New Game, Load Game, Settings, Quit
- Simple but styled with GDD palette
- New Game → starts Village Builder (Phase 1), later adds layer selection

#### [NEW] HUD / Layer Switcher
- `res://ui/screens/hud.tscn` — persistent top bar showing:
  - Current year & season
  - Four Purushartha axis mini-bars
  - Layer tabs (Village / Governance / Civilisation / Pilgrim) — only Village active in Phase 1
  - Pause / Settings buttons

---

## Phase 2 — Integration: Governance Layer + Cross-Layer Events

**Goal**: Add the Dharmic Governance layer with the four-axis system, council advisors, succession, and implement the first cross-layer event propagation between Village and Governance.

---

### 2.1 Governance Layer — Layer II (Artha)

#### Scene Tree Structure
```
GovernanceLayer (Node2D)
├── KingdomMap (TextureRect or TileMapLayer — simplified regional view)
├── GovernanceManager (script — core governance logic)
├── CouncilSystem (script — 4 advisors, loyalty, influence)
├── DecadeManager (script — decade-based turn progression)
├── SuccessionSystem (script — heir grooming)
├── GovernanceEventSystem (script — invasions, droughts, sage arrivals)
└── GovernanceUI (CanvasLayer)
    ├── AxisDisplay (4 Purushartha axis bars with labels)
    ├── CouncilPanel (4 advisor portraits + loyalty + advice)
    ├── DecisionPanel (event card with choices + axis shift preview)
    ├── SuccessionPanel (heir attributes + grooming options)
    └── LegacyScorePanel (end-of-reign summary)
```

#### [NEW] Four Purushartha Axes (full implementation)
- Each axis: 0–100 float value, stored in GlobalState
- Visual display: 4 colored bars (Dharma=saffron, Artha=gold, Kama=indigo, Moksha=ivory)
- **Imbalance consequences** (from GDD):
  - Artha high + Dharma low → peasant revolt
  - Moksha high + Artha low → military weakness
  - Kama low → cultural stagnation event
  - Dharma high + Kama low → rigid society
- Imbalance thresholds checked each decade

#### [NEW] Council System
- 4 advisors (from GDD): **Purohit** (spiritual), **Senapati** (military), **Amatya** (finance), **Vaishya** (trade)
- Each advisor: name, portrait, personality, loyalty (0–100), influence (0–100)
- Advisors give recommendations on events (biased toward their domain)
- Overriding an advisor costs loyalty; following gains loyalty
- Low loyalty → advisor may sabotage, defect, or resign
- Advisor data: `res://data/characters/advisors.json`

#### [NEW] Governance Events
- Events per decade: 2–4 events drawn from pool
- Event types (from GDD): Invasions, Droughts, Sage Arrivals, Trade Negotiations, Internal Revolts, Cultural Milestones
- Each event: description, 2–4 choices, each choice shifts axes differently
- Advisor recommendations shown alongside choices
- Events: `res://data/events/governance_events.json`

#### [NEW] Succession System
- Raja has lifespan (3–5 decades of rule)
- Must groom an heir: choose from 2–3 candidates with different temperaments
- Heir temperament shaped by kingdom's accumulated axis values
- On death: Legacy Score calculated, heir inherits with bonuses/penalties
- Smooth transition vs. crisis (based on heir preparation + kingdom stability)

#### [NEW] Legacy Scoring
- End-of-reign evaluation across all 4 axes
- Historical titles: "The Just", "The Conqueror", "The Patron", "The Ascetic", etc.
- Legacy modifiers carry into next generation
- Legacy display: narrative summary + axis chart

---

### 2.2 Cross-Layer Event System (Village ↔ Governance)

#### [MODIFY] [event_bus.gd](file:///d:/Projects/purusharthas/purusharthas/core/event_bus.gd)
- Add cross-layer propagation signals
- Implement modifier queue: when a layer emits an event, the EventBus translates it into modifiers for other layers

#### [NEW] Cross-Layer Modifier System
- Modifiers are typed: `{source_layer, target_layer, target_resource, magnitude, duration, reason}`
- Example propagations (from GDD):
  - Village famine → Governance Artha axis drops, tax revenue falls
  - Governance passes temple tax exemption → Village temple upkeep free, pilgrim donations surge
  - Village Panchayat revolt → Governance Artha drops, regional instability

#### [MODIFY] [global_state.gd](file:///d:/Projects/purusharthas/purusharthas/core/global_state.gd)
- Add modifier processing: `apply_modifier()`, `tick_modifiers()`, `remove_expired_modifiers()`
- Modifiers stack and decay over time

---

## Phase 3 — Expansion: Civilisation Layer + Pilgrim Route

**Goal**: Add the remaining two layers (Civilisation hex-map strategy and Pilgrim Route logistics sim) and complete the full cross-layer integration.

---

### 3.1 Civilisation Layer — Layer III (Kama)

#### Scene Tree Structure
```
CivilisationLayer (Node2D)
├── HexMap (TileMapLayer — hex grid of Indian subcontinent)
├── CivilisationManager (script — core civ logic)
├── DynastySystem (script — dynasty selection, traits, legacy)
├── DiplomacySystem (script — alliances, marriages, tribute)
├── MilitarySystem (script — armies, battles, expansion)
├── CultureSystem (script — cultural influence spread)
├── CivAI (script — rival dynasty AI)
└── CivilisationUI (CanvasLayer)
    ├── HexInfoPanel (selected tile info)
    ├── DiplomacyPanel (relations, treaties)
    ├── MilitaryPanel (army management)
    ├── CulturePanel (influence map overlay)
    ├── DynastyPanel (dynasty info, victory progress)
    └── TurnControls (end turn, speed)
```

#### [NEW] Hex Map System
- Hex-based TileMapLayer representing the Indian subcontinent
- Tile types: Plains, Mountains, Rivers, Forests, Coast, Desert
- Each hex: owner (dynasty), population, culture_level, resources, buildings
- ~200–300 hex tiles for a simplified subcontinent map
- Hex data: `res://data/map/subcontinent_hexes.json`

#### [NEW] Dynasty System
- 5 dynasties (from GDD): Maurya, Gupta, Chola, Maratha, Vijayanagara
- Each dynasty: unique starting position, special mechanics, victory bias
- Dynasty traits loaded from: `res://data/dynasties/dynasty_definitions.json`
- Player selects dynasty at game start (or this is pre-selected based on era)

#### [NEW] Diplomacy, Military, Culture Systems
- **Diplomacy**: alliances, marriage alliances, tribute, trade agreements, betrayal
- **Military**: army units (infantry, cavalry, elephants, navy for Chola), movement, simplified auto-resolve combat
- **Culture**: cultural influence spreads to adjacent hexes each turn; language/religion/architecture spread
- **Victory conditions** (from GDD): Chakravartin (military), Kalakar (cultural), Vaishya (trade), Dharmaraja (spiritual), Sarvamangala (balanced)

#### [NEW] Rival Dynasty AI
- Simple AI for non-player dynasties: expand, defend, trade, form alliances
- Each AI dynasty has a personality matching its historical pattern
- AI makes decisions each turn using weighted priorities

---

### 3.2 Pilgrim Route Layer — Layer IV (Moksha)

#### Scene Tree Structure
```
PilgrimLayer (Node2D)
├── RouteMap (Node2D — node/edge graph of pilgrimage route)
├── PilgrimManager (script — core pilgrim logic)
├── FacilitySystem (script — dharamshalas, ghats, temples, rest houses)
├── StaffSystem (script — priests, cooks, bearers, vaidyas, guides)
├── PilgrimAI (script — pilgrim needs, movement, satisfaction)
├── MiracleSystem (script — rare miraculous events)
└── PilgrimUI (CanvasLayer)
    ├── RouteOverview (node map with status indicators)
    ├── FacilityPanel (facility details, upgrades)
    ├── StaffPanel (hiring, assignment)
    ├── PilgrimFlowPanel (incoming/outgoing pilgrims, needs)
    ├── SeasonalSurgeWarning (Kumbh, Shravan alerts)
    └── TirthaScoreDisplay (route reputation)
```

#### [NEW] Route/Node Network
- 4 major shrines connected by a path network with intermediate stops
- Each node: type (shrine, rest house, ghat, market, crossroads), capacity, facilities
- Edges: distance, terrain difficulty, hazard level
- Visual: 2D node graph with paths drawn between nodes
- Route data: `res://data/map/pilgrim_route.json`

#### [NEW] Pilgrim Simulation
- Pilgrims arrive at entry nodes with varying needs: rest, food, ritual, medical, guidance
- Pilgrims move along the route, stopping at facilities
- Satisfaction tracked per pilgrim; aggregate satisfaction = route reputation
- Seasonal surges (from GDD): Kumbh, Shravan, Kartik Purnima — massive influx

#### [NEW] Facility & Staff Management
- Build/upgrade facilities at nodes: dharamshalas, temples, kitchens, clinics
- Hire staff: priests, cooks, palanquin bearers, vaidyas, guides
- Staff have skill levels and stamina; overwork reduces effectiveness
- Donations and offerings fund operations; reputation attracts benefactors

#### [NEW] Tirtha Scoring
- Composite of: pilgrim satisfaction, route safety, facility quality, spiritual events
- Tirtha status = route becomes a permanent sacred corridor
- High Tirtha → permanent boosts to all other layers (from GDD)

---

### 3.3 Full Cross-Layer Integration

#### [MODIFY] [event_bus.gd](file:///d:/Projects/purusharthas/purusharthas/core/event_bus.gd)
- Complete the cross-layer propagation matrix (all 4 layers → all 4 layers)
- All propagations from GDD §4 implemented:

| Trigger | Effects |
|---|---|
| Village famine | Tax ↓ in Governance; pilgrims ↓ on Route; expansion ↓ in Civ |
| Governance temple tax exemption | Route donations ↑; village temple free; culture ↑ in Civ |
| Civ expands to new region | New trade goods in Village; new destinations on Route; new province in Governance |
| Route achieves Tirtha | Village morale ↑ permanent; Governance Dharma ↑; Civ sacred architecture unlock |
| Village Panchayat revolt | Governance Artha ↓; Civ regional instability; Route pilgrims ↓ |

---

## Phase 4 — Polish: Art, Audio, Narrative, Save System

**Goal**: Transform the functional prototype into a polished, atmospheric experience with authentic Indian art, music, narrative framing, and robust save/load.

---

### 4.1 Art Pass

#### Village Layer (Pattachitra Style)
- Replace placeholder tiles with Pattachitra-inspired tileset:
  - Bold black outlines, flat fills, intricate interior patterns
  - Earthy palette: terracotta, indigo, ochre, cream
- Building sprites in Pattachitra style
- Character/villager sprites (small, stylized)
- Seasonal palette shifts (monsoon=lush greens, winter=golden, summer=warm ochres)

#### Governance Layer (Mughal Miniature Style)
- Kingdom map with Mughal miniature aesthetic: detailed architecture, jewel tones
- Advisor portraits in miniature painting style
- Decision card art with ornate borders
- Axis display with manuscript marginalia decoration

#### Civilisation Layer (Mughal Miniature + Map Style)
- Hex map tiles with period-appropriate terrain art
- Dynasty emblems and banners
- Battle/event illustrations
- Cultural influence shown as color gradients on map

#### Pilgrim Route Layer (Meditative/Sacred Style)
- Node illustrations of shrines, ghats, dharamshalas
- Pilgrim sprites (small, moving along paths)
- Sacred geometry decorations
- Warm, devotional color palette

#### Shared UI Art
- **Warli-style** elements for: map overlays, loading screens, transitions, borders
- Manuscript-marginalia inspired panels and frames
- Custom cursor themed to the game
- Transition animations between layers (Warli pattern wipes)

### 4.2 Audio Integration

#### [NEW] Audio Manager
- `res://core/audio_manager.gd` — autoload for music/SFX management
- Dynamic audio mixer: blends soundscapes when switching layers
- Layer-specific music systems:
  - **Village**: folk instruments (dhol, bansuri, sarangi), field/river/market ambience
  - **Governance**: Hindustani raga system, raga shifts with time/season/axis
  - **Civilisation**: orchestral + Carnatic elements, tempo varies with conflict/peace
  - **Pilgrim Route**: Vedic chants, temple bells, nature ambience
- SFX: UI clicks, building placement, season transitions, event stingers

> [!NOTE]
> Audio assets (music, SFX) will need to be sourced — either royalty-free Indian classical/folk music or commissioned. Placeholder silence/simple tones until assets are ready.

### 4.3 Narrative System

#### [NEW] Kathakaar (Narrator) System
- `res://core/narrator.gd` — manages narrative framing
- Opening sequence: wandering storyteller at a crossroads addresses player
- End-of-era narration: storyteller reflects on player's choices
- Contextual narration: storyteller comments on major events
- Text displayed in a styled dialogue box with portrait

#### [NEW] In-Game Encyclopedia
- `res://ui/screens/encyclopedia.tscn` — accessible from any layer
- Entries for: historical figures, concepts, terminology, dynasties, buildings, events
- Entries unlock as player encounters them
- Data: `res://data/encyclopedia/entries.json`

### 4.4 Save System (Full Implementation)

#### [MODIFY] [save_system.gd](file:///d:/Projects/purusharthas/purusharthas/core/save_system.gd)
- Complete JSON serialization of all game state
- Multiple save slots (3 manual + 1 autosave)
- Autosave on season/turn changes
- Save file includes: GlobalState, all layer states, TurnManager, unlocked encyclopedia entries
- Load game with full state restoration
- Save file validation and corruption recovery

### 4.5 Settings & Accessibility

#### [NEW] Settings Menu
- Audio: master, music, SFX, ambience volumes
- Display: resolution, fullscreen, V-sync
- Gameplay: text speed, auto-pause on events, tutorial tooltips
- Accessibility: text size scaling, colorblind palette option

---

## Verification Plan

### Automated Tests
We won't have a full test suite, but we'll verify:
```
# After each phase, run the project and verify:
# - No errors in Godot console
# - All autoloads register correctly
# - Scene tree loads without crashes
```

### Manual Verification Per Phase

**Phase 1:**
- [ ] Village Builder loads with tilemap and buildings
- [ ] Seasons cycle correctly (Kharif → Rabi → Zaid)
- [ ] Labor allocation affects production
- [ ] Panchayat triggers every few years, trust changes work
- [ ] Folk events cost resources and boost morale/culture
- [ ] Threats appear and player can respond
- [ ] Gram Swaraj score updates correctly
- [ ] Main menu → New Game → Village loads

**Phase 2:**
- [ ] Governance layer loads with kingdom map and advisor panels
- [ ] Decade events appear with choices and axis shifts
- [ ] Council advisors give recommendations, loyalty changes
- [ ] Imbalance consequences trigger correctly
- [ ] Succession system works (heir grooming, death, transition)
- [ ] Cross-layer events propagate (village famine → governance tax drop)
- [ ] Layer switching works (tab between Village and Governance)

**Phase 3:**
- [ ] Civilisation hex map loads with dynasty territories
- [ ] Turn-based expansion, diplomacy, and combat work
- [ ] Cultural influence spreads across hexes
- [ ] AI dynasties make decisions and expand
- [ ] Pilgrim Route node network loads with facilities
- [ ] Pilgrims arrive, move, and have needs fulfilled
- [ ] Seasonal surges create capacity pressure
- [ ] Full cross-layer propagation works across all 4 layers

**Phase 4:**
- [ ] All placeholder art replaced with styled assets
- [ ] Audio plays correctly per layer with transitions
- [ ] Kathakaar narration appears at key moments
- [ ] Encyclopedia entries unlock and display
- [ ] Save/Load works across all layers
- [ ] Settings menu functional
- [ ] Full playthrough from start to legacy score without crashes

---

## Execution Order

We'll build in this sequence, file by file:

1. **Folder structure** → create all directories
2. **Core autoloads** → GlobalState, EventBus, TurnManager, GameManager, SaveSystem (stub)
3. **Register autoloads** in project.godot
4. **Village data files** → JSON definitions for buildings, crops, events, threats
5. **Village tilemap + terrain** → TileSet, TileMapLayer, initial map
6. **Village systems** → LaborSystem, SeasonManager, BuildingSystem
7. **Village events** → PanchayatSystem, FolkEventSystem, ThreatSystem
8. **Village UI** → resource bars, labor panel, event cards, Gram Swaraj display
9. **Main menu + HUD** → menu screen, layer tabs, persistent HUD
10. **Phase 1 playtesting & polish**
11. **Governance layer** → all systems, UI, events
12. **Cross-layer V↔G** → event propagation, modifiers
13. **Civilisation layer** → hex map, dynasties, AI, combat, diplomacy
14. **Pilgrim Route layer** → node network, facilities, pilgrims
15. **Full cross-layer integration**
16. **Art pass** → all layers
17. **Audio** → music, SFX, dynamic mixer
18. **Narrative** → Kathakaar, encyclopedia
19. **Save system** → full implementation
20. **Final polish** → settings, accessibility, playtesting
