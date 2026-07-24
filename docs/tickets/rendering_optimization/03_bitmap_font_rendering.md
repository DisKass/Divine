# Ticket 03: Pre-baked Bitmap Font / Glyph Atlas

- **Label**: `wayfinder:task`
- **Mode**: AFK
- **Status**: OPEN
- **Blocked By**: [Ticket 02: RenderingServer 2D Canvas API Migration](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/docs/tickets/rendering_optimization/02_renderingserver_2d_api.md)
- **Blocks**: [Ticket 04: MultiMeshInstance2D GPU Instancing for Panels & Ports](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/docs/tickets/rendering_optimization/04_multimesh_gpu_instancing.md)

## Question

How can we replace runtime vector font outline calculations with a pre-baked Bitmap Font (`.font` / pre-rendered glyph atlas) to eliminate text rendering CPU overhead?

## Scope & Implementation Details

1. Generate or configure a fixed pixel-grid Bitmap Font asset (`FontFile` with texture glyph atlas).
2. Configure fixed outline/shadow glyph passes in the font resource.
3. Replace runtime `draw_string_outline` calls with single-pass bitmap font rendering.
