---
status: complete
---

# iOS Auth Login Integration Summary

Implemented LabBuddy iOS auth integration for the Go backend.

## Completed

- Added auth API client, models, session store, and Keychain token storage.
- Added SwiftUI login/register/code-login sheet.
- Integrated account state into `我的`.
- Added logout action.
- Added editable API base URL in Preferences for LAN/public testing.
- Added custom `Info.plist` with development HTTP allowance.
- Updated Xcode project references for new Swift files.
- Changed backend Compose port binding to `0.0.0.0:8088` for same-LAN device access.

## Verification

- Server `http://172.16.8.18:8088/health` returned `{"status":"ok"}`.
- iOS simulator build succeeded.
- iOS simulator install and launch succeeded after Info.plist fixes.
- Final simulator build succeeded after adding API address preference.

## Notes

- QQ SMTP still returns `535` from Tencent auth, so real email-code testing is blocked by provider-side authentication.
- For immediate UI flow testing, switch server `.env` to `EMAIL_MODE=log` and read codes from server logs, or use an already verified test account with password login.
