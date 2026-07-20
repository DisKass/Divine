# Refactoring #2: Architecture, UI, and Performance

Этот план описывает второй этап рефакторинга проекта, скорректированный с учетом ваших комментариев. Основное внимание уделяется устранению «раздутых» файлов, строгому разделению ответственности, внедрению масштабируемой системы модификаторов, переносу UI в `.tscn` и устранению узких мест в производительности.

## Общие правила для всех классов
В начале каждого скрипта будет добавлен короткий комментарий (с использованием `##`), описывающий зону ответственности (Zone of Responsibility) данного класса. Это поможет не нарушать архитектуру в будущем.

## Устранение предупреждений (Warnings)
Будут устранены все указанные предупреждения (UNUSED_VARIABLE, SHADOWED_GLOBAL_IDENTIFIER, INTEGER_DIVISION, UNUSED_SIGNAL, NARROWING_CONVERSION) путем переименования, приведения типов или удаления неиспользуемого кода.

## Разделение Архитектуры (Core Architecture)

Вы правы насчет того, что класс, отвечающий за 100 ресурсов и покупку зданий, тоже становится узким местом, а расчет модификаторов нельзя оставлять локальным. Мы реализуем следующую структуру:

#### [NEW] [resource_manager.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/resource_manager.gd)
- **Зона ответственности:** Хранение и изменение баланса ресурсов игрока (Credits, Iron Ore, Mana, и т.д.). Подтверждение транзакций (хватает ли средств).

#### [NEW] [building_manager.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/building_manager.gd)
- **Зона ответственности:** Отслеживание количества построенных зданий, лимитов и расчет текущей стоимости строительства. Выступает мостом между `ResourceManager` и логикой постройки.

#### [NEW] [modifier_manager.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/modifier_manager.gd)
- **Зона ответственности:** Централизованный расчет глобальных и локальных статов. Сбор бонусов из всех источников (Улучшения, Артефакты). Здесь будет заложен фундамент для формул типа PoE (Base * (1 + Increased) * More).

#### [NEW] [upgrades_manager.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/upgrades_manager.gd)
- **Зона ответственности:** Управление уровнями купленных глобальных улучшений. Регистрирует свои бонусы в `ModifierManager`.

#### [NEW] [artifacts_manager.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/artifacts_manager.gd)
- **Зона ответственности:** Инвентарь артефактов и слоты экипировки. При экипировке передает информацию в `ModifierManager`.

#### [NEW] [milestones_manager.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/milestones_manager.gd)
- **Зона ответственности:** Прогресс доставки ресурсов порталу и разблокировка тиров зданий.

#### [DELETE] [economy_manager.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/economy_manager.gd)
- Этот раздутый класс будет удален, а его функции распределены по менеджерам выше. В `main_game.gd` эти менеджеры будут инстанцироваться и связываться между собой.

---

### Вынос статических данных (Resources & .tres)

Мы создадим классы-контейнеры (наследующие `Resource`) для данных. Сами данные будут сохранены в папке `data/` в формате `.tres`.
- **`UpgradeData.gd`** -> `data/upgrades/*.tres`
- **`ArtifactData.gd`** -> `data/artifacts/*.tres`
- **`MilestoneData.gd`** -> `data/milestones/*.tres`
- **`BuildingDataDef.gd`** -> `data/buildings/*.tres` (Конфиги зданий и их стоимости)

Это полностью уберет хардкод из скриптов и позволит легко масштабировать проект (в будущем добавлять новые предметы можно будет просто создавая новый файл `.tres` в редакторе).

---

### Перенос UI в сцены (Decoupling View from Logic)

Я сгенерирую `.tscn` файлы для интерфейсов напрямую. Скрипты будут значительно сокращены, оставляя только логику связи кнопок с менеджерами.
- `hud.tscn` / `hud.gd`
- `shop_panel.tscn` / `shop_panel.gd`
- `artifacts_panel.tscn` / `artifacts_panel.gd`
- `inspector_panel.tscn` / `inspector_panel.gd`

---

### Производительность (Performance Optimization)

В `main_game.gd` функция `_update_ui()` рассчитывала `credits_per_tick` перебирая все здания каждый кадр.
- **Решение:** `credits_per_tick` будет кэшироваться в `FactoryNetwork` при изменении конфигурации сети (добавление продавца или смена его рецепта) и отдаваться в UI по запросу (O(1)).

---

### Тестирование (Benchmark)

Массивный `benchmark.gd` будет разбит на серию небольших скриптов, каждый из которых проверяет свою область.
- `tests/test_resources.gd`
- `tests/test_modifiers.gd`
- `tests/test_factory_flow.gd`
- `tests/test_save_system.gd`
Это позволит легко запускать конкретные проверки после изменений.

## План действий после вашего подтверждения
1. Создание Resource-классов для данных и `.tres` файлов с существующим контентом.
2. Создание новых менеджеров и удаление `EconomyManager`.
3. Рефакторинг `MainGame`, `SimulationTicker` и `FactoryNetwork` для работы с новыми менеджерами и `ModifierManager`.
4. Переписывание UI-файлов (создание `.tscn` и очистка `.gd`).
5. Разбиение тестов и исправление Warnings.
