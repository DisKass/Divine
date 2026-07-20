# Implementation Plan - Ticket 7: Save System Migration and Compatibility

Финализация системы сохранений: добавление версионирования сейв-файлов, проверка устойчивости к выходу новых полей и загрузке старых версий сохранения.

## User Review Required

> [!NOTE]
> 1. В сохранение добавляется поле `"version": 1`.
> 2. При загрузке устаревших сейвов без полей `upgrades`, `artifact_inventory` или `equipped_artifacts` автоматически подставляются безопасные значения по умолчанию без потери прогресса игрока.

## Proposed Changes

### Save & Migration Core

---

#### [MODIFY] [save_manager.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/save_manager.gd)
- Добавить константу `SAVE_VERSION = 1`.
- Записывать `"version": SAVE_VERSION` в `save_game()`.
- В `load_game()` проверять валидность типов и наличие версии.

---

#### [MODIFY] [economy_manager.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/economy_manager.gd)
- Убедиться, что в `from_dict(dict)` все ключи (`resources`, `building_counts`, `current_milestone_index`, `milestone_progress`, `upgrades`, `artifact_inventory`, `equipped_artifacts`) безопасно считываются с дефолтными значениями через `.get()`.

---

#### [MODIFY] [benchmark.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/core/benchmark.gd)
- Написать автотест `verify_save_system_compatibility()`:
  - Проверка сохранения и загрузки полной структуры со всеми новыми системами.
  - Проверка загрузки усеченного "старого" словаря сейва (версия 0) без падений.

## Verification Plan

### Automated Tests
- Запуск `godot --headless -s scripts/core/benchmark.gd` с новым тестом `verify_save_system_compatibility()`.

### Manual Verification
- Тест цикла сохранения и ручной перезапуск игры.
