# Guide de demonstration - Soutenance EcoSort

## Objectif de la demonstration

Presenter une plateforme complete de reconnaissance des dechets recyclables basee sur :

- une application mobile Flutter pour l'utilisateur final ;
- une API backend FastAPI ;
- un module IA combinant vision par ordinateur et OCR ;
- une interface web React pour l'administration et la supervision.

## Comptes de demonstration

Compte administrateur web :

- Email : `admin@ecosort.local`
- Mot de passe : `Admin123!`

Note : ce compte est reserve a la demonstration locale. En production, le mot de passe doit etre change et la MFA doit etre activee pour les roles privilegies.

## Lancement du backend

Depuis la racine du projet :

```powershell
python -m uvicorn backend_api:app --host 127.0.0.1 --port 8000
```

Pour un telephone physique sur le meme Wi-Fi, utiliser plutot :

```powershell
python -m uvicorn backend_api:app --host 0.0.0.0 --port 8000
```

Verification :

```powershell
Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/health
```

Documentation API FastAPI :

```text
http://127.0.0.1:8000/docs
```

## Lancement du web admin

Depuis `web_admin` :

```powershell
npm run dev -- --host 0.0.0.0 --port 5173
```

Interface :

```text
http://127.0.0.1:5173
```

Le web admin utilise le proxy Vite `/api`, ce qui evite les problemes CORS pendant la demonstration.

## Lancement de l'application mobile

Depuis `mobile_app` :

```powershell
flutter run
```

Selon la cible :

- Android emulator : l'API par defaut est `http://10.0.2.2:8000`.
- Web/Desktop : l'API par defaut est `http://127.0.0.1:8000`.
- Telephone physique : lancer avec l'adresse IP du PC.

Exemple telephone physique :

```powershell
flutter run --dart-define=API_BASE_URL=http://ADRESSE_IP_DU_PC:8000
```

## Scenario de demonstration conseille

### 1. Introduction

Presenter la problematique :

- les citoyens hesitent souvent sur la bonne consigne de tri ;
- certains emballages combinent plusieurs matieres ;
- les inscriptions, logos et textes peuvent aider a fiabiliser la decision ;
- la plateforme centralise les analyses pour ameliorer le modele.

### 2. Demonstration mobile

1. Ouvrir l'application mobile.
2. Se connecter ou creer un compte utilisateur.
3. Lancer une analyse avec une image de dechet.
4. Montrer le resultat :
   - classe detectee ;
   - statut `Recyclable`, `Non recyclable` ou `A verifier` ;
   - score de confiance ;
   - explication vision/OCR ;
   - consigne de tri ;
   - bouton de signalement d'erreur.
5. Ouvrir l'historique :
   - recherche ;
   - filtres par statut ;
   - consultation d'une ancienne analyse ;
   - modification/suppression locale de l'historique.

### 3. Demonstration web admin

1. Ouvrir `http://127.0.0.1:5173`.
2. Se connecter avec `admin@ecosort.local`.
3. Montrer le dashboard :
   - volume d'analyses ;
   - nombre de cas a verifier ;
   - utilisateurs actifs ;
   - confiance moyenne ;
   - repartition par classe.
4. Ouvrir `A verifier` :
   - afficher les miniatures ;
   - changer la classe proposee ;
   - valider manuellement un cas.
5. Ouvrir `Utilisateurs` :
   - rechercher un compte ;
   - filtrer par role ;
   - modifier role/statut ;
   - verifier l'e-mail.
6. Ouvrir `Categories` :
   - montrer les consignes de tri ;
   - modifier une categorie ;
   - ajouter une categorie.
7. Ouvrir `Feedback` :
   - montrer les signalements utilisateurs.
8. Ouvrir `Audit` :
   - montrer la tracabilite des actions sensibles.

## Correspondance avec le cahier de charge

Fonctionnalites deja demonstrables :

- authentification utilisateur ;
- historique des analyses ;
- soumission d'image ;
- classification vision + OCR ;
- score de confiance ;
- statut `A verifier` ;
- signalement d'erreur ;
- tableau de bord admin ;
- gestion utilisateurs ;
- gestion categories ;
- validation manuelle ;
- feedback ;
- audit minimal ;
- securisation par JWT ;
- RBAC serveur pour les routes admin ;
- validation minimale des fichiers images.

Fonctionnalites a presenter comme perspectives ou securite avancee :

- validation e-mail reelle ;
- reinitialisation de mot de passe ;
- MFA pour administrateurs ;
- refresh tokens revocables ;
- stockage images via URL signees ;
- nettoyage EXIF ;
- exports CSV/PDF ;
- versionnement avance du modele IA ;
- file de traitement asynchrone persistante.

## Verification avant presentation

Executer :

```powershell
python -m py_compile backend_api.py db_models.py auth_utils.py database.py fusion_service.py
```

```powershell
cd web_admin
npm run build
```

```powershell
cd mobile_app
flutter analyze
```

Resultat attendu :

- backend : aucune erreur ;
- web admin : build Vite termine avec succes ;
- mobile : `No issues found!`.
