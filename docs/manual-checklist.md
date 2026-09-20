# Manual test checklist / Ручная проверка

For each app below, with the model installed and permissions granted. / Для каждого приложения при установленной модели и выданных разрешениях.

Per-app checks / Проверки для каждого приложения:

- [ ] Dictation is pasted at the cursor. / Диктовка вставляется в позицию курсора.
- [ ] Enter is not pressed. / Enter не нажимается.
- [ ] The previous clipboard contents are restored (copy something before dictating, paste after). / Прежнее содержимое буфера обмена возвращается (скопируйте что-нибудь до диктовки, вставьте после).
- [ ] Cancel works: pressing the trigger with another key during recording inserts nothing. / Отмена сочетанием работает: нажатие другой клавиши вместе с триггером во время записи ничего не вставляет.

Apps / Приложения:

- [ ] Telegram
- [ ] WhatsApp
- [ ] Safari (text field on a web page / поле на веб-странице)
- [ ] ChatGPT / Claude (web or app / сайт или приложение)
- [ ] Notes / Заметки
- [ ] Messages / Сообщения
- [ ] Mail / Почта
- [ ] Terminal / Терминал

Permissions revoked / Разрешения отозваны:

- [ ] Microphone access revoked: a clear message is shown, no crash. / Доступ к микрофону отозван: показано понятное сообщение, приложение не падает.
- [ ] Accessibility revoked: a clear message is shown; the text is left on the clipboard. / «Универсальный доступ» отозван: показано понятное сообщение, текст остаётся в буфере обмена.

Also / Также:

- [ ] Both languages (Russian, English) and auto-detect. / Оба языка и автоопределение.
- [ ] After a rebuild, permissions must be granted again. / После пересборки права нужно выдать заново.
