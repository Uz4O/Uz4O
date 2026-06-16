# Auth and Profile Sync Design

## Goal

Add the first backend account layer so the app can sign users in and sync their
onboarding preferences plus current hardware profile across devices.

## Scope

- Phone-code login in development-code mode.
- Signed bearer access tokens.
- Current account endpoint.
- Onboarding profile get/update.
- Current hardware profile get/update.
- PostgreSQL persistence through Alembic.

Out of scope for this slice:

- Real SMS provider integration.
- Sign in with Apple.
- WeChat login.
- Refresh tokens and device management.
- Password login.

## API

- `POST /v1/auth/sms/send`
  - Body: `{ "phone": "13800138000" }`
  - Stores a hashed 6-digit code.
  - In debug mode returns the code for local/app testing.

- `POST /v1/auth/login`
  - Body: `{ "phone": "13800138000", "code": "123456" }`
  - Creates the account if missing.
  - Returns `{ "access_token": "...", "token_type": "bearer", "account": {...} }`.

- `GET /v1/auth/me`
  - Requires `Authorization: Bearer <token>`.

- `GET /v1/profile/onboarding`
  - Requires token.
  - Returns default profile if none has been saved.

- `PUT /v1/profile/onboarding`
  - Requires token.
  - Upserts preference and home feature order.

- `GET /v1/profile/hardware`
  - Requires token.
  - Returns default empty current-computer profile if none has been saved.

- `PUT /v1/profile/hardware`
  - Requires token.
  - Upserts current hardware profile fields.

## Data Model

- `account`
  - `id`
  - `phone`
  - `apple_sub`
  - `wechat_openid`
  - `nickname`
  - `created_at`
  - `updated_at`

- `auth_sms_code`
  - `id`
  - `phone`
  - `code_hash`
  - `expires_at`
  - `consumed_at`
  - `created_at`

- `onboarding_profile`
  - `account_id`
  - `preference`
  - `home_feature_order`
  - `updated_at`

- `hardware_profile`
  - `id`
  - `account_id`
  - `label`
  - `cpu`
  - `gpu`
  - `motherboard`
  - `memory`
  - `storage`
  - `power_supply`
  - `is_current_computer`
  - `was_skipped`
  - `updated_at`

## Security Notes

- SMS code plaintext is not stored.
- Tokens are signed with `APP_AUTH_TOKEN_SECRET`.
- Local tests can use the default development secret.
- The deployed server should have its own generated secret in `/opt/new-site/.env`.
- The API must not log or print codes, tokens, or secrets.

## Testing

- Unit-test token signing and verification.
- Repository-test account creation, SMS verification, and profile upserts.
- API-test SMS send/login, protected endpoint rejection, and profile sync.
- Run Alembic upgrade against a temporary SQLite database.
