# Privacy Policy

[Русская версия ниже](#политика-конфиденциальности)

MatveyVoice runs entirely on your Mac. The author does not receive any of your data: there are no accounts, servers, analytics, telemetry or crash reports.

## What the app handles

- **Audio.** Recorded only while you hold (or toggle) the dictation key, at most 5 minutes at a time. It is kept in memory, transcribed on your Mac and then discarded. It is never written to disk.
- **Dictated text.** Pasted into the active app through the clipboard. While it is on the clipboard it is marked as transient and concealed, so clipboard managers that follow the [nspasteboard.org](http://nspasteboard.org) convention skip it; your previous clipboard contents are restored right after the paste. The last result stays in memory so you can copy it again from the menu, and is gone when the app quits. Dictated text is never written to disk or to logs.
- **Password fields.** If the focused field is a password field, the text is not pasted and the clipboard is not touched.
- **Settings.** The hotkey, mode, language, model choice, your custom dictionary words and a few preferences are saved in the app's standard macOS preferences on your Mac.

## Network

The only network traffic is the one-time download of the speech model and its tokenizer from Hugging Face (huggingface.co) into `~/Library/Application Support/MatveyVoice/Models`. As with any download, Hugging Face sees your IP address; no audio or text is sent. After that the app works offline.

## Permissions

- **Microphone** — to record your voice.
- **Accessibility** — to notice the dictation key and paste text into other apps.

## Contact

Questions: open an issue in the [GitHub repository](https://github.com/Matteo-caffe/MatveyVoice). Security problems: see [SECURITY.md](SECURITY.md).

---

# Политика конфиденциальности

MatveyVoice работает полностью на вашем Mac. Автор не получает никаких ваших данных: нет аккаунтов, серверов, аналитики, телеметрии и отчётов о сбоях.

## Что обрабатывает приложение

- **Звук.** Записывается только пока вы держите (или включили) клавишу диктовки, не дольше 5 минут за раз. Хранится в памяти, распознаётся на вашем Mac и сразу отбрасывается. На диск не пишется никогда.
- **Продиктованный текст.** Вставляется в активное приложение через буфер обмена. Пока он в буфере, он помечен как временный и скрытый, поэтому менеджеры буфера обмена, поддерживающие соглашение [nspasteboard.org](http://nspasteboard.org), его не сохраняют; прежнее содержимое буфера возвращается сразу после вставки. Последний результат хранится в памяти, чтобы его можно было скопировать ещё раз из меню, и пропадает при выходе из приложения. На диск и в логи текст диктовки не пишется.
- **Поля паролей.** Если в фокусе поле пароля, текст не вставляется, а буфер обмена не трогается.
- **Настройки.** Клавиша, режим, язык, выбранная модель, слова вашего словаря и несколько параметров хранятся в стандартных настройках macOS на вашем Mac.

## Сеть

Единственный сетевой трафик — разовая загрузка модели распознавания и её токенизатора с Hugging Face (huggingface.co) в `~/Library/Application Support/MatveyVoice/Models`. Как при любой загрузке, Hugging Face видит ваш IP-адрес; звук и текст не отправляются. После этого приложение работает без интернета.

## Разрешения

- **Микрофон** — чтобы записывать голос.
- **Универсальный доступ** — чтобы замечать клавишу диктовки и вставлять текст в другие приложения.

## Связь

Вопросы — через issue в [репозитории на GitHub](https://github.com/Matteo-caffe/MatveyVoice). Проблемы безопасности — см. [SECURITY.md](SECURITY.md).
