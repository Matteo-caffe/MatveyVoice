<!-- autopilot:start -->
# MatveyVoice

Бесплатное open source приложение для macOS (14+, только Apple Silicon): диктовка голосом в любом приложении, распознавание локально через WhisperKit. Агент строки меню (`LSUIElement`).

## Команды

Все проверены.
- Тесты: `swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing` (72 passed)
- Один тест: `swift test --filter <Имя> -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing`
- Приложение: `scripts/build-app.sh` → `build/MatveyVoice.app` (arm64, ad-hoc подпись); запуск `open build/MatveyVoice.app`
- dmg: `scripts/make-dmg.sh` → `build/MatveyVoice.dmg`
- Иконка: `scripts/make-icon.sh` → `Resources/AppIcon.icns`

## Структура

```
Package.swift                     цели: MatveyVoiceCore (lib), MatveyVoice (exe), MatveyVoiceCoreTests
Sources/MatveyVoiceCore/
  Shared/                         общие типы (Types.swift) и протоколы (Protocols.swift)
  Settings/AppSettings.swift      настройки в UserDefaults
  Dictation/                      DictationController (сценарий), StatusLogic
  System/                         HotkeyMonitor, AudioRecorder, TextInserter, Permissions
  Transcription/                  WhisperTranscriber, ModelCatalog, SpeechFilter, TextPostProcessor
Sources/MatveyVoice/              main.swift, AppDelegate.swift, UI/ (меню, плашка, настройки, чек-лист)
Resources/{en,ru}.lproj/          <Таблица>.strings; Info.plist, AppIcon.icns
Tests/MatveyVoiceCoreTests/       зеркалят папки Core
scripts/  docs/manual-checklist.md  README.md  README.ru.md
```

## Ключевые файлы

- `Sources/MatveyVoiceCore/Shared/Protocols.swift` — `AudioRecording`, `Transcribing`, `TextInserting`, `PermissionsProviding`
- `Sources/MatveyVoiceCore/Dictation/DictationController.swift` — конечный автомат диктовки
- `Sources/MatveyVoiceCore/Transcription/WhisperTranscriber.swift` — загрузка модели и распознавание
- `Sources/MatveyVoiceCore/Transcription/ModelCatalog.swift` — модели: `small` (~250 МБ), `large-v3-turbo` (~630 МБ, по умолчанию)
- `Sources/MatveyVoice/AppDelegate.swift`, `UI/AppModel.swift` — сборка реальных модулей и подключение к контроллеру
- `Resources/Info.plist` — `LSUIElement`, описание доступа к микрофону

## Архитектура

- Вся логика в `MatveyVoiceCore`; исполняемый `MatveyVoice` только UI и проводка. UI читает `DictationController`, `AppSettings`, `Permissions`, `Transcriber.state`, сам логики не держит.
- Шов для тестов — `DictationController`: `init(settings:recorder:transcriber:inserter:postProcess:sleep:minimumDuration:maximumDuration:messageDuration:)`; запись, распознавание и вставка подставляются через протоколы. В приложении `postProcess: { TextPostProcessor.process($0, removeFillers: $1) }`.
- `DictationController` (`@MainActor @Observable`): `state` (`idle/recording/transcribing/inserting/message(text:)`), `lastResult`, `handlePress/Release/Cancel()`, `waitForCompletion()`. Владеет лимитом записи 300 с; нажатие и отмена во время transcribing/inserting игнорируются; пустой текст после постобработки = тишина. Язык, словарь, режим, removeFillers читает из `AppSettings` в момент нажатия/окончания записи.
- `HotkeyMonitor` (`start(hotkey:onPress:onRelease:onCancel:)`, `stop()`, `isAvailable`): активный CGEventTap, нужен только «Универсальный доступ». Без доступа при `start` слежение молча не поднимается — перезапускать по `Permissions.changes`. Логика нажатий — чистые `HotkeyStateMachine` и `HotkeyClassifier`.
- `Transcribing`: `state` (`notInstalled/downloading(progress:)/preparing/ready/failed(reason:)`), `prepare(modelID:) async`, `transcribe(_:language:hints:) async throws -> Transcription?` (`nil` = речи нет), `cancelPrepare()`. Реализация `WhisperTranscriber(downloadBase:)`; `state` до `prepare` — `.notInstalled`, приложение обязано вызвать `prepare` при старте. `switchProgress: ModelState?` — только на `WhisperTranscriber`, не в протоколе: прогресс смены модели при уже рабочей (`state` остаётся `.ready`).
- Постфильтры: `SpeechFilter.isSilent/isHallucination`, `TextPostProcessor.process(_:removeFillers:)` (чистая), `TranscriptionErrorDescriber.reason(for:)`. Автоопределение языка ограничено ru/en.
- `AudioRecording`: `start() throws`, `stop() -> RecordedAudio` (16 кГц моно `[Float]`), `levels: AsyncStream<Float>`. У `AudioRecorder` есть `onLimitReached`, нигде не подключён.
- `TextInserting.insert(_:) async throws -> InsertResult` (`inserted`/`copiedOnly(reason:)`): буфер обмена + синтетический ⌘V, прежний буфер возвращается через 250 мс, если его не меняли.
- `Permissions`: `status`, `request(_:)`, `openSettings(_:)`, `changes` (опрос раз в секунду). Универсальный доступ бывает только `.notDetermined`/`.granted`.
- Общие типы (`Sendable`): `Hotkey{rightOption,rightCommand,rightControl,fn}`, `TriggerMode{hold,toggle}`, `Language{auto,ru,en}`, `RecordedAudio`, `Transcription`, `InsertResult`, `PermissionsStatus`.
- `AppSettings` (`@MainActor @Observable`, `init(defaults:)`): hotkey, triggerMode, language, modelID, dictionary, removeFillers, launchAtLogin, setupCompleted.
- Нельзя: сеть кроме загрузки модели, аналитика, запись голоса или текста диктовки на диск, логирование текста диктовки.

## Соглашения кода

- Строки интерфейса — `String(localized: "key", table: "<Таблица>", bundle: .main)`; таблицы `Dictation`, `Transcription`, `System`, `UI` (у зоны своя), файлы `Resources/{en,ru}.lproj/<Таблица>.strings`, ключи — английские слова через точку. В UI — хелпер `ui(_:_:)` (`Sources/MatveyVoice/UI/Strings.swift`). Новый ключ — в обе локали (`LocalizationTests`).
- Swift 6 language mode; общие типы `Sendable`.
- SwiftUI `@State` недоступен на машине без Xcode (макрос не собирается) — используется `ObservableObject` + `@StateObject` (`SettingsView.swift`); наблюдение вне SwiftUI — `trackChanges` (`UI/Observing.swift`).
- Тесты на Swift Testing (`import Testing`, `@Test`), не XCTest.

## Окружение

Секретов и переменных окружения нет. Опционально `MATVEY_LIVE_DIR` — папка с `ru.wav`/`en.wav` для `LiveModelTests` (по умолчанию тест пропущен).

## Тесты

- `Tests/MatveyVoiceCoreTests/` зеркалит `Sources/MatveyVoiceCore/`; реальная модель Whisper в автотестах не запускается.
- `LiveModelTests` скачивает `small` (~250 МБ) в `$MATVEY_LIVE_DIR/models` — только вручную.
- Ручная проверка вставки по приложениям: `docs/manual-checklist.md`.

## Подводные камни

- Xcode нет, только Command Line Tools: `xcodebuild`/XCTest недоступны, `swift test` без флага `-plugin-path` не собирается («plugin for module TestingMacros not found»).
- Ad-hoc подпись (`codesign -s -`) в `scripts/build-app.sh` меняется при каждой пересборке — права «Универсальный доступ» и микрофон для `build/MatveyVoice.app` придётся выдавать заново.
- Модель тянется с Hugging Face в `~/Library/Application Support/MatveyVoice/Models` (`WhisperTranscriber.defaultDownloadBase`); токенизатор WhisperKit тоже скачивает при первой загрузке — единственный сетевой канал.
- `scripts/build-app.sh` отказывается работать не на arm64.
- `.gitignore` исключает `build/` и `.build/`.

## Как здесь работает Autopilot

Сборка ведётся навыком `/autopilot`. Требования, спецификация и таски — в `.autopilot/`.
Прогресс — `.autopilot/dashboard.html`. Правило: требование из `manifest.md`
может снять только пользователь.

Если работа продолжается — скажи «продолжи автопилот»: состояние поднимется
из `.autopilot/state.js`, переспрашивать ничего не нужно.
<!-- autopilot:end -->
