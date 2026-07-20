# Implementation Plan - Ticket 5: Artifact Altar Crafting & Global Inventory

Реализация механики крафта магических предметов в постройке **Artifact Altar**, сбор их в глобальный инвентарь игрока в `EconomyManager`, поддержка 2 экипируемых слотов с начислением глобальных пассивных модификаторов.

## User Review Required

> [!NOTE]
> В игру добавляются 3 древних артефакта с уникальными свойствами:
> 1. **Runesteel Amulet**: +25% к скорости переработки на заводах и +25% к скорости передачи по связям.
> 2. **Ring of Wealth**: +50% к кредитному доходу от продажи всех товаров.
> 3. **Philosopher's Stone**: +50% к скорости майнеров и +50% к скорости всех заводов.
> Игрок владеет глобальным инвентарем произведенных артефактов и может активировать до **2 артефактов** в экипировочных слотах одновременно.

## Proposed Changes

### Database & Simulation Core

---

#### [MODIFY] [recipes.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/recipes.gd)
- Расширить рецепты `artifact_altar`:
  - `runesteel_amulet`: 2 `runesteel_ingot`, 1 `mana_essence` (длительность: 5.0 сек).
  - `ring_of_wealth`: 2 `runesteel_ingot`, 2 `crystal_dust` (длительность: 4.0 сек).
  - `philosophers_stone`: 4 `runesteel_ingot`, 4 `mana_essence` (длительность: 8.0 сек).

---

#### [MODIFY] [economy_manager.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/economy_manager.gd)
- Определить конфигурацию `ARTIFACT_CONFIGS` (свойства, названия, модификаторы).
- Переменные состояния:
  - `artifact_inventory: Dictionary = {}` (`artifact_id -> count`)
  - `equipped_artifacts: Array[String] = ["", ""]` (2 слота)
- Сигналы: `artifact_crafted(id, count)`, `artifact_equipped(slot_idx, id)`, `artifact_unequipped(slot_idx, id)`.
- Методы:
  - `add_artifact_to_inventory(id: String, amount: int = 1) -> void`
  - `equip_artifact(slot_idx: int, id: String) -> bool`
  - `unequip_artifact(slot_idx: int) -> void`
  - `get_equipped_modifier_bonus(modifier_name: String) -> float`
- Поддержка `to_dict()` и `from_dict()`.

---

#### [MODIFY] [factory_network.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/factory_network.gd)
- Кэширование построек `artifact_altar`.
- В `tick(delta, economy)`: извлекать скрафченные артефакты из `outputs` алтаря, отправлять в `economy.add_artifact_to_inventory(id)` и обнулять буфер.
- Накладывать суммарные бонусы купленных апгрейдов и экипированных артефактов на майнеры, переработку, логистику и доход от `seller`.

## Verification Plan

### Automated Tests
- Запуск автотеста `verify_artifact_altar_and_inventory()` в `benchmark.gd`:
  - Производство `runesteel_amulet` в алтаре и его попадание в инвентарь `EconomyManager`.
  - Экипировка артефакта в слот 0 и проверка корректности возврата `get_equipped_modifier_bonus("factory_speed")`.

### Manual Verification
- Автоматический забор произведенного артефакта с Алтаря в счетчик глобального инвентаря при запуске симуляции.
