---
status: complete
---

# Summary

- Reused the existing Protocol extraction menu; added camera OCR, album image OCR, SOP PDF, kit/manual PDF, and literature PDF flows.
- Added local Vision OCR, PDFKit text extraction, and a rule-based Protocol draft parser.
- Generated editable Protocol drafts from extracted text, with source metadata, inferred ingredients, steps, duration, warnings, and a required final editor confirmation.
- Added iOS camera and photo library privacy strings to the generated Info.plist build settings.
- Extended ProtocolSourceType with camera and photo library sources and ordered the menu as photo/camera/PDF/literature workflows.

# Verification

- `make preflight`: passed
- `build_run_sim`: passed
- Simulator screenshot verified the app still launches to Today.
