---
status: complete
---

# Summary

- Added scanned/image-only PDF OCR for Protocol extraction.
- PDF import now first reads embedded text via PDFKit; if text is not useful, it renders pages locally and runs Vision OCR.
- Limits scanned PDF OCR to the first 12 pages for MVP responsiveness and explains that in the status message.
- Kept implementation local-first with Apple frameworks instead of adding backend or third-party OCR dependencies.

# Verification

- `make preflight`: passed
