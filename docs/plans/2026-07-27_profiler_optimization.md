# Optimization Plan for Factory Network and Rendering

The profiler screenshots indicate two massive bottlenecks causing the frame rate to drop when the camera moves or when the factory is running at full capacity with 1500+ buildings:
1. `BuildingRenderer._draw` takes **~16.4ms** per frame.
2. `FactoryNetwork.tick` takes **~10.8ms** per tick.

These two combined easily exceed the 16.6ms budget for 60 FPS, causing the framerate drop.

## Open Questions
No open questions. These optimizations are contained and will not alter gameplay behavior, but heavily refactor the rendering batching of individual buildings.

## Proposed Changes

### 1. `FactoryNetwork.gd` (Simulation Optimization)
The innermost simulation loop of the factory network currently allocates thousands of arrays per tick and recursive passes arrays. We will optimize this by eliminating GDScript allocations:
- **Avoid Array Allocations**: Replace `for val in from_b_first.outputs.values():` with a direct key-based dictionary loop to prevent creating 1500+ temporary value arrays per tick.
- **Remove Recursive Array Passing**: The `_try_transfer_through_splitter` function creates and recursively passes a `visited_splitters` array. We will replace this with a class-level dictionary `_temp_visited_splitters` that is cleared before starting a transfer. This eliminates dynamic array allocation and makes the recursive splitter lookup much faster.

### 2. `BuildingRenderer.gd` (Rendering Batching Fix)
Currently, `BuildingRenderer` draws **all text, borders, and progress bars for all visible buildings in a single `_draw` call in global space**. 
Because it relies on manual frustum culling, moving the camera forces a full redraw, invoking Godot's text shaping and drawing functions thousands of times per frame (taking ~13ms of the 16ms).
- We will strip Layers 2, 3, 4, and 5 (Borders, Progress Bars, Splitter Lines, Text) out of `BuildingRenderer._draw()`.
- `BuildingRenderer` will exclusively handle the high-performance `MultiMesh2D` updates (Background Panels and Ports).

### 3. `BuildingVisual.gd` (Local CanvasItem Redraws)
We will move the text, border, and progress bar drawing logic into `BuildingVisual._draw()`.
- Since each `BuildingVisual` is already a `Node2D` in the scene tree, Godot's RenderingServer will automatically apply native C++ frustum culling to them.
- They will draw in their own local coordinate space.
- They will only call `queue_redraw()` when their *individual* state changes (e.g., text updates, progress bar moves, splitter port flashes, or hover/selection state changes).
- **Result**: Moving the camera will **no longer trigger any GDScript text redraws**. Godot will simply pan the already-cached canvas items, practically eliminating the 16ms overhead.

## Verification Plan
### Automated Tests
- N/A

### Manual Verification
- Load a save with 1500+ buildings.
- Move the camera around wildly and observe if FPS stays at 60.
- Ensure text, borders, flashing ports, and progress bars still render correctly in their correct positions.
