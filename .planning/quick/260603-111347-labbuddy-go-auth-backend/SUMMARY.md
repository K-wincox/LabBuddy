---
status: complete
---

# LabBuddy Go Auth Backend Summary

Implemented a Go auth backend under `backend/labbuddy` and deployed it to `172.16.8.18:/home/kongweikang_2025/software/kwk/labbuddy`.

## Completed

- Added Go API service with registration, email-code verification, password login, code login, token refresh, logout, and `/me`.
- Added PostgreSQL migrations for users, verification codes, sessions, and profiles.
- Added Dockerfile and Compose deployment using `127.0.0.1:8088`.
- Created and used Docker network `labbuddy-shared` so API connects to PostgreSQL by container name `magicmirror-postgres`.
- Kept SMTP in `EMAIL_MODE=log` until real credentials are provided.

## Verification

- `GOPROXY=https://goproxy.cn,direct go test ./...` passed locally.
- Server Docker image built and container started.
- `GET /health` returned `{"status":"ok"}`.
- Register start -> log verification code -> register verify succeeded.
- `/api/v1/me` succeeded with access token.
- Refresh token endpoint succeeded.
- Logout endpoint succeeded.
- Password login succeeded.
- Verification-code login succeeded.

## Server State

- Database: `labbuddy`.
- App DB role: `labbuddy_app`.
- Server secret files:
  - `/home/kongweikang_2025/software/kwk/labbuddy/.db_password`
  - `/home/kongweikang_2025/software/kwk/labbuddy/.env`

SMTP credentials should be added only to the server `.env`, not to git.
