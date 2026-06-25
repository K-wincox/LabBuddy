---
status: complete
date: 2026-06-25
quick_id: 260625-web
---

# Upgrade Android OCR Extraction Completeness

## Scope

- Improve Android OCR coverage for Chinese and English Protocol/DMEM sources.
- Normalize OCR text before parsing so camera/photo/PDF results are less brittle.
- Support common split-line OCR patterns where reagent names and amounts appear on separate lines.
- Verify Android native build after dependency changes.

## Verification

- `flutter test test/widget_test.dart --plain-name "Buffer recipe extraction handles split OCR lines and Chinese labels"`
- `flutter test test/widget_test.dart --plain-name "Protocol extraction handles OCR split reagent amounts"`
- `flutter test test/widget_test.dart --plain-name "Protocol extraction exposes iOS-style source workflow"`
- `flutter test test/widget_test.dart --plain-name "DMEM extraction saves OCR text as a media template"`
- `flutter analyze`
- `flutter build apk --debug`
