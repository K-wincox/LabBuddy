---
status: complete
---

# Hide Auth Server Info Summary

Removed visible server address text from the first-login screen and switched the development default API URL to the Mac SSH tunnel.

## Completed

- Removed server host display from `AuthView`.
- Changed default API base URL to `http://172.16.14.27:18088`.
- Updated preferences default and helper copy.
- Switched server email mode to `log` for verification-code testing.

## Verification

- `http://172.16.14.27:18088/health` returned `{"status":"ok"}`.
- Server `EMAIL_MODE=log` is active.
- iOS simulator launch succeeded.
- Screenshot confirmed no server address is visible on the login screen.
