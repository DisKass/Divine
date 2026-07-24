# Ticket 02: RenderingServer 2D Canvas API Migration

- **Label**: `wayfinder:task`
- **Mode**: AFK
- **Status**: OPEN
- **Blocked By**: [Ticket 01: GDScript Caching & Dirty Redraw Optimization](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/docs/tickets/rendering_optimization/01_gdscript_caching_and_dirty_redraw.md)
- **Blocks**: [Ticket 03: Pre-baked Bitmap Font / Glyph Atlas](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/docs/tickets/rendering_optimization/03_bitmap_font_rendering.md)

## Question

How can we migrate static canvas elements (panels, static port markers, borders) to Godot's low-level `RenderingServer` 2D API (`RenderingServer.canvas_item_create()`) to bypass Node2D canvas redraw allocations?

## Scope & Implementation Details

1. Create persistent canvas item RIDs via `RenderingServer` when buildings are instantiated.
2. Update item transforms and modulate colors directly through `RenderingServer.canvas_item_set_transform()` and `RenderingServer.canvas_item_set_draw_index()`.
3. Separate dynamic elements (progress bars, flashing lines) from static panel geometry.
