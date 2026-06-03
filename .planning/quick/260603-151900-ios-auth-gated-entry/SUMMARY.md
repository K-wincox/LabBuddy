---
status: complete
---

# iOS Auth Gated Entry and Account Settings Summary

Implemented first-launch login/register gating and moved account settings behind the user card in `我的`.

## Completed

- App now shows `AuthView` before the main TabView when no authenticated session exists.
- Login/register UI now behaves as a full-screen entry surface, not a sheet-only utility.
- Main app loads after successful authentication.
- `我的` now uses a tappable user card to open user/preferences settings.
- Account actions are grouped in a concise settings-style card.
- Login button is no longer duplicated inside `我的`.

## Verification

- iOS simulator build succeeded.
- iOS simulator launch succeeded.
- Runtime screenshot confirmed first screen is the LabBuddy login/register gate.

## Notes

- QQ SMTP remains blocked by Tencent `535`, so registration-code delivery still needs provider-side resolution or temporary `EMAIL_MODE=log` for testing.
