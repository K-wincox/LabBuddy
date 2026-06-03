# LabBuddy Backend

Go backend for LabBuddy account registration, verification-code login, password login, logout, and profile lookup.

## Development defaults

- PostgreSQL database: `labbuddy`
- PostgreSQL app role: `labbuddy_app`
- API bind: `127.0.0.1:8088`
- Email mode before SMTP credentials are provided: `EMAIL_MODE=log`

## Endpoints

- `GET /health`
- `POST /api/v1/auth/register/start`
- `POST /api/v1/auth/register/verify`
- `POST /api/v1/auth/login/password`
- `POST /api/v1/auth/login/code/start`
- `POST /api/v1/auth/login/code/verify`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/me`

## SMTP

Keep `.env` on the server only. For QQ mail development SMTP:

```env
EMAIL_MODE=smtp
SMTP_HOST=smtp.qq.com
SMTP_PORT=587
SMTP_USER=your_email@qq.com
SMTP_PASSWORD=mail_authorization_code
SMTP_FROM=your_email@qq.com
```
