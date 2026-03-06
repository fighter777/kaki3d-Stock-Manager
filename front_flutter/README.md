# Front Flutter (Mobile NFC)

App mobile Flutter pour scanner un tag NFC de bobine et enregistrer la consommation via API Symfony.

## Fonctions MVP

- Scan NFC (Android / iOS)
- Lecture UID du tag
- Appel API: `GET /api/spools/nfc/{uid}`
- Affichage bobine trouvée
- Enregistrement consommation: `POST /api/usage-logs`

## Configuration API

Passer les valeurs au run/build via `--dart-define`:

- `API_BASE_URL`
- `API_TOKEN`

Exemple Android (émulateur):

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=API_TOKEN=change_me_secure_token
```

Exemple appareil réel:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://<IP_PC_LAN>:8000 \
  --dart-define=API_TOKEN=change_me_secure_token
```

## Permissions

- Android: `android.permission.NFC` + feature NFC dans `AndroidManifest.xml`
- iOS: `NFCReaderUsageDescription` dans `Info.plist` (+ capability NFC à activer dans Xcode)

## Validation locale

```bash
flutter analyze
flutter test
```

