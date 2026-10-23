# Сборка и упаковка

Текущая публичная сборка — macOS / arm64. Нужны Xcode, macOS SDK, Swift и штатные macOS `iconutil`, `strip`, `codesign`, `ditto`.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
./scripts/build-app.sh
```

Результат: `build/Blinkwell.app`. Скрипт генерирует собственный значок, удаляет отладочные символы и подписывает приложение ad hoc. Глобальный xcode-select не меняется. Developer ID и notarization не подключены.

Для ZIP:

```sh
mkdir -p release
ditto -c -k --sequesterRsrc --keepParent build/Blinkwell.app release/Blinkwell-macOS-0.5.2-arm64.zip
```

Для DMG:

```sh
mkdir -p build/dmg
ditto build/Blinkwell.app build/dmg/Blinkwell.app
ln -s /Applications build/dmg/Applications
hdiutil create -volname Blinkwell -srcfolder build/dmg -format UDZO release/Blinkwell-macOS-0.5.2-arm64.dmg
```

Не включай в репозиторий или релиз SQLite пользователей, настройки, ключи, содержимое .build и локальные пути. В release должны быть только приложение/дистрибутивы и контрольные суммы. Приложение проверяется командой `codesign --verify --deep --strict build/Blinkwell.app`; это проверка целостности локальной подписи, а не подтверждение Apple или тест всех сценариев интерфейса.
