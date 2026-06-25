---
status: complete
date: 2026-06-25
quick_id: 260625-web
---

# Summary

Upgraded Android OCR extraction completeness for Protocol and DMEM/media sources.

## Changes

- Added Chinese ML Kit text recognition alongside Latin recognition.
- Merged Latin and Chinese OCR outputs with line-level de-duplication.
- Added OCR text normalization before Protocol and DMEM parsing.
- Improved DMEM/media parser for split reagent-name and amount lines.
- Improved reagent name normalization for DMEM, FBS, and Pen-Strep/双抗.
- Extended Protocol reagent extraction to handle OCR split-line amounts.
- Added parser tests for Chinese/split-line media OCR and Protocol split reagent OCR.

## Verification

- `flutter test test/widget_test.dart --plain-name "Buffer recipe extraction handles split OCR lines and Chinese labels"` passed.
- `flutter test test/widget_test.dart --plain-name "Protocol extraction handles OCR split reagent amounts"` passed.
- `flutter test test/widget_test.dart --plain-name "Protocol extraction exposes iOS-style source workflow"` passed.
- `flutter test test/widget_test.dart --plain-name "DMEM extraction saves OCR text as a media template"` passed.
- `flutter analyze` passed.
- `flutter build apk --debug` passed.
