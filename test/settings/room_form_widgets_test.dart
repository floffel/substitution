import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/settings/widgets/form_section_card.dart';
import 'package:substitution/settings/widgets/room_basic_info_form.dart';
import 'package:substitution/settings/widgets/room_danger_zone.dart';
import 'package:substitution/settings/widgets/room_members_section.dart';
import 'package:substitution/settings/widgets/room_settings_section.dart';

class MockClient extends Mock implements Client {}

/// Lightweight test harness — mirrors `test/age_gate_test.dart`.
/// `.tr()` falls back to the raw key when translations are missing, which
/// is the case in unit tests, so we can assert against the translation
/// keys directly.
Widget _buildApp(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('en', 'US')],
    path: 'assets/translations',
    fallbackLocale: const Locale('en', 'US'),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('FormSectionCard', () {
    testWidgets('renders the title and all children', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          FormSectionCard(
            title: 'Test section',
            children: const [Text('child one'), Text('child two')],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Test section'), findsOneWidget);
      expect(find.text('child one'), findsOneWidget);
      expect(find.text('child two'), findsOneWidget);
    });

    testWidgets('renders with an empty children list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(FormSectionCard(title: 'Empty section', children: const [])),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Empty section'), findsOneWidget);
    });
  });

  group('FormToggleTile', () {
    testWidgets('renders title, subtitle and the icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          FormToggleTile(
            icon: Icons.security_rounded,
            title: 'Encryption',
            subtitle: 'End-to-end encrypt this room',
            value: false,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Encryption'), findsOneWidget);
      expect(find.text('End-to-end encrypt this room'), findsOneWidget);
      expect(find.byIcon(Icons.security_rounded), findsOneWidget);
    });

    testWidgets('invokes onChanged when toggled', (WidgetTester tester) async {
      var currentValue = false;
      await tester.pumpWidget(
        _buildApp(
          FormToggleTile(
            icon: Icons.public_rounded,
            title: 'Public',
            subtitle: 'Allow anyone to join',
            value: currentValue,
            onChanged: (v) => currentValue = v,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump(const Duration(milliseconds: 100));

      expect(currentValue, isTrue);
    });
  });

  group('RoomDangerZone', () {
    testWidgets('renders the warning + delete icons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildApp(RoomDangerZone(onDeleteRoom: () {})));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delete_forever_rounded), findsOneWidget);
    });

    testWidgets('invokes onDeleteRoom when tapped', (
      WidgetTester tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _buildApp(RoomDangerZone(onDeleteRoom: () => tapped = true)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.delete_forever_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tapped, isTrue);
    });
  });

  group('RoomBasicInfoForm', () {
    testWidgets('renders the three text fields', (WidgetTester tester) async {
      final nameCtl = TextEditingController();
      final aliasCtl = TextEditingController();
      final topicCtl = TextEditingController();

      await tester.pumpWidget(
        _buildApp(
          Form(
            child: RoomBasicInfoForm(
              nameController: nameCtl,
              aliasController: aliasCtl,
              topicController: topicCtl,
              homeserverSuffix: 'matrix.org',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TextFormField), findsNWidgets(3));
      // The alias field shows the homeserver suffix inline.
      expect(find.text(':matrix.org'), findsOneWidget);
      // And the literal "#" prefix.
      expect(find.text('#'), findsOneWidget);
    });

    testWidgets('homeserver suffix falls back to "homeserver" when null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          Form(
            child: RoomBasicInfoForm(
              nameController: TextEditingController(),
              aliasController: TextEditingController(),
              topicController: TextEditingController(),
              homeserverSuffix: null,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(':homeserver'), findsOneWidget);
    });

    testWidgets('alias validator rejects invalid characters', (
      WidgetTester tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      final nameCtl = TextEditingController(text: 'Test Room');
      final aliasCtl = TextEditingController(text: 'bad name with spaces');
      final topicCtl = TextEditingController();

      await tester.pumpWidget(
        _buildApp(
          Form(
            key: formKey,
            child: RoomBasicInfoForm(
              nameController: nameCtl,
              aliasController: aliasCtl,
              topicController: topicCtl,
              homeserverSuffix: 'matrix.org',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(formKey.currentState!.validate(), isFalse);
    });

    testWidgets('alias validator accepts empty (alias is optional)', (
      WidgetTester tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      final nameCtl = TextEditingController(text: 'Test Room');
      final aliasCtl = TextEditingController();
      final topicCtl = TextEditingController();

      await tester.pumpWidget(
        _buildApp(
          Form(
            key: formKey,
            child: RoomBasicInfoForm(
              nameController: nameCtl,
              aliasController: aliasCtl,
              topicController: topicCtl,
              homeserverSuffix: 'matrix.org',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('name validator rejects empty', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _buildApp(
          Form(
            key: formKey,
            child: RoomBasicInfoForm(
              nameController: TextEditingController(),
              aliasController: TextEditingController(),
              topicController: TextEditingController(),
              homeserverSuffix: 'matrix.org',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(formKey.currentState!.validate(), isFalse);
    });
  });

  group('RoomSettingsSection', () {
    testWidgets('substitution toggle is hidden in create mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          RoomSettingsSection(
            isPublic: false,
            onIsPublicChanged: (_) {},
            isEncrypted: null,
            alreadyEncrypted: false,
            onIsEncryptedChanged: (_) {},
            isSubstitutionRoom: true,
            onIsSubstitutionRoomChanged: (_) {},
            isBlogMode: false,
            onIsBlogModeChanged: (_) {},
            isEditMode: false, // create mode
            canChangeEncryption: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // In create mode, the substitution label must not appear.
      expect(find.text('settings.room_form.substitution_label'), findsNothing);
    });

    testWidgets('substitution toggle is shown in edit mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          RoomSettingsSection(
            isPublic: true,
            onIsPublicChanged: (_) {},
            isEncrypted: null,
            alreadyEncrypted: false,
            onIsEncryptedChanged: (_) {},
            isSubstitutionRoom: true,
            onIsSubstitutionRoomChanged: (_) {},
            isBlogMode: false,
            onIsBlogModeChanged: (_) {},
            isEditMode: true,
            canChangeEncryption: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('settings.room_form.substitution_label'),
        findsOneWidget,
      );
    });

    testWidgets('already-encrypted shows a read-only "on" tile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          RoomSettingsSection(
            isPublic: true,
            onIsPublicChanged: (_) {},
            isEncrypted: true,
            alreadyEncrypted: true,
            onIsEncryptedChanged: (_) {},
            isSubstitutionRoom: true,
            onIsSubstitutionRoomChanged: (_) {},
            isBlogMode: false,
            onIsBlogModeChanged: (_) {},
            isEditMode: true,
            canChangeEncryption: false, // immutable
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // The "already on" subtitle is rendered, and the locked state is
      // marked with a check-circle icon instead of a switch.
      expect(
        find.text('settings.room_form.encryption_already_on'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      // The encryption toggle is NOT rendered (it would be a 4th switch).
      // The remaining 3 switches (visibility, substitution, posting) are.
      expect(find.byType(SwitchListTile), findsNWidgets(3));
    });

    testWidgets(
      'invokes onIsPublicChanged when the visibility switch is toggled',
      (WidgetTester tester) async {
        var currentPublic = false;
        await tester.pumpWidget(
          _buildApp(
            RoomSettingsSection(
              isPublic: currentPublic,
              onIsPublicChanged: (v) => currentPublic = v,
              isEncrypted: null,
              alreadyEncrypted: false,
              onIsEncryptedChanged: (_) {},
              isSubstitutionRoom: true,
              onIsSubstitutionRoomChanged: (_) {},
              isBlogMode: false,
              onIsBlogModeChanged: (_) {},
              isEditMode: true,
              canChangeEncryption: true,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // First SwitchListTile is the visibility toggle.
        final switchFinder = find.byType(SwitchListTile).first;
        await tester.tap(switchFinder);
        await tester.pump(const Duration(milliseconds: 100));

        expect(currentPublic, isTrue);
      },
    );
  });

  group('RoomMembersSection', () {
    testWidgets('shows the "no members" empty state when lists are empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          RoomMembersSection(
            members: const [],
            bannedMembers: const [],
            room: null,
            client: MockClient(),
            onSetPowerLevel: (_, _) {},
            onKickMember: (_) {},
            onBanMember: (_) {},
            onUnbanMember: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('settings.room_form.members_empty'), findsOneWidget);
      expect(find.text('settings.room_form.banned_empty'), findsOneWidget);
    });
  });
}
