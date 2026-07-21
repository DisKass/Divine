# [QoL Pass] Уменьшение сетки в 2 раза, точные размеры зданий в клетках и запрет перекрытий

Этот план описывает уменьшение размера ячейки сетки в 2 раза (с 64px до 32px), внедрение поддержки многоклеточного размера зданий в сетке (Grid Footprint) в зависимости от их типа (Вариант А), а также строгую валидацию коллизий и подсветку с запретом наложения зданий.

## User Decisions & Agreed Options

- **Размеры зданий (Вариант А)**:
  - Шахты (`miner`, `miner_iron`, etc.): `3x3` клетки (96x96 px)
  - Фабрики/Заводы (`crusher`, `smelter`, `constructor`, `alchemy_lab`): `4x3` клетки (128x96 px)
  - Портал (`portal`) & Алтарь (`artifact_altar`): `4x4` клетки (128x128 px)
  - Скупщик (`seller`): `3x3` клетки (96x96 px)
- **Визуальная подсветка при перетаскивании**:
  - При перетаскивании над занятыми ячейками показывать визуальную красную рамку/подсветку невозможности размещения.
  - При отпускании мыши на занятой ячейке здание возвращается на свою исходную позицию.
- **Миграция старых сохранений**:
  - Временно добавить пересчет координат зданий при загрузке старых сохранений для тестирования (пересчет позиций `grid_position * 2` под сетку 32px), но перед финальным коммитом убрать мигратор.

---

## Proposed Changes

### Core Simulation & Grid System

#### [MODIFY] [building_data.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/building_data.gd)
- Добавить статическую конфигурацию размеров для типов зданий `BUILDING_SIZES`:
  - `miner*`: `Vector2i(3, 3)`
  - `crusher`, `smelter`, `constructor`, `alchemy_lab`: `Vector2i(4, 3)`
  - `portal`, `artifact_altar`: `Vector2i(4, 4)`
  - `seller`: `Vector2i(3, 3)`
- Добавить свойство `size_in_cells: Vector2i` в `BuildingData`.
- Добавить метод `get_occupied_cells() -> Array[Vector2i]`, возвращающий список всех ячеек сетки от `grid_position` до `grid_position + size_in_cells - (1,1)`.

#### [MODIFY] [factory_network.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/factory_network.gd)
- Обновить хранение `grid: Dictionary` (`Vector2i -> int building_id`), чтобы все клетки footprint'а здания ссылались на его `id`.
- Реализовать метод `is_area_free(top_left: Vector2i, size_in_cells: Vector2i, ignore_building_id: int = 0) -> bool`.
- Обновить `add_building` и `remove_building` для учета прямоугольника занимаемых клеток.
- Добавить метод `move_building(b_id: int, new_top_left: Vector2i) -> bool` с проверкой на коллизии перед изменением координат.

---

### Visual & Input Controllers

#### [MODIFY] [main_game.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/main_game.gd)
- Изменить `cell_size` на 32.
- В режиме постройки (`MouseMode.BUILD`) подгонять превью `build_preview` под размер `size_in_cells * cell_size` выбранного здания и проверять `network.is_area_free(...)`.

#### [MODIFY] [grid_renderer.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/grid_renderer.gd)
- Обновить дефолтный `cell_size = 32`.

#### [MODIFY] [building_visual.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/building_visual.gd)
- Настроить визуальный размер `panel.custom_minimum_size` на основе `data.size_in_cells * cell_size`.
- Размещать точный прямоугольник на сетке: `position = Vector2(data.grid_position) * cell_size + Vector2(size_in_cells * cell_size / 2.0)`.
- Обновить расчет внешних граней для подсоединения труб `get_connection_point_toward()`.
- Добавить свойства подсветки ошибочного перетаскивания (красная рамка при коллизии).

#### [MODIFY] [input_controller.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/input_controller.gd)
- Обновить клики и определение здания под мышью (`_get_building_id_under_mouse`) с учетом прямоугольников `size_in_cells`.
- При перетаскивании здания подсчитывать, свободна ли целевая позиция через `network.is_area_free(hover_grid_pos, b_data.size_in_cells, _dragged_building_id)`. Если нет — включать визуальный индикатор невалидности перетаскивания. При отпускании L-кнопки мыши — перемещать здание только если позиция свободна, иначе возвращать в `_drag_building_start_grid`.

---

## Verification Plan

### Manual Verification
- **Сетка**: Проверить шаги сетки 32px.
- **Размеры зданий**: Шахты/Скупщик 96x96 (3x3), Заводы 128x96 (4x3), Портал/Алтарь 128x128 (4x4).
- **Постройка и подкрашивание**: Проверить красный индикатор при наведении превью постройки на существующее здание.
- **Перетаскивание**: Проверить красную рамку при перетаскивании здания поверх другого здания и откат на исходную позицию при отпускании.
- **Сохранения**: Проверить временную конверсию старых сохранений.
