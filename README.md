# MatveyVoice

[Русская версия](README.ru.md)

Free, open source, fully local dictation for macOS. Hold a key, speak, release: the text is typed into whatever app you are using. Speech recognition runs on your Mac with Whisper; your voice never leaves it.

Inspired by the idea of Aqua Voice. MatveyVoice is an independent project: it is not affiliated with Aqua Voice and does not use its code, logos or other materials.

## Requirements and limitations

- macOS 14 or newer, Apple Silicon (M1 or later). Intel Macs are not supported.
- Languages: automatic detection, Russian or English. Mixing languages inside one phrase is not guaranteed to work.
- The app is ad-hoc signed and not notarized (see "First launch").

## Install

### From the .dmg

1. Download `MatveyVoice.dmg` from the [Releases](https://github.com/[GITHUB-USER]/MatveyVoice/releases) page.
2. Open it and drag MatveyVoice onto the Applications shortcut.
3. The first launch is blocked by Gatekeeper because the app is not notarized. Either right-click the app and choose "Open", or run:

   ```
   xattr -dr com.apple.quarantine /Applications/MatveyVoice.app
   ```

### From source

You need the Swift toolchain (Command Line Tools are enough; Xcode is not required).

```
git clone https://github.com/[GITHUB-USER]/MatveyVoice.git
cd MatveyVoice
scripts/build-app.sh      # builds build/MatveyVoice.app (arm64)
scripts/make-dmg.sh       # optional: builds build/MatveyVoice.dmg
open build/MatveyVoice.app
```

`scripts/make-icon.sh` regenerates `Resources/AppIcon.icns` from code.

Note for machines with only Command Line Tools: Swift Testing may fail to build with "plugin for module TestingMacros not found". Run the tests like this:

```
swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

## First launch and permissions

MatveyVoice lives in the menu bar. On first launch it walks you through:

- **Microphone**: to record your voice.
- **Accessibility** ("Universal Access" in Russian): to watch the trigger key and to paste text with Cmd+V.
- **Model download**: one time, see below.

Because the app is ad-hoc signed, macOS treats every rebuild as a new app: after rebuilding from source, grant the permissions again.

## Using it

- Default trigger: hold the **right Option** key, speak, release. Right Cmd, right Ctrl or Fn can be chosen in Settings.
- Mode "toggle" (press once to start, again to stop) is available in Settings.
- Pressing the trigger together with another key cancels the recording.
- The text is pasted through the clipboard, and your previous clipboard contents are restored afterwards. Enter is never pressed for you.
- Language: automatic, Russian or English.

## Models

| Model | Size | Notes |
|---|---|---|
| small | ~250 MB | faster, lighter |
| large-v3-turbo | ~630 MB | default, more accurate |

The model is downloaded once from Hugging Face into `~/Library/Application Support/MatveyVoice/Models`. WhisperKit also fetches the tokenizer from the same place. After that no internet connection is needed.

## Privacy

Nothing is sent anywhere: no analytics, no telemetry, no accounts. The only network traffic is the one-time model download. Audio and dictated text are not saved to disk.

## Manual test checklist

See [docs/manual-checklist.md](docs/manual-checklist.md).

## License

MIT, see [LICENSE](LICENSE). Copyright (c) 2026 [COPYRIGHT-HOLDER].
