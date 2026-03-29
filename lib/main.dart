import '/auth/auth.dart';
import '/auth/auth_state.dart';
import '/feed/feed.dart';
import '/post/post.dart';
import '/settings/pages/followfeeds.dart';
import '/settings/pages/ownfeeds.dart';
import '/settings/pages/key_verification.dart';
import '/settings/pages/profile.dart';
import '/write/pages/textmessage.dart';
import '/write/pages/filemessage.dart';
import '/write/pages/roomselect.dart';
import '/write/pages/locationmessage.dart';
import '/write/pages/voicemessage.dart';
import '/write/pages/emotemessage.dart';
import '/write/pages/stickermessage.dart';
import '/settings/pages/room_form_page.dart';
import '/settings/pages/legal.dart';
import '/help/pages/help_page.dart';
import '/shared/widgets/deep_link_confirmation_dialog.dart';
import '/auth/pages/host_page.dart';
import '/auth/pages/login.dart';
import '/shared/pages/scaffold_with_navigation.dart';
import '/shared/pages/age_gate.dart';
import '/profile/pages/user_profile.dart';
import '/chat/pages/chat_page.dart';
import '/feed/services/feed_state_cache.dart';
import '/shared/services/theme_service.dart';
import '/shared/services/connectivity_service.dart';
import '/shared/services/loading_service.dart';
import '/shared/services/substitution_service.dart';
import '/shared/theme/app_theme.dart';

import '/shared/constants.dart';
import '/shared/widgets/startroom_dialog.dart';
import '/shared/utils/share_helper.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart'; // init matrix
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart'; // provide the client across widgets/pages/routes
import 'package:go_router/go_router.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
// import 'package:logging/logging.dart' as l; // see @logging

// Global client reference for test teardown use only
Client? globalMatrixClient;

// Global SubstitutionService reference for test access only
SubstitutionService? globalSubstitutionService;

// Global database reference for test teardown use only
Database? globalDatabase;

/// Route guard used by all protected routes.
/// Redirects to `/age-gate` if the user hasn't confirmed their age, or to
/// `/intro` if they are not logged in. Returns `null` to allow navigation.
String? ageAndAuthRedirect(BuildContext context, GoRouterState state) {
  if (!AgeGatePage.confirmed) return '/age-gate';
  final client = globalMatrixClient;
  if (client == null || !client.isLogged()) return '/intro';
  return null;
}

void main() async {
  // Check if we are running in an integration test environment
  AppConstants.isIntegrationTest = const bool.fromEnvironment(
    'INTEGRATION_TEST',
    defaultValue: false,
  );

  // Disable runtime font fetching in integration tests to avoid network
  // failures (HandshakeException) in CI environments where Google Fonts
  // servers may be unreachable. Flutter falls back to the default platform font.
  if (AppConstants.isIntegrationTest) {
    GoogleFonts.config.allowRuntimeFetching = false;
  }

  // Dispose previous client and database if any (for test isolation)
  if (globalMatrixClient != null || globalDatabase != null) {
    try {
      debugPrint("Main: Disposing lingering resources...");
      final oldClient = globalMatrixClient;
      final oldDatabase = globalDatabase;
      globalMatrixClient = null;
      globalSubstitutionService = null;
      globalDatabase = null;

      // Dispose client resources with proper error handling
      if (oldClient != null) {
        try {
          oldClient.abortSync();
          await oldClient.dispose();
        } catch (e) {
          debugPrint("Error disposing Matrix client: $e");
        }
      }

      // Close database with proper error handling
      if (oldDatabase != null) {
        try {
          await oldDatabase.close();
        } catch (e) {
          debugPrint("Error closing database: $e");
        }
      }

      // Extended delay for iOS to fully release file locks and memory
      await Future.delayed(const Duration(milliseconds: 1000));
      debugPrint("Main: Lingering resources disposed.");
    } catch (e) {
      debugPrint("Error disposing previous resources at main start: $e");
    }
  }

  // Must be first — plugins like SharedPreferences and url_strategy need it.
  try {
    WidgetsFlutterBinding.ensureInitialized();
  } catch (e) {
    debugPrint("Binding already initialized: $e");
  }

  // Initialize FFI for Linux desktop support
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // usePathUrlStrategy() can only be called once per browser session.
  // Guard against the assertion error when multiple integration tests
  // each call app.main() (e.g., discovery_flow_test.dart on Web).
  try {
    usePathUrlStrategy();
  } catch (_) {
    // Already set — safe to ignore in tests.
  }

  // Show a branded loading screen immediately while heavy init runs.
  runApp(const _StartupLoadingScreen());

  /*
  // @logging This is to debug GoRouter, wich will not output anything without it
  l.Logger.root.level = l.Level.ALL; // defaults to Level.INFO
  l.Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  }); // */

  final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: "rootNav",
  );

  // Keep testRedirect as a convenience alias used by all protected routes.
  String? testRedirect(BuildContext context, GoRouterState state) =>
      ageAndAuthRedirect(context, state);

  // Load the persisted age-gate acceptance before building the router,
  // so the synchronous redirect function has the cached value available.
  await AgeGatePage.initConfirmed();

  GoRouter router = GoRouter(
    debugLogDiagnostics: true,
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/age-gate', builder: (_, _) => const AgeGatePage()),
      GoRoute(
        path: '/',
        redirect: testRedirect,
        builder: (_, _) => const Feed(),
        //parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) {
          // needed b.c. /feed:roomId has the same widget
          return CustomTransitionPage<void>(
            key: UniqueKey(),
            child: const Feed(),
            transitionsBuilder: (_, _, _, child) => child,
          );
        },
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/write/select/room', // write/select/room
        builder:
            (_, _) => ScaffoldWithNavigation(child: const RoomSelectPage()),
      ),
      GoRoute(
        path: '/intro',
        builder:
            (context, state) => const ScaffoldWithNavigation(
              showNavigation: false,
              child: IntroductionPage(),
            ),
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/feed/:roomId',
        builder:
            (context, state) => Feed(
              roomId:
                  state.pathParameters['roomId']!.startsWith("!")
                      ? state.pathParameters['roomId']!
                      : "#${state.pathParameters['roomId']!}",
            ),
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/post/:id',
        builder: (context, state) {
          final eventId = state.pathParameters['id']!;
          final roomId = state.uri.queryParameters['room']!;
          return ScaffoldWithNavigation(
            disableBodyPadding: true,
            extraActions: [
              Builder(
                builder:
                    (ctx) => IconButton(
                      onPressed:
                          () => ShareHelper.sharePost(ctx, eventId, roomId),
                      icon: const Icon(Icons.share_outlined),
                    ),
              ),
            ],
            child: Post(eventId: eventId, roomId: roomId),
          );
        },
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/profile/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return ScaffoldWithNavigation(
            child: UserProfilePage(userId: Uri.decodeComponent(userId)),
          );
        },
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/chat/:roomId',
        builder: (context, state) {
          final roomId = Uri.decodeComponent(state.pathParameters['roomId']!);
          return ChatPage(roomId: roomId);
        },
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/write/:roomid',
        builder: (contxt, state) {
          final String? eventId = state.uri.queryParameters['event'];
          final String roomId = state.pathParameters['roomid']!;
          return ScaffoldWithNavigation(
            child: TextMessageWrite(eventId: eventId, roomId: roomId),
          );
        },
      ),
      GoRoute(
        // TODO: have some ?goto=/feed/... functionality, so we can link to /into and link back to the page the user originaly wanted to visit
        redirect: testRedirect,
        path: '/file/:roomid',
        builder: (contxt, state) {
          final String? eventId = state.uri.queryParameters['event'];
          final String roomId = state.pathParameters['roomid']!;
          return ScaffoldWithNavigation(
            child: FileMessageWrite(eventId: eventId, roomId: roomId),
          );
        },
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/document/:roomid',
        builder: (contxt, state) {
          final String? eventId = state.uri.queryParameters['event'];
          final String roomId = state.pathParameters['roomid']!;
          // Document posts reuse the file message page (same UI, different default type group selection)
          return ScaffoldWithNavigation(
            child: FileMessageWrite(eventId: eventId, roomId: roomId),
          );
        },
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/location/:roomid',
        builder: (contxt, state) {
          final String? eventId = state.uri.queryParameters['event'];
          final String roomId = state.pathParameters['roomid']!;
          return ScaffoldWithNavigation(
            child: LocationMessageWrite(eventId: eventId, roomId: roomId),
          );
        },
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/voice/:roomid',
        builder: (contxt, state) {
          final String? eventId = state.uri.queryParameters['event'];
          final String roomId = state.pathParameters['roomid']!;
          return ScaffoldWithNavigation(
            child: VoiceMessageWrite(eventId: eventId, roomId: roomId),
          );
        },
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/emote/:roomid',
        builder: (contxt, state) {
          final String? eventId = state.uri.queryParameters['event'];
          final String roomId = state.pathParameters['roomid']!;
          return ScaffoldWithNavigation(
            child: EmoteMessageWrite(eventId: eventId, roomId: roomId),
          );
        },
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/sticker/:roomid',
        builder: (contxt, state) {
          final String? eventId = state.uri.queryParameters['event'];
          final String roomId = state.pathParameters['roomid']!;
          return ScaffoldWithNavigation(
            child: StickerMessageWrite(eventId: eventId, roomId: roomId),
          );
        },
      ),
      // Legacy permissions route — kept for backwards compatibility.
      // Redirects to the new unified room edit page.
      GoRoute(
        redirect: (context, state) {
          if (ageAndAuthRedirect(context, state) != null) {
            return ageAndAuthRedirect(context, state);
          }
          final roomId = state.pathParameters['roomId']!;
          return '/settings/room/$roomId/edit';
        },
        path: '/settings/room/:roomId/permissions',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/settings/room/create',
        builder: (context, state) => const RoomFormPage(),
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/settings/room/:roomId/edit',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          return RoomFormPage(roomId: roomId);
        },
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/settings/feed',
        builder:
            (context, state) =>
                ScaffoldWithNavigation(child: const FollowFeedSettings()),
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/settings/ownfeeds',
        builder:
            (context, state) =>
                ScaffoldWithNavigation(child: const OwnFeedSettings()),
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/settings/security',
        builder:
            (context, state) =>
                ScaffoldWithNavigation(child: const KeyVerificationPage()),
      ),
      GoRoute(
        path: '/settings/legal',
        builder:
            (context, state) =>
                const ScaffoldWithNavigation(child: LegalPage()),
      ),
      GoRoute(
        path: '/help',
        builder:
            (context, state) => const ScaffoldWithNavigation(child: HelpPage()),
      ),
      GoRoute(
        redirect: testRedirect,
        path: '/settings/profile',
        builder:
            (context, state) =>
                ScaffoldWithNavigation(child: const ProfilePage()),
      ),
      GoRoute(
        path: '/auth/host',
        builder:
            (context, state) => const ScaffoldWithNavigation(
              showNavigation: false,
              child: AuthFlow(authPageRoute: 'host'),
            ),
      ),
      GoRoute(
        path: '/auth/login',
        builder:
            (context, state) => const ScaffoldWithNavigation(
              showNavigation: false,
              child: AuthFlow(authPageRoute: 'login'),
            ),
      ),
      GoRoute(
        path: '/login-callback',
        builder: (context, state) {
          return Scaffold(
            body: FutureBuilder<void>(
              future: () async {
                final token = state.uri.queryParameters['loginToken'];
                final homeserverStr = state.uri.queryParameters['homeserver'];

                debugPrint(
                  "Callback params: token=${token != null ? 'YES' : 'NO'}, hs=$homeserverStr",
                );

                if (token == null) {
                  throw Exception("No login token received");
                }

                final client = Provider.of<Client>(context, listen: false);

                // Configure homeserver if provided and not set
                if (homeserverStr != null) {
                  client.homeserver = Uri.parse(homeserverStr);
                  debugPrint("Configured client homeserver to: $homeserverStr");
                } else if (client.homeserver == null) {
                  debugPrint(
                    "Warning: No homeserver configured for token login!",
                  );
                }

                debugPrint("[SSO] Attempting login with token...");
                try {
                  // Fix: m.login.token requires 'token' parameter, not 'password'
                  // Add timeout to detect hangs
                  await client
                      .login(LoginType.mLoginToken, token: token)
                      .timeout(
                        const Duration(seconds: 15),
                        onTimeout: () {
                          throw TimeoutException(
                            "Login timed out after 15 seconds",
                          );
                        },
                      );
                  debugPrint("[SSO] Login successful!");
                } catch (e, stack) {
                  debugPrint("[SSO] Login ERROR: $e");
                  debugPrint(stack.toString());
                  rethrow;
                }
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  final theme = Theme.of(context);
                  final colorScheme = theme.colorScheme;

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer.withValues(
                                  alpha: 0.3,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.error_outline_rounded,
                                color: colorScheme.error,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "Login Failed",
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                snapshot.error.toString(),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            FilledButton.icon(
                              onPressed: () => context.go('/auth/login'),
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: const Text("Back to Login"),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  // Success
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(
                                alpha: 0.4,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: colorScheme.primary,
                              size: 64,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Login Successful!",
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "You can now proceed to the app.",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: () async {
                              debugPrint("User clicked Continue button.");
                              final client = Provider.of<Client>(
                                context,
                                listen: false,
                              );
                              if (context.mounted) {
                                await showStartroomDialog(context, client);
                              }
                              if (context.mounted) {
                                context.go('/');
                              }
                            },
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text("Continue to App"),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        "Logging in...",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    ],
  );

  // await Hive.initFlutter();

  // Initialize the Matrix SDK database
  late final MatrixSdkDatabase matrixDatabase;

  if (!kIsWeb) {
    // Get the application documents directory
    final appDocDir = await getApplicationDocumentsDirectory();
    final dbPath = '${appDocDir.path}/matrix_database.db';

    // Open the SQLite database
    final database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) {
        // Create the database tables
        return db.execute('''
          CREATE TABLE clients (
            id TEXT PRIMARY KEY,
            homeserver_url TEXT,
            token TEXT,
            user_id TEXT
          )
        ''');
      },
    );
    globalDatabase = database;

    matrixDatabase = await MatrixSdkDatabase.init(
      "Substitution",
      database: database,
    );
  } else {
    // Web support: use default (IndexedDB)
    matrixDatabase = await MatrixSdkDatabase.init("Substitution");
  }

  final client = Client(
    "Substitution",
    database: matrixDatabase,
    supportedLoginTypes: {
      AuthenticationTypes.password,
      AuthenticationTypes.sso,
    },
  );
  globalMatrixClient = client;

  await EasyLocalization.ensureInitialized();
  await client.init();

  // Listen for deep links while the app is already running (e.g. SSO callback
  // returning from Safari). Placed here so both `client` and `router` are ready.
  if (!kIsWeb) {
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen((uri) async {
      debugPrint("[app_links] incoming URI: $uri");

      // For custom-scheme URIs like substitution://login-callback?loginToken=abc
      // Dart parses "login-callback" as the HOST, not the path.
      final host = uri.host;
      final path = uri.path;
      final routePath =
          host.isNotEmpty
              ? '/$host$path'
              : (path.startsWith('/') ? path : '/$path');

      debugPrint("[app_links] route path: $routePath");

      // Handle SSO callback directly here — we have the client instance and
      // avoid any BuildContext/Provider dependency inside the route builder.
      if (routePath == '/login-callback') {
        final token = uri.queryParameters['loginToken'];
        final homeserverStr = uri.queryParameters['homeserver'];
        debugPrint(
          "[SSO] token=${token != null ? 'YES' : 'NO'}, hs=$homeserverStr",
        );

        if (token == null) {
          debugPrint("[SSO] No loginToken in callback URL — aborting");
          return;
        }

        try {
          if (homeserverStr != null) {
            client.homeserver = Uri.parse(homeserverStr);
            debugPrint("[SSO] Set homeserver to $homeserverStr");
          }
          debugPrint("[SSO] Attempting token login...");
          await client.login(LoginType.mLoginToken, token: token);
          debugPrint("[SSO] Login successful");
          final navContext = rootNavigatorKey.currentContext;
          if (navContext != null && navContext.mounted) {
            await showStartroomDialog(navContext, client);
          }
          router.go('/');
        } catch (e, stack) {
          debugPrint("[SSO] Login ERROR: $e\n$stack");
          router.go('/auth/login');
        }
        return;
      }

      // For any other deep links, show a confirmation dialog before navigating.
      final location = uri.hasQuery ? '$routePath?${uri.query}' : routePath;
      final navContext = rootNavigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) {
        router.go(location);
        return;
      }

      // Determine the deep link type and identifier for the dialog.
      DeepLinkType linkType = DeepLinkType.generic;
      String? identifier = routePath;

      if (routePath.startsWith('/feed/')) {
        linkType = DeepLinkType.room;
        final roomPart = routePath.substring('/feed/'.length);
        identifier = roomPart.startsWith('!') ? roomPart : '#$roomPart';
      } else if (routePath.startsWith('/profile/')) {
        linkType = DeepLinkType.user;
        identifier = Uri.decodeComponent(
          routePath.substring('/profile/'.length),
        );
      } else if (routePath.startsWith('/post/')) {
        linkType = DeepLinkType.post;
        identifier = null;
      }

      // Check if user is logged in for protected routes.
      if (!client.isLogged() && linkType != DeepLinkType.generic) {
        final wantsLogin = await showDeepLinkLoginRequired(navContext);
        if (wantsLogin && navContext.mounted) {
          router.go('/auth/host');
        }
        return;
      }

      final confirmed = await showDeepLinkConfirmation(
        navContext,
        type: linkType,
        identifier: identifier,
      );

      if (confirmed) {
        router.go(location);
      }
    });
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('de', 'DE'),
        Locale('fr', 'FR'),
        Locale('af'),
        Locale('am'),
        Locale('ar'),
        Locale('az', 'AZ'),
        Locale('be'),
        Locale('bg'),
        Locale('bn', 'BD'),
        Locale('ca'),
        Locale('cs', 'CZ'),
        Locale('da', 'DK'),
        Locale('el', 'GR'),
        Locale('en', 'AU'),
        Locale('en', 'GB'),
        Locale('en', 'IN'),
        Locale('es', '419'),
        Locale('es', 'ES'),
        Locale('et'),
        Locale('eu', 'ES'),
        Locale('fa'),
        Locale('fi', 'FI'),
        Locale('fil'),
        Locale('fr', 'CA'),
        Locale('gl', 'ES'),
        Locale('gu'),
        Locale('he', 'IL'),
        Locale('hi', 'IN'),
        Locale('hr'),
        Locale('hu', 'HU'),
        Locale('hy', 'AM'),
        Locale('id'),
        Locale('is', 'IS'),
        Locale('it', 'IT'),
        Locale('ja', 'JP'),
        Locale('ka', 'GE'),
        Locale('kk'),
        Locale('km', 'KH'),
        Locale('kn', 'IN'),
        Locale('ko', 'KR'),
        Locale('ky', 'KG'),
        Locale('lo', 'LA'),
        Locale('lt'),
        Locale('lv'),
        Locale('ml', 'IN'),
        Locale('mn', 'MN'),
        Locale('mr', 'IN'),
        Locale('ms'),
        Locale('my', 'MM'),
        Locale('ne', 'NP'),
        Locale('nl', 'NL'),
        Locale('no', 'NO'),
        Locale('pa'),
        Locale('pl', 'PL'),
        Locale('pt', 'BR'),
        Locale('pt', 'PT'),
        Locale('rm'),
        Locale('ro'),
        Locale('ru', 'RU'),
        Locale('si', 'LK'),
        Locale('sk'),
        Locale('sl'),
        Locale('sr'),
        Locale('sv', 'SE'),
        Locale('sw'),
        Locale('ta', 'IN'),
        Locale('te', 'IN'),
        Locale('th'),
        Locale('tr', 'TR'),
        Locale('uk'),
        Locale('ur'),
        Locale('vi'),
        Locale('zh', 'CN'),
        Locale('zh', 'HK'),
        Locale('zh', 'TW'),
        Locale('zu'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      child: SubstitutionApp(client: client, router: router),
    ),
  );
}

class SubstitutionApp extends StatelessWidget {
  final Client client;
  final GoRouter router;

  const SubstitutionApp({
    super.key,
    required this.client,
    required this.router,
  });

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeService(),
      builder: (context, _) {
        final themeService = context.watch<ThemeService>();
        return MaterialApp.router(
          routerDelegate: router.routerDelegate,
          routeInformationParser: router.routeInformationParser,
          routeInformationProvider: router.routeInformationProvider,
          localizationsDelegates: [
            ...context.localizationDelegates,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeService.themeMode,
          builder:
              (context, child) => MultiProvider(
                providers: [
                  Provider<Client>(create: (context) => client),
                  ChangeNotifierProvider<SubstitutionService>(
                    create: (context) {
                      final svc = SubstitutionService(client);
                      globalSubstitutionService = svc;
                      return svc;
                    },
                  ),
                  Provider<ConnectivityService>(
                    create: (_) => ConnectivityService(),
                  ),
                  ChangeNotifierProvider<AuthState>(create: (_) => AuthState()),
                  Provider<FeedStateCache>(create: (_) => FeedStateCache()),
                  ChangeNotifierProvider<LoadingService>(
                    create: (_) => LoadingService(),
                  ),
                ],
                child: child,
              ),
        );
      },
    );
  }
}

class IntroductionPage extends StatefulWidget {
  const IntroductionPage({super.key});

  @override
  State<IntroductionPage> createState() => _IntroductionState();
}

class _IntroductionState extends State<IntroductionPage> {
  late final Client client = Provider.of<Client>(context, listen: false);
  final _introKey = GlobalKey<IntroductionScreenState>();

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      key: _introKey,
      pages: [
        PageViewModel(
          title: "intro.welcome.title".tr(),
          image: Image(
            image: const AssetImage('assets/icon/logo.png'),
            errorBuilder:
                (ctx, err, stack) =>
                    const Icon(Icons.image_not_supported, size: 80),
          ),
          bodyWidget: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: const Text("intro.welcome.desc").tr()),
                ],
              ),
            ],
          ),
        ),
        PageViewModel(
          title: "intro.account.title".tr(),
          bodyWidget: Column(
            //mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text("intro.account.desc").tr(),
            ],
          ),
        ),
        PageViewModel(
          title: "intro.host.title".tr(),
          bodyWidget: Column(
            children: [
              if (client.isLogged()) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text("intro.isLoggedIn").tr(),
              ] else ...[
                HostPage(onComplete: () => {_introKey.currentState?.next()}),
              ],
            ],
          ),
        ),
        PageViewModel(
          title: "intro.login.title".tr(),
          bodyWidget: Column(
            children: [
              if (client.isLogged()) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text("intro.isLoggedIn").tr(),
              ] else
                LoginPage(
                  onComplete: () {
                    _introKey.currentState?.next();
                    setState(() {});
                  },
                ),
            ],
          ),
        ),
        PageViewModel(
          title: "intro.finished.title".tr(),
          bodyWidget: Column(
            children: [
              if (!client.isLogged()) ...[
                const Text("intro.isNotLoggedIn").tr(),
              ] else ...[
                const Text("intro.finished.desc").tr(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('introGoButton'),
                    onPressed: () async {
                      final goRouter = GoRouter.of(context);
                      await showStartroomDialog(context, client);
                      if (mounted) {
                        goRouter.go("/");
                      }
                    },
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text("intro.finished.buttons.go").tr(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      canProgress: (int toPage) {
        if (toPage <= 2) {
          // allow navigation to Welcome, Account, and Host pages
          return true;
        } else if (toPage == 3 &&
            client.homeserver != null &&
            client.homeserver.toString() != "") {
          // only allow navigation to Login page if homeserver is set
          return true;
        } else if (toPage == 4 && client.isLogged()) {
          // only allow navigation to Finished page if logged in
          return true;
        } else {
          return false;
        }
      },
      showNextButton: true,
      showBackButton: true,
      showDoneButton: false,
      next: const Text("intro.buttons.next").tr(),
      back: const Text("intro.buttons.back").tr(),
    );
  }
}

/// Branded animated loading screen shown immediately on startup while heavy
/// async initialization (database, Matrix client, localization) completes.
/// Uses no localization or providers — just the app's visual identity.
class _StartupLoadingScreen extends StatefulWidget {
  const _StartupLoadingScreen();

  @override
  State<_StartupLoadingScreen> createState() => _StartupLoadingScreenState();
}

class _StartupLoadingScreenState extends State<_StartupLoadingScreen>
    with TickerProviderStateMixin {
  static const _sage = Color(0xFF5B8C5A);
  static const _lightBg = Color(0xFFFFFBF8);
  static const _darkBg = Color(0xFF111315);

  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _dotsController;
  late final AnimationController _glowController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    // Logo: scale up + fade in over 600ms
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));

    // Text: fade + slide up, starts after logo
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // Dots: looping for pulse effect
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Glow: slow pulsing radial gradient
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Sequence the animations
    _logoController.forward().then((_) {
      if (mounted) {
        _textController.forward();
        _dotsController.repeat();
        _glowController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _dotsController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? _darkBg : _lightBg;
    final textColor =
        isDark ? const Color(0xFFE3E2DF) : const Color(0xFF1A1C1E);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light),
      darkTheme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
        backgroundColor: bg,
        body: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glowSize = 0.4 + (_glowController.value * 0.15);
            final glowOpacity = isDark ? 0.12 : 0.08;
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: glowSize,
                  colors: [_sage.withValues(alpha: glowOpacity), bg],
                ),
              ),
              child: child,
            );
          },
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated logo
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: child,
                      ),
                    );
                  },
                  child: const Image(
                    image: AssetImage('assets/icon/logo.png'),
                    width: 88,
                    height: 88,
                    errorBuilder: _logoErrorBuilder,
                  ),
                ),

                const SizedBox(height: 20),

                // App name slides up
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Text(
                      'substitution',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // Pulsing dots loader
                AnimatedBuilder(
                  animation: _dotsController,
                  builder: (context, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        // Stagger each dot by 0.2 of the animation cycle
                        final offset = i * 0.2;
                        final t = (_dotsController.value - offset) % 1.0;
                        // Smooth pulse: peak at 0.3, fade by 0.6
                        final pulse =
                            t < 0.3
                                ? (t / 0.3)
                                : t < 0.6
                                ? 1.0 - ((t - 0.3) / 0.3)
                                : 0.0;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _sage.withValues(
                              alpha: 0.25 + (pulse * 0.75),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _logoErrorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return const Icon(Icons.spa_rounded, size: 88, color: _sage);
  }
}
