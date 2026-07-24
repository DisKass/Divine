# Ticket 04: MultiMeshInstance2D GPU Instancing for Panels & Ports

- **Label**: `wayfinder:task`
- **Mode**: AFK
- **Status**: OPEN
- **Blocked By**: [Ticket 03: Pre-baked Bitmap Font / Glyph Atlas](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/docs/tickets/rendering_optimization/03_bitmap_font_rendering.md)

## Question

How can we move building panel quads and port markers into `MultiMeshInstance2D` GPU buffers for zero-CPU instanced rendering at 2000+ buildings?

## Scope & Implementation Details

1. Construct a `MultiMesh` resource for building quad panels and port textures.
2. Update instance transform buffers and per-instance custom data (accent color, selection status) in bulk.
3. Completely offload 2D instance drawing to GPU hardware instancing.
