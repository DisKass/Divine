# Implementation Plan - Refactoring Building System into 8 Explicit Categories & Multi-Output Logic Buildings

This plan details the architectural refactoring of the factory building system into 8 explicit categories, including the implementation of multi-output logic buildings (splitters) and positional RMB sub-port linking.

## Overview of 8 Building Categories

1. **Miner (`miner`)**: 0 inputs, 1 output. Extracts raw resources (Iron Ore, Coal, Mana Crystal, etc.) based on chosen recipe.
2. **Smelter (`smelter`)**: 1 solid input, 1 output. Smelts solid resource into molten/ingot form (e.g. Iron Ore ➔ Iron Ingot).
3. **Converter (`converter`)**: 1 solid input, 1 output. Transforms shape/form of solid items (e.g. Iron Plate ➔ Iron Gear, Mana Crystal ➔ Crystal Dust).
4. **Assembler (`assembler`)**: 2 solid inputs, 1 output. Combines two solid resources into a complex product (e.g. Iron Ingot + Coal ➔ Steel Ingot).
5. **Extractor (`extractor`)**: 1 solid input, 1 liquid/aetherial output. Extracts liquid/essence from solid (e.g. Mana Crystal ➔ Mana Essence).
6. **Infuser / Filler (`infuser`)**: 2 inputs (1 solid + 1 liquid/aetherial), 1 output. Infuses solid item with liquid/essence (e.g. Iron Ingot + Mana Essence ➔ Runesteel Ingot).
7. **Unique (`portal`, `seller`)**: Recipe-dependent inputs, 0 outputs. Accepts items for Milestones delivery or Credit sales.
8. **Logic (`splitter_2`, `splitter_3`)**: 1 input, multiple outputs (2 or 3 output ports). Distributes incoming resource stream among multiple output connections.

---

## Technical Architectural Changes

### 1. Multi-Port Connections (`FactoryNetwork` & `BuildingData`)
- Extend connection structure from `{from_id, to_id}` to `{from_id, from_port, to_id, to_port}`.
- Standard single-output buildings default to `from_port = 0, to_port = 0`.
- Logic splitters (`splitter_2`, `splitter_3`) support `from_port` index 0, 1, (and 2 for 3-way splitters).
- `FactoryNetwork.add_connection(from_id, from_port, to_id, to_port)` replaces existing connection on `(from_id, from_port)`, preserving connections on other ports of the same logic building.
- In `FactoryNetwork.tick()`, logic splitters distribute output units in round-robin fashion across active output connections.

### 2. Positional Sub-Port RMB Linking (`InputController` & `BuildingVisual`)
- `BuildingVisual` renders explicit visual output port anchors/dots on its right border for each available output port.
- `BuildingVisual.get_output_port_at_position(global_pos)` determines which port index was right-clicked based on proximity/hitbox.
- `InputController` receives `building_right_clicked(building_id, port_index)` and stores `link_source_port`.
- Temporary linking line in `_draw()` renders from the exact global position of `link_source_port`.

### 3. Connection & Resource Packet Rendering (`ConnectionRenderer`)
- Connections are drawn between the exact source output port anchor (`from_port`) and target input port anchor (`to_port`).
- Flying resource packets travel along lines connecting specific port anchors.

### 4. Recipes & Building Definitions (`Recipes`, `BuildingManager`, `data/buildings/`)
- Update `Recipes.DATA` with recipes matching the new categories (`miner`, `smelter`, `converter`, `assembler`, `extractor`, `infuser`, `portal`, `seller`, `splitter_2`, `splitter_3`).
- Create building `.tres` resources for new building types.
- Unify old separate miners (`miner_iron`, `miner_coal`, etc.) under the unified `miner` building type with recipe selection.

---

## Proposed Changes

### Core Data & Simulation Layer

#### [MODIFY] [building_data.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/building_data.gd)
- Add output port configuration support (`output_ports_count`).
- Update default building sizes for new categories (`miner`, `smelter`, `converter`, `assembler`, `extractor`, `infuser`, `portal`, `seller`, `splitter_2`, `splitter_3`).

#### [MODIFY] [factory_network.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/factory_network.gd)
- Update `add_connection` to accept `(from_id, from_port, to_id, to_port)`.
- Update `_connection_cache` and `tick()` resource distribution to handle multi-port outputs and round-robin item splitting.
- Support `from_port` and `to_port` in `to_dict()` and `from_dict()`.

#### [MODIFY] [recipes.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/recipes.gd)
- Reorganize recipes under new category types: `miner`, `smelter`, `converter`, `assembler`, `extractor`, `infuser`, `portal`, `seller`, `splitter_2`, `splitter_3`.

#### [MODIFY] [building_manager.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/building_manager.gd)
- Load cost definitions for new category types.

---

### Visual & Input Layer

#### [MODIFY] [building_visual.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/building_visual.gd)
- Add visual indicators for input and output ports (sub-port dots/anchors on left/right edges).
- Add `get_output_port_at_position(global_pos) -> int` to return sub-port index under mouse cursor.
- Add `get_port_global_position(is_output: bool, port_idx: int) -> Vector2` for connection line endpoints.

#### [MODIFY] [input_controller.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/input_controller.gd)
- Emit `building_right_clicked(building_id, port_index)`.
- Support `link_source_port` state.
- Draw temporary link line starting from `link_source_port` global position.

#### [MODIFY] [connection_renderer.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/connection_renderer.gd)
- Draw lines and animate packets between specific port anchors of source and target buildings.

#### [MODIFY] [main_game.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/main_game.gd)
- Update link mode handling to pass `link_source_port`.
- Handle default recipe assignment for new building types.

#### [MODIFY] [hud.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/hud.gd)
- Update bottom panel building cards to display the new category types (`miner`, `smelter`, `converter`, `assembler`, `extractor`, `infuser`, `portal`, `seller`, `splitter_2`, `splitter_3`).

---

### Resource Data Files

#### [NEW] [splitter_2.tres](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/data/buildings/splitter_2.tres)
#### [NEW] [splitter_3.tres](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/data/buildings/splitter_3.tres)
#### [NEW] [converter.tres](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/data/buildings/converter.tres)
#### [NEW] [assembler.tres](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/data/buildings/assembler.tres)
#### [NEW] [extractor.tres](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/data/buildings/extractor.tres)
#### [NEW] [infuser.tres](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/data/buildings/infuser.tres)

---

## Verification Plan

### Automated / Logic Verification
- Test `FactoryNetwork` connection adding with sub-ports (`from_port` 0, 1, 2).
- Test multi-output distribution tick: verify items outputting from `splitter_2` alternate or balance between two connected target buildings.

### Manual Verification
- Place a `miner`, `smelter`, `converter`, `assembler`, `extractor`, `infuser`, `portal`, `seller`, `splitter_2`, and `splitter_3`.
- Right-click directly on Port 0 of `splitter_2` and connect to Building A.
- Right-click directly on Port 1 of `splitter_2` and connect to Building B.
- Verify visually that lines connect to separate ports and resources flow to both Building A and Building B.
- Verify saving and loading preserves sub-port connections.
