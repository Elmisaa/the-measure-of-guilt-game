# Настройка среды (Windows / UCRT64)

## Переменная GODOT_PATH
Для работы GoPeak путь к движку задается через переменную окружения `GODOT_PATH` в opencode.
Текущий путь: `C:/Program Files/Godot/Godot_v4.x.x-stable_win64.exe`

## Проверка кода (fallback, если MCP отвалился)
Запуск проверки скрипта:
`"$GODOT_PATH" --headless --path . --check-only -s res://<путь>.gd`

Запуск тестовой сцены:
`"$GODOT_PATH" --headless --path . res://scenes/_test_smoke.tscn --quit-after 300 2>&1 | tail -50`
