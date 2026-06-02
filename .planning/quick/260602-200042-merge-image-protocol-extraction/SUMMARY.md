---
status: complete
---

# Summary

- Merged camera OCR and album image OCR into one Protocol extraction source: `图片识别`.
- Kept both actions inside the extraction sheet as `拍照识别` and `相册导入` buttons.
- Added backward-compatible decoding so previously saved `拍照识别` or `相册导入` sources map to `图片识别`.

# Verification

- `make preflight`: passed
