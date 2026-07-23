# [План] Расширение ГД панели: Бесплатное строительство и Полные Темплейты Игры

Добавление новых возможностей в панель геймдизайнера (GD Panel):
1. **Галочка "Бесплатное строительство"**: возможность строить здания без затрат и без требований по наличию кредитов/ресурсов.
2. **Система Темплейтов (Templates / Save Slots)**: выпадающий список в ГД панели для создания, сохранения и переключения между различными независимыми слотами/состояниями игры (состояние включает здания, ресурсы, кредиты, майлстоуны, апгрейды и артефакты).
3. **Офлайн AFK бонус для активного темплейта**: при перезаходе в игру оффлайн-доход рассчитывается исключительно для последнего активного темплейта.

---

## Architecture & Design Decisions

> [!IMPORTANT]
> **Темплейт как полный профайл/слот сохранения (Full Game Save Slot)**:
> Каждый темплейт теперь хранит **полное состояние всей игры**:
> - Сетку зданий и их рецепты (`FactoryNetwork`)
> - Балансы ресурсов и кредитов (`ResourceManager`)
> - Количества построенных зданий (`BuildingManager`)
> - Купленные апгрейды (`UpgradesManager`)
> - Экипированные и полученные артефакты (`ArtifactsManager`)
> - Прогресс фаз и майлстоунов (`MilestonesManager`)
>
> **Архитектурные роли**:
> - **`TemplateManager` (`scripts/core/template_manager.gd`)**: управляет словарём темплейтов (слотов сохранения), клонирует текущий snapshot всей игры при создании нового темплейта, восстанавливает состояние всех менеджеров при смене темплейта.
> - **`SaveManager` (`scripts/core/save_manager.gd`)**: сериализует весь `TemplateManager` на диск в `user://factory_save.json` с поддержкой обратной совместимости.
> - **`MainGame` (`scripts/visual/main_game.gd`)**: при смене темплейта полностью перерисовывает игровое поле (`BuildingVisual`, `ConnectionRenderer`) и обновляет все UI панели (HUD, Inspector, Shop, Milestones).

---

## Proposed Changes

### 1. `BuildingManager` (`scripts/core/building_manager.gd`)
- Добавить флаг `free_buildings_mode: bool = false`.
- В `can_afford(type: String) -> bool`: если `free_buildings_mode == true`, возвращать `true` (при условии, что здание разблокировано по майлстоунам и не превышен лимит количества).
- В `buy_building(type: String) -> bool`: если `free_buildings_mode == true`, увеличивать `building_counts[type] += 1` без списания ресурсов через `resource_manager.spend()`.

---

### 2. `TemplateManager` (`scripts/core/template_manager.gd`)
- Хранит словарь/массив темплейтов (полных снимков состояния игры) и ID активного темплейта `active_template_id`.
- Поддерживает методы:
  - `create_template(name: String, all_managers_and_network_dict: Dictionary) -> String`
  - `switch_to_template(id: String, target_managers_and_network: Dictionary) -> bool`
  - `get_active_template() -> Dictionary`
  - `to_dict() -> Dictionary` и `from_dict(dict: Dictionary) -> void`

---

### 3. `SaveManager` (`scripts/core/save_manager.gd`)
- Сохраняет `TemplateManager` (содержащий все темплейты и текущий активный темплейт).
- Гарантирует обратную совместимость: старые сохранения v1/v2 преобразуются в первый темплейт `"Основной завод"`.

---

### 4. `GDPanel` (`scripts/visual/gd_panel.gd`)
- **Галочка "Бесплатное строительство"**: `CheckBox` ("🆓 Бесплатная постройка"), привязанная к `building_manager.free_buildings_mode`.
- **Выпадающий список "Темплейты"**:
  - `OptionButton`: Элемент 0 — `➕ Создать новый...`, Элементы 1..N — Имена всех темплейтов.
  - Выбор `➕ Создать новый...` открывает `ConfirmationDialog` с `LineEdit`. При вводе названия текущий snapshot (здания, кредиты, майлстоуны...) кэшируется в новый темплейт и загружается.
  - Выбор существующего темплейта мгновенно переключает всё состояние игры на этот темплейт.

---

### 5. `MainGame` (`scripts/visual/main_game.gd`)
- Реализовать реактивное переключение темплейтов:
  - При смене темплейта обновляются данные во всех менеджерах (`network`, `resource_manager`, `building_manager`, `upgrades_manager`, `artifacts_manager`, `milestones_manager`).
  - Полностью очищается и заново спавнится визуальное отображение фабрики на игровой сетке.
  - Обновляются все интерфейсы UI (ресурсы, апгрейды, инспектор, фазы).
- Гарантировать, что при запуске игры оффлайн catch-up (`SimulationTicker.catch_up_offline`) запускается именно для активного темплейта.

---

### 6. Юнит-тесты (`scripts/core/test_templates_and_gd_panel.gd`)
- Написать полный юнит-тест:
  - Проверка включения/выключения `free_buildings_mode`.
  - Проверка создания темплейтов с разным балансом кредитов, майлстоунами и зданиями.
  - Проверка сохранения и восстановления всех параметров каждого темплейта.
  - Проверка начисления офлайн AFK дохода только для активного темплейта.

---

## Verification Plan

### Automated Tests
- Запуск юнит-тестов с помощью Godot CLI:
  `godot --headless -s scripts/core/test_gd_panel.gd`
  `godot --headless -s scripts/core/test_save_system.gd`
  `godot --headless -s scripts/core/test_templates_and_gd_panel.gd`

### Manual Verification
- Открытие ГД панели в игре.
- Проверка работы галочки "Бесплатное строительство".
- Создание нового темплейта (например, "Завод 2"), покупка апгрейдов и изменение ресурсов/зданий в нем.
- Переключение назад на "Основной завод" и проверка полной сохранности старых кредитов, майлстоунов и схемы.
- Перезаход в игру и проверка корректного восстановления последнего активного темплейта и его AFK дохода.
