# План: Оптимизация производительности для 2000+ зданий (Цель: 60 FPS)

## Обзор
При 200+ зданиях игра на данный момент начинает терять FPS. Наша цель — добиться стабильных 60 FPS при 2000+ активных зданиях и связях.

### Основные узкие места (Bottlenecks):
1. **Кадровое обновление UI узлов `BuildingVisual` (Главная причина просадок FPS)**:
   - Каждое здание состоит из иерархии ~10 UI Control узлов (`PanelContainer`, `ProgressBar`, `Label`, `VBoxContainer`).
   - Каждый кадр (60 FPS) все 2000 объектов `BuildingVisual` запускают `_update_ui()`.
   - `_update_ui()` форматирует строки (`"%s: %d" % ...`), проверяет детей, запрашивает темы и обновляет `StyleBoxFlat`.
   - 2000 зданий = 20 000 UI узлов, пересчитывающих свой макет каждые 16 миллисекунд!
2. **Цикл проверки наведения в `InputController`**:
   - В `_process()` контроллер ввода обходит массив из 2000 зданий каждый кадр, чтобы выставить `is_hovered`, хотя меняется состояние максимум у 1 здания под курсором.
3. **Отрисовка связей и анимация ресурсов в `ConnectionRenderer`**:
   - `ConnectionRenderer._draw()` рисует линии всех связей и всех активных пакетов на карте без проверки их видимости в экране камеры.
4. **Нагрузка на симуляцию в `FactoryNetwork` и `BuildingData`**:
   - За 30 тиков в секунду тысячи раз выполняются проверки строк (`type.begins_with("splitter")`) и обращения к словарям (`active_recipe.get(...)`).

---

## Предлагаемые изменения

### 1. Визуальная оптимизация: Frustum Culling, LOD и событие в UI
#### [MODIFY] [building_visual.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/building_visual.gd)
- **Viewport Frustum Culling (Кадрирование)**: Добавить проверку попадания в экран камеры. Если здание за пределами экрана — выключаем его видимость (`visible = false`) и полностью пропускаем UI обновления.
- **LOD (Детализация по зуму)**: При сильном отдалении камеры (зум `< 0.45`), когда текст всё равно нечитаем, скрывать контейнеры надписей и прогресс-бары.
- **Dirty-driven Updates (Событийное обновление)**: Убрать вызов `_update_ui()` из каждого кадра `_process()`. Обновлять прогресс-бар только во время тика, а тексты ресурсов — только когда изменились значения.
- **Кэширование StyleBox**: Зафиксировать стилевые объекты и не менять их свойства каждый кадр.

### 2. Оптимизация ввода: Умное отслеживание Hover
#### [MODIFY] [input_controller.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/input_controller.gd)
- Запоминать `_last_hovered_building_id`.
- Обновлять флаг `is_hovered` только у двух зданий: у предыдущего (снимать) и у нового (ставить), убрав цикл по 2000 объектам в каждом кадре.

### 3. Оптимизация отрисовки связей и пакетов ресурсов
#### [MODIFY] [connection_renderer.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/connection_renderer.gd)
- **Кадрирование линий связей**: Рисовать `draw_line()` только для тех труб/связей, которые попадают в экран камеры.
- **Кадрирование пакетов ресурсов**: Не создавать и не анимировать визуальные пакеты ресурсов, если оба здания находятся за пределами экрана видимости камеры. (Без искусственных лимитов на количество пакетов).

### 4. Оптимизация бэкенда симуляции: Флаги типов и Zero-Allocation Ticks
#### [MODIFY] [building_data.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/building_data.gd)
- Добавить быстрые `bool` флаги: `is_splitter`, `is_portal`, `is_miner`, `is_seller`.
- Закэшировать ссылки на входы/выходы рецепта, чтобы убрать методы `.get()` и `.keys()` из горячих циклов тика.

#### [MODIFY] [factory_network.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/factory_network.gd)
- В `tick()` использовать быстрые `bool` флаги вместо проверки строк `type.begins_with()`.
- Использовать переиспользуемые буферные массивы при распределении ресурсов.

---

## План проверки

### Автоматические тесты
- Запуск всех существующих тестов для подтверждения целостности логики:
  `godot --headless -s scripts/core/test_factory_flow.gd`
  `godot --headless -s scripts/core/test_splitters.gd`
  `godot --headless -s scripts/core/test_resources.gd`
  `godot --headless -s scripts/core/test_modifiers.gd`
  `godot --headless -s scripts/core/test_save_system.gd`
  `godot --headless -s scripts/core/test_templates_and_gd_panel.gd`

### Стресс-тест и ручная проверка
- Написать стресс-тест бенчмарк, спавнящий 2000 зданий и связей для замера миллисекунд тика и кадров в секунду.
- Проверить плавность панорамирования, зума, выделения и переноса групп зданий.
