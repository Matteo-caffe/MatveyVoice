# interfaces.md

Читай это перед тем, как писать код. Границы ниже решены в спецификации — не переизобретай их. Что таск построил на самом деле, дописывается в конец (раздел «Что построено»).

## Правила проекта

- **Стек:** Swift 6.x, SwiftPM, macOS 14+, Apple Silicon. Приложение — агент строки меню (`LSUIElement`). Единственная внешняя зависимость — WhisperKit (argmaxinc/WhisperKit, MIT), подключает таск 01.
- **Инструментов Xcode на машине нет** — только Command Line Tools. `xcodebuild` и XCTest недоступны. Тесты пишутся на **Swift Testing** (`import Testing`, `@Test`), запускаются `swift test`.
- **Сборка и запуск:** `swift build` (проверка компиляции), `swift test` (тесты), `scripts/build-app.sh` (собирает `MatveyVoice.app` в `build/`), запуск — `open build/MatveyVoice.app`.
- **Устройство пакета:** библиотека `MatveyVoiceCore` (вся логика), исполняемый `MatveyVoice` (точка входа и UI), тесты `MatveyVoiceCoreTests`. `Package.swift` правит только таск 01; остальные кладут файлы в свои зоны, SwiftPM подхватывает их сам. Если нужно изменить `Package.swift` — вернуть `BLOCKED` с объяснением.
- **Строки интерфейса:** русский и английский, `Resources/en.lproj/<Таблица>.strings` и `Resources/ru.lproj/<Таблица>.strings`. У каждой зоны **своя таблица** (`Transcription`, `System`, `Dictation`, `UI`), чтобы параллельные таски не правили один файл. Использование: `String(localized: "key", table: "UI", bundle: .main)`. Ключи — английские слова через точку.
- **Нельзя:** платные сервисы и ключи; аналитика; запись голоса или текста диктовки на диск; логирование текста диктовки; сеть, кроме загрузки модели.
- **Зависимость недоступна или нужная установка** — вернуть `BLOCKED`, ничего не ставить самому.
- **Не трогать:** `.autopilot/`, `CLAUDE.md`, `.claude/`, чужие зоны.
- **Публиковать на GitHub, коммитить чужое и менять историю git — нельзя.** Коммит делает оркестратор.
- **Общие типы** живут в зоне таска 01 (`Sources/MatveyVoiceCore/Shared/`): `Hotkey` (`rightOption`/`rightCommand`/`rightControl`/`fn`), `TriggerMode`, `Language` (`auto`/`ru`/`en`), `RecordedAudio`, `Transcription`, `ModelState`, `InsertResult`, `PermissionsStatus`, `DictationState`, и протоколы `AudioRecording`, `Transcribing`, `TextInserting`, `PermissionsProviding`. Формы — как в таблице ниже.

## Границы, решённые в спецификации

| Модуль | Владеет | Выставляет | Прячет |
|---|---|---|---|
| `Settings` | настройки пользователя (клавиша, режим, язык, модель, словарь, слова-паразиты, автозапуск) | `AppSettings` — наблюдаемая структура: `hotkey`, `triggerMode` (`hold`/`toggle`), `language` (`auto`/`ru`/`en`), `modelID`, `dictionary: [String]`, `removeFillers: Bool`, `launchAtLogin: Bool` | способ хранения (UserDefaults) |
| `HotkeyMonitor` | слежение за клавишей запуска | `start(hotkey: Hotkey, onPress: () -> Void, onRelease: () -> Void, onCancel: () -> Void)`, `stop()`, `isAvailable: Bool` | системный перехват событий, отбрасывание сочетаний с другими клавишами |
| `AudioRecorder` | запись голоса | `start() throws`, `stop() -> RecordedAudio` (`samples: [Float]` 16 кГц моно, `duration`), `levels: AsyncStream<Float>` | AVAudioEngine, преобразование частоты, лимит 5 минут |
| `Transcriber` (протокол) | распознавание | `state: ModelState` (`notInstalled`/`downloading(progress)`/`preparing`/`ready`/`failed(reason)`), `prepare(modelID:) async`, `transcribe(_ audio: RecordedAudio, language: Language, hints: [String]) async throws -> Transcription?` (`nil` — речи нет), `cancelPrepare()` | WhisperKit, загрузка, прогрев, фильтр тишины и галлюцинаций |
| `TextPostProcessor` | правка результата | `process(_ text: String, removeFillers: Bool) -> String` (чистая функция) | список паразитов, обрезка пробелов |
| `TextInserter` (протокол) | вставка текста в активное приложение | `insert(_ text: String) async throws -> InsertResult` (`inserted`/`copiedOnly(reason)`) | буфер обмена, синтетический ⌘V, возврат буфера |
| `Permissions` | статус и запрос разрешений | `status: PermissionsStatus` (микрофон, доступ для вставки/слежения), `request(_:)`, `openSettings(_:)`, поток изменений | конкретные API macOS |
| `DictationController` | сценарий диктовки | `state: DictationState` (`idle`/`recording`/`transcribing`/`inserting`/`message(text)`), `lastResult: String?`, `handlePress()`, `handleRelease()`, `handleCancel()` | конечный автомат, лимиты, порядок вызовов, повторное нажатие в процессе |
| `UI` | меню, плашка, настройки, чек-лист первого запуска | только чтение `DictationController`, `Settings`, `Permissions`, `Transcriber.state` | вёрстка |

**Шов для тестов один — `DictationController`.** Ему подставляются `Transcriber` и `TextInserter` (и запись) через протоколы; поведение проверяется по состояниям и вызовам. Чистая функция `TextPostProcessor` проверяется напрямую (это не шов, а функция без зависимостей). Настоящая модель Whisper в автотестах не запускается (сотни МБ); её проверяет ручной прогон на реальном звуке.

## Что построено

### Из таска 01 — каркас

- Пакет `MatveyVoice`: цели `MatveyVoiceCore` (библиотека, зависит от WhisperKit 0.18.0), `MatveyVoice` (исполняемый), `MatveyVoiceCoreTests`. Swift 6 language mode, macOS 14+. Тесты: `swift test`, один — `swift test --filter <Имя>`. Сборка приложения: `scripts/build-app.sh` → `build/MatveyVoice.app`.
- `Shared` (public, Sendable): `Hotkey{rightOption,rightCommand,rightControl,fn}`, `TriggerMode{hold,toggle}`, `Language{auto,ru,en}`, `RecordedAudio(samples,duration)`, `Transcription(text,detectedLanguage?)`, `ModelState{notInstalled,downloading(progress:),preparing,ready,failed(reason:)}`, `InsertResult{inserted,copiedOnly(reason:)}`, `PermissionKind{microphone,accessibility}`, `PermissionState{notDetermined,granted,denied}`, `PermissionsStatus(microphone,accessibility)`, `DictationState{idle,recording,transcribing,inserting,message(text:)}`.
- Протоколы (AnyObject, Sendable): `AudioRecording{start() throws; stop()->RecordedAudio; levels: AsyncStream<Float>}`, `Transcribing{state; prepare(modelID:) async; transcribe(_:language:hints:) async throws -> Transcription?; cancelPrepare()}`, `TextInserting{insert(_:) async throws -> InsertResult}`, `PermissionsProviding{status; request(_:) async; openSettings(_:); changes: AsyncStream<PermissionsStatus>}`.
- `AppSettings` — `@MainActor @Observable final class`, `init(defaults: UserDefaults = .standard)`; поля `hotkey, triggerMode, language, modelID, dictionary, removeFillers, launchAtLogin`; `static defaultModelID = "large-v3-turbo"`.
- Строки: таблица `UI`, ключ `menu.quit`; `Resources/{en,ru}.lproj/`. Info.plist — `Resources/Info.plist`.
- Папки `Transcription/`, `System/`, `Dictation/` содержат файлы-заглушки `_*Zone.swift` — их владелец таска вправе удалить.
