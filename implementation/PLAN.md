# Village UI Implementation Plan

## Summary
Build the next frontend slice around the existing Godot Phase 1 village systems. The goal is to turn the current minimal HUD into a playable village management surface: resource visibility, labor allocation, season ending, event/threat/panchayat decisions, and Gram Swaraj feedback.

## Key Changes
- Replace the simple `VillageHUD` with a structured full-screen HUD: top resource/year bar, left labor panel, right village status panel, bottom action bar, and modal event cards.
- Add UI controls for `LaborSystem.set_allocation()` with bounded steppers/sliders for Farming, Craft Production, Trade Caravans, Temple Upkeep, and Community Service.
- Wire season flow in `VillageManager.end_season()` so each season runs production, food/population updates, threat checks, folk event checks, panchayat checks, Gram Swaraj refresh, then advances time.
- Add reusable event-card UI behavior for folk events, threats, and panchayat issues using the existing JSON data and system methods.
- Fix event propagation naming so famine/drought triggers call `EventBus.process_cross_layer_event("village", "village_famine", data)`.

## Interfaces / Behavior
- `VillageHUD` should discover the active `VillageManager` through the existing `village_manager` group.
- `VillageManager` should expose lightweight getters for current allocation, unallocated labor, Gram Swaraj score, pending event/threat/panchayat data, and current phase.
- UI decisions should call existing system methods first; only add new methods where needed to avoid direct mutation from UI.
- Resource labels should read from `GlobalState.village_state`, because village resources currently differ from top-level `GlobalState` resources.

## Test Plan
- Run the Godot project and verify no scene/autoload errors.
- Start a new game and confirm HUD shows year, season, population, food, gold, morale, trust, and Gram Swaraj tier.
- Change labor allocations and confirm total cannot exceed available labor.
- End several seasons and confirm production changes food/gold/culture/morale.
- Force or repeat seasons until folk events/threats/panchayat appear, then confirm choices apply outcomes and close cleanly.
- Trigger famine/drought path and confirm `EventBus` recognizes the cross-layer event without warning.

## Assumptions
- Focus stays on Village UI first, not main menu or the full shared UI component library.
- Placeholder panels/buttons are acceptable; art polish remains Phase 4.
- No new Governance/Civilisation/Pilgrim scenes are added in this slice.
- Current data files remain the source of truth for events, threats, panchayat issues, buildings, crops, and crafts.
