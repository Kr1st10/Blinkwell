# Публикация обновлений macOS

Sparkle 2.10.0 включён начиная с 0.5.4. Лента: `https://raw.githubusercontent.com/Kr1st10/Blinkwell/main/appcast.xml`. Обновления распространяются через публичные GitHub Releases. Предварительные версии этого проекта входят в общую ленту preview; стабильный канал пока не выделен.

## Ключ подписи

Закрытый ключ Ed25519 хранится в macOS Keychain, account `community.blinkwell.updates`. В Git и приложении находится только открытый ключ `SUPublicEDKey`. Никогда не коммить экспорт ключа, токены GitHub или содержимое Связки ключей. Не генерируй новый ключ для каждого релиза: установленным приложениям нужен прежний ключ. Для переноса/резервной копии используй официальную инструкцию Sparkle и защищённое хранилище; потеря ключа потребует отдельного плана миграции.

Подпись Sparkle защищает пакет и ленту. Она не заменяет Developer ID/notarization; текущая preview-сборка подписана ad hoc.

## Порядок

1. Увеличь `CFBundleVersion` в `Resources/Info.plist` строго относительно всех опубликованных сборок. Обнови `CFBundleShortVersionString`, README и CHANGELOG.
2. Выполни `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` и `./scripts/build-app.sh`. Скрипт сохраняет вложенную подпись Sparkle и проверяет структуру bundle.
3. Создай ZIP с симлинками через `ditto -c -k --sequesterRsrc --keepParent build/Blinkwell.app release/Blinkwell-macOS-VERSION-arm64.zip`. Содержимое ZIP должно содержать ровно одно основное приложение. DMG можно выпустить отдельно для первой установки.
4. Запусти генерацию в **отдельный временный файл**, ещё не заменяя публичную ленту:

   ```sh
   python3 scripts/make-appcast.py release/Blinkwell-macOS-VERSION-arm64.zip \
     --url https://github.com/Kr1st10/Blinkwell/releases/download/vVERSION/Blinkwell-macOS-VERSION-arm64.zip \
     --output build/appcast.xml
   ```

   Скрипт проверяет совпадение открытого ключа в приложении со Связкой ключей, подписывает архив, проверяет подпись, записывает длину/версии из архива, затем подписывает и проверяет XML.
5. Закоммить код, создай draft release с ZIP, DMG и SHA256SUMS. Проверь размеры/контрольные суммы, опубликуй release и проверь доступность файлов без авторизации.
6. Только после доступности архива скопируй `build/appcast.xml` в корень репозитория и отправь в main. Не редактируй подписанный XML вручную: после любого изменения подпиши заново.
7. Проверь на предыдущей сборке: найти обновление → скачать → установить и перезапустить. Дневная история и настройки должны сохраниться. При отсутствии новой версии должен появиться соответствующий результат. Отдельно проверяй режим скрытого Dock.

Встроенные проверки подписи:

```sh
.build/artifacts/sparkle/Sparkle/bin/sign_update --account community.blinkwell.updates --verify appcast.xml
```

Для проверки ZIP передай также подпись из enclosure. Сборочные артефакты, данные и секреты не добавляются в репозиторий. В релиз включается лицензия Sparkle из `THIRD_PARTY/Sparkle-LICENSE.txt`.
