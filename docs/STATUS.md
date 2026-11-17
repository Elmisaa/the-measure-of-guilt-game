# STATUS — текущее состояние проекта
Claude читает этот файл в начале каждой сессии и обновляет после каждого принятого шага. Держать коротким.

Режим согласования: STRICT
Текущий этап: Э1 принят (G1) → Э2 Стиль
Следующий шаг: Э1 — GDD-lite (нужны от пользователя: сеттинг, сюжет, жанр/вид, идея первой сцены, референсы в art/refs/)
Ждёт согласования: план Э2 (стиль); от пользователя — документы 2–3 и тексты экспозиции для s01_precinct

## Окружение
Godot: 4.7.2, путь: /Applications/Godot.app/Contents/MacOS/Godot
Codex CLI: 0.169.0 (Node 26 LTS через nvm), вход: да (ChatGPT)
Плагин Codex: codex@openai-codex 1.0.6 установлен (user scope), setup ready, review gate выключен

## Сцены
| Сцена | ТЗ | Визуал | План | Реализация | Приёмка |
|---|---|---|---|---|---|
| s01_precinct | дизайн DRAFT | — | — | — | — |

## Последние действия (последние 5, новые сверху)
- 2026-11-17 Э1: правки пользователя — 1993, есть ходьба, только русский, сцена s01 без предложений Claude
- 2026-11-17 Э1: референсы в art/refs/_style и s01_precinct, черновики GDD.md и дизайна s01_precinct
- 2026-11-17 Э0: вход в Codex, тест $imagegen → pixelize OK; референсы: art/refs/<scene>/ + tools/ref_sheet.py; флаг codex exec -s workspace-write
- 2026-11-17 Э0: Node LTS, Codex CLI, плагин Codex; project.godot (пиксельные настройки), папки, .gitignore, tools/ (pixelize, inspect_assets, make_preview), git init
