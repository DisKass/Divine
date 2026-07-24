# Ticket 01: GDScript Caching & Dirty Redraw Optimization

- **Label**: `wayfinder:task`
- **Mode**: AFK
- **Status**: CLOSED
- **Blocks**: [Ticket 02: RenderingServer 2D Canvas API Migration](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/docs/tickets/rendering_optimization/02_renderingserver_2d_api.md)

## Question

How can we eliminate CPU GDScript bottlenecks inside `BuildingRenderer._draw()` by caching port positions, pre-formatting resource text strings on simulation ticks, and switching `queue_redraw()` to dirty-driven updates?

## Resolution

- **Port Caching**: Completely eliminated all 1,400+ runtime calls to `get_port_global_position()`, `get_input_ports_count()`, and `get_output_ports_count()` inside `_draw()`. `BuildingRenderer` now accesses pre-calculated `_cached_in_ports_local` and `_cached_out_ports_local` arrays directly from `BuildingVisual`.
- **Resource String Caching**: Resource lines (`"Iron Ore: 10"`) and building titles are formatted into `_cached_in_text_lines`, `_cached_out_text_lines`, and `_cached_title_str` during simulation ticks in `BuildingVisual.update_text_cache()`. Zero string allocations or string manipulation routines occur inside `_draw()`.
- **Dirty-Driven Redraw**: Removed unconditional `queue_redraw()` from `_process()`. `BuildingRenderer` now triggers `queue_redraw()` strictly on camera transform/zoom changes, simulation ticks, or active port flash timer updates.
