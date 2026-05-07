# AGENTS.md — Substitution

## Project Overview

Substitution is a decentralized social network built with **Flutter/Dart** on the **Matrix protocol**. It supports all six Flutter platforms (Android, iOS, Web, Linux, macOS, Windows). Key dependencies: `matrix` SDK, `go_router`, `provider`, `easy_localization`, `flutter_quill`, `sqflite`, `flutter_vodozemac`.

**Dart SDK**: `>=3.7.0 <4.0.0`

## Build & Run Commands

| Command | Purpose |
|---|---|
| `flutter pub get` | Install dependencies |
| `flutter run` | Run the app (debug mode) |
| `flutter build <platform>` | Build for platform (`apk`, `ios`, `web`, `linux`, `windows`, `macos`) |
| `flutter build web --wasm --base-href /substitution/` | Production web build with WASM |
| `dart format .` | Format all Dart code |
| `flutter analyze` | Run static analysis / linting |

## Test Commands

### Quick reference

| Command | Purpose |
|---|---|
| `flutter test` | Run all unit + widget tests |
| `flutter test test/unit/` | Run only unit tests (fast, no Docker) |
| `flutter test test/unit/feed_paginator_test.dart` | **Run a single test file** |
| `flutter test --name "test name"` | Run tests matching a name pattern |
| `flutter test test/unit/ --reporter=expanded` | Verbose unit test output |

### Test runner script (`./scripts/test.sh`)

| Command | Purpose |
|---|---|
| `./scripts/test.sh unit` | Unit tests (`test/unit/`) — no Docker |
| `./scripts/test.sh widget` | Widget tests (`test/` excluding `unit/`) — no Docker |
| `./scripts/test.sh web` | Web integration tests (Chrome + Docker) |
| `./scripts/test.sh linux` | Linux desktop integration tests (Docker) |
| `./scripts/test.sh ios` | iOS simulator integration tests (Docker) |
| `./scripts/test.sh android` | Android emulator integration tests (Docker) |
| `./scripts/test.sh all` | Run everything available |
| `./scripts/test.sh <target> --no-docker` | Skip Docker service management |
| `./scripts/test.sh <target> --filter "pattern*"` | Filter integration tests by glob |

Integration tests require Docker infrastructure (Matrix Synapse + PostgreSQL + Redis + Dex OIDC), started via `docker-compose up`. Unit and widget tests need no external services.

### Test environment variables

- `MATRIX_SERVER` — default `http://localhost:8008`
- `MATRIX_TEST_USER` — default `testuser1`
- `MATRIX_TEST_PASSWORD` — default `testpass123`

## Test Patterns

- **Framework**: `flutter_test` (built-in) for unit/widget tests; `integration_test` + `patrol` for integration tests
- **Mocking**: `mocktail` (no code generation needed). Mock classes extend `Mock` and implement the target:
  ```dart
  class MockClient extends Mock implements Client {}
  ```
- **Test helpers** live in `test/helpers/test_helpers.dart`:
  - `setUpTestInfrastructure()` — call in `setUpAll` for shared mock setup
  - `pumpApp(tester, widget)` — wraps widget in EasyLocalization + Provider + MaterialApp + GoRouter
  - `createMockRoom()`, `createMockEvent()`, `createMockUser()` — factory helpers
- **Widget test setup** pattern:
  ```dart
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(MockEvent());
  });
  ```
- **Integration tests** call `app.main()` directly and navigate using widget `Key`s (e.g., `Key('loginUsernameInput')`)

## Project Architecture

Feature-based directory structure under `lib/`:

```
lib/
  main.dart                  # Entry point, GoRouter config, Matrix client init
  auth/                      # Authentication (login, host selection, SSO)
  chat/                      # Chat/DM functionality
  faq/                       # FAQ/help pages
  feed/                      # Main feed display
  post/                      # Individual post views
  profile/                   # User profile
  settings/                  # App settings
  write/                     # Content creation
  shared/                    # Cross-cutting concerns
    constants.dart
    extensions/
    mixins/
    models/
    pages/
    platform/
    services/
    theme/
    utils/
    widgets/
```

Each feature may have subdirectories: `pages/`, `widgets/`, `services/`, `mixins/`, `interfaces/`.

## Code Style Guidelines

### Formatting & Linting

- **Formatter**: `dart format .` (standard Dart formatter, default settings)
- **Linter**: `flutter_lints` (standard Flutter lint rules, no custom overrides)
- **Analysis**: Run `flutter analyze` before committing

### Import Ordering

Local (project) imports first, then a blank line, then package/dart imports:

```dart
import '/auth/auth.dart';
import '/feed/feed.dart';
import '/shared/constants.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'dart:async';
```

**Important**: Local imports use absolute-path syntax (`import '/auth/auth.dart';`), NOT the `package:substitution/...` form. Follow this convention.

### Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Classes | `PascalCase` | `SubstitutionService`, `FeedState` |
| Variables/fields | `camelCase` | `currentIndex`, `globalMatrixClient` |
| Constants | `camelCase` | `defaultEmojiFontFamily`, `radiusM` |
| Private members | `_` prefix | `_seedColor`, `_substitutionRoomIds` |
| Files | `snake_case` | `substitution_service.dart` |
| Test files | `snake_case_test.dart` | `feed_paginator_test.dart` |
| Widget keys | `camelCase` strings | `Key('fabNewPost')`, `Key('navHome')` |

### Type & Language Patterns

- Use `final` extensively for local variables and constructor parameters
- Use `const` constructors where possible: `const Feed({super.key, this.roomId})`
- Use `super.key` syntax (modern Dart shorthand)
- Use `late final` for lazily initialized fields
- Use `required` keyword for mandatory named parameters
- Null safety throughout — use `String?`, `Widget?`, `?.` operator
- Dart 3.7+ features: records, enhanced enums, pattern matching, switch expressions
- The project is migrating from Tuple classes to Dart Records `(Event event, Timeline timeline)`

### Error Handling

- Wrap non-critical operations in try-catch with `debugPrint("Error: $e")`
- Use separate try-catch blocks for independent cleanup operations
- Check `if (context.mounted)` before navigation after async operations
- Use `rethrow` for critical errors that must propagate
- Use `?.` null-safe operator extensively to handle nullable values

### State Management & Routing

- Access Matrix client: `Provider.of<Client>(context, listen: false)`
- Navigation: `go_router` with `GoRouter` configured in `lib/main.dart`
- Localization: `'feed.nav.home'.tr()` — keys defined in `assets/translations/{lang}.json`
- Theme: `Theme.of(context)` and `Theme.of(context).colorScheme`
- Global references for test access: `globalMatrixClient`, `globalSubstitutionService`, `globalDatabase`

### Localization

77+ languages supported. Translation files in `assets/translations/`. Add new keys to the relevant JSON files and use `'key.path'.tr()` in code.

## CI/CD

GitHub Actions workflow at `.github/workflows/integration-tests.yml`:
- Runs `flutter analyze` on every push/PR
- Unit + widget tests (no Docker)
- Multi-platform integration tests: Web (Chrome), Linux, iOS, Android — all sharded
- Automatic retries on flaky platforms (iOS: up to 2 retries)
- Deployment on version tags (`v*`): Google Play, GitHub Releases, GitHub Pages

## Makefile

The `Makefile` contains hardcoded author-specific paths. **Do not use it.** Use the standard Flutter commands or `./scripts/test.sh` instead.
