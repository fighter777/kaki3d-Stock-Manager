# Back Symfony (API)

API REST pour `kaki3d-Stock-Manager` (lookup NFC + inventaire + consommation).

## Endpoints

- `GET /api/health` (public)
- `GET /api/spools` (auth token)
- `GET /api/spools/nfc/{uid}` (auth token)
- `POST /api/usage-logs` (auth token)

## Auth

Utilise un header:

```http
Authorization: Bearer <API_TOKEN>
```

`API_TOKEN` est configuré dans `.env` / `.env.local`.

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

