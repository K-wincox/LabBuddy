---
status: in_progress
created: 2026-06-23
---

# iOS Release Assets on GitHub

## Goal
Publish the iOS version under the same GitHub project while keeping Android and iOS downloadable separately.

## Scope
- Keep Android and iOS source trees separated in the same repository.
- Add a mobile release workflow that uploads both Android APK and iOS prototype zip on version tags.
- Add iOS release documentation clarifying Xcode/Simulator package vs installable IPA.
- Commit current iOS source changes and release workflow.
- Verify iOS preflight build and iOS prototype packaging.

## Verification
- `./scripts/check-ios-local.sh`
- `./scripts/package-ios-prototype.sh`
- GitHub Release assets include Android APK and iOS prototype zip.
