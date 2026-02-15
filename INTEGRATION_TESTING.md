# Integration Testing

This project uses Docker Compose to run integration tests with a Matrix Synapse server and its dependencies.

## Quick Start

```bash
# Run all tests (automatically sets up Matrix server with test data)
docker-compose run test

# Keep services running and re-run tests
docker-compose up
docker-compose exec test flutter test integration_test/
docker-compose down
```

## How It Works

1. **PostgreSQL** starts first - database for Matrix Synapse
2. **Matrix Synapse** starts and connects to PostgreSQL
3. **matrix-init** script runs - creates test users and rooms:
   - Users: `testuser1`, `testuser2`, `testadmin` (password: `testpass123`)
   - Rooms: `test_general`, `test_photos`, `test_art`
4. **Redis** starts for caching
5. **test** service runs - executes all integration tests with access to the live Matrix server

Tests can access the Matrix server via environment variables:
- `MATRIX_SERVER=http://matrix-synapse:8008`
- `MATRIX_TEST_USER=testuser1`
- `MATRIX_TEST_PASSWORD=testpass123`

## Using Matrix in Tests

Access the Matrix server from your tests:

```dart
import 'package:matrix/matrix.dart';

testWidgets('Login to Matrix server', (WidgetTester tester) async {
  final client = Client('substitution_test');
  
  // Use environment variables set in docker-compose.yml
  const matrixServer = 'http://matrix-synapse:8008';
  const testUser = 'testuser1';
  const testPassword = 'testpass123';
  
  // Login
  await client.login(
    LoginType.mLoginPassword,
    identifier: AuthenticationUserIdentifier(user: testUser),
    password: testPassword,
  );
  
  // Now you can interact with the server
  expect(client.userID, contains(testUser));
  
  await client.logout();
});
```

## Configuration

Edit `docker-compose.yml` to:
- Enable/disable test platforms (set `FLUTTER_TEST_*` environment variables)
- Change test credentials (environment variables in `test` service)
- Modify test data (see `config/synapse/init_test_data.py`)
- Add more Matrix rooms or users

## Test Rooms

Pre-created test rooms available:
- **test_general** - General purpose test room
- **test_photos** - For photo/image tests
- **test_art** - For art content tests

All test users are members of all test rooms.

## Services

The Docker Compose setup includes:

- **PostgreSQL** (port 5432) - Database for Matrix Synapse
- **Matrix Synapse** (port 8008/8448) - Live Matrix homeserver
- **matrix-init** - Python script that creates test users and rooms
- **Redis** (port 6379) - Cache and session storage
- **test** - Flutter test runner that runs after all services are ready

All services have health checks and start in the correct order. The `test` service only starts after `matrix-init` completes successfully.

## Local Development

To run tests locally without Docker:

```bash
# Start only the services (no tests)
docker-compose up -d postgres matrix-synapse matrix-init redis

# Wait a moment for matrix-init to complete
sleep 5

# Run tests locally
flutter pub get
flutter test integration_test/

# Cleanup
docker-compose down
```

## Continuous Integration

See `.github/workflows/integration-tests.yml` for GitHub Actions workflow configuration. The CI pipeline will automatically:
1. Start all services
2. Create test data via matrix-init
3. Run integration tests
4. Report results

## Writing Tests

Add new integration tests to the `integration_test/` directory:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matrix/matrix.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('My Feature with Matrix', () {
    testWidgets('should sync with Matrix server', (WidgetTester tester) async {
      final client = Client('test_client');
      
      // Connect to test server
      await client.checkHomeserver(
        Uri.parse(String.fromEnvironment('MATRIX_SERVER', defaultValue: 'http://localhost:8008'))
      );
      
      // Login with test user
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(
          user: String.fromEnvironment('MATRIX_TEST_USER', defaultValue: 'testuser1')
        ),
        password: String.fromEnvironment('MATRIX_TEST_PASSWORD', defaultValue: 'testpass123'),
      );
      
      // Perform test
      expect(client.userID, isNotEmpty);
      
      // Cleanup
      await client.logout();
    });
  });
}
```

## Modifying Test Data

Edit `config/synapse/init_test_data.py` to:
- Add more test users (modify `TEST_USERS` list)
- Add more test rooms (modify `TEST_ROOMS` list)
- Customize user display names or room topics
- Add initial messages to rooms
- Set room permissions

After editing, rebuild and run:
```bash
docker-compose down -v  # Remove old data
docker-compose run test  # Run tests with new data
```

## Troubleshooting

### Tests can't connect to Matrix server
Check that `matrix-synapse` is healthy:
```bash
docker-compose logs matrix-synapse
```

### Test users not created
Check the matrix-init logs:
```bash
docker-compose logs matrix-init
```

### Force cleanup and restart
```bash
docker-compose down -v
docker-compose run test
```

### Access Matrix server directly
```bash
# Check server is running
curl http://localhost:8008/_matrix/client/versions

# List users (from within container)
docker-compose exec matrix-synapse bash
# Then use sqlite3 or admin API

# Check test rooms
curl http://localhost:8008/_matrix/client/r0/publicRooms
```

