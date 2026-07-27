# Optimization Plan for Factory Network and Rendering

The user has highlighted a valid concern regarding the increase in GPU Draw Calls if we un-batch the rendering. To maintain a low draw call count while solving the CPU bottlenecks, we will use a **Static/Dynamic Split Batching** approach.

## Proposed Changes

### 1. `FactoryNetwork.gd` (Simulation Optimization)
- **Avoid Array Allocations**: Replace `for val in from_b_first.outputs.values():` with a direct key-based dictionary loop to prevent creating 1500+ temporary value arrays per tick.
- **Remove Recursive Array Passing**: The `_try_transfer_through_splitter` function creates and recursively passes a `visited_splitters` array. We will replace this with a class-level dictionary `_temp_visited_splitters` that is cleared before starting a transfer. This eliminates dynamic array allocation and makes the recursive splitter lookup much faster.

### 2. `BuildingRenderer.gd` (Static / Dynamic Split)
We will keep everything batched inside `BuildingRenderer`, but we will split the GDScript drawing logic to prevent redrawing static elements when the camera moves.
- **Static Layer (`StaticRenderer` Node2D)**:
  - Will draw the standard Building Borders and all Text.
  - **No Frustum Culling**: It will draw all 1500+ buildings onto a single huge CanvasItem.
  - Godot's RenderingServer will automatically handle panning this CanvasItem when the camera moves, costing **0 ms** of GDScript CPU time.
  - `queue_redraw()` will ONLY be called when a building is added/removed, or when a building's text changes (e.g., resources update on a tick).
- **Dynamic Layer (`DynamicRenderer` Node2D)**:
  - Will draw Hover/Selected Borders, Progress Bars, and Splitter Flashes.
  - **With Frustum Culling**: Since these elements animate every frame, we will apply frustum culling to only process and draw the ones currently visible on screen.
  - Because we are only drawing simple lines and rects for a few active/visible buildings, this will be extremely fast (<< 1ms).
- **MultiMesh Layers**:
  - The background panels and ports will continue to use `MultiMesh2D` with frustum culling, exactly as they do now.

### 3. `BuildingVisual.gd`
- Keep it as a data container proxy.
- Ensure `update_text_cache()` flags the `BuildingRenderer` to request a static redraw, so text updates are correctly propagated.

## Verification Plan
### Automated Tests
- N/A

### Manual Verification
- Load a save with 1500+ buildings.
- Move the camera around wildly and observe if FPS stays at 60 (the 16ms CPU spike should be completely gone during camera panning).
- Ensure text, borders, flashing ports, and progress bars still render correctly in their correct positions.
- Ensure that when resources transfer, the text updates correctly without massive stuttering.
