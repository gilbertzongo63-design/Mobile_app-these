# 🔧 Plan d'Action Technique - Par Priorité

## 🎯 Objectif Soutenance (2 semaines max)

Déployer un système fonctionnel et sécurisé de reconnaissance de déchets avec :
- ✅ Authentification robuste
- ✅ Capture et analyse d'images
- ✅ Interface mobile fluide
- ✅ Dashboard admin basique
- ✅ Google OAuth optionnel

---

## ⚡ PRIORITÉ 1 : CRITIQUE (À faire aujourd'hui)

### 1.1 Google OAuth - 30 minutes
**État actuel :** Endpoint implémenté, Client ID manquant
**À faire :**
```bash
1. Aller sur https://console.cloud.google.com
2. Créer OAuth 2.0 Client ID (Web Application)
3. Copier le Client ID → .env
4. Redémarrer backend
5. Tester avec : python test_google_oauth_full.py
```

**Fichiers affectés :**
- `.env` : ajouter `GOOGLE_OAUTH_CLIENT_ID`
- `backend_api.py` : `/auth/google-login` (déjà prêt)
- `mobile_app/lib/services/auth_service.dart` : `googleLogin()` (déjà prêt)

**Temps estimé :** 30 min (dont 10 min pour créer le Client ID sur Google Cloud)

---

### 1.2 Vérification Email - Email non vérifié bloque login
**État actuel :** Protection activée, SMTP pas configuré
**Choix :**
- **Option A (Rapide)** : Bypass pour tests → modifier `backend_api.py` ligne ~1180
  ```python
  if not user.email_verified:
      # Comment cette ligne pour les tests :
      # raise HTTPException(status_code=403, detail="Email address is not verified")
  ```
  
- **Option B (Correct)** : Configurer SMTP
  ```env
  SMTP_SERVER=smtp.gmail.com
  SMTP_PORT=587
  SMTP_USERNAME=votre-email@gmail.com
  SMTP_PASSWORD=votre-mot-de-passe-app
  EMAIL_FROM_ADDRESS=noreply@yourapp.com
  ```

**Recommandation :** Option A pour tests rapides, Option B pour démo cliente

**Temps estimé :** 10 min (Option A) ou 30 min (Option B)

---

### 1.3 Tester le flux complet - Mobile + Backend
**Commandes :**
```bash
# Terminal 1 : Démarrer le backend
cd C:\Users\HP\Desktop\Soutenance-dev
python -m uvicorn backend_api:app --host 127.0.0.1 --port 8000

# Terminal 2 : Lancer l'app mobile
cd C:\Users\HP\Desktop\Soutenance-dev\mobile_app
flutter run

# Terminal 3 : Tests API
cd C:\Users\HP\Desktop\Soutenance-dev
python test_google_oauth_full.py
```

**Cas de test critiques :**
1. ✅ Enregistrement nouvel utilisateur
2. ✅ Connexion avec email/password
3. ✅ Connexion avec Google (une fois Client ID configuré)
4. ✅ Capture photo → soumission → résultat
5. ✅ Historique visible et filtrable

**Temps estimé :** 20 min pour tester chaque cas

---

## 🔒 PRIORITÉ 2 : SÉCURITÉ (Jour 2)

### 2.1 Rate Limiting - Protéger contre les abus
**À ajouter dans `backend_api.py` :**

```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

# Sur les endpoints sensibles
@app.post("/auth/login")
@limiter.limit("5/minute")  # 5 tentatives par minute
async def login(...):
    ...

@app.post("/predict")
@limiter.limit("10/hour")  # 10 analyses par heure
async def predict(...):
    ...
```

**Installation :** `pip install slowapi`

**Temps estimé :** 15 min

---

### 2.2 Headers de Sécurité HTTP
**À ajouter dans `backend_api.py` après `app = FastAPI(...)` :**

```python
@app.middleware("http")
async def add_security_headers(request, call_next):
    response = await call_next(request)
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Content-Security-Policy"] = "default-src 'self'"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    return response
```

**Temps estimé :** 10 min

---

### 2.3 Validation Images - Antivirus (Optionnel)
**État actuel :** Type MIME et taille validés ✅
**À faire :** Ajouter détection de malware simple
```python
# Dans backend_api.py, fonction _store_upload()
# Ajouter check EXIF, dimensions minimales

# Optionnel : intégrer ClamAV
# pip install pyclamd
```

**Temps estimé :** 30 min (si ClamAV)

---

## 📊 PRIORITÉ 3 : INTERFACE WEB ADMIN (Jour 3)

### 3.1 Web Admin - Interface React
**État actuel :** Dossier `web_admin` créé, probablement partiellement développé
**À faire :**
```bash
cd web_admin
npm install
npm run dev
```

**Fonctionnalités minimales requises :**
- [ ] Tableau de bord (nombre d'analyses, catégories)
- [ ] File "À vérifier" (validation manuelle)
- [ ] Gestion des comptes (créer/suspendre)
- [ ] Journaux d'audit (qui a fait quoi)
- [ ] Statistiques (graphiques par catégorie)

**Temps estimé :** 2-3 heures (selon l'état du code)

---

### 3.2 Connecter Web Admin au Backend
**À faire dans `web_admin` :**
1. Vérifier l'URL du backend dans `src/config/api.ts` ou équivalent
   ```typescript
   const API_URL = "http://127.0.0.1:8000";
   ```

2. Ajouter interceptor JWT :
   ```typescript
   // Récupérer token depuis localStorage
   // Ajouter à chaque requête: Authorization: Bearer {token}
   ```

3. Tester les endpoints principaux (GET /users, GET /predictions, etc.)

**Temps estimé :** 45 min

---

## 🧪 PRIORITÉ 4 : TESTS & DOCUMENTATION (Jour 4-5)

### 4.1 Tests Automatisés
**À créer :** `tests/test_backend.py`

```python
import pytest
from httpx import AsyncClient
from backend_api import app

@pytest.mark.asyncio
async def test_register():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.post("/auth/register", json={
            "email": "test@test.com",
            "full_name": "Test User",
            "password": "TestPass123!"
        })
        assert response.status_code == 200
        assert response.json()["user"]["email"] == "test@test.com"

@pytest.mark.asyncio
async def test_login():
    # Enregistrer d'abord
    # Puis tester la connexion
    pass

@pytest.mark.asyncio
async def test_predict():
    # Uploader une image
    # Vérifier la classification
    pass
```

**Lancer les tests :**
```bash
pip install pytest pytest-asyncio httpx
pytest tests/test_backend.py -v
```

**Temps estimé :** 1-2 heures

---

### 4.2 Documentation API
**État actuel :** Swagger automatique déjà là ✅
**À faire :**
1. Aller sur http://127.0.0.1:8000/docs (Swagger UI)
2. Documenter chaque endpoint avec descriptions
3. Ajouter des exemples de réponse
4. Générer OpenAPI JSON pour documentation externe

```python
# Dans backend_api.py
@app.post("/predict", 
    summary="Analyser une image",
    description="Soumet une image pour classification...",
    tags=["Analyse"]
)
async def predict(...):
    """
    - **image** : Fichier image (JPG, PNG)
    - **disable_ocr** : Ignorer OCR (booléen)
    
    Retourne:
    - **prediction_id** : ID unique
    - **predicted_class** : Catégorie détectée
    - **final_confidence** : Score 0-1
    """
```

**Temps estimé :** 30 min

---

### 4.3 Guide Utilisateur Mobile
**À créer :** Fichier `GUIDE_UTILISATEUR.md`

```markdown
# Guide d'Utilisation - EcoSort Mobile

## Installation
1. Télécharger sur Play Store / App Store
2. Créer un compte
3. Autoriser accès à la caméra

## Comment utiliser
1. Appui sur l'appareil photo
2. Prendre une photo OU importer depuis galerie
3. L'IA analyse automatiquement
4. Voir le résultat et la consigne de tri
5. Sauvegarder dans historique

## Dépannage
- La caméra demande une permission ? → Allez dans Paramètres > Autorisations
- L'image est floue ? → Reprenez la photo
- Le résultat semble faux ? → Cliquez "Signaler une erreur"
```

**Temps estimé :** 30 min

---

## 📅 CALENDRIER RECOMMANDÉ

| Jour | Tâche | Durée | Status |
|------|-------|-------|--------|
| **Jour 1** | Google OAuth + Tests critiques | 2h | 🔴 À faire |
| **Jour 1** | Email/SMTP (Option rapide) | 30 min | 🔴 À faire |
| **Jour 2** | Security headers + Rate limiting | 1h | 🟡 Commencer |
| **Jour 2** | Tester web admin (npm run dev) | 1h | 🟡 Commencer |
| **Jour 3** | Développer/compléter web admin | 3h | 🟡 En cours |
| **Jour 4** | Tests automatisés | 2h | 🟡 Commencer |
| **Jour 5** | Documentation + Démonstration | 2h | 🟡 Commencer |
| **Jour 6-7** | Tests utilisateurs + ajustements | 3h | 🔮 Planning |

---

## 🚀 Checklist Avant Soutenance

- [ ] Backend API démarre sans erreurs
- [ ] Google OAuth configuré et testé
- [ ] Enregistrement utilisateur fonctionne
- [ ] Connexion (email + Google) fonctionne
- [ ] Capture d'image fonctionne (pas d'écran rouge)
- [ ] Image soumise → résultat obtenu (< 5 sec)
- [ ] Historique consultable et filtrable
- [ ] Web admin affiche tableaux de bord
- [ ] Sécurité basique en place (headers, validation)
- [ ] Documentation complète
- [ ] Tests critiques passent
- [ ] Démo enregistrée (backup)

---

## 💡 Pro Tips

1. **Utiliser `.env` pour tous les secrets** (jamais en hard-code)
2. **Tester mobil en WiFi local** (IP PC au lieu de 127.0.0.1)
3. **Garder les logs pour débogage** (`tail -f backend.log`)
4. **Faire des commits réguliers** (git) avant chaque grosse modif
5. **Documenter au fur et à mesure** (pas à la fin)

---

## 📞 Contacts Support

- **Docs FastAPI :** https://fastapi.tiangolo.com
- **Flutter Docs :** https://flutter.dev/docs
- **React Docs :** https://react.dev
- **Google OAuth :** https://developers.google.com/identity/protocols/oauth2
- **OWASP Security :** https://owasp.org/Top10/
