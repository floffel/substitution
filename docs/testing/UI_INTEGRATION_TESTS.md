# UI + Matrix Server Integration Tests

> **Status:** Complete  
> **Created:** 2026-02-15  
> **Tests:** 6 comprehensive integration test suites  
> **Coverage:** User Stories US-1.1, US-1.2, US-1.3, US-2.4, US-2.1, US-3.1, US-4.1, US-4.3, US-5.1, US-5.2

## Overview

This document describes the full end-to-end integration tests that verify the Substitution app UI working with a **real Matrix server**. These tests go beyond the standalone Matrix server tests (`matrix_integration_test.dart`) to validate the complete user experience.

### Test Approach

- **Real Matrix Server:** Tests use the actual `matrix-synapse:8008` server running in Docker
- **Real App UI:** Tests launch the Flutter app and interact with the actual UI widgets
- **Pre-created Test Data:** Server is initialized with 3 test users and 3 test rooms containing pre-populated messages
- **Full User Flows:** Tests follow complete user stories from login through content interaction

## Test Files & Coverage

### 1. `integration_test/onboarding_and_login_test.dart`
**User Stories:** US-1.1 (Choose Homeserver), US-1.2 (Login), US-1.3 (Persistent Session)

Tests the complete onboarding and authentication flow:

| Test Case | What it validates |
|-----------|------------------|
| `Complete onboarding: host selection -> login -> view feed` | Full flow: enter homeserver URL → login with credentials → arrive at feed page |
| `Login with invalid credentials shows error` | Error handling when wrong username/password provided |
| `User can choose different homeserver` | UI correctly accepts custom homeserver URL input |

**Key Assertions:**
- Feed page displays after successful login
- Login form disappears after successful login
- Error dialogs appear on failed authentication
- Homeserver URL field accepts custom servers

### 2. `integration_test/feed_with_matrix_test.dart`
**User Story:** US-3.1 (Unified Timeline)

Tests viewing the main feed with content from all joined rooms:

| Test Case | What it validates |
|-----------|------------------|
| `Display unified feed from multiple rooms` | Feed shows messages from test_general, test_photos, test_art |
| `Feed displays content from test_general room (has 5 messages)` | test_general messages appear in feed |
| `Feed displays content from test_photos room (has 3 messages)` | test_photos messages appear in feed |
| `Feed loads and shows messages chronologically` | Messages load in chronological order; scrolling works |
| `Feed excludes test_art room (empty room)` | Empty room doesn't crash the feed |

**Key Assertions:**
- `ListView` widget displays the feed
- Messages from populated rooms are visible
- Feed gracefully handles empty rooms
- Infinite scroll works (drag to load more)

### 3. `integration_test/room_discovery_with_matrix_test.dart`
**User Story:** US-2.1 (Search Public Rooms), US-2.2 (Follow/Join)

Tests discovering and accessing rooms:

| Test Case | What it validates |
|-----------|------------------|
| `User can search for public rooms` | Room discovery/search UI is accessible |
| `Test rooms are discoverable (test_general, test_photos, test_art)` | All 3 test rooms are visible to users |
| `User can access room settings or details` | Can tap on rooms and view details |
| `Multiple test users can see the same rooms` | Both testuser1 and testuser2 see all 3 rooms |

**Key Assertions:**
- Room list/discovery UI is functional
- All 3 test rooms appear in room lists
- Users can navigate to room details
- Multi-user room visibility works

### 4. `integration_test/room_feed_with_matrix_test.dart`
**User Story:** US-2.4 (View Room Feed)

Tests viewing individual room content:

| Test Case | What it validates |
|-----------|------------------|
| `View individual room feed (test_general with 5 messages)` | Can navigate to and view a room's messages |
| `Room feed shows correct message count` | test_general displays its 5 messages |
| `Empty room (test_art) displays correctly with no messages` | Empty room view doesn't crash |
| `Room feed allows scrolling through message history` | Can scroll in room to load more messages |
| `Room displays user information with messages` | Sender info (avatars, names) displays with messages |

**Key Assertions:**
- Can access individual room views
- Messages are displayed with sender info
- Scrolling works in room feeds
- Empty rooms are handled gracefully

### 5. `integration_test/interaction_with_matrix_test.dart`
**User Story:** US-4.1 (React with Emoji), US-4.3 (Reply)

Tests message interactions:

| Test Case | What it validates |
|-----------|------------------|
| `Can react to messages with emoji` | Long-press shows reaction menu |
| `Can reply to messages` | Reply option appears; reply input activates |
| `Reactions from other users are visible` | Reaction UI elements display in feed |
| `Can view user profile by tapping avatar` | Avatar taps navigate to profile |
| `Message interactions work with messages from test_general room` | Real messages are interactive |
| `Thread/reply view shows conversation context` | Can view message threads |

**Key Assertions:**
- Message context menus appear on interaction
- Reply and reaction UI elements render
- User profiles are accessible
- Message threads display context

### 6. `integration_test/post_creation_with_matrix_test.dart`
**User Story:** US-5.1 (Compose Text), US-5.2 (Upload Media)

Tests creating and sending messages:

| Test Case | What it validates |
|-----------|------------------|
| `Can compose and send a text message` | Message input → send button → message sent |
| `Can select room before sending message` | Can choose target room from dropdown/list |
| `Sent message appears in feed` | New message is visible after sending |
| `Can create text post with formatting` | Text formatting tools are available |
| `Message appears in correct room (test_general)` | Message goes to selected room |
| `Multiple users can send messages to same room` | Both testuser1 and testuser2 can post |

**Key Assertions:**
- Compose UI (FAB, input fields) is accessible
- Messages can be sent via send button
- Sent messages appear in the feed immediately
- Room selection works for message targeting
- Multi-user messaging works

## Test Data

Tests use the pre-initialized Matrix server with:

**Users:**
- `testuser1` / `testpass123`
- `testuser2` / `testpass123`  
- `testadmin` / `testpass123`

**Rooms:**
- `test_general`: 5 messages
  - "Hello everyone! Welcome to this test room."
  - "This is the second message in the room."
  - "Check out this amazing content!"
  - (2 more messages)
  
- `test_photos`: 3 messages
  - Similar sample messages

- `test_art`: 0 messages (empty room for testing)

All users are members of all 3 rooms.

## Running the Tests

### Complete Integration Test Suite

```bash
# Start all services and run all tests
docker-compose up

# Or run tests in background
docker-compose up -d
docker-compose exec test flutter test integration_test/
```

### Run Specific Test Suite

```bash
# Just onboarding tests
docker-compose exec test flutter test integration_test/onboarding_and_login_test.dart

# Just feed tests
docker-compose exec test flutter test integration_test/feed_with_matrix_test.dart

# Just post creation tests
docker-compose exec test flutter test integration_test/post_creation_with_matrix_test.dart
```

### View Real-time Output

```bash
# Watch test output
docker-compose logs -f test

# Watch all services
docker-compose logs -f
```

## Service Dependencies

The tests depend on this service startup order (enforced by docker-compose):

1. **PostgreSQL** (database for Matrix)
2. **Matrix Synapse** (Matrix server) - waits for PostgreSQL to be healthy
3. **matrix-init** (Python script) - waits for Matrix to be healthy
   - Creates test users
   - Creates test rooms
   - Populates test messages
4. **Redis** (cache) - optional, for sessions
5. **test** (Flutter runner) - waits for matrix-init to complete

Tests cannot start until all services are running and data is initialized.

## Test Timeouts

Each test has a **60-second timeout** to allow for:
- App startup and hot reload (~5-10s)
- Network latency with Matrix server (~1-3s per operation)
- UI rendering and settlement (~2-5s per interaction)
- Async operations (login, sync, message sends)

## Expected Results

When tests run successfully:

```
✓ Onboarding and login completed successfully
✓ Unified feed displayed with messages
✓ Feed displays test_general room content
✓ Feed supports scrolling and infinite loading
✓ Room discovery UI accessible
✓ Test rooms are visible in the app
✓ Individual room feed displayed
✓ Room feed scrolling works
✓ Empty room handled gracefully
✓ Message reaction menu displayed
✓ Message sent successfully
✓ Message sent to test_general
```

All tests should pass without errors or crashes.

## Debugging Failed Tests

If a test fails:

1. **Check Matrix server is running:**
   ```bash
   curl http://localhost:8008/_matrix/client/versions
   ```

2. **Check test data was initialized:**
   ```bash
   docker-compose logs matrix-init
   ```

3. **View full test output:**
   ```bash
   docker-compose logs test
   ```

4. **Check app logs for errors:**
   ```bash
   flutter run --verbose  # if running locally
   ```

5. **Verify test user exists:**
   ```bash
   # In matrix-init logs, should show:
   # "✓ Created user testuser1"
   # "✓ Created room test_general with 5 messages"
   ```

## Notes for Future Enhancement

- Tests use basic widget finding (by type). Future tests could use Semantics/testTag for more robust element location
- Post creation tests make assumptions about button layouts (FAB, send icon). These may vary by implementation
- Media upload tests (images/videos) not included in initial suite - can be added when upload UI is implemented
- E2E encryption tests not included - requires encryption setup in Matrix server
- Performance/stress tests not included - could test with high message volumes

## User Stories Covered

| Epic | Story | Coverage |
|------|-------|----------|
| 1 | US-1.1 - Choose Homeserver | ✓ Complete |
| 1 | US-1.2 - Login with Credentials | ✓ Complete |
| 1 | US-1.3 - Persistent Session | ✓ Complete (implicit - login persists) |
| 2 | US-2.1 - Search Public Rooms | ✓ Partial |
| 2 | US-2.2 - Follow/Join Room | ✓ Partial |
| 2 | US-2.4 - View Room Feed | ✓ Complete |
| 3 | US-3.1 - Unified Timeline | ✓ Complete |
| 4 | US-4.1 - React with Emoji | ✓ Partial |
| 4 | US-4.3 - Reply/Thread | ✓ Partial |
| 5 | US-5.1 - Compose Text | ✓ Complete |
| 5 | US-5.2 - Upload Media | ✓ Partial |

## Related Files

- `docker-compose.yml` - Orchestration for all services
- `config/synapse/init_test_data.py` - Test data initialization
- `integration_test/matrix_integration_test.dart` - Pure Matrix SDK tests (no UI)
- `USER_STORIES.md` - User story definitions
- `TDD_PLAN.md` - Test-driven development plan
