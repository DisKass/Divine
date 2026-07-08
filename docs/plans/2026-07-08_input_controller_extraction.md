# План реализации: Выделение InputController

Этот план описывает вторую фазу рефакторинга: вынесение логики мышиного ввода, перетаскивания построек, сетки и координатных расчетов из класса `MainGame` в специализированный узел `InputController`.

---

## Предлагаемые изменения

### Visual Слой

#### [NEW] [input_controller.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/input_controller.gd)
Новый скрипт, наследующий `Node2D`. Он будет отвечать за:
1. Отслеживание жестов мыши и состояний ввода (клики, Panning камеры, Drag & Drop зданий).
2. Вычисление ячеек сетки под курсором (`_get_grid_position_under_mouse` и `_get_building_id_under_mouse`).
3. Сигнализирование `MainGame` о действиях игрока:
   * `building_clicked(building_id)`
   * `empty_space_clicked(grid_pos)`
   * `building_move_requested(building_id, new_grid_pos)`
   * `link_mode_cancelled`
4. Внутреннее перетаскивание превью-фантома здания при строительстве (`build_preview`).

Интерфейс класса:
```gdscript
extends Node2D
class_name InputController

signal building_clicked(building_id: int)
signal empty_space_clicked(grid_pos: Vector2i)
signal building_move_requested(building_id: int, new_grid_pos: Vector2i)
signal link_mode_cancelled

# Настройки и ссылки
var cell_size: int = 64
var camera: GameCamera
var network: FactoryNetwork
var visuals_map: Dictionary = {}
var build_preview: PanelContainer

# Состояние ввода
var current_mode: int = 0 # MainGame.MouseMode
var selected_build_type: String = ""
var link_source_id: int = 0
```

#### [MODIFY] [main_game.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/main_game.gd)
1. Удаление мышиных переменных: `_is_dragging_building`, `_dragged_building_id`, `_drag_building_start_grid`, `_lmb_press_pos`, `_has_dragged`.
2. Удаление методов `_unhandled_input()`, `_get_building_id_under_mouse()`, `_get_grid_position_under_mouse()`.
3. Инстанцирование `InputController` в `_ready()` и связывание его через сигналы с методами обработки:
   * `building_clicked` ➔ `_on_building_clicked(id)`
   * `empty_space_clicked` ➔ `_on_empty_space_clicked(pos)`
   * `building_move_requested` ➔ `_on_building_move_requested(id, pos)`
   * `link_mode_cancelled` ➔ `_on_link_mode_cancelled()`
4. Передача актуальных данных (`current_mode`, `selected_build_type`, `link_source_id`, `visuals_map`) in `InputController` при их обновлении в `MainGame`.

---

## План верификации

### Ручное тестирование
Мы убедимся, что все основные игровые механики работают без изменений:
1. Выбор здания левым кликом открывает Building Inspector.
2. Клик на пустую ячейку скрывает инспектор.
3. В режиме строительства превью-фантом следует за курсором и меняет цвет (зеленый/красный) в зависимости от занятости ячейки и баланса.
4. Клики в режиме строительства ставят здания на сетку.
5. Зажатие левой кнопки мыши (LMB) на пустом поле двигает камеру (Panning).
6. Зажатие LMB на здании перетаскивает его по сетке.
7. Правый клик (RMB) на здании активирует режим связей, клик на второе здание создает трубу, клик по пустому месту сбрасывает режим.
8. Режим сноса сносит кликнутое здание и возвращает ресурсы.
