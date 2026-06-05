# Mobile App

Base Flutter prepared for API integration with the waste sorting backend.

## Current scope

- Flutter app structure under `lib/`
- API configuration and HTTP client
- Auth, categories, prediction, and health services
- Token persistence with `shared_preferences`
- Simple home screen for backend connection checks

## Important

The Flutter CLI did not finish scaffolding automatically on this machine, so this folder currently contains the Dart/Flutter source structure only.

When Flutter responds correctly, generate native folders from inside this directory:

```powershell
cd mobile_app
flutter create .
flutter pub get
```

This will create `android/`, `ios/`, `web/`, etc. without replacing the existing `lib/` code.

## Backend base URL

Update the backend URL in `lib/config/api_config.dart` according to your device:

- Android emulator: `http://10.0.2.2:8000`
- iOS simulator / Windows local testing: `http://127.0.0.1:8000`
- Physical device: replace with your computer LAN IP
