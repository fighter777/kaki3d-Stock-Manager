# Kaki3D Stock Manager

Projet decoupe en 2 applications:

- `back_symfony`: API REST (auth, inventaire, consommation, stats)
- `front_flutter`: client mobile NFC qui consomme l'API

Le code historique Streamlit/Python est deplace dans `legacy_streamlit/`.

## Architecture

```
kaki3d-Stock-Manager/
|- back_symfony/     # Backend API Symfony
|- front_flutter/    # Front mobile Flutter (NFC)
|- mobile_app/       # Variante Flutter (historique)
`- legacy_streamlit/ # Ancienne app Streamlit + scripts SQL/assets
```

## Prerequis

- PHP 8.0+
- Composer
- Flutter 3.38+
- PostgreSQL (ou Supabase PostgreSQL)

## 1) Lancer le backend Symfony

Depuis `back_symfony`, configurer les variables d'environnement suivantes:

- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`
- `DB_SSLMODE` (ex: `require` pour Supabase, `prefer` en local)
- `CORS_ALLOWED_ORIGIN` (ex: `*` en dev, ou URL precise du front)

Installation et lancement:

```bash
cd back_symfony
composer install
php -S 127.0.0.1:8000 -t public
```

Verification rapide:

```bash
curl http://127.0.0.1:8000/api/health
```

## 2) Lancer le front Flutter

Depuis `front_flutter`:

```bash
cd front_flutter
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Pour emulateur Android, utiliser en general:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Endpoints principaux

- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/logout`
- `POST /api/auth/change-password`
- `GET /api/spools`
- `POST /api/spools`
- `PUT /api/spools/{id}`
- `DELETE /api/spools/{id}`
- `GET /api/spools/nfc/{uid}`
- `POST /api/usage-logs`
- `GET /api/stats/materials`
- `GET /api/stats/projects`
- `GET /api/stats/monthly`

## Legacy Streamlit

L'application Streamlit d'origine reste disponible pour reference/migration:

```bash
streamlit run legacy_streamlit/app.py
```

Elle n'est plus la cible principale du projet.
