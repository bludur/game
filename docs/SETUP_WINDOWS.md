# Windows Setup

Проект закреплён на Godot 4.7.2 — это более свежий патч выбранной ветки 4.7,
чем первоначально запланированный 4.7.1.

## Установка инструментов

```powershell
winget install --id GodotEngine.GodotEngine --exact
winget install --id BlenderFoundation.Blender.LTS --exact
winget install --id KDE.Krita --exact
winget install --id Git.Git --exact
winget install --id GitHub.GitLFS --exact
winget install --id GitHub.cli --exact
```

После установки откройте новый терминал и проверьте версии:

```powershell
.\tools\godot.ps1 -Console --version
git --version
git lfs version
gh --version
```

Локальный `tools/godot.ps1` находит последнюю WinGet-установку Godot напрямую.
Это делает запуск проекта независимым от Windows App Alias, который иногда
остаётся привязан к удалённой версии после обновления.

## GitHub

Авторизация выполняется один раз интерактивно:

```powershell
gh auth login
```

Создавать удалённый репозиторий следует после выбора имени и видимости
(`private` рекомендуется для раннего прототипа).

## Проверка проекта

```powershell
.\tools\qa\run_checks.ps1
```

Команда запускает главную сцену, проектный smoke-тест и модульные тесты GUT.
