# Wayfinder Map: Rendering Performance & GDScript Optimization Phase

## Destination

Achieve stable 60+ FPS performance at 2000+ active buildings by systematically eliminating GDScript CPU bottlenecks, migrating to low-level Godot RenderingServer 2D APIs, implementing bitmap font rendering, and hardware MultiMesh2D instancing across progressive commits.

## Notes

- **Domain**: Godot 4.7 / GDScript / RenderingServer / MultiMesh2D.
- **Rules**: Do not commit automatically. Execute one ticket per commit.
- **Execution Override**: This map carries actual code execution in its tasks to deliver high-performance rendering.

## Decisions so far

- [Ticket 01: GDScript Caching & Dirty Redraw Optimization](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/docs/tickets/rendering_optimization/01_gdscript_caching_and_dirty_redraw.md) — Eliminated 1,400+ runtime port lookup calls and string allocations in `_draw()`, switching `queue_redraw()` to dirty-driven camera/tick events.

## Frontier (Open & Unblocked)

- [Ticket 02: RenderingServer 2D Canvas API Migration](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/docs/tickets/rendering_optimization/02_renderingserver_2d_api.md) — Type: `wayfinder:task` (AFK). Migrate static building panels & borders to persistent `RenderingServer` canvas items.

## Blocked Tickets

- [Ticket 03: Pre-baked Bitmap Font / Glyph Atlas](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/docs/tickets/rendering_optimization/03_bitmap_font_rendering.md) — Type: `wayfinder:task` (AFK). Blocked by Ticket 02.
- [Ticket 04: MultiMeshInstance2D GPU Instancing for Panels & Ports](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/docs/tickets/rendering_optimization/04_multimesh_gpu_instancing.md) — Type: `wayfinder:task` (AFK). Blocked by Ticket 03.

## Completed

- [Ticket 01: GDScript Caching & Dirty Redraw Optimization](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/docs/tickets/rendering_optimization/01_gdscript_caching_and_dirty_redraw.md) — Type: `wayfinder:task` (AFK).

## Not yet specified

- **Dynamic GPU Buffer Updates**: Partial buffer updates for animated building properties.

## Out of scope

- **Visual Assets Overhaul**: Custom 3D meshes or textures for buildings.
- **LOD Text Filtering**: Hiding text based on camera zoom levels.
