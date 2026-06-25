# Guide: Configuration de Google OAuth

## ✅ Prérequis
- Un compte Google
- Accès à Google Cloud Console

## 📋 Étapes de configuration

### 1. Créer un projet Google Cloud

1. Allez à : https://console.cloud.google.com
2. Créez un nouveau projet (ou utilisez un projet existant)
3. Sélectionnez votre projet

### 2. Activer l'API Google Sign-In

1. Allez à **APIs & Services** > **Library**
2. Cherchez **Google+ API** (ou "Google Identity")
3. Cliquez sur **Enable**

### 3. Créer les identifiants OAuth 2.0

1. Allez à **APIs & Services** > **Credentials**
2. Cliquez sur **+ Create Credentials** > **OAuth 2.0 Client ID**
3. Choisissez **Web Application**
4. Remplissez les informations :
   - **Name** : EcoSort Mobile/Web
   - **Authorized redirect URIs** :
     ```
     http://localhost:3000
     http://127.0.0.1:3000
     http://localhost:8000
     http://127.0.0.1:8000
     ```
5. Cliquez sur **Create**

### 4. Copier le Client ID

1. Une fenêtre s'affichera avec vos identifiants
2. Copiez le **Client ID** (format : `xxxxxx.apps.googleusercontent.com`)

### 5. Ajouter le Client ID au fichier `.env`

Ouvrez ou créez le fichier `.env` à la racine du projet :

```
GOOGLE_OAUTH_CLIENT_ID=votre-client-id-ici.apps.googleusercontent.com
```

Exemple complet :
```env
APP_SECRET=dev-secret-change-me
GOOGLE_OAUTH_CLIENT_ID=123456789-abcdefg.apps.googleusercontent.com
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=votre-email@gmail.com
SMTP_PASSWORD=votre-mot-de-passe-app
EMAIL_FROM_ADDRESS=noreply@ecosort.com
```

### 6. Redémarrer le backend

```powershell
cd C:\Users\HP\Desktop\Soutenance-dev
python -m uvicorn backend_api:app --host 127.0.0.1 --port 8000
```

### 7. Tester l'authentification Google

**Sur la plateforme web (si elle existe) :**
```bash
npm run dev
```
Cliquez sur "Sign in with Google"

**Sur l'application mobile (Flutter) :**
```bash
flutter run
```
Allez à l'écran Auth et cliquez sur "Sign in with Google"

## 🐛 Dépannage

### Erreur: "Google OAuth client ID is not configured"
- ✅ Solution : Vous avez suivi les étapes 1-5 ? Redémarrez le backend.

### Erreur: "Invalid Google ID token"
- ✅ Assurez-vous que le Client ID dans `.env` correspond au Client ID Google
- ✅ Vérifiez que le token Google n'est pas expiré

### Erreur: "Google account email is not verified"
- ✅ Utilisez un compte Google avec un email vérifié (c'est automatique pour les comptes Gmail)

### CORS ou erreur de réseau
- ✅ Vérifiez que le backend écoute sur `127.0.0.1:8000` ou `0.0.0.0:8000`
- ✅ Sur mobile, utilisez l'adresse IP locale du PC (`192.168.x.x:8000`)

## 📱 Configuration mobile (Flutter)

Pour tester sur Android/iOS, vous devez aussi :

1. Dans `mobile_app/pubspec.yaml` :
   ```yaml
   google_sign_in: ^6.0.0
   ```

2. Sur Android (`android/app/build.gradle`) :
   ```gradle
   // Assurez-vous que minSdkVersion >= 19
   ```

3. Récupérez le **Authorized SHA-1 certificate fingerprint** :
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore
   ```
   Ajoutez-le à Google Cloud Console > Credentials > Android (si vous l'avez configuré)

## 🔒 Sécurité en production

Avant de déployer en production :
- ✅ Utilisez des variables d'environnement (ne commitez jamais le `.env`)
- ✅ Récupérez un Client ID **spécifique à la production**
- ✅ Configurez les URIs de redirection correctes
- ✅ Activez le HTTPS obligatoire
- ✅ Changez `APP_SECRET` par une clé forte

## 🧪 Test rapide de l'endpoint

```bash
python test_google_oauth_full.py
```

Cela teste :
- Santé de l'API
- Enregistrement utilisateur
- Connexion utilisateur
- Configuration Google OAuth
- Endpoint `/auth/google-login`
