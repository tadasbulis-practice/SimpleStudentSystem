# SimpleStudentMobile (Flutter: Android + iOS)

A mobile client for **SimpleStudentApi**: one more technology on the same REST contract
(`swagger.json`) that the .NET and PHP frontends use. It runs on Android and iOS
**phones and tablets**.

| Tab | What it does |
|-----|--------------|
| **Home** | Info about the project (heterogeneous system), API address, connection test (`GET /api/info`) |
| **Students** | Full CRUD: list, create, edit, delete (`/api/students`) |

Phones get a bottom **NavigationBar**. Tablets and landscape screens (≥ 600 dp) get a side **NavigationRail**.

> **Setting up Flutter, Dart, VS Code, Android Studio, Xcode and CocoaPods** on Windows / Linux / macOS:
> [docs/Flutter-Setup_Guide_EN.md](docs/Flutter-Setup_Guide_EN.md) (EN) ·
> [docs/Flutter-Setup_Gidas_LT.md](docs/Flutter-Setup_Gidas_LT.md) (LT)

---

## Architecture

```
 Android / iOS phone or tablet
   SimpleStudentMobile (Flutter, Dart)
        │  HTTP + JSON   (package:http)
        ▼
 http://<API address>:6001   SimpleStudentApi (.NET 8)      ─┐ same contract
 http://<API address>:6002   SimpleStudentPhpApi (PHP)       ─┘ (swagger.json)
        │
        ▼
 SQL Server (Docker)  or  MySQL (XAMPP)
```

## Project structure

```
SimpleStudentMobile/
├── pubspec.yaml                  <- dependencies: http, shared_preferences
├── lib/
│   ├── main.dart                 <- app + tab menu (NavigationBar / NavigationRail)
│   ├── config/api_config.dart    <- API address: default per platform, saved on the device
│   ├── models/student.dart       <- Student (same fields as in swagger.json)
│   ├── models/api_info.dart      <- /api/info response
│   ├── services/student_api.dart <- REST client: getStudents, createStudent, ... + ApiException
│   ├── screens/home_screen.dart  <- tab 1: project info + connection test
│   ├── screens/students_screen.dart     <- tab 2: list, pull-to-refresh, swipe to delete
│   ├── screens/student_form_screen.dart <- create / edit / delete form
│   └── widgets/centered_content.dart    <- limits width on tablets
├── test/widget_test.dart         <- tests with a fake API (no network needed)
├── android/, ios/                 <- native projects, already allow HTTP to the lab API
├── tool/configure_platforms.dart <- (re)generates android/ + ios/ and allows HTTP
└── docs/                         <- setup guides: Flutter-Setup_Guide_EN.md, Flutter-Setup_Gidas_LT.md
```

The `android/` and `ios/` folders are included and already allow plain HTTP to the lab API.
If they are missing, `tool/configure_platforms.dart` regenerates them (step 2 below).

---

## iOS prerequisites (macOS only): Xcode + CocoaPods

`flutter doctor` must not show `✗ CocoaPods not installed` before you build for iPhone / iPad.
Flutter uses Swift Package Manager by default, but plugins without SPM support still need CocoaPods.

```bash
# 1. Homebrew – skip if `brew --version` works (https://brew.sh)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Apple Silicon (M1–M4) only – the "Next steps" the installer prints:
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# 2. CocoaPods
brew install cocoapods
pod --version        # e.g. 1.16.x

# 3. Check
flutter doctor       # the Xcode line must show [✓]
```

Do **not** use `sudo gem install cocoapods` with the macOS system Ruby – it often fails.
Flutter runs `pod install` itself during `flutter run` / `flutter build ios`.
Full steps (Xcode, simulators, real devices): section 9 of [docs/Flutter-Setup_Guide_EN.md](docs/Flutter-Setup_Guide_EN.md) / [docs/Flutter-Setup_Gidas_LT.md](docs/Flutter-Setup_Gidas_LT.md).

---

## Run it

### 1. Start the API

From the `student-docker-lab-plus-mssql` folder (see the main README):

```bash
docker-compose -f docker-compose.infra.yml up -d   # SQL Server (once)
docker-compose up --build -d                        # API on :6001, PHP API on :6002
```

Check in the browser: http://localhost:6001/swagger

### 2. Get the packages

```bash
cd SimpleStudentMobile
flutter pub get
```

`android/` and `ios/` are already in the project and allow plain HTTP to the lab API:

| File | Setting |
|------|---------|
| `android/app/src/main/AndroidManifest.xml` | `INTERNET` permission, `android:usesCleartextTraffic="true"` |
| `ios/Runner/Info.plist` | `NSAppTransportSecurity` → `NSAllowsArbitraryLoads`, `NSLocalNetworkUsageDescription` |

If `android/` or `ios/` is missing (or the HTTP settings were lost), run
`dart run tool/configure_platforms.dart` – it runs `flutter create . --platforms=android,ios`
(does not overwrite existing files) and adds the settings again. Safe to run many times.

> ⚠️ Plain HTTP is allowed **only because this is a lab**. A real app uses HTTPS.

### 3. Start an emulator / simulator and run

```bash
flutter emulators                    # list emulators
flutter emulators --launch <id>      # start one (Android emulator or iOS Simulator)
flutter devices                      # the device must be listed
flutter run                          # or F5 in VS Code / ▶ in Android Studio
```

### 4. Set the API address (if needed)

The app guesses the address from the platform:

| Where the app runs | API address |
|--------------------|-------------|
| Android emulator | `http://10.0.2.2:6001` (10.0.2.2 = your computer) |
| iOS Simulator (Mac) | `http://localhost:6001` |
| Real Android via **USB** | `http://localhost:6001` after `adb reverse tcp:6001 tcp:6001` (see below) |
| Real phone / tablet via **Wi-Fi** | `http://<your computer's IP>:6001` – same Wi-Fi network |
| PHP API in Docker | port `6002` instead of `6001` |
| PHP API in XAMPP | `http://10.0.2.2/simpleStudentApi` (emulator) |

Change it on the **Home** tab → **Change** (saved on the device), or at start-up:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:6001
```

Find your computer's IP: Windows `ipconfig`, macOS `ipconfig getifaddr en0`, Linux `hostname -I`.
On a real device, allow port 6001 in the computer's firewall.

### Real device cannot reach the API?

`10.0.2.2` works **only in the Android emulator**. On a real phone or tablet (and in your computer's browser)
it leads nowhere – you get *"The API did not answer within 10 s … http://10.0.2.2:6001"*.

**Option A – USB (Android, most reliable in class – Wi-Fi and firewall do not matter):**

```bash
adb devices                          # the device must be listed
adb reverse tcp:6001 tcp:6001        # prints 6001; repeat after re-plugging the cable
# several devices connected:  adb -s <device ID> reverse tcp:6001 tcp:6001
flutter run -d <device ID> --dart-define=API_BASE_URL=http://localhost:6001
```

`adb` not found? Windows `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`,
macOS `~/Library/Android/sdk/platform-tools/adb`, Linux `~/Android/Sdk/platform-tools/adb`.

**Option B – Wi-Fi (Android and iPhone/iPad):**

1. Computer IP: Windows `ipconfig` (IPv4 Address), macOS `ipconfig getifaddr en0`, Linux `hostname -I`.
2. Open `http://<IP>:6001/swagger` in the **device's browser** – it must open. If not: firewall, or the Wi-Fi isolates devices (guest / public networks) → use option A.
3. In the app: **Home → Change** → `http://<IP>:6001`.

An address saved with **Change** takes priority over `--dart-define` (**Change → Use default** resets it).
Full steps: section 11.6 of the setup guide in `docs/`.

---

## Build for phones and tablets

| Target | Command | Result |
|--------|---------|--------|
| Android APK (install on any phone/tablet) | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` |
| Android App Bundle (Google Play) | `flutter build appbundle` | `build/app/outputs/bundle/release/app-release.aab` |
| iOS (macOS + Xcode only) | `flutter build ios` | then **Product → Archive** in Xcode |

- Release APK is signed with the debug key by default – fine for the lab, not for Google Play.
- iOS on a real iPhone/iPad: open `ios/Runner.xcworkspace` in Xcode → **Runner → Signing & Capabilities** →
  select your **Team** (a free Apple ID works) and change the **Bundle Identifier** to something unique,
  e.g. `lt.kaunokolegija.simpleStudentMobile.vardenis`.
- **Minimum iOS version: 17.0** – set in `ios/Runner.xcodeproj` (`IPHONEOS_DEPLOYMENT_TARGET`) and `ios/Podfile`
  (`platform :ios, '17.0'`), so you do not need to change it in Xcode. Android: minimum API 24.
- **iPhone/iPad – open the app from the home screen:** a debug build only starts from Flutter tooling or Xcode
  (iOS 14+ restriction: *"debug mode Flutter apps can only be launched from Flutter tooling…"*).
  Install a release build instead – it stays on the device and opens like a normal app:
  `flutter run --release -d <iPhone ID> --dart-define=API_BASE_URL=http://<computer IP>:6001`
  (no hot reload; with a free Apple account it works for 7 days).
- iPad and Android tablets are supported out of the box (`TARGETED_DEVICE_FAMILY = "1,2"` on iOS).

## Tests

```bash
flutter analyze
flutter test
```

The tests use `MockClient` from `package:http/testing.dart`, so the API does not need to run.

---

## How it uses the API

```dart
final api = StudentApi(baseUrl: 'http://10.0.2.2:6001');

final students = await api.getStudents();          // GET    /api/students
final created  = await api.createStudent(student); // POST   /api/students
await api.updateStudent(created);                  // PUT    /api/students/{id}
await api.deleteStudent(created.id);               // DELETE /api/students/{id}
final info     = await api.getInfo();              // GET    /api/info
```

Errors arrive as `ApiException`. For **400** the API sends a ValidationProblem; its `errors`
map becomes `ApiException.fieldErrors` and the form shows each message under the right field.

Compared with the other clients:

| | .NET frontend | PHP frontend | Flutter app |
|---|---|---|---|
| Runs on | server (browser shows HTML) | server | the phone itself |
| Uses swagger.json | generated C# client (NSwag) | reads it at runtime | hand-written Dart client (can be generated: `openapi-generator -g dart`) |
| Reaches the API at | `simplestudentapi:8080` (Docker network) | same | your computer's address (10.0.2.2 / LAN IP) |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Real device: *"did not answer … http://10.0.2.2:6001"* | `10.0.2.2` is emulator-only. USB: `adb reverse tcp:6001 tcp:6001` + `http://localhost:6001`; Wi-Fi: `http://<computer IP>:6001` – see *Real device cannot reach the API?* |
| `Cannot connect to http://...` | API running? Correct address for your device (table above)? Firewall? |
| `Cleartext HTTP traffic ... not permitted` (Android) | Run `dart run tool/configure_platforms.dart` again, then a full restart (not hot reload) |
| `App Transport Security has blocked a cleartext HTTP` (iOS) | Same as above; check `ios/Runner/Info.plist` |
| Real iPhone cannot reach the PC | Allow **Local Network** for the app in iOS Settings; same Wi-Fi; firewall |
| `✗ CocoaPods not installed` (flutter doctor, macOS) | `brew install cocoapods` (needs Homebrew), reopen the terminal, `flutter doctor` – see *iOS prerequisites* above |
| `brew: command not found` / `pod: command not found` | Run the two `brew shellenv` lines above, open a new terminal; `which pod` should print `/opt/homebrew/bin/pod` |
| `pod install` errors | `cd ios && rm -rf Pods Podfile.lock && cd ..`, then `flutter clean`, `flutter pub get`, `flutter run` |
| iPhone: *"In iOS 14+, debug mode Flutter apps can only be launched…"* | Install a release build: `flutter run --release -d <iPhone ID>` |
| Xcode: `could not find included file 'Generated.xcconfig'` | Run `flutter pub get` in `SimpleStudentMobile` first (it creates `ios/Flutter/Generated.xcconfig`), then open `ios/Runner.xcworkspace` |
| iPhone app uses `http://localhost:6001` | Correct only for the iOS Simulator. On a real iPhone: **Home → Change** → `http://<computer IP>:6001`, allow **Local Network** |
| `flutter create` says the name is invalid | Use the script – it passes `--project-name simple_student_mobile` |
