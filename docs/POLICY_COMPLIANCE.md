# Play / AdMob / privacy — suspension risk checklist

Use this before any Play upload. Items marked **FIXED IN APP** are already handled in code. Items marked **YOU MUST DO** are console / listing actions only you can complete.

## Critical (account / AdMob suspension risk)

| Issue | Status | Action |
|-------|--------|--------|
| Shipping Google **test AdMob IDs** in production | **FIXED IN APP** | Release builds throw if `useTestAds == true` or placeholder unit IDs remain |
| Granting rewards without a real ad (invalid traffic) | **FIXED IN APP** | QA reward simulation disabled in `kReleaseMode` |
| Accounts without **in-app account deletion** | **FIXED IN APP** | Account → **Delete Account & Cloud Save** |
| Missing **public privacy policy URL** with ads | **YOU MUST DO** | Host policy HTTPS page; set `LegalConfig.privacyPolicyUrl` |
| Empty **support email** | **YOU MUST DO** | Set `LegalConfig.supportEmail` |
| Firestore left in **open test rules** | **YOU MUST DO** | Deploy `firestore.rules` from repo |
| Play **Data safety** form inaccurate | **YOU MUST DO** | Declare Ad ID, ads, account info, app activity, cloud save |
| Listing omits **Contains ads** | **YOU MUST DO** | Enable ads declaration in Play Console |
| **Designed for Families** / under-13 without compliance | **DO NOT** | App is general audience — do not enroll Families unless fully compliant |
| Fake affiliation with other games (e.g. Ludo King) | **OK** | Original Tap & Dodge gameplay; do not claim endorsement or copy assets |

## Game idea / IP

- Mechanics are a standard arcade dodge/collect campaign — original code and art direction in this repo.
- Do **not** use another studio’s name, logo, characters, or audio in the listing or APK.
- Do **not** claim “official”, “licensed”, or “inspired by [brand]” in the store listing.

## Data you actually process (declare accurately)

- Local preferences: progress, settings  
- Optional Google Sign-In: Firebase UID, name/email/photo from Google  
- Firestore: progress document under `users/{uid}`  
- AdMob: advertising ID + ad measurement (via Google)  
- Network: required for ads and Google/cloud features  

## Pre-publish switches

1. Create real AdMob app + units → paste IDs in `ad_config.dart` + `AndroidManifest` App ID  
2. `AdConfig.useTestAds = false`  
3. `AdConfig.qaSimulateRewardedWhenAdFails = false` (already inert in release)  
4. Host privacy policy + set URL + support email  
5. Deploy Firestore rules  
6. Content rating questionnaire (ads answers)  
7. Data safety form aligned with this doc  

## Not automatic compliance

Client Firestore rules reduce misuse; they are **not** full anti-cheat. Do not promise rankings that rely only on client trust.
