# Tap & Dodge

Casual 2D arcade game built with **Flutter** and **Flame**.

Dodge hazards, collect coins, clear a **50-level campaign**, earn daily rewards, and unlock ship skins. **Internet is required** because the game uses **Google AdMob** (rewarded / interstitial / app-open).

**Accounts:** Continue with **Google** (Firestore cloud save/restore) or **Guest** (local only; progress wiped each time Guest is chosen). Firebase setup: [`docs/FIREBASE_SETUP.md`](docs/FIREBASE_SETUP.md).

> AdMob is still on **Google test IDs**. Switch to production IDs before Play publish — see [`docs/PLAY_STORE.md`](docs/PLAY_STORE.md).

## Run on Android

```bash
flutter devices
flutter pub get
flutter run
```

## Useful commands

```bash
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

## Android production identity

- **applicationId:** `com.ujjwal.tapandodge`
- Signing: copy `android/key.properties.example` → `android/key.properties` after creating a keystore.
- Privacy: Home → **Privacy** (set `LegalConfig.privacyPolicyUrl` before store upload).

## Project layout

- `lib/main.dart` — entry, portrait lock, theme
- `lib/screens/` — home, campaign, hangar, privacy, game overlays
- `lib/game/` — Flame world, campaign, components
- `lib/services/` — score, audio, ads, consent, connectivity
- `assets/audio/` — short WAV effects
