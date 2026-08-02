# Vault Gateway Rework & The Void

This plan covers adding the new `the_void` building, changing the `vault_gateway` to support bidirectional "Store" and "Retrieve" modes, and implementing a system to track unique artifacts (with their stats) as they flow on the factory belts.

## Proposed Changes

### 1. Direct Artifact Transfer on Belts

Because buildings will hold at most one unique artifact at their input/output, we don't need a complex UID registry. We can directly store the `ItemData` dictionary inside `BuildingData` and pass it between buildings.

#### [MODIFY] [building_data.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/building_data.gd)
- Add `var input_artifact: Dictionary = {}` and `var output_artifact: Dictionary = {}`.
- Update `to_dict` and `from_dict` to serialize these dictionaries.

#### [MODIFY] [artifact_system.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/systems/artifact_system.gd)
- Refactor `add_artifact_base_to_inventory` so it doesn't create the artifact anymore. Create `generate_artifact(base_id) -> Dictionary` to handle rolling an `ItemData`.
- Add `store_artifact_in_vault(state: GameState, item_dict: Dictionary) -> bool`: pushes an item directly into the inventory.

### 2. Gameplay Systems (Flow & Production)

#### [MODIFY] [production_system.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/systems/production_system.gd)
- **Shell Forge**: When completing a recipe that outputs an artifact base, use `generate_artifact` to create the item, assign it to `output_artifact`, and increment `outputs[base_id] += 1.0`.

#### [MODIFY] [flow_system.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/systems/flow_system.gd)
- At the end of `tick()` (where it currently handles Portal deliveries and Credit selling), add logic for our new "delivery/sink" buildings:
  - **The Void**: Iterate all void buildings, clear their `inputs` and `input_artifact` dictionaries (destroying any delivered items).
  - **Vault Gateway (Store)**: Iterate all gateways in "store" mode. If `input_artifact` is not empty, push it to `artifact_inventory` via `ArtifactSystem.store_artifact_in_vault`, and clear `inputs`.
- In `tick` (transfer logic), when a resource is transferred from `from_building` to `to_building`:
  - Check if `ArtifactSystem.artifact_configs.has(resource_name)`.
  - If yes, assign `to_building.input_artifact = from_building.output_artifact.duplicate()`, and `from_building.output_artifact.clear()`.
  - Handle splitters correctly: transfer `output_artifact` instantly across the splitters chain into the final destination's `input_artifact`.
- Update `_try_transfer_to_vault` to return false if the gateway is in "Retrieve" mode. In "Store" mode, allow the item to enter `vault.inputs` and `vault.input_artifact`.

#### [MODIFY] [factory_state.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/state/factory_state.gd)
- Add `var voids: Array[BuildingData] = []` and `var vault_gateways: Array[BuildingData] = []` to performance caches. Populate them in `rebuild_caches()`.

#### [MODIFY] [building_data.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/building_data.gd)
- `DEFAULT_SIZES`: Change `vault_gateway` to `Vector2i(3, 3)`. Add `"the_void": Vector2i(3, 3)`.
- Add `var vault_gateway_mode: String = "store"`.
- Add fast flag `var is_the_void: bool = false`. Update initialization.
- `get_output_ports_count`: Return `1` for `vault_gateway` if mode is `"retrieve"`.
- `get_input_ports_count`: Return `0` for `vault_gateway` if mode is `"retrieve"`.

#### [MODIFY] [recipes.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/recipes.gd) & [hud.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/hud.gd)
- Add `"the_void"` to recipes (empty) and HUD (dark purple color, name "The Void").

#### [MODIFY] [main_game.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/main_game.gd) & [artifact_system.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/systems/artifact_system.gd)
- Add drag-and-drop logic for Vault Gateway (Retrieve):
  - User drags artifact from UI inventory to Vault Gateway.
  - Find item in `artifact_inventory`, remove it.
  - Assign the item to the gateway's `output_artifact` and increment `outputs[item["base_id"]] = 1.0`.
- Add drag-and-drop logic for The Void:
  - If dropped, permanently erase from `artifact_inventory`.
- Connect the Mode Toggle signal from `InspectorPanel`. Switch mode, swap `inputs` <-> `outputs`, swap `input_artifact` <-> `output_artifact`, and trigger redraw.

### 4. UI Inspector

#### [MODIFY] [inspector_panel.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/inspector_panel.gd) & [inspector_panel.tscn](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scenes/inspector_panel.tscn)
- Add a segmented button/toggle for "Store" / "Retrieve" mode.
- Visible only for `vault_gateway`. Emit signal when changed.

## Verification Plan
1. Produce an artifact with Shell Forge. Verify it flows down the belt and reaches a Vault Gateway (Store mode).
2. Check the UI inventory to see the artifact and its stats.
3. Switch a Vault Gateway to Retrieve mode. Drag the artifact from the inventory onto it.
4. Verify the artifact exits the gateway onto the belt. Re-route it into a Store Gateway and verify it retains its original stats when it reappears in the UI inventory.
5. Drop an artifact from the UI inventory onto The Void. Verify it is permanently destroyed.
