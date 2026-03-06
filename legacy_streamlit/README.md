# Kaki3D Legacy Streamlit

Version historique de Kaki3D Stock Manager basee sur Streamlit + Python + PostgreSQL (Supabase).

Cette application est conservee pour reference et transition. La cible principale du repo est maintenant:

- `back_symfony/` (API)
- `front_flutter/` (client mobile NFC)

## Fonctionnalites

- Inventaire des bobines avec poids restant
- Ajout de bobines et parametres slicer
- Modification des bobines
- Enregistrement de consommation
- Statistiques (matiere, projet, mois)
- Workflow NFC (scan externe + retour dans l'app)

## Prerequis

- Python 3.11+
- PostgreSQL (Supabase recommande)

## Installation

Depuis la racine du projet:

```bash
cd legacy_streamlit
python -m venv .venv
```

Activation:

```bash
# Windows
.venv\Scripts\activate

# macOS/Linux
source .venv/bin/activate
```

Installation des dependances:

```bash
pip install -r requirements.txt
```

## Configuration

### 1) Secrets Streamlit

Creer le fichier `../.streamlit/secrets.toml`:

```toml
[database]
host = "db.XXXX.supabase.co"
dbname = "postgres"
user = "postgres"
password = "VOTRE_MOT_DE_PASSE"
port = "5432"
```

### 2) Pseudo affiche dans l'app

Modifier `config_custom.py`:

```python
pseudo = "Kaki3D"
```

### 3) Schema SQL

Executer `script-creation-table-inventaire.sql` sur votre base PostgreSQL/Supabase.

## Lancer l'application

Depuis la racine du projet:

```bash
streamlit run legacy_streamlit/app.py
```

## NFC (legacy)

- Le scan NFC est fait via une page web externe (`kakicrypto.github.io/.../nfc.html`)
- Compatibilite pratique: Android + Chrome
- En cas d'echec, l'UID peut etre saisi manuellement dans l'interface

## Structure

```
legacy_streamlit/
|- app.py
|- action.py
|- database.py
|- config_custom.py
|- requirements.txt
|- script-creation-table-inventaire.sql
|- nfc.html
|- static/
`- asset/
```

## Notes

- Cette version est legacy: pas d'API REST decouplee, logique metier dans l'app.
- Pour les nouveaux developpements, utiliser `back_symfony` + `front_flutter`.
