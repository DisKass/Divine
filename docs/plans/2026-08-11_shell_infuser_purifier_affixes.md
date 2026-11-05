# [Plan] Implementation of Shell Infuser, Purifier, and PoE Affix System

This plan introduces two new buildings—**Shell Infuser (4x4)** and **Purifier (3x3)**—along with a complete PoE-style item affix generation & execution engine for Artifacts.

## User Review Required

> [!IMPORTANT]
> - **Shell Infuser (4x4)**: Consumes 3 `mana_essence` and 1 white (0 affixes) artifact to roll **3–6 random affixes** (prefixes and suffixes, max 3 each) with random tiers, values, and building tags. Transits non-white artifacts (>0 affixes) directly to output without consuming essence. Duration: 5.0s.
> - **Purifier (3x3)**: Consumes 0 additional resources. Clears all affixes from colored artifacts (>0 affixes) in 3.0s, turning them white. Transits white artifacts directly to output.
> - **Building Tags**: Most affixes roll a building tag: `[All]` (weight 50) or specific building category tags (`[Miner]`, `[Smelter]`, `[Converter]`, `[Assembler]`, `[Extractor]`, `[Infuser]`, `[Seller]` with weight 500 each). Special rules:
>   - Artifact-processing buildings (`shell_forge`, `shell_infuser`, `purifier`, `vault_gateway`, `artifact_altar`, `the_void`) do not have building tags and are ignored by `[All]`.
>   - `aoe_bonus` (+Radius) and `sell_multiplier` (+Sell value for Sellers) do not roll random building tags.

## Proposed Changes

### Core Data & State Layer

#### [MODIFY] [item_data.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/state/item_data.gd)
- Update affix storage structures (`prefixes`, `suffixes`) to hold detailed dictionary representations of rolled affixes:
  `{"id": String, "tier": int, "value": float, "tag": String, "text": String}`
- Update helper methods (`get_modifier_total`, `get_all_modifier_names`, `from_dict`, `to_dict`) to process tagged affixes and provide queried bonus values for specific building categories.

#### [MODIFY] [building_config.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/state/building_config.gd)
- Add process logic handlers for `"shell_infuser"` and `"purifier"`:
  - `"shell_infuser"`: Custom input/output check for white vs. non-white artifacts and `mana_essence` consumption.
  - `"purifier"`: Custom logic to clear item affixes.

#### [MODIFY] [recipes.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/recipes.gd)
- Register recipes for `shell_infuser` and `purifier`.

---

### Core Business Logic Systems

#### [NEW] [affix_database.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/systems/affix_database.gd)
- Create database containing definitions for all 5 prefixes and 5 suffixes:
  - Tiers (T5–T1 or T3–T1), value ranges, weights, display formatters, tag applicability.
  - Tag definitions and weights (`[All]`: 50, `[Miner]`, `[Smelter]`, `[Converter]`, `[Assembler]`, `[Extractor]`, `[Infuser]`, `[Seller]`: 500 each).

#### [MODIFY] [artifact_system.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/systems/artifact_system.gd)
- Add `infuse_artifact(item_dict: Dictionary) -> Dictionary` to roll 3–6 affixes for white artifacts:
  - Randomly select $N \in [3, 6]$ affixes.
  - Alternatingly/randomly pick prefix vs suffix slot while ensuring max 3 prefixes and max 3 suffixes, and no duplicate affix IDs.
  - Roll Tier according to weights, roll random value within tier range, roll tag according to tag weights.
- Add `purify_artifact(item_dict: Dictionary) -> Dictionary` to strip all prefixes and suffixes.

#### [MODIFY] [production_system.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/systems/production_system.gd)
- Integrate processing ticks for `shell_infuser` and `purifier`:
  - `shell_infuser`: check input artifact. If colored (>0 affixes), instantly push to output slot without consuming `mana_essence`. If white (0 affixes), require 3 `mana_essence`, run production duration (5.0s), then output infused artifact.
  - `purifier`: check input artifact. If white, instantly pass through to output. If colored, run production duration (3.0s), clear affixes, and output white artifact.
- Implement mechanics for active item modifiers on producing buildings:
  - `crit_craft_chance`: Instant completion check upon start.
  - `double_craft_chance`, `extra_flat_chance`: Extra production yields upon cycle completion.
  - `save_input_chance`: Input preservation during consumption phase.
  - Continuous/Interrupted acceleration timer tracking on `BuildingInstance`.

#### [MODIFY] [modifier_system.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/systems/modifier_system.gd)
- Enhance `get_bonus` and `get_multiplier` to evaluate building category tags against artifact affixes in range of active Altars.
- Enforce tag restrictions (e.g. `[Smelter]` only boosts smelters, `[All]` boosts non-artifact production buildings).

---

### Visual & Building Integration

#### [MODIFY] [building_system.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/systems/building_system.gd)
- Register `shell_infuser` (4x4) and `purifier` (3x3) building types, dimensions, ports, and costs.

#### [MODIFY] [inspector_panel.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/inspector_panel.gd)
- Update Artifact tooltip and UI view to render colored affix text lines with tags (e.g., `+47% к скорости работы зданий [Smelter]`).

## Verification Plan

### Automated / Logic Verification
- Test `ArtifactSystem.infuse_artifact()` across multiple iterations to ensure:
  - 3 to 6 affixes are rolled.
  - Max 3 prefixes and max 3 suffixes.
  - No duplicate affix types on a single item.
  - Tiers, values, and tags are correctly assigned.
- Test `ArtifactSystem.purify_artifact()` to ensure all affixes are cleared.
- Verify `ProductionSystem` correctly handles pass-through logic for already-infused artifacts in `shell_infuser` and clean artifacts in `purifier`.

### Manual Verification
- Place `Shell Infuser` (4x4) and feed white artifacts + `mana_essence`. Confirm essence is spent and artifacts receive 3–6 affixes with correct formatting.
- Feed an infused artifact into `Shell Infuser`. Confirm it passes through immediately without losing essence.
- Feed an infused artifact into `Purifier` (3x3). Confirm affixes are removed after 3.0s.
- Socket infused artifacts into `ArtifactAltar` and verify nearby buildings receive targeted bonuses matching their tags.
