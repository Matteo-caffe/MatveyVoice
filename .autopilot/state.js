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
  "updatedAt": "2026-09-20T19:02:30+03:00",
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
      "startedAt": "2026-09-20T19:02:30+03:00"
    },
    {
      "id": "review",
      "status": "pending"
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
      "status": "pending",
      "retries": 0,
      "repairs": 0,
      "handoffs": 0
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
      "status": "pending",
      "retries": 0,
      "repairs": 0,
      "handoffs": 0
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
      "status": "pending",
      "retries": 0,
      "repairs": 0,
      "handoffs": 0
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
      "status": "pending",
      "retries": 0,
      "repairs": 0,
      "handoffs": 0
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
      "status": "pending",
      "retries": 0,
      "repairs": 0,
      "handoffs": 0
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
      "status": "pending",
      "retries": 0,
      "repairs": 0,
      "handoffs": 0
    }
  ],
  "singlePass": null,
  "tests": null,
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
  "concerns": [],
  "reviewers": {
    "manifestSpec": null,
    "craft": null
  },
  "blind": null
}
