# CalDoo (卡嘟)

English | [简体中文](README.md)

An offline-first **Android** diet & nutrition tracker: log meals by photo or
Chinese free text (typed, or dictated with the keyboard's own microphone),
capture 营养成分表 labels into a food library, hand-copy one daily
exercise-burn number, and review per-meal / daily / weekly / monthly energy
and salt — analysis by a bring-your-own-key (BYOK) AI provider.

Everything except the AI analysis works fully offline; all data lives in the
on-device SQLite database (whole-kcal integers end to end, see
[design/integer-energy.md](design/integer-energy.md); switchable display
units, see [design/display-units.md](design/display-units.md)). An AI failure
never blocks saving a meal.

## Features

- **概览 dashboard**: one screen, three views (日 / 周 / 月), swipe through
  history, jump back to today. The meal log is a flat chronological list (one
  row per food), not meal-type buckets — all logging happens on this tab.
- **食物库 food library**: live, searchable catalogue of every captured food
  (labels / AI estimates / manual). 添加食物 offers 拍照识别营养标签 (AI) or
  手动录入 (offline). One photo may contain several labels; each food carries a
  free-text supplement (package size, aliases, remarks).
- **设置 settings**: two pages — 模型设置 (BYOK key / base URL / model, with
  保存 and 测试连接) and 数据显示 (kcal↔kJ, salt↔sodium). Display preferences
  change what is shown, never the stored values, and never affect manual entry.
- **Voice input**: deliberately no in-app speech recogniser
  (`SpeechRecognizer` is unusable by third-party apps on several Chinese
  ROMs). The 语音输入 button just focuses the field and points at the IME's
  microphone key; the app requests no microphone permission.

## Add your BYOK key

The API key is write-only: stored in `flutter_secure_storage` (Android
Keystore-backed), never in the database, logs or export files.

1. Open **我的 → 设置**
2. Paste your DeepSeek key (`sk-...`) into **API Key**, tap **保存**
3. Optionally **测试连接** to verify

Defaults (overridable in Settings; any OpenAI-compatible endpoint works):
`https://api.deepseek.com` + `deepseek-flash`, path
`POST {baseUrl}/chat/completions`.

## Backup and the install rule (important)

Every record lives in the app's private SQLite database with
`android:allowBackup="false"` — **uninstall destroys everything, no OS-level
recovery**. Two layers of protection:

- **Automatic backup**: on launch and whenever the app moves to the
  background, the whole dataset (the same JSON as the export) is written to
  the public folder `下载/卡嘟备份/`, newest 10 kept — the copies survive an
  uninstall. Restore in **我的 → 数据备份**, or import any `data.json` via
  从文件导入. Backups never contain the API key.
- **Safe install**: install via `tool/install_android.sh` — it builds the
  release APK itself, refuses without a recent automatic backup, then installs
  with `adb install -r` (overwrite in place). **Never install with a command
  that uninstalls first.**

```bash
tool/install_android.sh                     # build + check backup + install -r
ALLOW_NO_BACKUP=1 tool/install_android.sh   # bypass the backup check
SKIP_BUILD=1 tool/install_android.sh        # reuse the existing release APK
```

## Development

```bash
flutter pub get
flutter run          # Android device or emulator

dart run build_runner build   # regenerate Drift / Riverpod / json_serializable after model changes

flutter test         # unit + widget suite
flutter analyze      # must report 0 issues
```

## CI/CD

GitHub Actions, toolchain pinned to stable 3.47.5 (bump both workflows with
the local `flutter upgrade`):

- **CI** (`ci.yml`, pushes to master + PRs): build_runner freshness check (the
  committed `.g.dart` files must match their sources), `dart format`,
  `flutter analyze`, full test suite. The `test/ui_renders` goldens are macOS
  review artifacts (tagged `ui-renders`, declared in `dart_test.yaml`) — CI
  runs `--exclude-tags=ui-renders`; regenerate on a Mac with
  `flutter test --update-goldens test/ui_renders`.
- **Release** (`release.yml`, tag-triggered): tag `vX.Y.Z` must match the
  version in `pubspec.yaml` — bump the version first, then tag; builds the
  signed release APK and publishes it to GitHub Releases.

  ```bash
  git tag v1.2.3 && git push origin v1.2.3
  ```

Signing reads the gitignored `android/key.properties` +
`android/app/caldoo-release.jks`; CI restores both from four Secrets
(`ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` /
`ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD`). A checkout without
`key.properties` falls back to debug signing, so `flutter run --release`
keeps working locally.

> ⚠️ **Back up the keystore and both passwords** (password manager or
> similar). Losing them is permanent: Android rejects updates signed with a
> different key.

## Deliberately out of scope

- No backend / accounts / sync — local-only.
- No Health Connect or OEM fitness SDKs — exercise is one hand-copied daily
  burn number.
- No barcode UI, no on-device OCR, no on-device food model — labels are
  AI-parsed (BYOK, online) or manual.
- No in-app ASR — the keyboard's microphone (see above).
- No child mode / activity-level picker — one adult profile; the baseline IS
  the BMR (Mifflin-St Jeor from sex/birthday/height/weight, age derived from
  the birthday), exercise is added on top, so it can never be double-counted.
- No configurable week / month — Monday 00:00 → Sunday 24:00 and the calendar
  month, fixed.
- No landscape layout — portrait-locked (on Android 16+ large screens
  rotation is the OS's call).
- Android only — no iOS / macOS / web / Windows / Linux.
