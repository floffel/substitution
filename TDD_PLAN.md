# TDD Plan - Substitution

> **Last updated:** 2026-02-14
> **Relates to:** [USER_STORIES.md](./USER_STORIES.md)

This document defines the test-driven development plan for every user story in Substitution. It is designed so that multiple developers or agents can work on different work items **concurrently** without conflicts.

---

## Table of Contents

- [How to Use This Document](#how-to-use-this-document)
- [Status Legend](#status-legend)
- [Implementation Status Overview](#implementation-status-overview)
- [WI-0: Test Infrastructure (prerequisite)](#wi-0-test-infrastructure)
- [Epic 1: Onboarding & Identity](#epic-1-onboarding--identity)
- [Epic 2: Discovery & Subscriptions](#epic-2-discovery--subscriptions)
- [Epic 3: The Feed (Consumption)](#epic-3-the-feed-consumption)
- [Epic 4: Engagement & Interaction](#epic-4-engagement--interaction)
- [Epic 5: Content Creation](#epic-5-content-creation)
- [Epic 6: Privacy & Settings](#epic-6-privacy--settings)
- [Recommended Execution Order](#recommended-execution-order)
- [Final Test File Structure](#final-test-file-structure)

---

## How to Use This Document

1. **Claim a work item** by writing your name/agent-id in the `Assigned to` field and setting status to `IN PROGRESS`.
2. **Check dependencies** before starting — some items require `WI-0` (test infrastructure) to be completed first.
3. **Follow TDD discipline:** write the failing tests first, then implement code to make them pass, then refactor.
4. **Each work item is independent** unless explicitly noted in its `Dependencies` field. Multiple items can be worked on in parallel.
5. **Mark as DONE** when all tests pass and code is implemented. Run `flutter test` to verify nothing is broken.

### Branch Naming Convention

```
tdd/<work-item-id>    e.g. tdd/wi-0, tdd/us-1.4, tdd/us-6.3
```

### Merge Order

Merge `WI-0` first. After that, work items can be merged in any order unless dependencies say otherwise.

---

## Status Legend

| Status | Meaning |
|--------|---------|
| `NOT STARTED` | No one is working on this yet |
| `IN PROGRESS` | Claimed and actively being worked on |
| `DONE` | Tests pass, code complete, merged |
| `BLOCKED` | Waiting on a dependency |

---

## Implementation Status Overview

| Story | Description | Code Exists? | Tests Exist? | Work Item | Status |
|-------|------------|:------------:|:------------:|-----------|--------|
| — | Test infrastructure | — | — | WI-0 | `NOT STARTED` |
| US-1.1 | Choose homeserver | Yes | Smoke only | WI-1.1 | `NOT STARTED` |
| US-1.2 | Login with credentials | Yes | Smoke only | WI-1.2 | `NOT STARTED` |
| US-1.3 | Persistent session | Yes | No | WI-1.3 | `NOT STARTED` |
| US-1.4 | Edit profile | **No** | No | WI-1.4 | `NOT STARTED` |
| US-2.1 | Search public rooms | Yes | Smoke only | WI-2.1 | `NOT STARTED` |
| US-2.2 | Follow/join room | Yes | No | WI-2.2 | `NOT STARTED` |
| US-2.3 | Unfollow/leave room | Yes | No | WI-2.3 | `NOT STARTED` |
| US-2.4 | View room feed | Yes | No | WI-2.4 | `NOT STARTED` |
| US-3.1 | Unified timeline | Yes | Smoke only | WI-3.1 | `NOT STARTED` |
| US-3.2 | Infinite scroll | Yes | No | WI-3.2 | `NOT STARTED` |
| US-3.3 | Rich media previews | Yes | No | WI-3.3 | `NOT STARTED` |
| US-3.4 | Offline caching | **Partial** | No | WI-3.4 | `NOT STARTED` |
| US-4.1 | React with emojis | Yes | No | WI-4.1 | `NOT STARTED` |
| US-4.2 | See reaction counts | Yes | No | WI-4.2 | `NOT STARTED` |
| US-4.3 | Reply/thread | Yes | No | WI-4.3 | `NOT STARTED` |
| US-4.4 | Tap avatar for profile | **No** | No | WI-4.4 | `NOT STARTED` |
| US-5.1 | Compose text posts | Yes | Smoke only | WI-5.1 | `NOT STARTED` |
| US-5.2 | Upload images/videos | Yes | Smoke only | WI-5.2 | `NOT STARTED` |
| US-5.3 | Create new room | Yes | No | WI-5.3 | `NOT STARTED` |
| US-5.4 | Set room permissions | **Partial** | No | WI-5.4 | `NOT STARTED` |
| US-6.1 | Clear local cache | **No** | No | WI-6.1 | `NOT STARTED` |
| US-6.2 | Verify encryption keys | **No** | No | WI-6.2 | `NOT STARTED` |
| US-6.3 | Light/dark mode toggle | **No** | No | WI-6.3 | `NOT STARTED` |

---

## WI-0: Test Infrastructure

| Field | Value |
|-------|-------|
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | None |
| **Blocks** | All other work items |
| **Estimated effort** | Small |

### Goal

Create shared test utilities to eliminate duplication across all test files.

### Files to Create

#### `test/helpers/test_helpers.dart`

```dart
// Shared mock classes (eliminate duplication from 8+ test files)
class MockClient extends Mock implements Client {}
class MockRoom extends Mock implements Room {}
class MockEvent extends Mock implements Event {}
class MockUser extends Mock implements User {}

// Widget wrapper helper
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Client? mockClient,
  GoRouter? router,
}) async { ... }

// Factory helpers
MockRoom createMockRoom({String name, String id, Uri? avatar, int powerLevel});
MockEvent createMockEvent({String type, String body, String? formattedText, Room room, User sender});
MockUser createMockUser({String id, String displayName});
```

**Details:**
- `pumpApp` wraps the child in `EasyLocalization` + `MultiProvider<Client>` + `MaterialApp` (or `MaterialApp.router` if router is provided)
- Contains the common `setUpAll` logic: `SharedPreferences.setMockInitialValues({})` and `EasyLocalization.ensureInitialized()`
- All existing 8 test files should be refactored to use these helpers (but this is optional and can be done incrementally)

#### `test/helpers/mock_router.dart`

```dart
// GoRouter test helpers for verifying navigation
GoRouter createMockRouter({String initialLocation = '/'});
// Utility to verify that a route was pushed
```

### Acceptance Criteria

- [ ] `test/helpers/test_helpers.dart` exists with `MockClient`, `MockRoom`, `MockEvent`, `MockUser`, `pumpApp`, and factory helpers
- [ ] `test/helpers/mock_router.dart` exists with `createMockRouter`
- [ ] `flutter test` passes (no regressions in existing tests)

---

## Epic 1: Onboarding & Identity

---

### WI-1.1: Choose Homeserver (behavioral tests for existing code)

| Field | Value |
|-------|-------|
| **User Story** | US-1.1 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source file** | `lib/auth/pages/host.dart` |
| **Estimated effort** | Small |

#### Unit Tests — `test/unit/homeserver_validation_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Valid homeserver URL passes check | `client.checkHomeserver(Uri.parse('https://matrix.org'))` is called; `onComplete` fires |
| 2 | Invalid URL shows error | Mock `checkHomeserver` to throw; verify `AlertDialog` appears |
| 3 | Empty input is rejected | Verify form validation prevents submission |
| 4 | Default value is `matrix.org` | `TextFormField` initial value equals `matrix.org` |

#### Widget Tests — `test/auth/host_page_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Smoke: renders text field and submit button | `find.byType(TextFormField)`, `find.byType(ElevatedButton)` |
| 2 | Entering URL and tapping submit calls `checkHomeserver` | Enter text, tap button, `verify(() => client.checkHomeserver(...))` |
| 3 | Successful check calls `onComplete` | Mock success, verify callback fired |
| 4 | Failed check shows error dialog | Mock throw, verify `find.byType(AlertDialog)` |
| 5 | Loading state shows indicator | After tap, verify `CircularProgressIndicator` before async completes |

#### Integration Test — `integration_test/onboarding_flow_test.dart` (shared with WI-1.2, WI-1.3)

| # | Test Case |
|---|-----------|
| 1 | Start at introduction -> navigate to host selection -> enter homeserver -> verify navigation to login |

---

### WI-1.2: Login with Matrix Credentials (behavioral tests for existing code)

| Field | Value |
|-------|-------|
| **User Story** | US-1.2 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source file** | `lib/auth/pages/login.dart` |
| **Estimated effort** | Small |

#### Unit Tests — `test/unit/login_logic_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Login call uses correct parameters | `client.login(LoginType.mLoginPassword, identifier: ..., password: ...)` called with entered values |
| 2 | SSO URL is constructed correctly | Verify URL contains homeserver + `/_matrix/client/v3/login/sso/redirect` + correct redirect URI |

#### Widget Tests — `test/auth/login_page_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | **Existing smoke test** — keep as-is | `LoginPage` renders, 2 `TextFormField`s, 1 `ElevatedButton` |
| 2 | Enter credentials + tap login -> calls `client.login()` | `verify(() => mockClient.login(...))` with correct args |
| 3 | Successful login calls `onComplete` | Mock success, verify callback |
| 4 | Failed login shows error dialog | Mock throw, verify `AlertDialog` appears |
| 5 | Empty fields show validation errors | Tap login without input, verify form errors |
| 6 | Loading indicator during login | Verify `CircularProgressIndicator` while async pending |
| 7 | SSO button visible when flows include SSO | Mock `loginFlows` to include SSO type, verify button |

#### Integration Test — part of `integration_test/onboarding_flow_test.dart`

| # | Test Case |
|---|-----------|
| 1 | Host -> login with credentials -> verify client is logged in -> navigates to feed |

---

### WI-1.3: Persistent Session (tests for existing code)

| Field | Value |
|-------|-------|
| **User Story** | US-1.3 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source file** | `lib/main.dart` (client init logic) |
| **Estimated effort** | Small |

#### Unit Tests — `test/unit/session_persistence_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Client is initialized with database store name `substitution_store` | Verify constructor args |
| 2 | `client.init()` is called during app startup | Verify init is invoked |
| 3 | Logged-in state persists through database | Mock `client.isLogged()` -> true after init |

#### Widget Tests — `test/main/app_startup_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | If `client.isLogged() == true`, router redirects to `/feed` | Verify no auth flow shown |
| 2 | If `client.isLogged() == false`, router shows introduction/auth | Verify `IntroductionPage` or auth route |

---

### WI-1.4: Edit Profile (NEW FEATURE — full TDD)

| Field | Value |
|-------|-------|
| **User Story** | US-1.4 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source files to create** | `lib/settings/pages/profile.dart` |
| **Source files to modify** | `lib/main.dart` (add route), `lib/settings/widgets/menu.dart` (add menu entry) |
| **Estimated effort** | Medium |

#### Implementation Details

**New file `lib/settings/pages/profile.dart`** — `ProfilePage` StatefulWidget:
- Fetch current profile via `client.getProfileFromUserId(client.userID!)` or `client.ownProfile`
- Display current avatar (circular, with fallback)
- `TextFormField` for display name, pre-filled with current value
- Avatar picker button using `file_selector` to pick an image
- "Save" `ElevatedButton`:
  - Calls `client.setDisplayName(newName)` if name changed
  - Calls `client.setAvatar(MatrixFile(...))` if avatar changed
- Show `SnackBar` on success, `AlertDialog` on error
- `CircularProgressIndicator` while saving

**Route addition in `lib/main.dart`**:
```dart
GoRoute(
  path: '/settings/profile',
  builder: (context, state) => const ScaffoldWithNavigation(child: ProfilePage()),
),
```

**Menu update in `lib/settings/widgets/menu.dart`**:
- Add `ListTile` with `Icons.person` and text "Edit Profile" that navigates to `/settings/profile`
- Show only when `client.isLogged()` is true

#### Unit Tests — `test/unit/profile_update_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | `setDisplayName` called with correct value | Mock client, call update, verify |
| 2 | `setAvatar` called with correct `MatrixFile` | Mock client, verify file data |
| 3 | Empty display name is rejected | Verify validation prevents save |

#### Widget Tests — `test/settings/profile_page_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Smoke: renders display name field, avatar, save button | `find.byType(TextFormField)`, `find.byType(ElevatedButton)` |
| 2 | Displays current profile data | Name field shows `client.profile.displayName` |
| 3 | Edit name + tap save -> calls `setDisplayName()` | Enter new name, tap save, verify |
| 4 | Tap avatar -> opens file picker | Verify file picker dialog |
| 5 | Select file + save -> calls `setAvatar()` | Mock file selection, tap save, verify |
| 6 | Success shows SnackBar | Mock success, verify `SnackBar` |
| 7 | Error shows AlertDialog | Mock throw, verify `AlertDialog` |
| 8 | Loading state during save | Verify `CircularProgressIndicator` |

#### Integration Test — `integration_test/profile_edit_test.dart`

| # | Test Case |
|---|-----------|
| 1 | Menu -> "Edit Profile" -> edit name -> save -> verify updated |

---

## Epic 2: Discovery & Subscriptions

---

### WI-2.1: Search Public Rooms (behavioral tests for existing code)

| Field | Value |
|-------|-------|
| **User Story** | US-2.1 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source file** | `lib/settings/pages/followfeeds.dart` |
| **Estimated effort** | Medium |

#### Unit Tests — `test/unit/room_search_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | `queryPublicRooms` called with correct server and search term | Verify args |
| 2 | Pagination: `since` token is passed for next page | Verify second call includes `since` |
| 3 | Race condition: outdated response is discarded | Trigger two searches rapidly, verify only latest response is used |

#### Widget Tests — `test/settings/followfeeds_search_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | **Existing smoke test** — keep as-is | Widget renders, add icon visible |
| 2 | Entering text triggers room search | Enter text, verify `queryPublicRooms` called |
| 3 | Search results displayed as `RoomWidget` list | Mock results, verify `RoomWidget` count |
| 4 | Empty results shows appropriate state | Mock empty response, verify empty state |
| 5 | Switching server chip triggers new search | Tap different chip, verify new query |
| 6 | Add server button opens `DialogAddServer` | Tap add icon, verify dialog |
| 7 | Scrolling to bottom loads next page | Scroll, verify `PagingController` fetches |

#### Integration Test — `integration_test/discovery_flow_test.dart` (shared with WI-2.2, WI-2.3)

| # | Test Case |
|---|-----------|
| 1 | Navigate to follow feeds -> add server -> search rooms -> see results |

---

### WI-2.2: Follow/Join a Room (tests for existing code)

| Field | Value |
|-------|-------|
| **User Story** | US-2.2 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source file** | `lib/settings/pages/followfeeds.dart` |
| **Estimated effort** | Small |

#### Unit Tests — `test/unit/room_join_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | `client.joinRoom(roomId)` is called | Verify correct room ID |
| 2 | Account data `{"joined": true}` set after join | Verify `setAccountData('substitution', roomId, ...)` |
| 3 | `isRoomInSubstitution()` returns true after join | Call extension, assert true |

#### Widget Tests — `test/settings/followfeeds_join_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Tap join icon on unjoined room -> calls `joinRoom()` | Tap icon, verify |
| 2 | After successful join, widget shows leave icon | Verify icon change |
| 3 | Join failure shows error feedback | Mock throw, verify SnackBar or dialog |

---

### WI-2.3: Unfollow/Leave a Room (tests for existing code)

| Field | Value |
|-------|-------|
| **User Story** | US-2.3 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source file** | `lib/settings/pages/followfeeds.dart` |
| **Estimated effort** | Small |

#### Unit Tests — `test/unit/room_leave_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | `client.leaveRoom(roomId)` is called | Verify correct room ID |
| 2 | Account data updated to remove substitution flag | Verify `setAccountData` call |

#### Widget Tests — `test/settings/followfeeds_leave_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Tap leave icon on joined room -> calls `leaveRoom()` | Tap icon, verify |
| 2 | After leaving, widget shows join icon | Verify icon change |
| 3 | Leave failure shows error feedback | Mock throw, verify |

---

### WI-2.4: View Room Feed in Isolation (tests for existing code)

| Field | Value |
|-------|-------|
| **User Story** | US-2.4 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source files** | `lib/feed/feed.dart`, `lib/feed/pages/home.dart` |
| **Estimated effort** | Small |

#### Widget Tests — `test/feed/room_feed_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Smoke: renders `HomePage` with `roomId` parameter | Widget exists |
| 2 | Only events from specified room are displayed | Mock 2 rooms, pass 1 roomId, verify only its events show |
| 3 | Room name appears in header/AppBar | Verify room name text |
| 4 | Navigation back returns to main feed | Tap back, verify route |

#### Integration Test — `integration_test/room_feed_test.dart`

| # | Test Case |
|---|-----------|
| 1 | Main feed -> tap room-specific link -> verify only that room's posts show |

---

## Epic 3: The Feed (Consumption)

---

### WI-3.1: Unified Timeline (behavioral tests for existing code)

| Field | Value |
|-------|-------|
| **User Story** | US-3.1 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source file** | `lib/feed/pages/home.dart` |
| **Estimated effort** | Medium |

#### Unit Tests — `test/unit/timeline_merge_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Events from multiple rooms sorted by `originServerTs` descending | Create mock events with different timestamps, verify order |
| 2 | Only `m.room.message` events pass filter | Mix event types, verify only messages returned |
| 3 | Replies/threads/edits excluded | Create events with `m.relates_to`, verify excluded |
| 4 | Only sender power level >= 50 events shown | Mock power levels, verify filter |
| 5 | Only rooms with `substitution` account data included | Mock account data, verify room filter |

#### Widget Tests — `test/feed/home_page_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | **Existing smoke test** — extend | Keep existing assertions |
| 2 | Posts from multiple rooms appear in chronological order | Mock 2 rooms with events, verify display order |
| 3 | Each post shows room name, author, content | Verify text content in `PostWidget` |
| 4 | Tapping a post navigates to `/post/:id` | Tap `PostWidget`, verify navigation |
| 5 | Pull-to-refresh fetches new events | Perform drag-down gesture, verify refresh |

#### Integration Test — `integration_test/feed_test.dart`

| # | Test Case |
|---|-----------|
| 1 | Log in -> see feed -> verify posts from multiple rooms appear sorted |

---

### WI-3.2: Infinite Scroll (tests for existing code)

| Field | Value |
|-------|-------|
| **User Story** | US-3.2 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source file** | `lib/feed/pages/home.dart` |
| **Estimated effort** | Small |

#### Widget Tests — `test/feed/infinite_scroll_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Initial load fetches first page | Verify `PagingController` fetches page 1 |
| 2 | Scrolling to bottom triggers next page fetch | Scroll down, verify second fetch |
| 3 | Loading indicator shown during fetch | Verify `CircularProgressIndicator` |
| 4 | No more events -> no loading indicator | Mock last page, verify no indicator |
| 5 | Error state shows retry option | Mock error, verify retry widget |

---

### WI-3.3: Rich Media Previews (tests for existing code)

| Field | Value |
|-------|-------|
| **User Story** | US-3.3 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source files** | `lib/post/widgets/display/file_display.dart`, `lib/post/widgets/display/file_display_container.dart` |
| **Estimated effort** | Medium |

#### Widget Tests — `test/post/file_display_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Smoke: `FileDisplay` renders for image message type | Widget exists |
| 2 | Smoke: `FileDisplay` renders for video message type | Widget exists |
| 3 | Image events show image widget | Verify image widget present |
| 4 | Video events show `VideoPlayer` with controls | Verify `VideoPlayer` + overlay |
| 5 | `FileDisplayContainer` shows carousel for multi-file | Mock multiple files, verify `CarouselSlider` |
| 6 | Tapping image opens fullscreen `DismissiblePage` | Tap, verify dialog |

#### Widget Tests — `test/post/post_widget_media_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | `PostWidget` with `m.image` shows `FileDisplayContainer` | Verify container present |
| 2 | `PostWidget` with `m.video` shows `FileDisplayContainer` | Verify container present |
| 3 | `PostWidget` with `m.text` + HTML shows formatted body | Verify HTML rendering |

---

### WI-3.4: Offline Caching (PARTIAL — needs implementation + tests)

| Field | Value |
|-------|-------|
| **User Story** | US-3.4 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source files to create** | `lib/shared/services/connectivity_service.dart` |
| **Source files to modify** | `lib/feed/pages/home.dart`, `lib/main.dart` (add provider) |
| **New dependency** | `connectivity_plus` (add to `pubspec.yaml`) |
| **Estimated effort** | Large |

#### Implementation Details

**New file `lib/shared/services/connectivity_service.dart`** — `ConnectivityService`:
- Wraps `connectivity_plus` plugin
- `Stream<bool> get onConnectivityChanged` — emits true/false
- `Future<bool> get isOnline` — checks current state
- Expose as a `Provider` or `ChangeNotifierProvider`

**Modify `lib/feed/pages/home.dart`**:
- On initial load, first display events from local Matrix SDK database (already cached by the SDK)
- Attempt network fetch in background; update UI when data arrives
- When offline (`ConnectivityService.isOnline == false`), show an "Offline — showing cached content" banner (e.g., `MaterialBanner` or `SnackBar`)
- When network request fails, fall back to cached data with an error indicator

**Modify `lib/main.dart`**:
- Add `ConnectivityService` to `MultiProvider`

#### Unit Tests — `test/unit/connectivity_service_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | `isOnline` returns true when connected | Mock connectivity, assert |
| 2 | `isOnline` returns false when disconnected | Mock no connectivity, assert |
| 3 | Stream emits correct events on change | Listen to stream, toggle connectivity, verify emissions |

#### Widget Tests — `test/feed/offline_mode_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | When offline, cached posts are still displayed | Mock offline + cached events, verify `PostWidget`s |
| 2 | When offline, "offline" banner is shown | Verify banner/indicator widget |
| 3 | When coming back online, new posts are fetched | Toggle to online, verify fetch |
| 4 | Network failure with cached data shows error indicator | Mock throw + cached data, verify indicator |

#### Integration Test — `integration_test/offline_test.dart`

| # | Test Case |
|---|-----------|
| 1 | Load feed online -> simulate offline -> cached posts visible -> back online -> refresh works |

---

## Epic 4: Engagement & Interaction

---

### WI-4.1: React with Emojis (tests for existing code)

| Field | Value |
|-------|-------|
| **User Story** | US-4.1 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source files** | `lib/post/mixins/iconpicker.dart`, `lib/post/widgets/post.dart`, `lib/post/widgets/comment.dart` |
| **Estimated effort** | Small |

#### Unit Tests — `test/unit/reaction_send_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | `event.room.sendReaction(eventId, emoji)` called with correct params | Mock room, verify call |
| 2 | Emoji picker selection maps to correct Unicode key | Verify selected emoji string |

#### Widget Tests — `test/post/reaction_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Tap reaction icon on `PostWidget` opens emoji picker | Tap icon, verify `EmojiPicker` dialog |
| 2 | Selecting emoji calls `sendReaction()` | Select emoji, verify call |
| 3 | Emoji picker dialog can be dismissed | Dismiss dialog, verify closed |
| 4 | Same behavior on `CommentWidget` | Repeat tests for comment |

---

### WI-4.2: See Reaction Counts (tests for existing code)

| Field | Value |
|-------|-------|
| **User Story** | US-4.2 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source file** | `lib/post/widgets/display/reactions_display.dart` |
| **Estimated effort** | Small |

#### Unit Tests — `test/unit/reaction_aggregation_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Multiple reactions with same emoji counted correctly | Group 3 thumbs-up -> count = 3 |
| 2 | User IDs tracked per reaction | Verify list of user IDs per emoji key |
| 3 | Duplicate reactions from same user deduplicated | Same user, same emoji -> count = 1 |

#### Widget Tests — `test/post/reactions_display_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Smoke: renders with mock reactions | `find.byType(ReactionsDisplay)` |
| 2 | Displays correct emoji with correct count | Find emoji text, verify count |
| 3 | Tooltip shows usernames | Long-press/hover, verify tooltip content |
| 4 | Long-press own reaction shows redact option | Long-press own, verify redact |
| 5 | Redact calls `room.redactEvent(reactionEventId)` | Tap redact, verify call |
| 6 | No reactions renders empty | Mock empty reactions, verify nothing rendered |

---

### WI-4.3: Reply to a Post (tests for existing code)

| Field | Value |
|-------|-------|
| **User Story** | US-4.3 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source files** | `lib/post/widgets/post.dart`, `lib/write/pages/textmessage.dart`, `lib/post/pages/post.dart`, `lib/post/widgets/comment.dart` |
| **Estimated effort** | Medium |

#### Widget Tests — `test/post/reply_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Tap reply icon on `PostWidget` -> navigates to write page with `eventId` query param | Verify navigation |
| 2 | `TextMessageWrite` with `eventId` shows original post | Verify `PostWidget` displayed |
| 3 | Sending reply includes `m.relates_to` with `m.in_reply_to` | Verify `room.sendEvent()` args |
| 4 | Replies appear as `CommentWidget` on post page | Mock timeline with reply, verify |

#### Widget Tests — `test/post/comment_threading_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | `PostPage` loads comments via timeline | Mock timeline with replies, verify `CommentWidget` count |
| 2 | Nested comments render with left border indentation | Verify `Container` with left border |
| 3 | Comments are collapsible via tap | Tap comment, verify body collapsed |

---

### WI-4.4: Tap Avatar for Profile (NEW FEATURE — full TDD)

| Field | Value |
|-------|-------|
| **User Story** | US-4.4 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source files to create** | `lib/profile/pages/user_profile.dart` |
| **Source files to modify** | `lib/main.dart` (add route), `lib/post/widgets/post.dart` (make avatar tappable), `lib/post/widgets/comment.dart` (make avatar tappable) |
| **Estimated effort** | Medium |

#### Implementation Details

**New file `lib/profile/pages/user_profile.dart`** — `UserProfilePage` StatefulWidget:
- Takes `userId` parameter
- Fetches profile via `client.getProfileFromUserId(userId)`
- Displays: large avatar, display name, Matrix ID (`@user:server`)
- Lists rooms where user has power level >= 50 and room is in substitution (user's "feeds")
- Each room is a tappable `ListTile` navigating to `/feed/:roomId`
- Loading state with `FutureBuilder`
- Error state for invalid/unknown user

**Route addition in `lib/main.dart`**:
```dart
GoRoute(
  path: '/profile/:userId',
  builder: (context, state) {
    final userId = state.pathParameters['userId']!;
    return ScaffoldWithNavigation(child: UserProfilePage(userId: userId));
  },
),
```

**Modify `lib/post/widgets/post.dart`**:
- Wrap the avatar `CircleAvatar` / `ClipOval` with `GestureDetector` or `InkWell`
- On tap: `context.push('/profile/${Uri.encodeComponent(userId)}')`

**Modify `lib/post/widgets/comment.dart`**:
- Same avatar wrapping as above

#### Unit Tests — `test/unit/user_profile_fetch_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | `client.getProfileFromUserId(userId)` is called | Verify call with correct ID |
| 2 | Rooms filtered to show only rooms where user is creator | Mock rooms with various power levels, verify filter |

#### Widget Tests — `test/profile/user_profile_page_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Smoke: renders avatar, display name, Matrix ID | Verify widgets present |
| 2 | Shows list of rooms user posts in | Mock rooms, verify `ListTile` count |
| 3 | Tapping a room navigates to `/feed/:roomId` | Tap, verify navigation |
| 4 | Loading state while fetching | Verify `CircularProgressIndicator` |
| 5 | Error state for invalid user ID | Mock throw, verify error message |

#### Widget Tests — `test/post/avatar_tap_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Tapping avatar on `PostWidget` navigates to `/profile/:userId` | Tap avatar, verify navigation |
| 2 | Tapping avatar on `CommentWidget` navigates to `/profile/:userId` | Tap avatar, verify navigation |

#### Integration Test — `integration_test/profile_view_test.dart`

| # | Test Case |
|---|-----------|
| 1 | View post -> tap avatar -> see profile -> tap their room -> see room feed |

---

## Epic 5: Content Creation

---

### WI-5.1: Compose Text Posts (behavioral tests for existing code)

| Field | Value |
|-------|-------|
| **User Story** | US-5.1 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source file** | `lib/write/pages/textmessage.dart` |
| **Estimated effort** | Medium |

#### Widget Tests — `test/write/textmessage_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | **Existing smoke test** — keep | Widget renders, `ListTile` present |
| 2 | Quill editor is present and accepts text input | Find `QuillEditor`, enter text |
| 3 | Bold/italic toolbar buttons apply formatting | Tap bold, verify delta |
| 4 | Tap send -> converts delta to HTML, calls `room.sendEvent()` | Verify `sendEvent` with `m.room.message`, `formatted_body` |
| 5 | Message contains both plain text and HTML body | Verify both `body` and `formatted_body` in event content |
| 6 | When replying, `m.relates_to` is included | Set `eventId`, verify relation in args |
| 7 | Successful send navigates away | Mock success, verify navigation |
| 8 | Failed send shows retry dialog | Mock throw, verify dialog |
| 9 | Cancel during retry navigates back | Tap cancel, verify navigation |

---

### WI-5.2: Upload Images/Videos (behavioral tests for existing code)

| Field | Value |
|-------|-------|
| **User Story** | US-5.2 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source file** | `lib/write/pages/filemessage.dart` |
| **Estimated effort** | Medium |

#### Widget Tests — `test/write/filemessage_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | **Existing smoke test** — keep | Widget renders, `ListTile` present |
| 2 | File picker button present | Find pick button |
| 3 | Selected files appear in preview list with title fields | Mock file selection, verify list |
| 4 | Editing a file title updates data | Enter text in title field, verify |
| 5 | Tap send -> calls `room.sendFileEvent()` for each file | Verify call count matches file count |
| 6 | Multi-file upload links via `RelationshipTypes.reference` | Verify relation in subsequent uploads |
| 7 | Upload failure shows retry/cancel dialog per file | Mock throw, verify dialog |
| 8 | Successful upload navigates away | Mock success, verify navigation |

---

### WI-5.3: Create a New Room (tests for existing code)

| Field | Value |
|-------|-------|
| **User Story** | US-5.3 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source file** | `lib/settings/widgets/dialogcreateroom.dart` |
| **Estimated effort** | Small |

#### Widget Tests — `test/settings/dialog_create_room_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Smoke: renders name, alias, topic fields and create button | Find 3 `TextFormField`s, 1 button |
| 2 | Enter details + tap create -> calls `client.createRoom()` | Verify args: `name`, `roomAliasName`, `topic`, `visibility: public` |
| 3 | After creation, `setAccountData('substitution', roomId, {"joined": true})` called | Verify account data set |
| 4 | Successful creation closes dialog | Verify dialog dismissed |
| 5 | Empty name shows validation error | Tap create without name, verify error |
| 6 | Creation failure shows error dialog | Mock throw, verify `AlertDialog` |
| 7 | Loading state during creation | Verify `CircularProgressIndicator` |

---

### WI-5.4: Set Room Permissions (PARTIAL — needs implementation + tests)

| Field | Value |
|-------|-------|
| **User Story** | US-5.4 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source files to create** | `lib/settings/pages/room_permissions.dart` |
| **Source files to modify** | `lib/main.dart` (add route), `lib/settings/pages/ownfeeds.dart` (add link), `lib/settings/widgets/roomwidget.dart` (add settings icon) |
| **Estimated effort** | Large |

#### Implementation Details

**New file `lib/settings/pages/room_permissions.dart`** — `RoomPermissionsPage` StatefulWidget:
- Takes `roomId` parameter
- Fetches room via `client.getRoomById(roomId)`
- Shows current power levels from `room.getState('m.room.power_levels')`
- **Blog/Community toggle:**
  - "Blog" mode: `events_default: 50` (only admins can post)
  - "Community" mode: `events_default: 0` (anyone can post)
  - Toggle calls `room.setRoomStateWithKey('m.room.power_levels', '', updatedContent)`
- **Member list:** Shows room members with current power levels
- **Change power level:** Tap member -> slider/dropdown to set power level -> calls `room.setPower(userId, level)`
- Only accessible to users with power level >= 100 (room admin)

**Route addition in `lib/main.dart`**:
```dart
GoRoute(
  path: '/settings/room/:roomId/permissions',
  builder: (context, state) {
    final roomId = state.pathParameters['roomId']!;
    return ScaffoldWithNavigation(child: RoomPermissionsPage(roomId: roomId));
  },
),
```

**Modify `lib/settings/widgets/roomwidget.dart`**:
- Add gear/settings `IconButton` for rooms where current user is admin
- On tap: navigate to `/settings/room/:roomId/permissions`

#### Unit Tests — `test/unit/room_permissions_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | `room.setPower(userId, level)` called correctly | Verify args |
| 2 | Blog mode sets `events_default: 50` | Verify state content |
| 3 | Community mode sets `events_default: 0` | Verify state content |
| 4 | Only room admins (power >= 100) can change permissions | Verify access check |

#### Widget Tests — `test/settings/room_permissions_page_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Smoke: renders blog/community toggle, member list | Find `Switch`/`ToggleButtons`, `ListView` |
| 2 | Toggle to blog -> calls `setRoomStateWithKey` with `events_default: 50` | Verify call |
| 3 | Toggle to community -> sets `events_default: 0` | Verify call |
| 4 | Member list shows current power levels | Verify text content |
| 5 | Changing member power level calls `setPower()` | Interact, verify call |
| 6 | Non-admin users see read-only view | Mock low power, verify no toggle/edit |

#### Integration Test — `integration_test/room_permissions_test.dart`

| # | Test Case |
|---|-----------|
| 1 | Create room -> navigate to permissions -> switch to community -> verify -> switch to blog -> verify |

---

## Epic 6: Privacy & Settings

---

### WI-6.1: Clear Local Cache (NEW FEATURE — full TDD)

| Field | Value |
|-------|-------|
| **User Story** | US-6.1 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source files to create** | `lib/settings/widgets/dialog_clear_cache.dart` |
| **Source files to modify** | `lib/settings/widgets/menu.dart` (add menu entry) |
| **Estimated effort** | Small |

#### Implementation Details

**New file `lib/settings/widgets/dialog_clear_cache.dart`** — `DialogClearCache` StatelessWidget:
- `AlertDialog` with warning text: "This will delete all local data. You will be logged out."
- Cancel button: closes dialog
- Confirm button:
  - Calls `client.logout()` to end session
  - Calls `client.database?.clear()` or deletes the database
  - Navigates to `/` (introduction page)
  - Loading state while clearing

**Modify `lib/settings/widgets/menu.dart`**:
- Add `ListTile` with `Icons.delete_outline` and text "Clear Cache"
- On tap: `showDialog(builder: (_) => DialogClearCache())`
- Show only when `client.isLogged()` is true

#### Unit Tests — `test/unit/cache_clear_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | `client.logout()` is called | Verify call |
| 2 | `client.database.clear()` is called (or equivalent) | Verify call |
| 3 | After cache clear, `client.isLogged()` returns false | Assert false |

#### Widget Tests — `test/settings/clear_cache_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | "Clear Cache" menu item visible in drawer | Find `ListTile` with delete icon |
| 2 | Tapping it opens confirmation dialog | Tap, verify `AlertDialog` |
| 3 | Cancel dismisses dialog without action | Tap cancel, verify no logout called |
| 4 | Confirm calls cache clear logic | Tap confirm, verify `logout()` and `database.clear()` |
| 5 | After clearing, user redirected to intro | Verify navigation to `/` |

#### Integration Test — `integration_test/clear_cache_test.dart`

| # | Test Case |
|---|-----------|
| 1 | Login -> menu -> clear cache -> verify redirected to intro |

---

### WI-6.2: Verify Encryption Keys (NEW FEATURE — full TDD)

| Field | Value |
|-------|-------|
| **User Story** | US-6.2 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source files to create** | `lib/settings/pages/key_verification.dart` |
| **Source files to modify** | `lib/main.dart` (add route), `lib/settings/widgets/menu.dart` (add menu entry) |
| **Estimated effort** | Large |

#### Implementation Details

**New file `lib/settings/pages/key_verification.dart`** — `KeyVerificationPage` StatefulWidget:
- Fetches devices via `client.userDeviceKeys[client.userID]?.deviceKeys`
- Lists each device with: device name, device ID, verification status icon (verified / unverified / blocked)
- "Verify" button per unverified device:
  - Starts verification via `device.startVerification()`
  - Shows emoji comparison step (the Matrix SAS verification emojis)
  - Confirm/reject buttons
  - On confirm: marks device as verified
- "Block" option per device
- Uses Matrix SDK's `KeyVerification` class and its event stream

**Route addition in `lib/main.dart`**:
```dart
GoRoute(
  path: '/settings/security',
  builder: (context, state) => const ScaffoldWithNavigation(child: KeyVerificationPage()),
),
```

**Modify `lib/settings/widgets/menu.dart`**:
- Add `ListTile` with `Icons.security` and text "Security"
- On tap: navigate to `/settings/security`

#### Unit Tests — `test/unit/key_verification_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | `client.userDeviceKeys` returns device list | Mock device keys, verify list |
| 2 | Verification state mapping (verified, unverified, blocked) | Assert status enum mapping |
| 3 | Starting verification calls `device.startVerification()` | Verify call |

#### Widget Tests — `test/settings/key_verification_page_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Smoke: renders device list with verification status icons | Verify `ListView`, icon types |
| 2 | Unverified device shows "Verify" button | Find button for unverified device |
| 3 | Tap verify starts verification flow | Tap, verify `startVerification()` called |
| 4 | Emoji comparison step shows emojis | Mock verification state, verify emoji display |
| 5 | Confirming emojis marks device verified | Tap confirm, verify status update |
| 6 | Blocking a device updates status | Tap block, verify |

#### Integration Test — `integration_test/key_verification_test.dart`

| # | Test Case |
|---|-----------|
| 1 | Menu -> Security -> see devices -> start verification -> complete flow |

---

### WI-6.3: Light/Dark Mode Toggle (NEW FEATURE — full TDD)

| Field | Value |
|-------|-------|
| **User Story** | US-6.3 |
| **Status** | `NOT STARTED` |
| **Assigned to** | — |
| **Dependencies** | WI-0 |
| **Source files to create** | `lib/shared/services/theme_service.dart` |
| **Source files to modify** | `lib/main.dart` (add provider, set `themeMode`, define `darkTheme`), `lib/settings/widgets/menu.dart` (add toggle) |
| **Estimated effort** | Medium |

#### Implementation Details

**New file `lib/shared/services/theme_service.dart`** — `ThemeService` extending `ChangeNotifier`:
```dart
class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  ThemeService() { _loadFromPrefs(); }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('theme_mode');
    if (stored != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == stored,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  Future<void> toggleTheme() async {
    final next = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    await setThemeMode(next);
  }
}
```

**Modify `lib/main.dart`** (`SubstitutionApp`):
- Add `ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService())` to `MultiProvider`
- In `MaterialApp.router`:
  - `themeMode: context.watch<ThemeService>().themeMode`
  - Keep existing `theme:` as light theme
  - Add `darkTheme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true, brightness: Brightness.dark)`

**Modify `lib/settings/widgets/menu.dart`**:
- Add a `SwitchListTile` at the bottom of the drawer:
  - Title: "Dark Mode"
  - Value: `context.watch<ThemeService>().themeMode == ThemeMode.dark`
  - On changed: `context.read<ThemeService>().toggleTheme()`

#### Unit Tests — `test/unit/theme_service_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Default theme mode is `ThemeMode.system` | `expect(service.themeMode, ThemeMode.system)` |
| 2 | `toggleTheme()` switches between light and dark | Toggle, verify mode changed |
| 3 | `setThemeMode()` persists to SharedPreferences | Set mode, read prefs, verify stored |
| 4 | Loading from SharedPreferences restores saved theme | Set prefs value, create new service, verify mode |
| 5 | `notifyListeners()` is called on change | Use mock listener, verify called |

#### Widget Tests — `test/settings/theme_toggle_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | Toggle switch visible in menu drawer | Find `SwitchListTile` |
| 2 | Toggle reflects current theme mode | Verify switch value matches service |
| 3 | Tapping toggle calls `toggleTheme()` | Tap, verify service state changed |

#### Widget Tests — `test/main/theme_app_test.dart`

| # | Test Case | What to Assert |
|---|-----------|---------------|
| 1 | App starts with system theme by default | Verify `themeMode` is `ThemeMode.system` |
| 2 | `darkTheme` is defined and different from `theme` | Verify both themes exist with different brightness |
| 3 | Changing ThemeService updates MaterialApp reactively | Set dark mode, verify `Brightness.dark` applied |

#### Integration Test — `integration_test/theme_toggle_test.dart`

| # | Test Case |
|---|-----------|
| 1 | Open menu -> toggle dark mode -> verify scaffold background changes -> toggle back -> verify light |

---

## Recommended Execution Order

Items within the same priority level can be worked on **concurrently** by different agents/developers.

| Priority | Work Items | Reason |
|----------|-----------|--------|
| **P0** | WI-0 | All other items depend on shared test helpers |
| **P1** | WI-6.3, WI-6.1, WI-1.4 | Simple new features, no cross-dependencies |
| **P2** | WI-4.4, WI-5.4, WI-3.4, WI-6.2 | More complex new features, independent of each other |
| **P3** | WI-1.1, WI-1.2, WI-1.3 | Add behavioral tests to existing auth code |
| **P3** | WI-2.1, WI-2.2, WI-2.3, WI-2.4 | Add behavioral tests to existing discovery code |
| **P3** | WI-3.1, WI-3.2, WI-3.3 | Add behavioral tests to existing feed code |
| **P3** | WI-4.1, WI-4.2, WI-4.3 | Add behavioral tests to existing interaction code |
| **P3** | WI-5.1, WI-5.2, WI-5.3 | Add behavioral tests to existing creation code |

### Concurrency Map

After WI-0 is done, up to **20 work items** can proceed in parallel. Here is the dependency graph:

```
WI-0 (test infrastructure)
  |
  +-- WI-1.1, WI-1.2, WI-1.3  (parallel)
  +-- WI-1.4                    (parallel, no deps)
  +-- WI-2.1, WI-2.2, WI-2.3, WI-2.4  (parallel)
  +-- WI-3.1, WI-3.2, WI-3.3  (parallel)
  +-- WI-3.4                    (parallel, adds connectivity_plus dep)
  +-- WI-4.1, WI-4.2, WI-4.3  (parallel)
  +-- WI-4.4                    (parallel, no deps)
  +-- WI-5.1, WI-5.2, WI-5.3  (parallel)
  +-- WI-5.4                    (parallel, no deps)
  +-- WI-6.1                    (parallel, no deps)
  +-- WI-6.2                    (parallel, no deps)
  +-- WI-6.3                    (parallel, no deps)
```

> **Note:** WI-3.4 adds `connectivity_plus` to `pubspec.yaml`. Coordinate with other agents to avoid merge conflicts on that file.

---

## Final Test File Structure

```
test/
  helpers/
    test_helpers.dart                    # WI-0
    mock_router.dart                     # WI-0
  unit/
    homeserver_validation_test.dart      # WI-1.1
    login_logic_test.dart                # WI-1.2
    session_persistence_test.dart        # WI-1.3
    profile_update_test.dart             # WI-1.4
    room_search_test.dart                # WI-2.1
    room_join_test.dart                  # WI-2.2
    room_leave_test.dart                 # WI-2.3
    timeline_merge_test.dart             # WI-3.1
    connectivity_service_test.dart       # WI-3.4
    reaction_send_test.dart              # WI-4.1
    reaction_aggregation_test.dart       # WI-4.2
    user_profile_fetch_test.dart         # WI-4.4
    room_permissions_test.dart           # WI-5.4
    cache_clear_test.dart                # WI-6.1
    key_verification_test.dart           # WI-6.2
    theme_service_test.dart              # WI-6.3
  auth/
    host_page_test.dart                  # WI-1.1
    login_page_test.dart                 # WI-1.2 (extend existing)
  feed/
    home_page_test.dart                  # WI-3.1 (extend existing)
    room_feed_test.dart                  # WI-2.4
    infinite_scroll_test.dart            # WI-3.2
    offline_mode_test.dart               # WI-3.4
  post/
    post_widget_media_test.dart          # WI-3.3
    file_display_test.dart               # WI-3.3
    reaction_test.dart                   # WI-4.1
    reactions_display_test.dart          # WI-4.2
    reply_test.dart                      # WI-4.3
    comment_threading_test.dart          # WI-4.3
    avatar_tap_test.dart                 # WI-4.4
  profile/
    user_profile_page_test.dart          # WI-4.4
  settings/
    followfeeds_search_test.dart         # WI-2.1
    followfeeds_join_test.dart           # WI-2.2
    followfeeds_leave_test.dart          # WI-2.3
    dialog_create_room_test.dart         # WI-5.3
    room_permissions_page_test.dart      # WI-5.4
    clear_cache_test.dart                # WI-6.1
    key_verification_page_test.dart      # WI-6.2
    theme_toggle_test.dart               # WI-6.3
    profile_page_test.dart               # WI-1.4
  main/
    app_startup_test.dart                # WI-1.3
    theme_app_test.dart                  # WI-6.3
  write/
    textmessage_test.dart                # WI-5.1 (extend existing)
    filemessage_test.dart                # WI-5.2 (extend existing)

integration_test/
  onboarding_flow_test.dart              # WI-1.1, WI-1.2, WI-1.3
  discovery_flow_test.dart               # WI-2.1, WI-2.2, WI-2.3
  feed_test.dart                         # WI-3.1
  room_feed_test.dart                    # WI-2.4
  offline_test.dart                      # WI-3.4
  profile_view_test.dart                 # WI-4.4
  profile_edit_test.dart                 # WI-1.4
  room_permissions_test.dart             # WI-5.4
  clear_cache_test.dart                  # WI-6.1
  key_verification_test.dart             # WI-6.2
  theme_toggle_test.dart                 # WI-6.3
```

> **Total:** ~40 test files covering all 21 user stories with unit, widget, and integration tests.
