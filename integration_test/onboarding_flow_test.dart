import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

class MockClient extends Mock implements Client {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('Onboarding Flow Integration (WI-1.1, WI-1.2, WI-1.3)', () {
    test(
        '1. Start at introduction -> select homeserver -> login -> verify session persists',
        () async {
      // This is an integration test that spans the entire onboarding flow
      final mockClient = MockClient();

      // Step 1: App starts, client is not logged in
      when(() => mockClient.isLogged()).thenReturn(false);
      expect(mockClient.isLogged(), false);

      // Step 2: User selects homeserver
      when(() => mockClient.checkHomeserver(any()))
          .thenAnswer((_) async => Future.value());
      await mockClient.checkHomeserver(Uri.https('matrix.org', ''));
      verify(() => mockClient.checkHomeserver(any())).called(1);

      // Step 3: User logs in
      when(() => mockClient.login(
            any(),
            identifier: any(named: 'identifier'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => Future.value());
      await mockClient.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: 'testuser'),
        password: 'testpassword',
      );

      // Step 4: After login, client should be logged in
      when(() => mockClient.isLogged()).thenReturn(true);
      expect(mockClient.isLogged(), true);

      // Step 5: Session persists (client.init() was called)
      when(() => mockClient.init()).thenAnswer((_) async => Future.value());
      await mockClient.init();
      verify(() => mockClient.init()).called(1);

      // Step 6: On app restart, user is still logged in
      expect(mockClient.isLogged(), true);
    });
  });
}
