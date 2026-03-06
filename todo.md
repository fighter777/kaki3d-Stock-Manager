# TODO

- [ ] Ajouter la fonctionnalite "Dupliquer une bobine existante".
  - Objectif: faciliter le re-stock des memes references de bobines.
  - Regles metier:
    - Copier les parametres techniques de la bobine source.
    - Reinitialiser l'etat d'usure (bobine "a neuf").
    - Ne pas copier les `usage_logs`.
    - Associer un nouveau `nfc_id` (ou le laisser vide jusqu'a scan/ecriture).
  - API proposee:
    - `POST /api/spools/{id}/clone`
  - Front propose:
    - Bouton "Dupliquer" depuis la vue inventaire/detail bobine.

- [ ] Au scan NFC, detecter si le tag est deja connu.
  - Flux UX:
    - Si tag connu: ouvrir directement la bobine existante.
    - Si tag inconnu: afficher un prompt "Tag inconnu, creer une nouvelle bobine ?".
    - Si confirmation: ouvrir le formulaire de creation avec `nfc_id` pre-rempli.
  - API:
    - Reutiliser `GET /api/spools/nfc/{uid}` (200 si connu, 404 si inconnu).
  - Front:
    - Ajouter le prompt de creation sur statut 404.
