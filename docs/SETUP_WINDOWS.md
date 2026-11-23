# Настройка среды (Windows / UCRT64)

## Переменная GODOT_PATH
Для работы GoPeak путь к движку задается через переменную окружения `GODOT_PATH` в opencode.
Текущий путь: `C:/Program Files/Godot/Godot_v4.x.x-stable_win64.exe`

## Проверка кода (fallback, если MCP отвалился)
Запуск проверки скрипта:
`"$GODOT_PATH" --headless --path . --check-only -s res://<путь>.gd`

Запуск тестовой сцены:
`"$GODOT_PATH" --headless --path . res://scenes/_test_smoke.tscn --quit-after 300 2>&1 | tail -50`

## Что поменялось у Claude (2026-11-23)
- Проект теперь на рендере **Forward+** (нужен Vulkan или D3D12 — у современных видеокарт есть).
- Перевод строк в репозитории — LF (`.gitattributes`); Git на Windows сам конвертирует при checkout.
- `MCPRuntime` работает как раньше, но не включается в релизной сборке и при запуске `tests/`.
- Тесты Claude: `"$GODOT_PATH" --path . -s res://tests/test_<имя>.gd` (с окном; добавьте `-- --shots`, чтобы сохранить скриншоты в art/previews).
- Скрипты `tools/*.py` нужны только для подготовки графики (Python 3 + numpy, scipy, Pillow).
