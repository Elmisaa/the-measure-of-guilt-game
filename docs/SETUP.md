# Настройка среды (этап Э0), macOS

Claude Code выполняет шаги по одному, в режиме STRICT спрашивая «ок» перед каждым.
Шаги с пометкой 👤 делает пользователь (браузер или интерактивные команды).

## Проверка того, что уже есть
```bash
node -v            # нужно 18.18+
python3 -c "import PIL; print(PIL.__version__)"
git --version
ls /Applications | grep -i godot
which codex && codex --version
```

## Установка недостающего
| Что | Команда |
|---|---|
| Node.js | `brew install node` (или через nvm) |
| Pillow | `python3 -m pip install --user pillow` |
| Godot 4 | `brew install --cask godot` или скачать с godotengine.org |
| Codex CLI | `npm install -g @openai/codex` |
| 👤 Вход в Codex | `codex login` → войти аккаунтом ChatGPT в браузере; проверка `codex login status` |

## Плагин Codex для Claude Code
Claude может попробовать из терминала:
```bash
claude plugin marketplace add openai/codex-plugin-cc
claude plugin install codex@openai-codex
```
Если эти команды недоступны — 👤 в окне Claude Code:
```
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
/codex:setup
```
Review gate не включать.

## Проверка генерации картинок (1 тестовая картинка)
```bash
codex exec --full-auto "\$imagegen pixel art green slime, solid #FF00FF background, save to art/drafts/_test/slime.png"
python3 tools/inspect_assets.py art/drafts/_test/
```

## Проект
1. Создать проект Godot 4 в папке (или открыть существующий), положить сюда CLAUDE.md, AGENTS.md, docs/.
2. Project Settings: Stretch Mode `viewport`, Aspect `keep`, Scale Mode `integer`, Default Texture Filter `Nearest`. Разрешение — после Э2.
3. Создать папки из docs/WORKFLOW.md §5, `.gitignore` (`.godot/`, `art/drafts/`), `git init`, первый коммит.
4. Claude пишет `tools/pixelize.py`, `tools/make_preview.py`, `tools/inspect_assets.py`.
5. Проверка headless: `godot --headless --path . --quit` без ошибок.
6. Обновить docs/STATUS.md (версии, пути) → G0.

## Разрешения Claude Code (чтобы не подтверждать каждую команду)
В `.claude/settings.json` проекта можно разрешить частые безопасные команды, например
`Bash(codex exec:*)`, `Bash(python3 tools/*)`, `Bash(godot --headless:*)`, `Bash(git add:*)`, `Bash(git commit:*)`.
Добавлять только с согласия пользователя.
