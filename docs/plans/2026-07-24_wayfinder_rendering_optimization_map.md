# Wayfinder Map: Rendering Performance & GDScript Optimization Phase

## Destination

Achieve stable 60+ FPS performance at 2000+ active buildings by systematically eliminating GDScript CPU bottlenecks, implementing bitmap font rendering, and hardware MultiMesh2D instancing across progressive commits.

## Notes

- **Domain**: Godot 4.7 / GDScript / MultiMesh2D / Bitmap Font.
- **Rules**: Do not commit automatically. Execute one ticket per commit.
- **Execution Override**: This map carries actual code execution in its tasks to deliver high-performance rendering.

## Decisions so far

- [Ticket 01: GDScript Caching & Dirty Redraw Optimization](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/docs/tickets/rendering_optimization/01_gdscript_caching_and_dirty_redraw.md) — Eliminated 1,400+ runtime port lookup calls and string allocations in `_draw()`, switching `queue_redraw()` to dirty-driven camera/tick events.
- [Ticket 02: MultiMeshInstance2D Hardware Instancing Migration](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/docs/tickets/rendering_optimization/02_renderingserver_2d_api.md) — Migrated 2,000 background panels to GPU hardware instanced `MultiMeshInstance2D`, removing `draw_rect` loops from GDScript and rendering all panels in 1 Draw Call.

## Frontier (Open & Unblocked)

- [Ticket 03: Pre-baked Bitmap Font / Glyph Atlas](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/docs/tickets/rendering_optimization/03_bitmap_font_rendering.md) — Type: `wayfinder:task` (AFK). Replace runtime vector font outline calculations with pre-baked bitmap font atlas.

## Blocked Tickets

*(None)*

## Completed

- [Ticket 01: GDScript Caching & Dirty Redraw Optimization](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/docs/tickets/rendering_optimization/01_gdscript_caching_and_dirty_redraw.md) — Type: `wayfinder:task` (AFK).
- [Ticket 02: MultiMeshInstance2D Hardware Instancing Migration](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/docs/tickets/rendering_optimization/02_renderingserver_2d_api.md) — Type: `wayfinder:task` (AFK).

## Not yet specified

- **Dynamic GPU Buffer Updates**: Partial buffer updates for animated building properties.

## Out of scope

- **Multiple Separate CanvasItem RIDs**: Avoid creating individual CanvasItem RIDs per building on RenderingServer (disables CanvasItem batching).
- **LOD Text Filtering**: Hiding text based on camera zoom levels.
