# План реализации сцены: <сцена>
Статус: DRAFT / APPROVED
Визуал: APPROVED (дата) ← без этого план не согласуется

## Что должно работать (критерии приёмки)
- [ ] …
- [ ] …

## Дерево узлов
```
Forest (Node2D)
├─ TileMapLayer
├─ Player (instance scenes/player.tscn)
├─ Enemies (Node2D)
└─ UI (CanvasLayer)
```

## Скрипты и системы
| Файл | Назначение | Кто делает |
|---|---|---|
| scripts/player/player.gd | движение, стейт-машина | Claude |
| scripts/enemies/slime.gd | по образцу base_enemy.gd | Codex |

## Сигналы и связи
- …

## Риски / открытые вопросы
- …

## Шаги (каждый — отдельное согласование в режиме STRICT)
1. …
