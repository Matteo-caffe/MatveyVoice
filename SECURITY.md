# Security Policy

MatveyVoice has the same macOS permissions as a keylogger would (Accessibility and the microphone), so security reports are taken seriously.

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub: open the [Security tab](https://github.com/Matteo-caffe/MatveyVoice/security) of this repository and click **Report a vulnerability**. Do not open a public issue for security problems.

## Supported versions

Only the latest release receives security fixes.

## Verifying a download

Only download MatveyVoice from the [Releases](https://github.com/Matteo-caffe/MatveyVoice/releases) page of this repository. Forks and re-uploads elsewhere are not official.

Check the checksum published next to the `.dmg`:

```
shasum -a 256 -c MatveyVoice.dmg.sha256
```

Releases built by GitHub Actions also carry a build provenance attestation that ties the `.dmg` to the exact commit it was built from:

```
gh attestation verify MatveyVoice.dmg -R Matteo-caffe/MatveyVoice
```

## Scope

In scope: anything that lets dictated text or audio leave the Mac, be written to disk or logs, or be read by another process; code injection into the signed app; tampering with the model download.
