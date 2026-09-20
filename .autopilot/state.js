window.STATE =
{
  "slug": "matveyvoice-dictation",
  "dir": "2026-09-20-matveyvoice-dictation--wip",
  "title": "MatveyVoice — диктовка голосом в любом приложении macOS",
  "mode": "semi",
  "depth": "normal",
  "polish": null,
  "tier": "T2",
  "briefFile": "2026-09-20-brief.md",
  "memoryFile": "CLAUDE.md",
  "skillDir": "/Users/matvejsuskov/MatveyVoice/.claude/skills/autopilot",
  "startedAt": "2026-09-20T18:52:00+03:00",
  "updatedAt": "2026-09-20T19:39:05+03:00",
  "finishedAt": null,
  "stages": [
    {
      "id": "preflight",
      "status": "done",
      "startedAt": "2026-09-20T18:52:00+03:00",
      "finishedAt": "2026-09-20T18:52:45+03:00"
    },
    {
      "id": "manifest",
      "status": "done",
      "startedAt": "2026-09-20T18:52:45+03:00",
      "finishedAt": "2026-09-20T18:53:07+03:00"
    },
    {
      "id": "briefing",
      "status": "done",
      "startedAt": "2026-09-20T18:53:07+03:00",
      "finishedAt": "2026-09-20T18:58:31+03:00"
    },
    {
      "id": "spec",
      "status": "done",
      "startedAt": "2026-09-20T18:58:31+03:00",
      "finishedAt": "2026-09-20T19:02:30+03:00"
    },
    {
      "id": "plan",
      "status": "done",
      "startedAt": "2026-09-20T19:02:30+03:00",
      "finishedAt": "2026-09-20T19:02:30+03:00",
      "note": "6 тасков, ярус T2, 3 волны"
    },
    {
      "id": "build",
      "status": "active",
      "startedAt": "2026-09-20T19:02:30+03:00",
      "note": "5 из 6 тасков готовы"
    },
    {
      "id": "review",
      "status": "active",
      "startedAt": "2026-09-20T19:14:21+03:00",
      "note": "проверено 5 из 6"
    },
    {
      "id": "final",
      "status": "pending"
    }
  ],
  "requirements": {
    "total": 13,
    "done": 0,
    "inTicket": 13,
    "inSpec": 0,
    "placeholder": 0,
    "deferred": 0,
    "dropped": 0
  },
  "tickets": [
    {
      "id": "01",
      "title": "Каркас: пакет, оболочка, общие типы, настройки, сборка .app",
      "requirements": [
        "R01",
        "R06",
        "R07"
      ],
      "blockedBy": [],
      "wave": 1,
      "zone": [
        "Package.swift",
        "Sources/MatveyVoice/",
        "Sources/MatveyVoiceCore/Shared/",
        "Sources/MatveyVoiceCore/Settings/",
        "scripts/build-app.sh"
      ],
      "status": "done",
      "retries": 0,
      "repairs": 0,
      "handoffs": 0,
      "startedAt": "2026-09-20T19:03:02+03:00",
      "finishedAt": "2026-09-20T19:14:21+03:00",
      "commit": "b621d7c",
      "tests": {
        "passed": 2,
        "failed": 0
      },
      "files": [
        "Package.swift",
        "Sources/MatveyVoiceCore/Shared/",
        "Sources/MatveyVoiceCore/Settings/",
        "scripts/build-app.sh"
      ],
      "concerns": []
    },
    {
      "id": "02",
      "title": "Распознавание: WhisperKit, модель, фильтр, постобработка",
      "requirements": [
        "R03",
        "R11i",
        "R12i",
        "A01",
        "A02"
      ],
      "blockedBy": [
        "01"
      ],
      "wave": 2,
      "zone": [
        "Sources/MatveyVoiceCore/Transcription/"
      ],
      "status": "done",
      "retries": 0,
      "repairs": 1,
      "handoffs": 0,
      "startedAt": "2026-09-20T19:14:21+03:00",
      "tests": {
        "passed": 23,
        "failed": 0
      },
      "finishedAt": "2026-09-20T19:39:05+03:00",
      "commit": "7ddcee3",
      "repairFindings": [
        "фильтр галлюцинаций резал настоящую речь; старая модель должна оставаться рабочей при смене"
      ]
    },
    {
      "id": "03",
      "title": "Система: клавиша, запись, вставка, разрешения",
      "requirements": [
        "R04",
        "R09i",
        "R10i"
      ],
      "blockedBy": [
        "01"
      ],
      "wave": 2,
      "zone": [
        "Sources/MatveyVoiceCore/System/"
      ],
      "status": "done",
      "retries": 0,
      "repairs": 0,
      "handoffs": 0,
      "startedAt": "2026-09-20T19:14:21+03:00",
      "finishedAt": "2026-09-20T19:33:17+03:00",
      "commit": "4ab9d66",
      "tests": {
        "passed": 13,
        "failed": 0
      }
    },
    {
      "id": "04",
      "title": "Сценарий диктовки: конечный автомат",
      "requirements": [
        "R02",
        "R03",
        "R04"
      ],
      "blockedBy": [
        "01"
      ],
      "wave": 2,
      "zone": [
        "Sources/MatveyVoiceCore/Dictation/"
      ],
      "status": "done",
      "retries": 0,
      "repairs": 1,
      "handoffs": 0,
      "startedAt": "2026-09-20T19:14:21+03:00",
      "finishedAt": "2026-09-20T19:33:17+03:00",
      "commit": "a30afa9",
      "repairFindings": [
        "R02.5: нет сообщения при остановке по лимиту; усилены тесты"
      ],
      "tests": {
        "passed": 18,
        "failed": 0
      }
    },
    {
      "id": "05",
      "title": "Интерфейс: меню, плашка, настройки, чек-лист",
      "requirements": [
        "R01",
        "R02",
        "R05",
        "R10i"
      ],
      "blockedBy": [
        "01",
        "02",
        "03",
        "04"
      ],
      "wave": 3,
      "zone": [
        "Sources/MatveyVoice/UI/"
      ],
      "status": "in-progress",
      "retries": 0,
      "repairs": 0,
      "handoffs": 0,
      "startedAt": "2026-09-20T19:39:05+03:00"
    },
    {
      "id": "06",
      "title": "Упаковка и репозиторий: dmg, README, лицензия",
      "requirements": [
        "R06",
        "R07",
        "R08",
        "R13i"
      ],
      "blockedBy": [
        "01"
      ],
      "wave": 3,
      "zone": [
        "scripts/make-dmg.sh",
        "README.md",
        "LICENSE",
        "docs/"
      ],
      "status": "done",
      "retries": 0,
      "repairs": 0,
      "handoffs": 0,
      "startedAt": "2026-09-20T19:33:17+03:00",
      "finishedAt": "2026-09-20T19:39:05+03:00",
      "commit": "1631f3f"
    }
  ],
  "singlePass": null,
  "tests": {
    "passed": 49,
    "failed": 0
  },
  "debt": {
    "placeholders": [
      "[GITHUB-USER] и [COPYRIGHT-HOLDER] в README и LICENSE"
    ],
    "assumptions": [
      "Лицензия MIT — принято за пользователя (он лицензию не называл)",
      "Распознавание — WhisperKit (Whisper на устройстве), модель large-v3-turbo по умолчанию",
      "Горячая клавиша по умолчанию — удержание правого ⌥",
      "Вставка через буфер обмена и ⌘V"
    ],
    "emptyEnv": []
  },
  "additions": [],
  "coverage": {
    "findings": 1,
    "note": "R02: функции Aqua сверх диктовки (контекст экрана, голосовые команды, LLM-правка) вынесены в Вне рамок → deferred, попадёт в отчёт; остальное покрыто"
  },
  "concerns": [
    "Package.swift:11 — WhisperKit from 0.9.0, проверено на 0.18.0 (поднять нижнюю границу)",
    "AppDelegate.swift:9 — при одновременном старте двух копий обе могут завершиться (R01.3)",
    "Apple Silicon не закреплён в сборке (R01.1) — решить в таске 06 (только arm64)",
    "AppDelegate.swift:22 — accessibilityDescription вне таблицы строк",
    "AppSettingsTests — нет теста на неизвестный rawValue в UserDefaults",
    "TextInserter.swift — текст диктовки не помечен как временный (ConcealedType/TransientType): менеджеры буфера сохранят его; возврат буфера по фиксированным 250 мс — медленное приложение получит старое содержимое",
    "HotkeyStateMachine.swift:31 — триггер при уже зажатых других клавишах всё равно даёт press (R09i.2)",
    "HotkeyMonitor.swift — нет deinit→stop(); при tapCreate==nil молча не поднимается (05 перезапускает по Permissions.changes)",
    "AudioRecorder.swift — гонка колбэка лимита со stop()/start(); onLimitReached не подключён, лимит считается дважды (рекордер и таймер контроллера)",
    "TextInserter.postCommandV — код клавиши V привязан к раскладке (Dvorak)",
    "Permissions — accessibility не бывает .denied; UI должен одинаково говорить «не выдан/отозван»",
    "Тесты DictationController видят ключи строк, а не переведённый текст (нет bundle в тестах)",
    "Тест-команда на этой машине: swift test с -Xswiftc -plugin-path … (см. interfaces.md)",
    "scripts/make-dmg.sh — собирает из уже существующей build/MatveyVoice.app, может быть устаревшей",
    "build-app.sh — ключ значка дописывается PlistBuddy, без иконки сборка молча идёт без неё",
    "SpeechFilter — список галлюцинаций короткий, составлен по памяти; пороги тишины подобраны на глаз",
    "WhisperTranscriber — ветка switchProgress без автотеста, large-v3-turbo вручную не прогонялась"
  ],
  "reviewers": {
    "manifestSpec": "a17d0b82dc95984c4",
    "craft": "a6aaa7728fd5a09e9"
  },
  "blind": null
}
