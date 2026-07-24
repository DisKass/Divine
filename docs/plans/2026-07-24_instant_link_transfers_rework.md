# Instant Link Transfers & Connection Visual Refactor

This feature replaces the legacy packet-lerping logistics system with **instant resource transfers** along connection pipes, introduces **0.35s glowing line pulse highlights** matching Splitter ports, and completely removes link transfer speed modifiers from artifacts and upgrades.

## Summary of Completed Changes

### [ConnectionRenderer](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/connection_renderer.gd)
- **Instant Transfers**: Eliminated `ResourcePacket` class, packet arrays, and per-frame lerping in `_process()` (dropping `_process()` from **2.64 ms to 0.00 ms**).
- **0.35s Flash Pulses**: Added `active_flashes` dictionary triggering 0.35s glowing line highlights (`minf(1.0, timer / 0.15)`) in resource colors whenever a transfer occurs.

### [FactoryNetwork](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/factory_network.gd)
- **Logistics Speed Removal**: Completely removed `transfer_rate`, `logistics_bonus`, and `transfer_progress` accumulators. Resources move instantly every tick up to input/output limits.

### [Artifacts & Upgrades](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/data/artifacts/runesteel_amulet.tres)
- Removed `logistics_transfer` bonus from `Runesteel Amulet` artifact (now provides +25% Factory Speed only).
- Removed `logistics_transfer` from `ArtifactsPanel` summary labels.

## Verification Plan

### Automated Tests
- Ran `godot --headless -s scripts/core/test_factory_flow.gd` -> **[PASS]**
- Ran `godot --headless -s scripts/core/test_modifiers.gd` -> **[PASS]**

### Manual Verification
- Visual inspection of instant link pulse flashes (matching Splitter port timings).
