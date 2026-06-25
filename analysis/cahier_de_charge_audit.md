# Audit du cahier de charge - Projet Soutenance

## Theme

Conception et implementation d'un systeme intelligent de reconnaissance des dechets recyclables fonde sur la vision par ordinateur et l'OCR pour optimiser le tri selectif.

## Synthese du cahier de charge

Le projet attendu est une plateforme complete composee de quatre blocs :

- Application mobile Flutter pour l'utilisateur final.
- Interface web React pour l'administration et la supervision.
- Backend Python expose via API REST securisee.
- Service IA combinant vision par ordinateur, OCR et moteur de decision.

Le systeme doit permettre a un utilisateur de soumettre une image, obtenir une classification avec score de confiance, consulter son historique, signaler une erreur, et recevoir une recommandation de tri. Les administrateurs et gestionnaires doivent pouvoir superviser les analyses, gerer les utilisateurs, gerer les categories, valider les cas incertains et consulter des statistiques.

## Exigences prioritaires Must

### Comptes et securite

- Inscription avec validation e-mail.
- Connexion securisee avec gestion des tentatives echouees.
- MFA pour les roles privilegies.
- Reinitialisation du mot de passe.
- Gestion du profil utilisateur.
- Deconnexion et revocation des sessions.
- Mots de passe haches robustement.
- JWT de courte duree avec refresh tokens revocables.
- RBAC applique cote serveur.
- Verification de propriete des ressources.
- Validation des entrees et protection contre injections, XSS/CSRF, abus et fichiers dangereux.

### Mobile utilisateur

- Capture via appareil photo.
- Import depuis galerie.
- Validation du type, taille et format.
- Soumission securisee au backend.
- Affichage du resultat avec categorie, score et recommandation.
- Historique automatique.
- Recherche/filtrage historique.
- Signalement d'une classification erronee.

### IA et OCR

- Pretraitement image via OpenCV.
- Classification par vision par ordinateur.
- OCR via Tesseract quand du texte est present.
- Fusion vision + OCR avec score de confiance.
- Statut "A verifier" quand le score est trop faible.
- Explication simple du resultat.

### Administration web

- Gestion des comptes utilisateurs.
- Gestion des roles et permissions.
- Gestion du referentiel categories/consignes.
- File de validation des cas "A verifier".
- Tableau de bord de supervision.
- Journaux d'activite et d'audit.

### Donnees

- Base relationnelle PostgreSQL.
- Stockage des images.
- Historique des analyses.
- Feedback utilisateur.
- Dataset enrichi par images annotees.
- Versionnement modele IA.

## Etat actuel observe dans le code

### Backend Python

Deja present :

- API FastAPI.
- Inscription et connexion basiques.
- JWT signe maison.
- Hachage mot de passe PBKDF2.
- Upload image.
- Prediction image avec vision + OCR.
- Fusion via `fusion_service.py`.
- Historique utilisateur par `/predictions` et `/history`.
- Feedback utilisateur.
- Categories seed.
- Statistiques basiques via `/stats`.
- Verification de propriete pour predictions utilisateur.

Ecarts principaux :

- Pas de roles utilisateur dans le modele actuel.
- Pas de RBAC serveur.
- Pas de validation e-mail.
- Pas de MFA.
- Pas de reset password.
- Pas de refresh token ni revocation de sessions.
- Pas de verrouillage anti-bruteforce.
- Pas de vraie gestion admin des utilisateurs.
- Pas de file de validation des cas "A verifier".
- Pas de journaux d'audit.
- Upload images expose via `/uploads` statique.
- Validation fichier limitee a l'extension, pas au MIME/taille/contenu.
- Pas de nettoyage EXIF.
- Pas de modele de version IA persiste.
- Pas d'exports CSV/PDF.

### Application mobile Flutter

Deja present :

- Structure Flutter complete.
- Ecrans d'authentification, accueil, scan, resultat, historique, parametres, notifications, confidentialite, aide, conseils.
- Services API pour auth, prediction, utilisateur, categories.
- Capture/import probablement couverts par l'ecran scan.
- Historique et modification/suppression de prediction connectes au backend.

Points a verifier/ameliorer :

- Qualite de l'image avant envoi.
- Compression avant transmission.
- Recherche et filtres avances dans l'historique.
- Signalement d'erreur complet et visible.
- Export historique.
- Deconnexion/revocation effective.
- UX d'explication du resultat alignee sur "Recyclable / Non recyclable / A verifier".
- Internationalisation reelle.

### Web admin React

Deja present :

- Interface visuelle riche avec dashboard, flux, utilisateurs, points de collecte, rapports.
- Navigation et composants d'administration.

Ecarts principaux :

- Donnees principalement statiques.
- Pas d'authentification admin.
- Pas de connexion API apparente.
- Pas de RBAC.
- Pas de gestion reelle des utilisateurs.
- Pas de validation des cas "A verifier".
- Pas de gestion categories/consignes.
- Pas de consultation audit logs.
- Probleme d'encodage visible dans les textes accentues.

## Priorites recommandees

### Phase 1 - Alignement minimal soutenance

Objectif : rendre le projet coherent, demonstrable et conforme aux exigences Must les plus visibles.

1. Ajouter roles et statuts utilisateur dans le backend.
2. Ajouter RBAC serveur pour les routes admin.
3. Ajouter endpoints admin : utilisateurs, stats, categories, predictions a verifier, feedback.
4. Ajouter statut de prediction clair : recyclable, non_recyclable, review.
5. Connecter le web admin aux donnees reelles de l'API.
6. Corriger l'encodage et les libelles web.
7. Renforcer la validation upload : extension, MIME, taille.
8. Ajouter journal d'audit minimal.

### Phase 2 - Qualite produit

1. Ameliorer historique mobile : recherche, filtres, signalement.
2. Ajouter recommandations de tri plus explicites.
3. Ajouter gestion categories/consignes depuis l'admin.
4. Ajouter file de validation des cas "A verifier".
5. Ajouter statistiques plus completes.

### Phase 3 - Securite avancee et livrables

1. Validation e-mail.
2. Reset password.
3. Refresh tokens et revocation.
4. Anti-bruteforce.
5. MFA pour administrateurs/gestionnaires.
6. Documentation API, securite, tests et recette.

## Decision de travail proposee

Commencer par la Phase 1, car elle donne rapidement vie au projet pour une soutenance :

- backend d'abord, car il conditionne mobile et web ;
- web admin ensuite, pour afficher une vraie plateforme de gestion ;
- mobile enfin, pour harmoniser les ecrans avec les nouveaux statuts et retours.

## Avancement Phase 1

### Backend - realise

- Ajout des champs utilisateur : role, statut, verification e-mail, compteur d'echecs de connexion, verrouillage temporaire.
- Ajout du statut de validation sur les predictions.
- Ajout d'une table `audit_logs`.
- Ajout d'un bootstrap local : si aucune personne n'est administrateur dans une base existante, le plus ancien utilisateur devient administrateur.
- Ajout du RBAC serveur pour les routes privilegiees.
- Ajout des routes admin :
  - `GET /admin/stats`
  - `GET /admin/users`
  - `PATCH /admin/users/{user_id}`
  - `GET /admin/predictions`
  - `PATCH /admin/predictions/{prediction_id}/validate`
  - `GET /admin/feedback`
  - `GET /admin/audit-logs`
  - `POST /admin/categories`
  - `PATCH /admin/categories/{category_id}`
- Renforcement minimal de la connexion : verrouillage temporaire apres plusieurs echecs.
- Renforcement minimal upload image : verification extension, type MIME, taille maximale et validite image via Pillow.
- Verification effectuee : compilation Python, import backend, smoke tests `/health`, `/categories`, `/admin/stats`, `/admin/users`.

### Backend - reste a faire plus tard

- Validation e-mail reelle par code/lien.
- Reset password.
- Refresh tokens et revocation de sessions.
- MFA pour administrateurs/gestionnaires.
- Nettoyage EXIF.
- URLs signees pour images au lieu du montage statique `/uploads`.
- Exports CSV/PDF.

### Web admin - realise

- Remplacement des donnees statiques par une interface connectee a l'API.
- Ajout d'un ecran de connexion admin via `/auth/login`.
- Stockage local du jeton JWT pour la session web.
- Chargement des donnees reelles :
  - statistiques via `/admin/stats`
  - utilisateurs via `/admin/users`
  - predictions a verifier via `/admin/predictions?review_status=review`
  - categories via `/categories`
  - feedback via `/admin/feedback`
  - audit via `/admin/audit-logs`
- Gestion des roles et statuts utilisateurs depuis l'interface.
- Validation manuelle des cas "A verifier" depuis l'interface.
- Ajout/modification des categories et consignes de tri.
- Correction globale des libelles mal encodes par une nouvelle UI propre.
- Verification effectuee : `npm run build`.

### Web admin - ameliorations de presentation realisees

- Ajout d'une table des dernieres analyses traitees dans le dashboard.
- Ajout des miniatures d'images pour les analyses et la file de validation.
- Ajout d'une recherche dans la file de validation.
- Ajout d'une recherche et d'un filtre par role dans la gestion des utilisateurs.
- Ajout de compteurs rapides : utilisateurs actifs, administrateurs, feedbacks, note moyenne.
- Ajout de compteurs d'analyses par categorie dans le referentiel.
- Amelioration de l'affichage des raisons de decision IA/OCR.
- Amelioration de la lecture des journaux d'audit avec details formates.
- Passage des images via le proxy `/api` pour eviter les blocages navigateur.
- Verification effectuee : `npm run build`, `GET /`, `GET /api/health`.

### Mobile - realise

- Centralisation des libelles metier dans `PredictionResult` :
  - classe lisible ;
  - statut de tri ;
  - raison IA/OCR ;
  - consigne de tri ;
  - recommandation de bac ;
  - confiance formatee.
- Alignement de l'ecran resultat sur ces libelles centralises.
- Nettoyage des textes mal encodes visibles dans l'ecran resultat.
- Nettoyage des textes mal encodes visibles dans l'historique.
- Ajout des widgets de recherche/filtre manquants dans l'historique.
- Enrichissement du resume d'historique avec les cas non recyclables et a verifier.
- Verification effectuee : `dart format`, `flutter analyze`.

### Documentation de soutenance - realise

- Ajout de `analysis/guide_demo_soutenance.md`.
- Le guide contient :
  - les commandes de lancement backend, web admin et mobile ;
  - les identifiants admin de demonstration ;
  - le scenario de demonstration mobile ;
  - le scenario de demonstration web admin ;
  - la correspondance avec le cahier de charge ;
  - les fonctionnalites a presenter comme perspectives ;
  - la checklist de verification avant presentation.
