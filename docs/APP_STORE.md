# Apple App Store — Tap & Dodge (iOS)

## Identity

- **Bundle ID:** `com.ujjwal.tapandodge` (matches Android applicationId)
- **Display name:** Tap & Dodge
- **Version:** from `pubspec.yaml` (`FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER`)

## Why Sign in with Apple is included

App Store Guideline **4.8**: if you offer a third-party login (Google), you must also offer **Sign in with Apple** as an equivalent option. The auth screen shows Apple (iOS) + Google + Guest.

## Firebase Console (you must do on a Mac/browser)

1. Firebase → Project **tapdodge-294f4** → Add app → **iOS**
2. Bundle ID: `com.ujjwal.tapandodge`
3. Download **`GoogleService-Info.plist`** → replace  
   `ios/Runner/GoogleService-Info.plist`
4. Copy **REVERSED_CLIENT_ID** from that plist into  
   `ios/Runner/Info.plist` → `CFBundleURLSchemes`
5. Run on Mac:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=tapdodge-294f4 --platforms=android,ios
   ```
   (updates `lib/firebase_options.dart` iOS values)
6. Authentication → Sign-in method → enable **Apple** and **Google**
7. Apple Developer → Certificates, Identifiers & Profiles → your App ID → enable **Sign In with Apple**
8. Xcode → Runner target → Signing & Capabilities → confirm **Sign In with Apple** (entitlements file is already `Runner/Runner.entitlements`)
9. Add `GoogleService-Info.plist` to the Runner target in Xcode (Copy Bundle Resources) if it is not already listed

## AdMob iOS

1. Create an iOS app + ad units in AdMob
2. Replace `GADApplicationIdentifier` in `ios/Runner/Info.plist`
3. Paste iOS unit IDs in `lib/services/ad_config.dart` (`productionIos*`)
4. Set `AdConfig.useTestAds = false` before App Store release

## Privacy / App Privacy labels

Use the same public policy as Play:

- Privacy: `https://tapdodge-294f4.web.app/privacy/`
- Terms: `https://tapdodge-294f4.web.app/terms/`
- Support: `navaparameetdev@gmail.com`

Declare in App Store Connect App Privacy: account info, product interaction, advertising data (AdMob), identifiers.

## Account deletion

Already in-app: Account → **Delete Account & Cloud Save** (App Store requirement when accounts exist).

## Build (Mac)

```bash
cd tap_and_dodge
flutter pub get
cd ios && pod install ; cd ..   # if using CocoaPods
flutter build ipa --release
```

Open `build/ios/archive` / Organizer to upload, or:

```bash
flutter build ipa
xcrun altool ... # or Transporter / Xcode Organizer
```

## Manual checklist before submit

- [ ] Real `GoogleService-Info.plist` + URL scheme
- [ ] Firebase Apple + Google providers enabled
- [ ] Sign In with Apple capability on App ID
- [ ] Production AdMob iOS IDs + `useTestAds = false`
- [ ] Hosted privacy URL works
- [ ] Test Apple SSO, Google SSO, Guest, cloud restore, delete account on a real device
