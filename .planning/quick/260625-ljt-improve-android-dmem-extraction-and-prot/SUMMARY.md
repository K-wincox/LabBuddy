---
status: complete
date: 2026-06-25
quick_id: 260625-ljt
---

# Summary

Implemented Android DMEM/media recipe extraction and upgraded Protocol extraction sources.

## Changes

- Added a Tools screen `DMEM 提取` flow that previews and saves extracted media recipes as buffer templates.
- Added a shared buffer recipe parser for common media lines such as DMEM, FBS, and Pen-Strep with inferred base volume.
- Reworked Protocol extraction source actions into PDF, text, camera, photo upload, and paste OCR flows with progress and timeout fallback.
- Added native Android OCR methods through the existing `labbuddy/data_card` channel:
  - `recognizeImageText`
  - `captureImageText`
  - `recognizePdfText`
- Added ML Kit text recognition dependency and PDF page rendering for the first three pages to keep parsing bounded.
- Added widget test coverage for Protocol source actions and DMEM recipe extraction.

## Verification

- `flutter analyze` passed.
- `flutter test test/widget_test.dart --plain-name "Protocol extraction exposes iOS-style source workflow"` passed.
- `flutter test test/widget_test.dart --plain-name "DMEM extraction saves OCR text as a media template"` passed.
- `flutter build apk --debug` passed and produced `build/app/outputs/flutter-apk/app-debug.apk`.
