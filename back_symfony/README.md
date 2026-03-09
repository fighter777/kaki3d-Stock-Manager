# Back Symfony (API)

API REST pour `kaki3d-Stock-Manager` (lookup NFC + inventaire + consommation).

## Endpoints

- `GET /api/health` (public)
- `POST /api/auth/register` (public)
- `POST /api/auth/login` (public)
- `POST /api/auth/logout` (auth token)
- `POST /api/auth/change-password` (auth token)
- `GET /api/spools` (auth token)
- `GET /api/spools/aggregated` (auth token)
- `POST /api/spools` (auth token)
- `PUT /api/spools/{id}` (auth token)
- `DELETE /api/spools/{id}` (auth token)
- `POST /api/spools/{id}/clone` (auth token)
- `GET /api/spools/nfc/{uid}` (auth token)
- `GET /api/brands` (auth token)
- `GET /api/materials` (auth token)
- `POST /api/usage-logs` (auth token)
- `GET /api/stats/materials` (auth token)
- `GET /api/stats/projects` (auth token)
- `GET /api/stats/monthly` (auth token)

## Auth

Utilise un header:

```http
Authorization: Bearer <API_TOKEN>
```

Un token utilisateur est retourné par `register` / `login` et peut être utilisé dans le même header.
`logout` révoque ce token.
`change-password` met à jour le mot de passe, révoque les sessions existantes et renvoie un nouveau token.

Rate limit auth:
- `register`: 5 tentatives / minute / IP
- `login`: 10 tentatives / minute / IP + 7 tentatives / minute / email

Audit logs:
- événements tracés: `register`, `login`, `logout`, `change_password`
- succès/échec, IP, email/user_id, message, metadata
- table: `public.app_audit_logs`

## Configuration

Variables à ajuster:

- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`
- `DB_SSLMODE`
- `CORS_ALLOWED_ORIGIN`

## Lancer en local

```bash
cd back_symfony
php -S 127.0.0.1:8000 -t public
```

Validation:

```bash
php bin/console lint:container
php bin/console debug:router
```

Initialiser les tables auth si besoin:

```bash
php bin/console app:auth:init
```
