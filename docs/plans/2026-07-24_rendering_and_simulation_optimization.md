# Rendering and Simulation Optimization Plan

The goal of this optimization is to drastically reduce the CPU overhead (Script Functions) in the main game loop, specifically targeting the top 4 heaviest operations shown in the profiler to bring the total cycle under 6ms.

## User Review Required
> [!IMPORTANT]
> The optimizations involve modifying the core simulation tick and the drawing routines. Please review the strategy below to ensure it aligns with the project's architectural constraints. No visual features will be removed, only batched or cached.

## Proposed Changes

### Core Simulation Layer

#### [MODIFY] [factory_network.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/factory_network.gd)
- **Bottleneck**: `FactoryNetwork.tick` takes ~6.8ms. Inside the inner connection loop, it rebuilds a valid `resources` list dynamically by calling `outputs.keys()`, checking `begins_with("_")`, and probing `to_b.inputs.has(res)`. 
- **Optimization (Pre-calculated Resource Arrays)**:
  - During `rebuild_caches()`, calculate the exact array of transferable resources (`cached_resources`) for each connection cache tuple.
  - The cache tuple will become: `[from_b, to_b, conn, from_port, to_port, cached_resources]`.
  - In `tick()`, completely remove the `if/else` checks for `is_portal` and `is_splitter` that build the array, and just iterate over the pre-built `cached_resources` array.
  - This avoids thousands of dictionary checks and string validations per tick.
  - Update `BuildingData.set_recipe` so it triggers a cache rebuild in the network to keep `cached_resources` up-to-date.

### Rendering Layer

#### [MODIFY] [connection_renderer.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/connection_renderer.gd)
- **Bottleneck**: `ConnectionRenderer._draw` takes ~3.15ms and invokes `BuildingVisual.get_port_global_position` hundreds of times (1.25ms overhead).
- **Optimization (Line Caching)**:
  - Introduce `_cached_pipe_lines: PackedVector2Array` which stores all connection points.
  - Generate this geometry ONCE when the network changes.
  - In `_draw()`, bypass looping through all connections and `get_port_global_position` entirely. Just call `draw_multiline(_cached_pipe_lines, line_color, line_width)`.

#### [MODIFY] [building_renderer.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/building_renderer.gd)
- **Bottleneck**: `BuildingRenderer._draw` takes ~8.46ms. It iterates over `visible_visuals` and `std_visuals` repeatedly (up to 7 separate loops) to draw outlines, background bars, progress bars, internal splitter lines, and text.
- **Optimization (Loop Fusion & Geometry Caching)**:
  - **Geometry Caching**: Cache the `PackedVector2Array` for building borders instead of recreating it every frame. Mark it dirty only when visibility/culling, selection, or hover state changes.
  - **Loop Fusion**: Combine the multiple loops into fewer, optimized passes where possible. Progress bars will continue using `draw_rect` since they already batch automatically.

## Verification Plan
### Automated Tests
- Run `test_performance_2000.gd` to verify `FactoryNetwork` remains correct and show improved TPS.
### Manual Verification
- Load a massive factory save.
- Open the Profiler (Time -> Self).
- Verify that `FactoryNetwork.tick`, `BuildingRenderer._draw`, and `ConnectionRenderer._draw` combined take < 6ms.
- Ensure progress bars, borders, text, and resource connection flashes render correctly.
