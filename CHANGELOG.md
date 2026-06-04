# Changelog

All notable changes to Substitution are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Deep-link destination preservation (`?goto=`)** — when a logged-out user follows
  a deep link to a protected page, the route guard now redirects to
  `/intro?goto=<encoded-original-uri>`. After completing the introduction/login flow,
  the "Continue to App" button reads the `?goto=` and navigates the user back to the
  page they originally requested.
- **Alias-taken validation in the create-room dialog** — a sync format check on the
  alias field, plus an async `getRoomIdByAlias` lookup right before submission that
  surfaces a localized "alias is already taken" error if the homeserver already has
  that alias. The server's `M_ROOM_IN_USE` rejection is also caught and surfaced as
  the same message.
- **`SubstitutionRoom` data model tests** covering constructor defaults and optional
  fields (6 cases).
- **`ShareHelper` URL-generation tests** covering alias stripping, userId encoding, and
  the post URL shape (8 cases).
- **`relativeTime` helper tests** covering all formatting branches and boundary
  conditions (19 cases including clock-skew safety).
- **`routing_utils` helper tests** covering the `?goto=` redirect logic and the
  open-redirect / XSS safety guard `safeGotoDestination()` (35 cases).
- **`servers` helper tests** covering the centralized `getSubstitutionServers` /
  `setSubstitutionServers` functions (6 cases).
- **Room-form extracted-widget tests** covering `FormSectionCard`, `FormToggleTile`,
  and `RoomDangerZone` (6 cases).

### Fixed
- `flutter analyze` now reports no issues (removed stale `build/` artifacts and the
  unused `lib/test_infinite.dart` placeholder).
- **Race condition in `DialogAddServer.checkHost`** — added a monotonic sequence
  counter so that if two near-simultaneous server validations complete out of order,
  only the latest result is allowed to mutate state. Prevents the form from marking
  a stale host as valid if a faster follow-up check finishes first.
- **Missing media-type guard in `FileDisplayContainer.relatedFiles`** — the aggregator
  now restricts the file carousel to events whose `messageType` is in
  `{m.image, m.video, m.audio, m.file}`, so text/emote/notice/location replies are
  no longer incorrectly shown as related files.
- **Missing `try`/`catch` in `DialogAddServer.addRoom`** — the
  `client.queryPublicRooms` call was already wrapped, but the now-removed TODO
  comment was misleading future readers; the docstring now explicitly documents the
  failure modes (`M_FORBIDDEN`, federation errors) and how the catch surfaces them.

### Changed
- **Applied the `MatrixEssentials` mixin** to 6 settings/write pages that were
  previously duplicating the
  `Client get client => Provider.of<Client>(context, listen: false);` pattern by hand.
  Removes 6 copies of the same getter in favor of one canonical implementation.
- **Centralized Substitution server account-data access** in
  `lib/shared/utils/servers.dart` (`getSubstitutionServers` / `setSubstitutionServers`).
  Three files (`followfeeds.dart`, `dialogaddserver.dart`, `dialogdeleteserver.dart`)
  used to duplicate the `client.getAccountData(userID!, 'substitution.servers')` +
  error-fallback pattern; the centralized helper also documents the account-data key
  (`substitutionServersAccountDataKey`) so the magic string lives in one place. Two
  more files (`textmessage.dart`, `ownfeeds.dart`) had dead copies of the getter that
  were never called and have been removed.
- **Moved `RoomWidget`** from `lib/settings/widgets/` to `lib/shared/widgets/`
  to match its actual usage (it was imported by both `lib/settings/` and
  `lib/write/`). Updated 3 lib/ imports and 3 integration_test/ imports.
- **Extracted `IntroductionPage`** from `lib/main.dart` to
  `lib/auth/pages/introduction_page.dart`. The 159-line public class was the
  bulk of `main.dart` after the deep-link work, and now lives next to the other
  auth pages.
- **Extracted `StartupLoadingScreen`** from `lib/main.dart` to
  `lib/shared/widgets/startup_loading_screen.dart`. The private `_StartupLoadingScreen`
  class became a public, reusable widget (used at app startup before
  `MaterialApp.router` is constructed).
- **Decomposed `lib/post/interfaces/i_event.dart` (`IEventWidget`)** — extracted
  the avatar / username / `comments` helper logic into a new
  `EventView` class (`lib/post/interfaces/event_view.dart`). `IEventWidget` is
  now a thin layer that exposes an `eventView` getter and delegates its
  existing `avatarURL` / `username` / `hasAvatarURL` / `comments` methods to it.
  Subclasses (`PostWidget`, `CommentWidget`, `PostPage`) keep compiling without
  changes, while new code (services, previews) can construct an `EventView`
  directly without a widget context — which is what the original TODO requested.
  Also resolved the in-file `// TODO: rename to IEvent` by documenting why the
  `Widget` suffix is intentional (distinguishes it from the plain Matrix
  `Event` type, and the file is already in `interfaces/` so the lowercase
  `i_event.dart` filename is the only `I`-prefix the file    needs).
- **Decomposed `room_form_page.dart`** (1590 → 1021 lines, **−569 lines / −36%**)
  by extracting the following widgets to `lib/settings/widgets/`:
  - `RoomAvatarPicker` (avatar with camera overlay)
  - `RoomBasicInfoForm` (name / alias / topic)
  - `RoomDangerZone` (delete room)
  - `FormSectionCard` + `FormToggleTile` (shared building blocks)
  - `RoomSettingsSection` (visibility / encryption / substitution / blog)
  - `RoomMembersSection` + `MemberTile` + `BannedMemberTile`
  - The remaining planned extraction — `RoomFormController` (a `ChangeNotifier`
    that owns the form data and save/create logic) — is documented in the file's
    header comment for follow-up. It is not done because the form is now small
    enough (~1000 lines) that the existing in-State pattern is still readable,
    and a controller rewrite would touch every method.
- **Extracted `RoomFormController`** (ChangeNotifier) to
  `lib/settings/pages/room_form_controller.dart` — owns the form data
  (text controllers, settings toggles, invite list), the loaded room
  (room, members, banned members, error state), and all server-side
  mutations (create / save / loadRoom / kick / ban / unban /
  setPowerLevel / deleteRoom). The controller is intentionally
  `BuildContext`-free: UI side effects (snackbars, dialogs, navigation)
  stay in `RoomFormPage`, which implements the `RoomFormPrompter`
  interface for the dialogs the controller's mutation methods need.
  The page is now a thin shell (~693 lines down from ~1020) that
  instantiates the controller, wires it to the widgets via
  `ListenableBuilder`, and owns the UI. Resolves the
  "remaining planned extraction" item listed above.

### Changed
- **`filemessage.dart`**: the original `// TODO: change for ios, file types are unsupported`
  was a holdover from the `file_selector` v1.x days. The current
  `file_selector` v9+ (the version this project uses) fully supports
  `acceptedTypeGroups` on iOS via UTType. Replaced the TODO with a
  one-paragraph comment documenting that.
- **`matrix_essentials.dart`**: the original two TODOs (`icon picker
  is not really ideal` and `macros are released`) were both
  design observations rather than actionable code. Replaced them
  with a single design-note block explaining the history; the
  `MatrixEssentials` mixin above is the realized version.
- **`dialogdeleteserver.dart`**: the original `// todo: maybe we have
  to add a new flag to rooms` was a feature request to add a
  per-room `joined_via_substitution` flag so the dialog could just
  unset the flag instead of fully leaving the room. Replaced with a
  comment explaining why this is deferred (requires a Matrix spec
  change + schema migration) and what the current implementation
  does instead.
- **Applied the `SendWithRetry` mixin** to `textmessage.dart` and
  `filemessage.dart`, resolving the two stale "this is the same as
  in filemessage.dart" / "make it a mixin" TODOs that had been
  sitting in `textmessage.dart` since the write pages were
  refactored. Both `_send` methods now share the same retry loop
  pattern via the mixin. Added a new `navigateOnSuccess: true`
  parameter to the mixin so the file-message page can disable
  per-file navigation (it now navigates once at the end, mirroring
  the original behavior). The text-message `_send` shrank from
  ~70 lines to ~15 lines.
- **`main.dart`**: removed the stale `// TODO: have some ?goto=/feed/...`
  comment on the `/file/:roomid` route — the `?goto=` deep-link
  preservation was implemented earlier this session (see
  `ageAndAuthRedirect`). Replaced with a comment pointing at the
  real implementation.
- **`file_display.dart` and `file_display_container.dart`**:
  removed two stale TODOs (the "rename to FileDisplay" suggestion
  in the container — the pair `FileDisplay` (single) /
  `FileDisplayContainer` (list) is now self-explanatory; and the
  "downloadAndDecryptAttachment for encrypted files" comment —
  the per-file `FileDisplay` widget already handles decryption via
  `getDecryptedFileForEvent` / `getDecryptedFileObjectUrlForEvent`).
  Replaced each with a one-paragraph doc comment explaining where
  the functionality actually lives.

### Security
- The `?goto=` feature validates destination URLs via `safeGotoDestination()` which
  rejects: external URLs (`https://…`), protocol-relative URLs (`//evil.com`),
  `javascript:` / `data:` / `file:` schemes, and any auth page (to prevent redirect
  loops). 11 of the 35 new routing tests cover these security cases.

### Tests
- **Test count: 242 → 357** (+115 new tests across 9 new test files).
- Added `test/post/event_view_test.dart` (9 cases) covering the extracted
  `EventView` class: avatar URL helpers, username (with "unknown" fallback),
  `postEvent` defaulting, and the `comments` aggregator (deduplication by
  eventId, sort by `originServerTs` newest-first, empty list).
- Added `test/settings/room_form_controller_test.dart` (15 cases) covering
  the new `RoomFormController` ChangeNotifier: create-mode defaults,
  setter notification + no-op behavior, dispose, `loadRoom` happy path
  + missing-room + null-SubstitutionService fallback, `submit` (create)
  happy + error path, and all four member actions (kick, ban, unban,
  setPowerLevel) plus `deleteRoom` (each verifies the underlying Matrix
  SDK call and member-list refresh).

## [1.8.0] - 2026-06-03

### CI
- Skip E2E tests on direct push to `main`.
- Bumped to v1.8.0.

### Fixed
- Resolve v1.8.0 CI failures across web, linux, and android.

## [1.7.3] - 2026-05-15

### Fixed
- Keep feed saturation progressing.

## [1.7.2] - 2026-05-12

### Fixed
- Use `compileSdkVersion 36` (latest stable); preview SDK breaks cargokit.

## [1.7.1] - 2026-05-07

### Fixed
- Use `compileSdkPreview` for Android 16 (Baklava) API 37.
- Use full path to `sdkmanager` in CI for Android SDK 37 install.

## [1.7.0] - 2026-05-02

### Added
- **Background sync** for notifications and chat read receipts when the app is not in
  the foreground (uses WorkManager on Android, BGTaskScheduler on iOS, ~15 min intervals).
- **Full Security page** with cross-signing, SAS verification, key backup, and session
  management.
- **Chat read receipts** and feed pagination fixes.

### Changed
- **Bumped dependencies** to latest, raised iOS target to 14.0.
- **Pin `connectivity_plus` to 7.0.0** (7.1.0 uses iOS 26 SDK-only API).
- **iOS builds use Xcode 26**, Android compileSdk 37.
- **Fix `rootNavigatorKey` re-init crash** during integration test re-runs.

### Fixed
- Error handling for unsupported and bad-encrypted message types.
- Disable swipe-to-dismiss while zoomed so pinch-to-zoom works in fullscreen image viewer.
- Rename Help page to FAQ with updated route, icons, and translations.
- Restyle report submit buttons from green to orange for better UX.

## [1.6.6] - 2026-04-22

### Fixed
- Replace `pumpAndSettle` with explicit pumps in `app_test` to avoid timeout from
  Matrix sync loop.
- Pass empty string DSN to Sentry 9.x instead of null to avoid `ArgumentError`.
- Remove unused `workmanager` dependency (Kotlin 2.x incompatible).
- Upgrade `sentry_flutter` to 9.16.0 for Kotlin 2.x compatibility.
- Downgrade Kotlin plugin to 1.9.25 for `sentry_flutter` compatibility.

## [1.6.3] - 2026-04-15

### Changed
- Bumped version to 1.6.3+29.

### Fixed
- Enable core library desugaring for `flutter_local_notifications`.
- Add unique `heroTags` to FloatingActionButtons to prevent hero conflict.
- Resolve CI failures in Linux build and test teardown.

## [1.6.0] - 2026-04-08

### Added
- **Change post URL scheme to `/room/:roomId/:postId`** for cleaner shareable links.

### Changed
- Restyle emote posts as borderless inline rows; fix previews.

### Fixed
- Restore bottom nav and back button on room feed after posting.

## [1.5.0] - 2026-04-01

### Added
- **Search** for rooms on any server.
- **File uploads** as a first-class post type.
- **Edit / delete posts** (own posts only).
- **Room members page** with per-room member list.
- **Local notifications** for chat and follow feeds (no Firebase required).
- **Sentry integration** for crash reporting (self-hosted DSN configurable via
  `--dart-define=SENTRY_DSN=...`).

### Fixed
- Newly created rooms not showing in post selection; add substitution room toggle for
  existing rooms.
- Default new room visibility to private.
- Wrap `sendEvent` in try/catch across all write pages to prevent stuck loading dialog.
- 33 missing translation keys added to all 76 non-English locales.

## [1.4.1] - 2026-03-25

### Fixed
- Use `replaceText` instead of `document.insert` to enable send button in integration test.

## [1.4.0] - 2026-03-22

### Added
- **Overhaul of the new message page** with 5 new post types (text, file, location, voice,
  emote, sticker) and a unified, polished UX.
- **Help center / FAQ** with full i18n across 77 locales.
- **Deep link confirmation** dialog before navigating to user-supplied URLs.
- **Share buttons** for rooms, profiles, and posts.

### Fixed
- Full-bleed footer bar and Quill rich text editor on post detail page.
- Restore feed scroll position via `initialScrollOffset` instead of post-frame `jumpTo`.
- Defer `MxcImage` MediaQuery access to avoid `initState` error.
- Room select text overflow and use cached room lookup.
- Handle existing releases and allow tag deploys to GitHub Pages.
- Handle missing `captureScreenshot` channel on Linux desktop.
- Correct feed ordering, comment deduplication, and pagination efficiency.
- Resolve actionable TODOs — add missing i18n, null safety, and sync translations.
- Improve UI loading states, error handling, and navigation consistency.

## [1.3.6] - 2026-03-12

### Fixed
- Bumped version to 1.3.6+17.

## [1.3.5] - 2026-03-10

### Fixed
- Bumped version to 1.3.5+16.

## [1.3.4] - 2026-03-08

### Changed
- Bumped version to 1.3.4+15.
- Upgraded dependencies.

## [1.3.3] - 2026-03-05

### Fixed
- Use conditional imports for `package:web` to fix Linux/native builds.

## [1.3.2] - 2026-03-03

### Changed
- Bumped version to 1.3.2+13.
- Replaced `universal_html` with `package:web` for WASM compatibility.

## [1.3.0] - 2026-02-28

### Added
- **GitHub Pages web deployment** with WASM build.
- **Screenshots CI** for store listing assets.
- **Play Store description** updates.
- **Reddit-style fullscreen image viewer** with auto-hiding controls and share.
- **Replace create room dialog with full-page room form** for richer validation.

### Fixed
- Replace create room dialog with full-page room form.
- Lazy-build `FollowFeedSettings` to prevent background fetch loop in IndexedStack.
- Cache full `accountData` future transform to prevent FutureBuilder rebuild loop.
- Stop infinite `pumpAndSettle` loop in `HomePage` feed paging listener.
- Stop infinite `pumpAndSettle` loop caused by `FollowFeeds` paging listener.

## [1.2.x] - 2026-02 series

### Added
- Full-bleed footer bar and Quill rich text editor on post detail page.
- Prompt user to join the Substitution startroom on every login.

### Fixed
- Resolve broken profile images by adding authenticated media support.
- Replace reactions spinner with `SizedBox.shrink` and cache future.
- Stop infinite `pumpAndSettle` loop in feed paging listener.
- Skip feed prepend while page fetch in progress to break `pumpAndSettle` loop.
- Reduce `queryPublicRooms` timeout to 8s and decouple refresh from `setState`.
- Resolve `flutter analyze` warnings (unused_element, unnecessary_underscores).

## [1.0.0] - 2025-12 (initial public release)

### Added
- Initial public release of Substitution — a decentralized social network on the
  Matrix protocol.
- Cross-platform support: Android, iOS, Web, Linux, macOS, Windows.
- Core features:
  - Decentralized homeserver selection at first launch.
  - Public Substitution room on `substitution.art:matrix.org` (room ID
    `#substitution.art:matrix.org`).
  - Posts: text, image, video, file, location, voice, emote, sticker, rich-text.
  - Fine-grained posting control: only accounts with power level > 50 can post.
  - Comments and reactions on posts and comments.
  - Follow any room on any server, search for rooms, manage joined feeds.
  - E2E encryption support (where the homeserver / room allows).
  - Age gate and GDPR-compliant privacy controls.
  - 77-language UI localization.

[Unreleased]: https://github.com/floffel/substitution/compare/v1.8.0...HEAD
[1.8.0]: https://github.com/floffel/substitution/compare/v1.7.3...v1.8.0
[1.7.3]: https://github.com/floffel/substitution/compare/v1.7.2...v1.7.3
[1.7.2]: https://github.com/floffel/substitution/compare/v1.7.1...v1.7.2
[1.7.1]: https://github.com/floffel/substitution/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/floffel/substitution/compare/v1.6.6...v1.7.0
[1.6.6]: https://github.com/floffel/substitution/compare/v1.6.3...v1.6.6
[1.6.3]: https://github.com/floffel/substitution/compare/v1.6.0...v1.6.3
[1.6.0]: https://github.com/floffel/substitution/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/floffel/substitution/compare/v1.4.1...v1.5.0
[1.4.1]: https://github.com/floffel/substitution/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/floffel/substitution/compare/v1.3.6...v1.4.0
[1.3.6]: https://github.com/floffel/substitution/compare/v1.3.5...v1.3.6
[1.3.5]: https://github.com/floffel/substitution/compare/v1.3.4...v1.3.5
[1.3.4]: https://github.com/floffel/substitution/compare/v1.3.3...v1.3.4
[1.3.3]: https://github.com/floffel/substitution/compare/v1.3.2...v1.3.3
[1.3.2]: https://github.com/floffel/substitution/compare/v1.3.0...v1.3.2
[1.3.0]: https://github.com/floffel/substitution/compare/v1.2.9...v1.3.0
[1.0.0]: https://github.com/floffel/substitution/releases/tag/v1.0.0
