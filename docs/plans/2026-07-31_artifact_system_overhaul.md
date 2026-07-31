# Artifact System Overhaul

We will implement a new artifact system inspired by Path of Exile (PoE) items. Artifacts will become unique items with bases, implicit stats, prefixes, and suffixes. They will be placed into "Altars" (4x4 buildings) and their modifiers will apply locally to buildings within their Area of Effect (AoE).

## Proposed Changes

---

### Core Data & State

#### [NEW] `scripts/core/state/item_data.gd`
- Represents a unique crafted artifact instance.
- Properties: `uid` (String), `base_id` (String), `aoe_size` (int), `implicit_stats` (Dictionary), `prefixes` (Dictionary), `suffixes` (Dictionary).
- `to_dict()` and `static from_dict()` for serialization.

#### [MODIFY] `scripts/core/state/progress_state.gd`
- Change `artifact_inventory` from `Dictionary[String, int]` to `Array[Dictionary]` representing instances of `ItemData`. Limit of 5 items.
- Remove `equipped_artifacts` (this logic moves to Altars).

#### [MODIFY] `scripts/core/building_data.gd`
- Update `DEFAULT_SIZES`: `artifact_altar` to 4x4, add `shell_forge` (3x3), add `vault_gateway` (2x2).
- Add a new property `held_artifact: Dictionary = {}` to store the currently slotted artifact data.
- Update `is_portal` or logic for `vault_gateway` so it can behave similarly to a portal but specifically for artifacts.

#### [MODIFY] `scripts/resources/artifact_data.gd`
- Update to represent the "Base" of an item.
- Add `@export var aoe_size: int = 1`.
- Add dictionary fields for base implicit modifiers.

---

### Systems Logic

#### [MODIFY] `scripts/core/recipes.gd`
- Add new building categories: `shell_forge` and `vault_gateway`.
- `shell_forge`: Recipe `craft_artifact_base`, takes old artifact inputs (e.g., `runesteel_ingot` and `mana_essence`), produces a base item resource `artifact_base`.
- `vault_gateway`: Takes `artifact_base` as input, forwards to inventory. No outputs.

#### [MODIFY] `scripts/core/systems/artifact_system.gd`
- Update `add_artifact_to_inventory` to accept a base and create an `ItemData` instance.
- Add lists of possible affixes (as requested) to a constants dictionary for future use, but for now we only produce raw bases.
- Add logic for slotting an item from inventory into a specific Altar (by building ID).
- Add logic for transferring items from `vault_gateway` to inventory (returns false if inventory is full).

#### [MODIFY] `scripts/core/systems/modifier_system.gd`
- Change `get_multiplier(state: GameState, modifier_name: String, building: BuildingData = null)` to support local modifiers.
- If `building` is provided, iterate over `state.factory.altars`.
- If an altar has a `held_artifact`, calculate the AoE Rect: `Rect2i(grid_x - aoe, grid_y - aoe, size_x + aoe * 2, size_y + aoe * 2)`. Check if `building.get_occupied_cells()` intersects it.
- If it intersects, add the artifact's modifiers to the total.

#### [MODIFY] `scripts/core/systems/production_system.gd`
- Update `vault_gateway` logic: if the gateway has an item in its input, try to send it to the inventory via `ArtifactSystem.add_artifact_to_inventory`. If successful, consume the input.
- `shell_forge` logic remains standard: produces `artifact_base`. Output limit is 1.

#### [MODIFY] `scripts/core/simulation_ticker.gd`
- Let `ProductionSystem` query `ModifierSystem` per-building during `tick()` to apply local modifiers accurately (like Factory Speed and Mining Speed).

---

### UI & Rendering

#### [MODIFY] `scripts/visual/artifacts_panel.gd`
- Redesign the panel.
- Implement a 5-slot visual inventory for holding unique items.
- Remove old global slots.
- Support dragging an item from inventory to the game view to equip onto an Altar.

#### [MODIFY] `scripts/visual/input_controller.gd`
- Handle Drag and Drop of items onto the grid.
- If dropped over an Altar, slot the item into the Altar.

#### [MODIFY] `scripts/visual/grid_renderer.gd`
- Add a function to draw the AoE highlight on the floor around Altars that have an artifact.

#### [MODIFY] `scripts/visual/building_renderer.gd`
- For `artifact_altar`, draw the artifact icon and its stats directly on the 4x4 sprite/area if it holds an artifact.

## Verification Plan

### Manual Verification
- Place a `Shell Forge` and connect resources to it. Verify it produces an artifact base.
- Place a `Vault Gateway` and connect the forge to it. Verify the item moves from the forge to the gateway and into the new Inventory.
- Verify that if the inventory has 5 items, the `Vault Gateway` stops accepting items, causing the `Shell Forge` to eventually fill its output buffer and pause.
- Place a 4x4 Altar.
- Equip the artifact from inventory into the Altar.
- Verify the floor highlights the correct AoE (e.g., 6x6 for AoE 1).
- Place a Miner inside the AoE and one outside. Verify the one inside mines faster (based on artifact stats, if we give the base an implicit stat for testing).
- Verify the stats display on top of the Altar.
