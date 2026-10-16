# Firebase + Google / Apple Sign-In + Cloud Save

## What the app uses

| Service | Purpose |
|---------|---------|
| Firebase Auth (Google + Apple) | Identity (`uid`) — Apple required for App Store when Google SSO is offered |
| Cloud Firestore | `users/{uid}` campaign save |
| SharedPreferences | Local cache + Guest progress |

iOS App Store steps: see [`APP_STORE.md`](APP_STORE.md).

Guest progress is **never** written to a shared public Firestore document.

## Manual Firebase Console checklist

Already done for project `tapdodge-294f4` if you followed prior setup:

1. Android app package: `com.ujjwal.tapandodge`
2. `google-services.json` in `android/app/`
3. Authentication → Google provider **Enabled**
4. Firestore database created
5. Debug SHA-1 fingerprint added
6. Web client ID in `lib/firebase_options.dart` → `googleServerClientId`

Still required for production:

- Add **release** keystore SHA-1 before Play release
- Deploy security rules below (replace test-mode rules)
- Set hosted Privacy / Terms URLs in `lib/services/legal_config.dart`

## Deploy Firestore rules

File in repo: [`../firestore.rules`](../firestore.rules)

```bash
# From project root, after firebase login + firebase use tapdodge-294f4
firebase deploy --only firestore:rules
```

Or paste the contents of `firestore.rules` into Firebase Console → Firestore → Rules → Publish.

## Document shape

```
users/{firebaseUid}
  uid: string          // must equal auth.uid
  email: string?
  displayName: string?
  schemaVersion: int
  updatedAt: timestamp // server
  progress: {
    schemaVersion, bestScore, totalCoins,
    unlockedLevel (1..50), highestCompletedLevel,
    campaignComplete, streak, daily day keys,
    ownedSkinIds, equippedSkinId,
    worldRewardsClaimed, levelBests, updatedAtMs
  }
```

## Conflict policy (guest ↔ cloud)

- Max unlocked / completed level
- Max best score per level
- Max coins (**not** summed)
- Union of skins and world rewards
- Prefer local equipped skin if still owned

## Auth vs internet

- **Guest auth** does not require internet
- **Google Sign-In** and cloud sync require internet
- Campaign gameplay still uses the existing connectivity gate for ads / online play

## Guest → Google

Account → **Save My Progress** merges local guest save with cloud, then uploads. Guest data is not discarded on failure.
