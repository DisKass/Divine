# Implementation Plan - Ticket 2: Portal Building and Milestone Progression Core

Реализация фундаментальной логики здания **Portal** и системы вех прогрессии (Milestones Tiers 1-3) в `FactoryNetwork` и `EconomyManager`.

## User Review Required

> [!NOTE]
> Здание `Portal` является центральным объектом сдачи произведенных ресурсов на базе завода. На сетке разрешено строить только 1 Портал (`max_count = 1`). При поступлении ресурсов в Портал через соединения (connections) ресурсы поглощаются и засчитываются в счет активной вехи (Milestone).

## Open Questions

- Понадобится ли специальный интерфейс инспектора Портала в рамках этого тикета?
  *Ответ: Нет, визуальный инспектор и интерфейс разблокировок перенесены в Ticket 3 (HITL).*

## Proposed Changes

### Core Simulation & Economy

---

#### [MODIFY] [economy_manager.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/economy_manager.gd)
- Добавить конфигурацию стоимости для `portal` (стоимость: 50.0 кредитов, максимальное количество: 1).
- Описать список вех `MILESTONES`:
  - **Tier 1 (Industrial Foundation)**: 20 `iron_plate`, 10 `iron_gear`.
  - **Tier 2 (Alchemical Synthesis)**: 30 `iron_ingot`, 15 `mana_essence`.
  - **Tier 3 (Artifact Mastery)**: 10 `runesteel_ingot`.
- Добавить переменные состояния:
  - `current_milestone_index: int = 0`
  - `milestone_progress: Dictionary = {}`
- Добавить методы:
  - `submit_portal_resource(res_name: String, amount: float) -> void`: учитывает доставленные ресурсы в `milestone_progress` и проверяет выполнение условий вехи.
  - `get_current_milestone() -> Dictionary`: возвращает данные о текущей вехе и текущем прогрессе.
  - `is_building_limit_reached(type: String) -> bool`: возвращает true, если превышен лимит зданий данного типа (для `portal`).
- Поддержка `to_dict()` и `from_dict()` для сохранения прогресса вех.

---

#### [MODIFY] [building_data.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/building_data.gd)
- Добавить специальную обработку для типа `portal`: входные лимиты `input_limits` для принимаемых ресурсов выставляются в 9999.0, чтобы Портал мог принимать любые производственные ресурсы без затора.

---

#### [MODIFY] [factory_network.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/factory_network.gd)
- Добавить кэш для порталов (`_portals: Array[BuildingData]`).
- Обновить `rebuild_caches()` для учета построек типа `portal`.
- В `tick(delta, economy)`: для всех зданий типа `portal` извлекать поступившие `inputs`, передавать их в `economy.submit_portal_resource(res, amount)` и обнулять соответствующие входные буферы Портала.
- В `add_connection` разрешить соединение любых построек, имеющих outputs, с `portal`.

---

#### [MODIFY] [main_game.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/main_game.gd)
- Обновить проверку возможности размещения постройки с учетом лимита зданий (проверка `economy_manager.is_building_limit_reached(building_type)`).

## Verification Plan

### Automated Tests
- Запуск симуляции с тестовой сетью `Miner -> Conveyor/Connection -> Portal` в безголовном режиме или через вызов тиков `FactoryNetwork` в коде для проверки сдачи ресурсов и переключения вех при достижении нужного количества.

### Manual Verification
- Размещение 1-го Портала на сетке (попытка разместить 2-й Портал должна быть заблокирована).
- Направление ресурсов в Портал через соединения и проверка увеличения прогресса активной вехи.
