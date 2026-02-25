import '/auth/auth.dart';
import '/auth/auth_state.dart';
import '/feed/feed.dart';
import '/post/post.dart';
import '/settings/pages/followfeeds.dart';
import '/settings/pages/ownfeeds.dart';
import '/settings/pages/key_verification.dart';
import '/settings/pages/profile.dart';
import '/write/pages/textmessage.dart';
import '/settings/pages/room_permissions.dart';
import '/settings/pages/legal.dart';
import '/write/pages/filemessage.dart';
import '/write/pages/roomselect.dart';
import '/auth/pages/host_page.dart';
import '/auth/pages/login.dart';
import '/shared/pages/scaffold_with_navigation.dart';
import '/shared/pages/age_gate.dart';
import '/profile/pages/user_profile.dart';
import '/shared/services/theme_service.dart';
import '/shared/services/connectivity_service.dart';
import '/shared/services/substitution_service.dart';

import '/shared/constants.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart'; // init matrix
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart'; // provide the client across widgets/pages/routes
import 'package:go_router/go_router.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
// import 'package:logging/logging.dart' as l; // see @logging

// Global client reference for test teardown use only
Client? globalMatrixClient;

// Global SubstitutionService reference for test access only
SubstitutionService? globalSubstitutionService;

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
  // Must be first — plugins like SharedPreferences and url_strategy need it.
  WidgetsFlutterBinding.ensureInitialized();

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
        path: '/settings/room/:roomId/permissions',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          return ScaffoldWithNavigation(
            child: RoomPermissionsPage(roomId: roomId),
          );
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
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            "Login Failed",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              snapshot.error.toString(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => context.go('/auth/login'),
                            child: const Text("Back to Login"),
                          ),
                        ],
                      ),
                    );
                  }
                  // Success - Show manual continue button
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 64,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Login Successful!",
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text("You can now proceed to the app."),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: () {
                            debugPrint(
                              "User clicked Continue button. Navigating to /",
                            );
                            context.go('/');
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text("Continue to App"),
                        ),
                      ],
                    ),
                  );
                }
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Logging in..."),
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

    matrixDatabase = await MatrixSdkDatabase.init(
      "Substitution",
      database: database,
    );
  } else {
    // Web support: use default (IndexedDB)
    matrixDatabase = await MatrixSdkDatabase.init("Substitution");
  }

  // Dispose previous client if any (for test isolation)
  if (globalMatrixClient != null) {
    try {
      await globalMatrixClient!.dispose();
    } catch (_) {}
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
          debugPrint("[SSO] Login successful — navigating to /");
          router.go('/');
        } catch (e, stack) {
          debugPrint("[SSO] Login ERROR: $e\n$stack");
          router.go('/auth/login');
        }
        return;
      }

      // For any other deep links, navigate normally.
      final location = uri.hasQuery ? '$routePath?${uri.query}' : routePath;
      router.go(location);
    });
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('de', 'DE'),
        Locale('fr', 'FR'),
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
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.green,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.green,
            brightness: Brightness.dark,
          ),
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
                //Spacer(),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green[200],
                    border: Border.all(width: 1, color: Colors.grey),
                  ),
                  child: Icon(Icons.check, size: 60, color: Colors.grey[800]),
                ),
                const SizedBox(height: 30),
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
                //Spacer(),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green[200],
                    border: Border.all(width: 1, color: Colors.grey),
                  ),
                  child: Icon(Icons.check, size: 60, color: Colors.grey[800]),
                ),
                const SizedBox(height: 30),
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
                ElevatedButton(
                  onPressed: () async {
                    String id = AppConstants.substitutionRoomAlias;

                    final goRouter = GoRouter.of(context);
                    try {
                      // try, so it'll not fail if we already joined the room. TODO; make this an optional step and handle, if we don't follow any rooms

                      await client.joinRoom(id, serverName: ["matrix.org"]);
                      await client.setAccountDataPerRoom(
                        client.userID!,
                        id,
                        "substitution",
                        {"joined": true},
                      );
                    } catch (e) {
                      debugPrint("Error joining default room: $e");
                    }

                    goRouter.go("/");
                  },
                  child:
                      const Text(
                        "intro.finished.buttons.add_to_room_and_go",
                      ).tr(),
                ),
                ElevatedButton(
                  key: const Key('introGoButton'),
                  // todo: nicer button...
                  onPressed: () async {
                    // todo: adapted from settings/pages/followFeeds.dart -> make it a mixin
                    if (mounted) {
                      context.go("/");
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.east),
                      const SizedBox(width: 8),
                      const Text("intro.finished.buttons.go").tr(),
                    ],
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
