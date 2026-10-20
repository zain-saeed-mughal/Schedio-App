# Schedio for Android and iOS

Native Flutter/Dart app backed by the existing Schedio Laravel API.

## Run

Use Flutter 3.47.4 / Dart 3.13.3 and the committed pubspec.lock.

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-staging-host/api/v1/
```

Deploy the API before signing in. Keep the trailing slash in API_BASE_URL. Do not place secrets in Dart defines.

## Verify

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter test integration_test/app_test.dart -d DEVICE_ID
```

The integration smoke test requires a clean Android/iOS device or simulator. iOS builds require macOS/Xcode.

## Structure

- lib/core: typed transport models, Dio repository, Riverpod providers, secure session handling, local device alerts, shared widgets.
- lib/features: authentication, dashboard, calendar, workspace modules, availability, booking, settings/profile.
- lib/theme: Schedio charcoal/amber Material 3 theme.
- assets: original Schedio logo and bundled open-licensed Plus Jakarta Sans.
- test: model/repository/auth provider/widget/calendar/editor tests and sign-in golden.

The reusable workspace editor/list reduces duplicate form and pagination logic. Business rules remain in Laravel. No separate mobile business database or WebView is used.

See ../docs/API.md, ../docs/FEATURE_PARITY.md and ../docs/RELEASE.md for contracts, verified coverage, production dependencies and signing instructions.
