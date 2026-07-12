# Release guide — أرشيف البكالوريا (Android / Play Store)

## 0. One-time signing setup (already done)
- Keystore: `android/app/upload-keystore.jks`
- Credentials: `android/key.properties` (alias `upload`)
- Gradle reads them in `android/app/build.gradle.kts` → `signingConfigs.release`.

> ⚠️ **BACK UP `upload-keystore.jks` AND `key.properties` NOW**, somewhere safe
> and private (password manager / offline backup). If you lose this keystore you
> can **never publish an update** to the same app on Google Play — you'd have to
> ship a brand-new listing. These two files are git-ignored on purpose.
>
> To regenerate with your own password instead of the auto-generated one:
> ```
> keytool -genkeypair -v -keystore android/app/upload-keystore.jks \
>   -keyalg RSA -keysize 2048 -validity 10000 -alias upload
> ```
> then update `android/key.properties` to match.

## 1. Build the signed App Bundle (.aab — what Play wants)
From the `app/` folder:
```
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-PUBLIC-KEY
```
Output: `build/app/outputs/bundle/release/app-release.aab`  ← upload this.

(If you hard-coded the keys in `lib/config/app_config.dart`, you can drop the
`--dart-define` flags.)

### Optional: a signed APK for quick on-device testing
```
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

## 2. Versioning (every update)
Edit `version:` in `pubspec.yaml` — format `versionName+versionCode`:
```
version: 1.0.0+1   # first release  -> versionName 1.0.0, versionCode 1
version: 1.0.1+2   # next update     -> versionName 1.0.1, versionCode 2
```
`versionCode` **must strictly increase** on every upload. Or override per-build:
`--build-name=1.0.1 --build-number=2`.

## 3. What's already configured for a submittable release
- **applicationId**: `com.malik.bacsci` (final, reverse-domain).
- **minSdk 24**, **targetSdk 36**, **compileSdk 36** (Flutter 3.44 defaults;
  targetSdk 36 is above Google's current API-35 floor). ✅
- **R8 code shrinking + resource shrinking** enabled for release.
- **Adaptive icon** (foreground + `#1E40AF` background) + **splash** (incl.
  Android 12+ splash), matching the design system.
- **Permissions**: `INTERNET` (declared) plus `ACCESS_NETWORK_STATE` (merged in
  by `connectivity_plus`). Both are **normal, non-sensitive** permissions and
  need **no** Data Safety disclosure — the app still collects no personal data.

## 4. Privacy policy
Host `../privacy-policy/index.html` (e.g. GitHub Pages) and paste its public URL
into Play Console → App content → Privacy policy. Required even though the app
collects nothing.

## 5. Play Store listing text
See `../store-listing-ar.md` (title ≤30, short ≤80, full ≤4000 — all within limit).

## 6. Manual steps in Play Console (can't be done in code)
Content rating questionnaire · Data Safety form (declare: no data collected) ·
feature graphic 1024×500 + screenshots · closed testing with real testers before
production.
