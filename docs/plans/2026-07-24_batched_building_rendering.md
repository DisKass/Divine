# План: Переработка отрисовки зданий с поддержкой 2D Батчинга (Batched Building Rendering)

## Обзор
На данный момент каждое здание на фабрике создается как отдельный узел `BuildingVisual` (`Node2D`), содержащий в себе целое дерево из ~10 UI Control узлов (`PanelContainer`, `StyleBoxFlat`, `VBoxContainer`, `Label`, `ProgressBar`, `ColorRect`, `Control overlay`). 
При масштабировании фабрики до 2000+ зданий это приводит к созданию более **20 000 активных узлов в SceneTree** и тысячам отдельных вызовов отрисовки (Draw Calls). В результате Godot 2D-рендерер не может применять авто-батчинг, а CPU затрачивает ресурсы на пересчет UI-макетов.

**Цель:** Переработать отрисовку зданий на пакетную (батчинговую) модель через единый компонент `BuildingRenderer` (или сгрупированную пакетную отрисовку в 2D), избавившись от тяжелых UI-узлов у каждого здания и сократив количество вызовов отрисовки до считанных единиц при стабильных 60 FPS.

---

## User Review Required

> [!IMPORTANT]
> **Облегченный интерфейс и обратная совместимость:**
> - Все методы публичного API `BuildingVisual` (`get_port_global_position`, `get_input_port_for_resource`, `get_output_port_at_position`, `trigger_output_pulse`, `is_selected`, `is_hovered` и т.д.) сохраняются в полном объеме для абсолютной совместимости с `InputController`, `ConnectionRenderer` и `MainGame`.
> - Вместо 10 тяжелых Control-узлов на каждое здание, visual-объект здания становится легким контейнером состояний, а вся отрисовка геометрии, плашек, прогресс-баров, шрифтов и портов передается в `BuildingRenderer`, который выполняет её за **1-4 пакетных Draw Call** на весь экран.
> - **Кадрирование (Frustum Culling)**: Централизованный рендерер `BuildingRenderer` использует прямоугольник видимости камеры для отсечения закадровых зданий до отрисовки.

---

## Open Questions

На данный момент открытых вопросов нет.

---

## Proposed Changes

### Visual Subsystem

#### [NEW] [building_renderer.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/building_renderer.gd)
- Создать централизованный узел `BuildingRenderer` (наследующий `Node2D`), отвечающий за пакетную отрисовку всех видимых зданий.
- Реализовать единый цикл `_draw()`, разбитый на последовательные визуальные слои (для максимального батчинга в Godot 2D):
  1. **Фоновые панели и границы зданий**: Пакетная отрисовка прямоугольников зданий (`draw_rect` / `draw_style_box`) с акцентными цветами типов, подсветкой выделения (золотая), наведения и ошибок при перетаскивании.
  2. **Прогресс-бары производства**: Пакетная отрисовка фона и заполнения прогресса для активных зданий.
  3. **Внутренние линии сплиттеров и точки портов**: Отрисовка связей сплиттеров и цветных кругов входных (голубые) и выходных (оранжевые) портов (`draw_circle`).
  4. **Текстовые заголовки и ресурсы**: Отрисовка названия здания и количества ресурсов на входах/выходах при соответствующем уровне детализации (LOD).
- Интегрировать быструю фильтрацию по кадру видимости камеры (Frustum Culling).

#### [MODIFY] [building_visual.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/building_visual.gd)
- Удалить создание тяжелых UI узлов (`PanelContainer`, `VBoxContainer`, `Label`, `ProgressBar`, `StyleBoxFlat`).
- Превратить `BuildingVisual` в легкий proxy-класс / узел состояний, который рассчитывает математику позиций портов, хранит флаги (`is_selected`, `is_hovered`, `is_invalid_drag`, таймеры пульсации портов) и запрашивает перерисовку у `BuildingRenderer`.
- Сохранить все публичные методы геометрии портов (`get_port_global_position`, `get_input_port_for_resource`, `get_output_port_at_position`, `get_connection_point_toward`) для гарантированной работы существующих систем.

#### [MODIFY] [main_game.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/main_game.gd)
- Внедрить `BuildingRenderer` в сцену игры и связать его с `visuals_map` и `camera`.
- Оптимизировать обновление визуалов при изменениях состояния и тиках симуляции.

---

## Verification Plan

### Automated Tests
- Запуск всех имеющихся модульных и интеграционных тестов для проверки отсутствия регрессий:
  - `godot --headless -s scripts/core/test_factory_flow.gd`
  - `godot --headless -s scripts/core/test_splitters.gd`
  - `godot --headless -s scripts/core/test_resources.gd`
  - `godot --headless -s scripts/core/test_modifiers.gd`
  - `godot --headless -s scripts/core/test_save_system.gd`
  - `godot --headless -s scripts/core/test_templates_and_gd_panel.gd`

### Visual & Performance Verification
- Запуск бенчмарка `scripts/core/test_performance_2000.gd` для проверки симуляции.
- Создание / запуск теста с спавном 2000 зданий с включенной визуализацией и замер FPS / количества Draw Calls при панорамировании и зуме.
- Ручная проверка корректности отображения типов зданий, портов, прогресс-баров, наведения, выделения и проведения связей между зданиями.
