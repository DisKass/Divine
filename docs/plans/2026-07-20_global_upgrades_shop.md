# Implementation Plan - Ticket 4: Global Upgrades Shop Core & UI

Реализация системы глобальных улучшений в `EconomyManager`, учет их эффектов в `BuildingData` и `FactoryNetwork`, а также визуальное окно Магазина Улучшений в интерфейсе HUD.

## User Review Required

> [!NOTE]
> Вводится 3 ветки глобальных улучшений:
> 1. **Mining Overclock**: Увеличивает скорость добычи руд шахтами (+15% за уровень).
> 2. **Factory Efficiency**: Увеличивает скорость работы перерабатывающих построек — плавилен, дробилок, конструкторов и лаб (+20% за уровень).
> 3. **Logistics Pipeline**: Повышает скорость передачи ресурсов по связям (+50% за уровень от базовых 5.0 ед/сек).

## Proposed Changes

### Core Economy & Simulation

---

#### [MODIFY] [economy_manager.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/economy_manager.gd)
- Добавить конфигурацию `UPGRADE_CONFIGS` с описанием 3 веток улучшений (базовые цены, экспоненциальный рост стоимости, максимальный уровень, бонус за уровень).
- Переменная `upgrades: Dictionary = {}` для хранения приобретенных уровней.
- Методы:
  - `get_upgrade_level(id: String) -> int`
  - `get_upgrade_cost(id: String) -> Dictionary`
  - `get_upgrade_bonus(id: String) -> float`
  - `can_afford_upgrade(id: String) -> bool`
  - `buy_upgrade(id: String) -> bool`
- Сериализация в `to_dict()` и `from_dict()`.

---

#### [MODIFY] [building_data.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/building_data.gd)
- Метод `tick(delta: float, speed_multiplier: float = 1.0)`: учитывать переданный множитель скорости для ускорения накопления `production_progress`.

---

#### [MODIFY] [factory_network.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/factory_network.gd)
- В `tick(delta, economy)` извлекать бонусы апгрейдов из `economy`:
  - Для майнеров использовать `miner_speed` бонус.
  - Для производственных зданий использовать `factory_speed` бонус.
  - Базовую скорость передачи `transfer_rate = 5.0` умножать на `(1.0 + transfer_bonus)`.

---

### UI Components

---

#### [NEW] [shop_panel.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/shop_panel.gd) / [shop_panel.tscn](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scenes/shop_panel.tscn)
- Модальное окно/панель магазина с карточками каждого апгрейда.
- Для каждой карточки отображать: Название, Описание, Текущий уровень (e.g. `Lvl 3/10`), Эффект и Кнопку покупки с вычислением стоимости.

---

#### [MODIFY] [hud.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/hud.gd)
- Добавить кнопку "Upgrades Shop 🛒" в верхнюю панель меню HUD.
- Обработка открытия/закрытия панели магазина.

## Verification Plan

### Automated Tests
- Обновить `benchmark.gd` с вызовом `verify_upgrades_shop()`:
  - Покупка апгрейда `miner_speed` и списание кредитов.
  - Проверка роста скорости добычи и скорости передачи ресурсов по сетке при купленном апгрейде `logistics`.

### Manual Verification
- Открытие окна магазина по кнопке "Upgrades Shop 🛒" в HUD.
- Покупка апгрейда (кнопка становится активной/неактивной в зависимости от наличия кредитов).
- Визуальная проверка укорочения производственного цикла построек.
