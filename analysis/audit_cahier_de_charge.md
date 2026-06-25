# Audit d'alignement avec le cahier de charge

Projet : Reconnaissance des dechets recyclables par vision par ordinateur et OCR.

Document source : `CAHIER_DE_CHARGE_MEMOIRE-GILBERT_v2.docx`

## 1. Synthese du cahier de charge

Le projet attendu est une solution de gestion en ligne composee de trois blocs :

- application mobile Flutter pour l'utilisateur final ;
- plateforme web React pour l'administration, la supervision et la validation ;
- backend Python/FastAPI avec API securisee, base de donnees, stockage d'images, vision par ordinateur, OCR et moteur de decision.

Le systeme doit permettre de soumettre une image, reconnaitre un dechet ou objet recyclable, combiner vision + OCR, afficher un resultat avec score de confiance, classer le resultat en `Recyclable`, `Non recyclable` ou `A verifier`, historiser chaque analyse, permettre le feedback utilisateur, et fournir une interface web d'administration pour les utilisateurs, roles, categories, statistiques, validations et journaux.

Les exigences les plus importantes sont les exigences `Must` :

- authentification, profil, sessions ;
- capture/import d'image, validation fichier ;
- pipeline image OpenCV + vision + OCR Tesseract + fusion ;
- resultat clair, historique, signalement d'erreur ;
- administration : comptes, roles, categories, validations, dashboard, audit ;
- securite : mots de passe haches, JWT, RBAC, validation entree, CORS, logs, protection donnees ;
- stockage des images annotees et retours pour enrichir le dataset.

## 2. Etat actuel observe

### Backend

Le backend possede deja un noyau fonctionnel :

- FastAPI avec endpoints `/auth/register`, `/auth/login`, `/users/me`, `/predict`, `/analyze`, `/predictions`, `/history`, `/stats`, `/categories`, `/feedback`.
- Vision par ordinateur via `vision_service.py`.
- OCR via `ocr_service.py`.
- Fusion vision + OCR via `fusion_service.py`.
- Historique en base via `Prediction`.
- Feedback utilisateur via `Feedback`.
- Categories initialisees au demarrage.
- Stockage local des images dans `backend_data/uploads`.
- Authentification JWT et hachage de mot de passe.

Principales limites backend :

- pas de validation email reelle ;
- pas de MFA ;
- pas de refresh tokens ni revocation de sessions ;
- pas de roles/RBAC dans le modele `User` ;
- pas d'administration serveur des utilisateurs/categories/validations ;
- pas de file de traitement asynchrone ;
- pas de journal d'audit ;
- pas de versionnement modele en base ;
- validation fichier limitee a l'extension, pas au MIME/taille/contenu ;
- images exposees par `/uploads` en statique, sans URL signee ;
- `/stats` est public ;
- pas de rate limiting, headers de securite, reset password, suppression compte, exports.

### Mobile Flutter

Le mobile possede deja :

- inscription/connexion ;
- capture camera et import galerie ;
- compression via `image_picker` (`imageQuality`, dimensions max) ;
- analyse image via API ;
- affichage du resultat avec classe, score, details vision/OCR/fusion ;
- historique utilisateur ;
- correction/suppression d'une prediction ;
- profil, photo de profil, deconnexion ;
- pages de preferences : langue, notifications, confidentialite, aide, conseils.

Principales limites mobile :

- plusieurs textes sont mal encodes (`DÃ©connexion`, `MÃ©tal`, etc.) ;
- pas de validation qualite image avant envoi ;
- pas de recherche/filtrage de l'historique ;
- signalement d'erreur existe plutot comme correction directe de prediction, pas comme workflow de feedback clair ;
- pas d'export CSV/PDF ;
- langue/notifications semblent surtout locales ou statiques ;
- deconnexion supprime seulement le token local, sans revocation serveur ;
- pas de suppression de compte ;
- pas de mode hors ligne.

### Web admin React

Le web admin existe mais semble majoritairement statique :

- pages dashboard, suivi des flux, utilisateurs, points de collecte, rapports ;
- donnees codees en dur dans `App.jsx` ;
- pas d'appel API observe ;
- pas d'authentification admin ;
- pas de RBAC ;
- pas de gestion reelle des utilisateurs/categories/validations/audit ;
- plusieurs textes mal encodes ;
- certaines pages ne correspondent pas directement au cahier de charge, ex. points de collecte est plutot une perspective d'evolution.

## 3. Matrice rapide des exigences fonctionnelles

| Ref | Exigence | Etat |
| --- | --- | --- |
| EF-01 | Inscription avec validation email | Partiel : inscription oui, validation email non |
| EF-02 | Connexion securisee + tentatives echouees | Partiel : login oui, anti-bruteforce non |
| EF-03 | MFA privilegies | Manquant |
| EF-04 | Reset password | Manquant |
| EF-05 | OAuth Google | Manquant, optionnel |
| EF-06 | Profil/preferences/langue/suppression | Partiel : profil/preferences oui, suppression non |
| EF-07 | Deconnexion + revocation jetons | Partiel : logout local, revocation non |
| EF-08 | Capture camera | Present |
| EF-09 | Import image | Present |
| EF-10 | Controle qualite image | Manquant/partiel |
| EF-11 | Validation type/taille/format | Partiel |
| EF-12 | Compression image | Partiel mobile |
| EF-13 | Pretraitement OpenCV | Present cote OCR, a confirmer vision |
| EF-14 | Classification vision | Present |
| EF-15 | OCR Tesseract | Present |
| EF-16 | Fusion vision + OCR | Present |
| EF-17 | Statut A verifier seuil parametrable | Partiel |
| EF-18 | Explication/resultat et consigne | Present cote mobile, categories backend |
| EF-19 | Resultat clair + score + recommandation | Present |
| EF-20 | Historique automatique | Present pour utilisateur authentifie |
| EF-21 | Recherche/filtrage historique | Manquant |
| EF-22 | Signalement erreur | Partiel : feedback backend, UI mobile a renforcer |
| EF-23 | Export historique | Manquant, optionnel |
| EF-24 | Gestion comptes admin | Manquant reel |
| EF-25 | Roles/permissions RBAC | Manquant |
| EF-26 | Gestion categories/consignes | Partiel : lecture categories, pas CRUD admin |
| EF-27 | File validation A verifier | Manquant |
| EF-28 | Dashboard supervision | Partiel : stats backend simples, web statique |
| EF-29 | Journaux audit | Manquant |
| EF-30 | Statistiques agregees | Partiel |
| EF-31 | Indicateurs modele | Partiel/manquant |
| EF-32 | Export rapports | Manquant, optionnel |
| EF-33 | Stockage images annotees/retours | Partiel : images + feedback, annotation incomplete |
| EF-34 | Interface annotation/validation | Manquant |
| EF-35 | Versionnement modeles | Manquant/partiel via `model_profile.py` |
| EF-36 | Suivi perf versions | Manquant, optionnel |
| EF-37 | Notifications email/push | Manquant/partiel local |
| EF-38 | Internationalisation | Partiel/stub |
| EF-39 | Mode hors-ligne | Manquant, optionnel |
| EF-40 | API publique documentee | Partiel : Swagger FastAPI, pas versionnement public |

## 4. Priorites recommandees

### Phase 1 - Rendre le projet coherent pour la soutenance

1. Corriger les textes/encodages mobile et web.
2. Connecter le web admin aux endpoints reels au lieu des donnees statiques.
3. Ajouter les champs de roles/statuts utilisateur et proteger les endpoints admin.
4. Ajouter un vrai statut d'analyse (`accepted`, `review`, `rejected`) et une file `A verifier`.
5. Ajouter CRUD categories/consignes cote backend + web.
6. Renforcer l'historique mobile avec recherche/filtrage et signalement clair.

### Phase 2 - Securite et exigences Must

1. Politique mot de passe plus stricte.
2. Gestion tentatives echouees/verrouillage temporaire.
3. Validation MIME/taille image.
4. Endpoints admin securises par role.
5. Journal d'audit pour actions sensibles.
6. Deconnexion serveur/revocation de token ou liste de sessions.

### Phase 3 - Livrables de qualite

1. Documentation API et architecture.
2. Plan de tests et tests automatises essentiels.
3. Rapport de correspondance cahier de charge.
4. Donnees seed/demo pour presenter l'application.

## 5. Decision de travail proposee

La prochaine etape ideale est de traiter d'abord la coherence visible :

- correction des textes mal encodes ;
- alignement des libelles avec le cahier de charge (`Recyclable`, `Non recyclable`, `A verifier`) ;
- puis raccordement du web admin au backend.

Cette approche donne vite une application presentable pour la soutenance, tout en posant ensuite les bases propres pour RBAC, validations et audit.
