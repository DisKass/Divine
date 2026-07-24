# Factory Network & Renderer Optimizations (Profiler Iteration 2)

Based on the profiler screenshot and an analysis of the codebase, we've identified three significant bottlenecks that can be heavily optimized to drop frame times further.

## Proposed Changes

### 1. Optimize MultiMesh Rebuilding (Renderer)
- **Problem**: `BuildingRenderer._draw` takes **5.88 ms**. A major chunk of this time (2.4 ms) is spent inside `_update_panel_multimesh`, `_update_std_ports_multimesh`, and `_update_splitter_ports_multimesh`. These are being called *every single frame* `_draw` is executed (which happens constantly during port flashing), even though the building positions and counts haven't changed.
- **Solution**: Cache the MultiMesh updates. We will only call the `_update_*_multimesh` methods when `_culling_dirty` is true (i.e., when buildings are added, removed, moved, or the camera zooms/pans enough to change the visible set). 
- **Impact**: Saves ~2.4 ms per redraw.

### 2. O(1) Building Under Mouse Lookup (Input Controller)
- **Problem**: `InputController._get_building_id_under_mouse` takes **1.21 ms**. It currently loops through *all* buildings and calculates a bounding box collision every frame.
- **Solution**: Since the factory grid is strictly aligned to the `cell_size`, and we already maintain `network.grid` mapping `Vector2i` cells to `building_id`, we can replace the O(N) loop with a lightning-fast O(1) grid lookup.
- **Impact**: Drops input detection time to virtually 0 ms.

### 3. Early Output Exit (Factory Network)
- **Problem**: `FactoryNetwork.tick` takes **4.69 ms**. A significant part of this is iterating through all connections and doing Dictionary lookups (`.get()`) to figure out if there's any resource to transfer.
- **Solution**: Most factories spend their time either producing or waiting, meaning their `outputs` dictionary is empty (values < 1.0) most of the time. We can add a fast pre-check on the building's output values (`from_b.outputs.values()`) before iterating over its outgoing connections. If there are no completed resources to send, we skip the connection iteration entirely.
- **Impact**: Drastically reduces dictionary lookups in the core simulation loop, saving substantial CPU time during ticks.

## Open Questions
- None. These are direct algorithmic optimizations that won't affect gameplay behavior or visual output.

## Verification Plan
- Run the game and verify that buildings can still be clicked, hovered, and dragged properly.
- Verify that buildings render correctly while flashing, panning, and zooming.
- Verify that factory resources still transfer as expected.
