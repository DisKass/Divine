# План рефакторинга: Архитектура "Систем" (Все менеджеры)

Этот план направлен на завершение перехода к Data-Driven Systems. В первой фазе мы уже перенесли `factory_network.gd` в системы (`GridSystem`, `FlowSystem`, `ProductionSystem`). Теперь мы сделаем то же самое для всех остальных менеджеров из папки `core`.

## User Review Required
> [!IMPORTANT]
> Это масштабные изменения. Мы удалим все классы менеджеров (`ResourceManager`, `BuildingManager`, `UpgradesManager`, `ArtifactsManager`, `MilestonesManager`, `ModifierManager`, `SaveManager`, `TemplateManager`) и заменим их на глобальный объект состояния `GameState` и статические классы-системы. Это затронет скрипты `main_game.gd`, весь UI и все тесты.
> Пожалуйста, подтвердите, что такой масштаб изменений отвечает вашим ожиданиям.

## Proposed Changes

Мы введем глобальный контейнер данных симуляции — `GameState`, но **избежим проблемы "супер-класса" за счет композиции**. `GameState` не будет плоской свалкой всех переменных, а будет состоять из логических под-состояний:
- `FactoryState`: Здания, сетка, линки (уже есть).
- `EconomyState`: Ресурсы и баланс.
- `ProgressState`: Апгрейды, артефакты, вехи, активные модификаторы.

Таким образом `GameState` — это просто корень (Root), который удобно сохранять и передавать, а Системы будут оперировать только с теми под-состояниями, которые им нужны. Это дает идеальный баланс: единая точка входа для сохранений и чистые границы для систем.

### [NEW] scripts/core/state/ (Папка состояний)
- `game_state.gd` (Корень, содержит методы `to_dict`/`from_dict`)
- `economy_state.gd` (Данные ресурсов)
- `progress_state.gd` (Данные прокачки)

### [DELETE] Старые менеджеры
Удаляем следующие файлы:
- `scripts/core/resource_manager.gd`
- `scripts/core/building_manager.gd`
- `scripts/core/upgrades_manager.gd`
- `scripts/core/artifacts_manager.gd`
- `scripts/core/milestones_manager.gd`
- `scripts/core/modifier_manager.gd`
- `scripts/core/save_manager.gd`
- `scripts/core/template_manager.gd`
- `scripts/core/factory_state.gd` (переместим в `scripts/core/state/`)

### [NEW] Новые Системы
Создаем статические классы с логикой, которые принимают `GameState` первым аргументом:
- `scripts/core/systems/resource_system.gd`
- `scripts/core/systems/building_system.gd`
- `scripts/core/systems/upgrade_system.gd`
- `scripts/core/systems/artifact_system.gd`
- `scripts/core/systems/milestone_system.gd`
- `scripts/core/systems/modifier_system.gd`
- `scripts/core/systems/save_system.gd`
- `scripts/core/systems/template_system.gd`

### [MODIFY] Интеграция в проект
- В `main_game.gd` и `simulation_ticker.gd` мы заменим инициализацию десятка менеджеров на создание одного `GameState`.
- В UI (например, `HUD`, `GDPanel`, `InspectorPanel`) передадим `GameState` вместо менеджеров.
- Тесты будут переписаны для работы с `GameState`.

## Verification Plan

### Automated Tests
- Запуск всех тестов в `scripts/core/test_*.gd`, которые мы обновим под новую архитектуру.

### Manual Verification
- Запуск игры, загрузка сохранений, покупка зданий и апгрейдов, проверка работы панели GD (смена шаблонов).
