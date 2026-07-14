# Play Store Deployment Guide — أرشيف البكالوريا

An end-to-end checklist for publishing (and later updating) this app on
Google Play. Values specific to this project are filled in; tick boxes as
you go.

---

## 1. Release signing (one-time — ALREADY DONE for this repo)

This project already has signing wired up. The two secret files are
**git-ignored** and must exist locally:

- [ ] `app/android/app/upload-keystore.jks` exists
- [ ] `app/android/key.properties` exists and matches the keystore

If you ever need to regenerate from scratch:

```bash
keytool -genkeypair -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

then create `android/key.properties`:

```properties
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

`android/app/build.gradle.kts` already loads this file and signs release
builds with it (falls back to debug keys if the file is missing, so builds
never break on other machines).

> ⚠️ **BACK UP BOTH FILES NOW** (password manager / offline drive). Losing
> the keystore permanently locks you out of updating the published app.

- [ ] Keystore + key.properties backed up somewhere safe

## 2. App identity & versioning

- **applicationId:** `com.malik.bacsci` (already set — permanent once
  published, never change it)
- **Versioning:** edit `version:` in `app/pubspec.yaml`, format
  `versionName+versionCode`:
  - first release `1.0.0+1`
  - bugfix update `1.0.1+2`
  - feature update `1.1.0+3`
  - **versionCode (after the `+`) must strictly increase on every upload**

- [ ] `pubspec.yaml` version bumped for this release

## 3. Build the release bundle

```bash
cd app
flutter build appbundle --release
```

Output lands at:

```
app/build/app/outputs/bundle/release/app-release.aab
```

- [ ] `.aab` built without errors
- [ ] Quick smoke test of the matching APK on a real device
      (`flutter build apk --release`, install, open a PDF)

## 4. Google Play Console — first-time setup

- [ ] Create a developer account at https://play.google.com/console
      ($25 one-time fee, identity verification can take a few days)
- [ ] **Create app** → name `أرشيف بكالوريا علوم تجريبية`, default language
      Arabic, type **App**, **Free**
- [ ] Declare it does NOT contain ads (it doesn't)

## 5. Store listing

Ready-made copy lives in [`store-listing-ar.md`](store-listing-ar.md)
(title 27/30 chars, short description 74/80, full description within 4000).

Assets needed:

| Asset | Spec | Status |
|---|---|---|
| App icon | 512×512 PNG, ≤1 MB | export from `app/assets/icon/icon_full.png` |
| Feature graphic | 1024×500 PNG/JPG | **you must create this** |
| Phone screenshots | 2–8, 16:9 or 9:16, min 320px side | capture from the app |
| 7" / 10" tablet screenshots | optional but recommended | capture on tablet/emulator |

- [ ] Title / short / full description pasted from `store-listing-ar.md`
- [ ] Icon uploaded
- [ ] Feature graphic uploaded
- [ ] At least 2 phone screenshots uploaded
- [ ] App category: **Education** · contact email set

## 6. Required declarations

- [ ] **Privacy policy URL** — host [`privacy-policy/index.html`](privacy-policy/index.html)
      (GitHub Pages works: Settings → Pages on this repo, or any static host)
      and paste the public URL in *App content → Privacy policy*.
      Required even though the app collects nothing.
- [ ] **Data safety form** — declare **no data collected, no data shared**
      (true: no accounts, no analytics, anonymous downloads only)
- [ ] **Content rating questionnaire** — category *Reference/Education*;
      answer no to everything sensitive → expect **Everyone / PEGI 3**
- [ ] **Target audience** — 13+ (lycée students); not a "designed for
      children" app
- [ ] Ads declaration: **No ads**

## 7. Testing → production flow

1. - [ ] **Internal testing** track first: upload the `.aab`, add your own
         email as tester, install via the opt-in link, verify sync + PDFs
2. - [ ] **Closed testing**: Google requires new personal accounts to run a
         closed test with **≥12 testers for 14 days** before production —
         recruit classmates/friends, keep the test running
3. - [ ] Apply for **production access** once the closed test qualifies
4. - [ ] **Production** release: upload (or promote) the `.aab`, staged
         rollout 20% → 100% is a safe pattern
5. - [ ] After approval: monitor *Android vitals* and crash reports

Review times: first submission typically 3–7 days; updates usually <48h.

## 8. Common rejection reasons to avoid (education apps)

- [ ] **Broken first-run** — the reviewer opens the app once: the sync
      screen must work on their network and never dead-end (our retry
      states cover this; keep Supabase egress quota healthy before review)
- [ ] **Privacy policy URL missing/dead** — must load publicly, match the
      app name, and reflect reality (no data collected)
- [ ] **Data safety form contradicting behavior** — we declare "no
      collection"; never add analytics later without updating the form
- [ ] **Copyright complaints** — exam papers are government-published
      documents; if Play ever asks, be ready to state the source of the
      content (official ONEC exam papers, publicly published)
- [ ] **Metadata violations** — don't put "الأفضل/#1" or competitor names
      in the title/description; don't stuff keywords
- [ ] **Screenshots not matching the real app** — capture from the actual
      build, no mockups with fake content
- [ ] **Targeting children incorrectly** — we target 13+; do not select the
      "primarily for children" program (it triggers stricter review)

## 9. Updating the app later

1. Make changes → `flutter analyze && flutter test`
2. Bump `version:` in `pubspec.yaml` (increase both parts appropriately)
3. `flutter build appbundle --release`
4. Play Console → Production → *Create new release* → upload `.aab` →
   release notes (Arabic) → roll out
5. Content changes (new exam PDFs) need **no app update at all** — upload
   via the admin dashboard and installed apps pick them up automatically
