# Gemini Context: Substitution

## Project Overview
**Substitution** is a decentralized social network application built with **Flutter**, utilizing the **Matrix protocol** for communication and data storage. It aims to provide a privacy-focused alternative to traditional social networks, supporting features like rich text posting, media sharing, and room-based feeds.

### Key Technologies
*   **Framework:** Flutter (Dart)
*   **Protocol:** Matrix (via `matrix` package)
*   **Routing:** `go_router`
*   **State Management:** `provider` (primarily for the Matrix `Client`)
*   **Localization:** `easy_localization`
*   **Database:** `sqflite` (Native), IndexedDB (Web)
*   **Rich Text:** `flutter_quill`
*   **Encryption:** `flutter_olm`, `flutter_openssl_crypto`

## Architecture & Structure
The project follows a feature-based directory structure inside `lib/`:

*   **`lib/main.dart`**: Entry point. Initializes the Matrix client, database, localization, and sets up the `GoRouter`.
*   **`lib/auth/`**: Authentication logic (`login.dart`, `host.dart`) and the `AuthFlow` widget.
*   **`lib/feed/`**: Displays the main feed of posts from joined rooms.
*   **`lib/post/`**: Views for individual posts (`post.dart`).
*   **`lib/write/`**: Interfaces for creating new content (text messages, file uploads).
*   **`lib/settings/`**: Application settings (e.g., managing followed feeds).
*   **`lib/shared/`**: Reusable widgets and mixins (e.g., `ScaffoldWithNavigation`).

### Routing
Routing is managed by `GoRouter` in `main.dart`.
*   **Guards:** A `testRedirect` function checks `client.isLogged()` and redirects unauthenticated users to `/intro`.
*   **Deep Linking:** Supports routes like `/feed/:roomId` and `/post/:id`.

## Development Conventions

### Building and Running
*   **Run:** `flutter run`
*   **Build:** `flutter build <platform>` (e.g., `apk`, `ios`, `web`)
*   **Formatting:** `dart format .`
*   **Linting:** Uses `flutter_lints`. Run `flutter analyze` to check code quality.

### Code Style
*   **Tuples:** The project is migrating towards using Dart Records (e.g., `(Event event, Timeline timeline)`) instead of older Tuple classes.
*   **TODOs:** Check codebase for inline `TODO` comments.

### Dependencies & Setup
*   **Matrix SDK:** The app requires a Matrix homeserver connection.
*   **Native Dependencies:**
    *   **Linux:** Requires `libsqlite3-dev` (implied by `sqflite_common_ffi`).
    *   **Encryption:** Depends on `flutter_olm` which may require native build tools (e.g., `cmake`, `ninja`).

## Common Tasks
*   **Adding a Route:** Add a new `GoRoute` entry in the `router` configuration in `lib/main.dart`.
*   **Localization:** Add new keys to `assets/translations/{lang}.json` and generate keys if necessary.
*   **State Access:** Access the Matrix client via `Provider.of<Client>(context, listen: false)`.

## Known Issues / Notes
*   **Web Support:** Uses IndexedDB.
*   **Desktop Support:** Linux support is explicitly initialized in `main.dart` with `sqfliteFfiInit()`.
*   **Makefile:** The existing `Makefile` contains hardcoded paths specific to the original author's machine and should generally be avoided in favor of standard Flutter commands.
