# Google Play release checklist — Tap & Dodge (Android)

## App identity

- **App name:** Tap & Dodge
- **applicationId:** `com.ujjwal.tapandodge`
- **Version:** `pubspec.yaml` (`1.0.0+1` → versionName `1.0.0`, versionCode `1`)
- Change the applicationId only **before** the first Play upload.

## Product facts (declare these accurately)

- **Internet required** to play (ads + connectivity gate).
- **Ads:** rewarded, interstitial, app-open via Google AdMob.
- **Accounts:** Google Sign-In (cloud save) or Guest (local; survives restarts; optional “Save My Progress”).
- **Progress:** Firestore `users/{uid}` for Google; SharedPreferences for Guest.
- Deploy [`../firestore.rules`](../firestore.rules) before production. See [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md).

## AdMob (do later — still on test IDs)

1. Create an Android app in [AdMob](https://apps.admob.com).
2. Create units: Rewarded, Interstitial, App Open.
3. Replace App ID in `android/app/src/main/AndroidManifest.xml`.
4. Paste unit IDs in `lib/services/ad_config.dart`.
5. Set `AdConfig.useTestAds = false`.
6. Host a public privacy policy URL and set `LegalConfig.privacyPolicyUrl`.
7. Fill Play **Data safety** for ads / Advertising ID / network.

Until then, keep `useTestAds = true` and Google sample App ID.

## Permissions

- `INTERNET`
- `ACCESS_NETWORK_STATE`
- Advertising ID permission comes from the AdMob SDK merge.

## Signing (required for store)

1. Create upload keystore (once):

```bash
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Copy `android/key.properties.example` → `android/key.properties` and fill passwords.
3. Never commit `key.properties` or `*.jks`.
4. Build:

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

If `key.properties` is missing, release builds still sign with the **debug** key (dev only).

## Store listing

- Phone screenshots (2–8, portrait).
- Feature graphic 1024×500.
- Short description: dodge hazards, collect coins, 50-level campaign; contains ads.
- Full description: mention internet + ads + local progress.
- Content rating questionnaire (ads may affect answers).
- Privacy policy URL (hosted) — in-app policy is already included under Home → Privacy.
- Data safety: ads / Ad ID / app activity as applicable.

## Pre-submit QA (release build)

1. Cold start → consent (if region requires) → home.
2. Daily / hangar / campaign clear / rewarded continue / 2x coins.
3. Airplane mode → Retry + Open network settings.
4. Confirm package id `com.ujjwal.tapandodge` on the installed release build.
