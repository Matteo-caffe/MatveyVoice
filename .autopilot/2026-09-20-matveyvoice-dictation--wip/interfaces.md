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

### Из таска 04 — сценарий диктовки

- `@MainActor @Observable public final class DictationController`; `init(settings: AppSettings, recorder: any AudioRecording, transcriber: any Transcribing, inserter: any TextInserting, postProcess: @Sendable (String, Bool) -> String = тождественная, sleep:, minimumDuration = 0.3, maximumDuration = 300, messageDuration = 3)`.
- `state: DictationState`, `lastResult: String?`; `handlePress()`, `handleRelease()`, `handleCancel()`, `waitForCompletion() async`.
- Подключение (таск 05): `postProcess: { TextPostProcessor.process($0, removeFillers: $1) }`. Язык, словарь, режим, removeFillers читаются из `AppSettings` в момент нажатия/окончания записи.
- Строки: таблица `Dictation`, ключи `message.*` (modelNotInstalled, modelDownloading, modelPreparing, modelFailed, recordFailed, recognitionFailed, noSpeech, needAccess, insertFailed).
- Лимит записи 300 с держит сам контроллер (у `AudioRecording` нет колбэка о лимите). Нажатие/отмена во время transcribing/inserting игнорируются. Пустой текст после постобработки = тишина.

### Из таска 03 — система

- `HotkeyMonitor` (final, @unchecked Sendable): `init()`; `start(hotkey:onPress:onRelease:onCancel:)` (замыкания `@escaping () -> Void`, приходят на главном run loop); `stop()`; `isAvailable: Bool`. Слежение — активный CGEventTap, нужен только «Универсальный доступ» (Мониторинг ввода не запрашивается). Если доступа нет при `start`, слежение молча не поднимается — таск 05 перезапускает `start` по `Permissions.changes`.
- `HotkeyStateMachine` (struct, чистая) `handle(_ HotkeyEvent) -> HotkeyOutput?`; `HotkeyClassifier.classify(kind:keyCode:flags:hotkey:)`.
- `AudioRecorder: AudioRecording`; `init()`; `static maxDuration = 300`; `onLimitReached: (@Sendable () -> Void)?` — сейчас нигде не подключён (лимит держит DictationController).
- `TextInserter: TextInserting`; `init(pasteboard:isTrusted:sendPaste:restoreDelay:)`, в приложении `TextInserter()`; буфер возвращается через 250 мс, если его не меняли.
- `Permissions: PermissionsProviding`; `init()`; `changes` — опрос раз в секунду. Универсальный доступ отдаётся как `.notDetermined` или `.granted` (`.denied` не бывает).
- Строки: таблица `System`, ключ `insert.noAccess`.

### Из таска 02 — распознавание

- `WhisperTranscriber: Transcribing` (@unchecked Sendable): `init(downloadBase: URL? = nil)`; `static defaultDownloadBase` = `~/Library/Application Support/MatveyVoice/Models`; `state`, `prepare(modelID:) async`, `cancelPrepare()`, `transcribe(_:language:hints:) async throws -> Transcription?`.
- `TextPostProcessor.process(_ text: String, removeFillers: Bool) -> String`.
- `ModelCatalog`: `entries`, `entry(for:)`, `whisperKitVariant(for:)`; small = `openai_whisper-small` (~250 МБ), large-v3-turbo = `openai_whisper-large-v3-v20240930_turbo` (~630 МБ).
- `SpeechFilter.isSilent([Float])`, `SpeechFilter.isHallucination(String)`; `TranscriptionErrorDescriber.reason(for:)`; строки — таблица `Transcription`.
- Автоопределение языка ограничено ru/en. WhisperKit при первой загрузке сам тянет токенизатор с Hugging Face (тот же единственный сетевой канал).

### Тест-команда (важно)

На этой машине `swift test` без флага не собирает Swift Testing: «plugin for module TestingMacros not found». Рабочая команда: `swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing`. Не менять ничего в системе.

### Правка таска 02 (после ревью)

- `WhisperTranscriber.switchProgress: ModelState?` — загрузка другой модели при уже рабочей: пока она идёт, `state` остаётся `.ready`, диктовка идёт на прежней; `nil`, если переключения нет. Не входит в протокол `Transcribing` — UI (таск 05) читает его на самом `WhisperTranscriber`. Если рабочей модели ещё нет, прогресс идёт в `state`.
- `state` при запуске приложения — `.notInstalled`, пока не вызван `prepare(modelID:)`: таск 05 обязан вызвать `prepare` при старте.
- `SpeechFilter.isHallucination` отбрасывает только полные известные фразы, известную подпись с именем ≤2 слов с заглавной, текст в скобках/♪ до 4 слов. `TranscriberError` — `LocalizedError`.

### Из таска 06 — упаковка

- `scripts/build-app.sh` (только arm64, подхватывает `Resources/AppIcon.icns`), `scripts/make-icon.sh`, `scripts/make-dmg.sh` → `build/MatveyVoice.dmg`, `docs/manual-checklist.md`. README.md/README.ru.md описывают возможности приложения — таск 05 реализует ровно их (первый запуск с чек-листом, выбор клавиши, режим, язык, модель, словарь, слова-паразиты, «Запускать при входе», «Скопировать последнюю диктовку»).
