# Переход на Data-Driven архитектуру зданий (Слоты и Конфиги)

Цель данного плана — избавиться от динамических словарей-буферов и жестко зашитых проверок (hardcodes) в логике, внедрив строгую систему Слотов (`ItemSlot`) и Конфигураций (`BuildingConfig`).



## User Review Required

> [!WARNING]
> Это масштабный рефакторинг ядра, затрагивающий систему сохранений. Старые сохранения сломаются (так как `inputs` и `outputs` исчезнут). Вы согласны с этим риском?

## Proposed Changes

### Core State & Configuration

#### [NEW] `scripts/core/state/item_slot.gd`
Создание класса `ItemSlot`.
- **Поля:** `accepted_tags: Array[String]`, `current_item: String` (изначально пуст), `amount: float`, `capacity: float`.
- **Методы:** `can_accept(item: String) -> bool`, `push(item: String, amount: float)`, `pull(amount: float)`.

#### [NEW] `scripts/core/state/building_config.gd`
Создание класса (возможно, `Resource`) для описания неизменяемых характеристик здания.
- **Логика:** `buffer_mode` (`"separated"`, `"shared"`), `process_logic` (`"recipe"`, `"void"`, `"passthrough"`), `global_output_link` (`"credits"`, `""`).
- **UI:** `show_input_slots: bool`, `show_output_slots: bool`, `ui_title_override: String`.

---

### Системы и Данные Зданий

#### [MODIFY] `scripts/core/state/building_data.gd`
- **Удаление:** `inputs`, `outputs`, `input_limits`, `output_limits`, а также всех флагов `is_the_void`, `is_portal` и т.д.
- **Добавление:** Массивы `input_slots: Array[ItemSlot]`, `output_slots: Array[ItemSlot]`, `shared_slots: Array[ItemSlot]`. Ссылка на `config: BuildingConfig`.
- **Обновление `set_recipe()`:** Теперь эта функция читает рецепт и генерирует объекты `ItemSlot` с нужными лимитами, привязывая их к зданию.

#### [MODIFY] `scripts/core/systems/flow_system.gd`
- Удаление хардкода (`if is_vault_gateway`, `if is_portal`).
- Маршрутизация сплиттеров теперь проверяет `to_building.config.process_logic == "passthrough"`.
- Логика передачи предметов теперь вызывает методы `can_accept()` и `push()` у `ItemSlot`, вместо инъекции ключей в словари.
- Удаление костылей в конце тика (очистка Void, отправка в Portal) — эта логика переедет в `BuildingSystem`.

#### [MODIFY] `scripts/core/state/factory_state.gd`
- В `rebuild_caches()` логика сопоставления портов теперь будет опрашивать `ItemSlot.accepted_tags`, а не динамически создавать ключи. Ограничения (`maxf`) больше не нужны, так как `capacity` лежит внутри `ItemSlot`.

#### [MODIFY] `scripts/core/systems/building_system.gd`
- В функцию `tick` добавляется обработка `process_logic`: если `"void"` — очистить слоты; если `"recipe"` — провести крафт по рецепту. Если `global_output_link == "credits"` — начислить кредиты игроку.

---

### UI & Визуал

#### [MODIFY] `scripts/visual/building_visual.gd`
- Визуал больше не фильтрует ключи (`_` или `"credits"`). Он напрямую итерируется по массивам `input_slots` и `output_slots`.
- Если слот пуст, визуал пишет тег из `accepted_tags`. Если занят — пишет `current_item`.
- Чтение параметров отображения из `BuildingConfig` (скрыть пустые слоты, переопределить название).
- Отрисовка портов теперь строго опирается на количество элементов в массиве `slots`.

## Verification Plan
### Автоматизированные тесты
- Отсутствуют, но будет проведена тщательная ручная проверка.

### Ручная проверка
- Установка всех типов зданий: Miner, Smelter, Assembler, Splitter.
- Проверка портала (поглощение предметов и получение наград).
- Проверка The Void (уничтожение без ошибок).
- Проверка Vault Gateway (режимы Store/Retrieve с общим слотом).
- Убедиться, что при смене рецепта ресурсы не "прыгают" и не ломают конвейеры.
