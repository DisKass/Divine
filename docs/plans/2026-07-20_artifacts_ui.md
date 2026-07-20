# Implementation Plan - Ticket 6: Artifact Inventory Panel & Equipment UI

Создание пользовательского интерфейса для просмотра созданных артефактов, управления 2 слотами экипировки и наглядного отображения активных пассивных бонусов фабрики.

## User Review Required

> [!NOTE]
> В интерфейс добавляется кнопка **"Artifacts 💍"** в верхнем меню HUD.
> Модальное окно **Artifacts & Equipment** включает:
> 1. **Equipped Slots**: 2 слота активных артефактов с кнопками снятия ("Unequip").
> 2. **Global Inventory**: Список скрафченных артефактов в наличии с кнопками "Equip".
> 3. **Active Effects Summary**: Отображение всех действующих глобальных пассивных усилений от надетых артефактов.

## Proposed Changes

### UI Components

---

#### [NEW] [artifacts_panel.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/artifacts_panel.gd) / [artifacts_panel.tscn](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scenes/artifacts_panel.tscn)
- Скрипт и сцена модального окна `ArtifactsPanel` (унаследован от `PanelContainer`).
- Показывает 2 экипированных слота, список созданных артефактов в инвентаре игрока и итоговые бонусы.
- Реакция на нажатия кнопок `Equip` и `Unequip`, вызывающие `economy.equip_artifact()` и `economy.unequip_artifact()`.
- Подключение сигналов `artifact_crafted`, `artifact_equipped`, `artifact_unequipped` для авто-обновления.

---

#### [MODIFY] [hud.gd](file:///c:/MyThings/Projects/Godot/my-divine-with-antigravity-1/scripts/visual/hud.gd)
- Добавить ссылку `var artifacts_panel: ArtifactsPanel`.
- Добавить кнопку **"Artifacts 💍"** в верхнюю панель `top_hbox`.
- Инстанцировать `artifacts_panel` при старте и вызывать обновление при вызове `update_hud()`.

## Verification Plan

### Automated Tests
- Обновить `benchmark.gd` с вызовом `verify_artifacts_ui_state()`:
  - Проверка корректной отработки вызовов `equip_artifact` и `unequip_artifact` со сменой состояний слотов.

### Manual Verification
- Открытие окна "Artifacts 💍" по кнопке в верхнем меню HUD.
- Крафт артефакта на `Artifact Altar` (Tier 3) -> появление предмета в списке Artifact Inventory.
- Экипировка предмета в Слот 1 -> перемещение предмета в верхний слот и активация пассивного бонуса.
- Снятие предмета кнопкой "Unequip" -> возвращение предмета в инвентарь.
