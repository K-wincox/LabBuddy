---
status: complete
date: 2026-06-25
quick_id: 260625-ljt
---

# Improve Android DMEM Extraction And Protocol Source Parsing

## Scope

- Add Android Tools entry for extracting DMEM/media recipes from camera, uploaded photo, PDF, text, or pasted OCR text.
- Improve Android Protocol extraction sources so image/PDF imports use real local recognition where possible and avoid long blocking waits.
- Keep parsing local-first and compatible with the existing Protocol and buffer-template data models.

## Verification

- `flutter analyze`
- `flutter test test/widget_test.dart --plain-name "Protocol extraction exposes iOS-style source workflow"`
- `flutter test test/widget_test.dart --plain-name "DMEM extraction saves OCR text as a media template"`
- `flutter build apk --debug`
