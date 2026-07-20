# Implementation Plan - Ticket 3: Portal Inspector and Tier Unlocking UI

Реализация визуального интерфейса для постройки **Portal**, отображение прогресса вех (Milestones Tiers 1-3) в инспекторе зданий и **динамическое разделение/разблокировка построек в HUD по достигнутому Tier**.

## User Review Required

> [!NOTE]
> Здания в магазине нижнего меню теперь будут разделены по тирам прогрессии:
> - **Tier 1 (Базовая фабрика)**: Iron Miner, Coal Miner, Crusher, Smelter, Constructor, Seller, Portal.
> - **Tier 2 (Алхимия)**: Crystal Miner, Alchemy Lab *(требуется прохождение Milestone Tier 1)*.
> - **Tier 3 (Артефакты)**: Artifact Altar *(требуется прохождение Milestone Tier 2)*.
> До момента открытия соответствующего тира карточки недоступных построек будут заблокированы в HUD с плашкой "Locked (Tier X)".

## Proposed Changes

### UI & Core Economy

---

#### [MODIFY] [economy_manager.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/economy_manager.gd)
- Назначить тиры разблокировки для каждого типа зданий:
  - `tier = 1`: `portal`, `miner_iron`, `miner_coal`, `crusher`, `smelter`, `constructor`, `seller`.
  - `tier = 2`: `miner_crystal`, `alchemy_lab`.
  - `tier = 3`: `artifact_altar`.
- Добавить метод `get_building_required_tier(type: String) -> int`.
- Добавить метод `is_building_unlocked(type: String) -> bool` (сравнивает требуемый тир здания с `current_tier`).
- В `can_afford(type: String)` учитывать условие `is_building_unlocked(type)`.

---

#### [MODIFY] [inspector_panel.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/inspector_panel.gd)
- Добавить специальную секцию инспектирования для здания типа `portal`:
  - Заголовок с названием и тиром вехи.
  - Полосы прогресса и текстовые счетчики для каждого требуемого ресурса активного Milestone (например `Iron Ingot: 20 / 30`).
  - Плашка статуса или кнопка подтверждения сдачи вехи.

---

#### [MODIFY] [hud.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/hud.gd)
- Обновить блокировку кнопок в карточках построек: если здание еще не разблокировано по Tier, блокировать кнопку покупки и отображать надпись "Locked (Tier X)".

## Verification Plan

### Automated Tests
- Обновить `benchmark.gd` с проверкой доступности/блокировки зданий до и после сдачи вехи Portal (`is_building_unlocked`).

### Manual Verification
- Старт новой игры: `miner_crystal`, `alchemy_lab` и `artifact_altar` заблокированы в HUD с пометкой "Locked".
- Клик по зданию `Portal`: отображение требуемых ресурсов и шкалы прогресса в панели инспектора.
- При сдаче ресурсов вехи Tier 1 в Портал: карточки `miner_crystal` и `alchemy_lab` становятся доступными для покупки.
