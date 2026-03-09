# Front Flutter (Mobile NFC)

App mobile Flutter pour scanner un tag NFC de bobine et enregistrer la consommation via API Symfony.

## Fonctions

- Inscription / connexion (`register` / `login`)
- Logout (`/api/auth/logout`)
- Changement mot de passe (`/api/auth/change-password`)
- Scan NFC (Android / iOS)
- Lecture UID du tag
- Appel API: `GET /api/spools/nfc/{uid}`
- Tag inconnu: proposition de creation bobine avec `nfc_id` pre-rempli
- Fallback sans NFC: recherche manuelle par UID
- Enregistrement consommation: `POST /api/usage-logs`
- Gestion bobines: create / update / delete / clone
- Actions guidees inventaire: utiliser / modifier / dupliquer
- Stats: matieres / projets / mensuel (graphiques)

## Configuration API

Passer les valeurs au run/build via `--dart-define`:

- `API_BASE_URL`

Exemple Android (emulateur):

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Exemple appareil reel:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://<IP_PC_LAN>:8000
```

## Permissions

- Android: `android.permission.NFC` + feature NFC dans `AndroidManifest.xml`
- iOS: `NFCReaderUsageDescription` dans `Info.plist` (+ capability NFC a activer dans Xcode)

## Validation locale

```bash
flutter analyze
flutter test
```
