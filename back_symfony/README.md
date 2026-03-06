# Back Symfony (API)

API REST pour `kaki3d-Stock-Manager` (lookup NFC + inventaire + consommation).

## Endpoints

- `GET /api/health` (public)
- `POST /api/auth/register` (public)
- `POST /api/auth/login` (public)
- `GET /api/spools` (auth token)
- `GET /api/spools/nfc/{uid}` (auth token)
- `POST /api/usage-logs` (auth token)

## Auth

Utilise un header:

```http
Authorization: Bearer <API_TOKEN>
```

`API_TOKEN` est configuré dans `.env` / `.env.local`.

Un token utilisateur est retourné par `register` / `login` et peut être utilisé dans le même header.

## Configuration

Variables à ajuster:

- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`
- `DB_SSLMODE`
- `API_TOKEN`
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
