# EduTrack - Flutter app

Flutter (Dart, Material 3), Provider + MVVM + Repository, SQLite offline store with a sync queue.
See the root [README](../README.md) for the full system overview and sync design.

## Setup
```bash
flutter create . --org com.edutrack --project-name edutrack --platforms android   # generates android/ (keeps lib/ and pubspec.yaml)
python tool/patch_android.py        # INTERNET permission, app label "EduTrack", minSdk 23
flutter pub get
flutter analyze
flutter test
flutter run                         # debug: talks to http://10.0.2.2:5000/api (emulator -> your PC)
```
> If `flutter create .` overwrites `pubspec.yaml` or `lib/main.dart`, restore them with `git checkout -- pubspec.yaml lib/main.dart`.

## API address
- Release builds default to `https://edutrack-backend.enzonic.dev/api`.
- Debug builds default to `http://10.0.2.2:5000/api` (Android emulator).
- Override: `flutter run --dart-define=API_BASE_URL=http://<PC-LAN-IP>:5000/api`, or change it inside the app (Profile > Server address).

## Release APK
```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

## Structure
`lib/core` (theme, constants, errors, validators) - `lib/models` - `lib/services` (api, database, sync, connectivity, storage) -
`lib/repositories` - `lib/viewmodels` - `lib/views` - `lib/widgets` (common + custom) - `test/`
