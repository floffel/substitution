import '/auth/auth.dart';
import '/feed/feed.dart';
import '/post/post.dart';
import '/settings/pages/followfeeds.dart';
import '/settings/pages/ownfeeds.dart';
import '/write/pages/textmessage.dart';
import '/write/pages/filemessage.dart';
import '/write/pages/roomselect.dart';
import '/auth/pages/host.dart';
import '/auth/pages/login.dart';
import '/shared/pages/scaffold_with_navigation.dart';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart'; // init matrix
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart'; // provide the client across widgets/pages/routes
import 'package:go_router/go_router.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
// import 'package:logging/logging.dart' as l; // see @logging

void main() async {
  // Initialize FFI for Linux desktop support
  // Initialize FFI for Linux desktop support
  if (!kIsWeb && Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  usePathUrlStrategy();

  /*
  // @logging This is to debug GoRouter, wich will not output anything without it
  l.Logger.root.level = l.Level.ALL; // defaults to Level.INFO
  l.Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  }); // */

  final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: "rootNav");

  String? testRedirect(BuildContext context, GoRouterState state) {
    if (!Provider.of<Client>(context, listen: false).isLogged()) {
      return '/intro';
    } else {
      return null;
    }
  }

  GoRouter router = GoRouter(
      debugLogDiagnostics: true,
      navigatorKey: rootNavigatorKey,
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          redirect: testRedirect,
          builder: (_, __) => const Feed(),
          //parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (_, __) {
            // needed b.c. /feed:roomId has the same widget
            return CustomTransitionPage<void>(
                key: UniqueKey(),
                child: const Feed(),
                transitionsBuilder: (_, __, ___, child) => child);
          },
        ),
        GoRoute(
          redirect: testRedirect,
          path: '/write/select/room', // write/select/room
          builder: (_, __) =>
              ScaffoldWithNavigation(child: const RoomSelectPage()),
        ),
        GoRoute(
          path: '/intro',
          builder: (context, state) =>
              ScaffoldWithNavigation(child: const IntroductionPage()),
        ),
        GoRoute(
            redirect: testRedirect,
            path: '/feed/:roomId',
            builder: (context, state) => Feed(
                roomId: state.pathParameters['roomId']!.startsWith("!")
                    ? state.pathParameters['roomId']!
                    : "#${state.pathParameters['roomId']!}")),
        GoRoute(
          redirect: testRedirect,
          path: '/post/:id',
          builder: (context, state) {
            final eventId = state.pathParameters['id']!;
            final roomId = state.uri.queryParameters['room']!;
            return ScaffoldWithNavigation(
                child: Post(eventId: eventId, roomId: roomId));
          },
        ),
        GoRoute(
            redirect: testRedirect,
            path: '/write/:roomid',
            builder: (contxt, state) {
              final String? eventId = state.uri.queryParameters['event'];
              final String roomId = state.pathParameters['roomid']!;
              return ScaffoldWithNavigation(
                  child: TextMessageWrite(eventId: eventId, roomId: roomId));
            }),
        GoRoute(
            // TODO: have some ?goto=/feed/... functionality, so we can link to /into and link back to the page the user originaly wanted to visit
            redirect: testRedirect,
            path: '/file/:roomid',
            builder: (contxt, state) {
              final String? eventId = state.uri.queryParameters['event'];
              final String roomId = state.pathParameters['roomid']!;
              return ScaffoldWithNavigation(
                  child: FileMessageWrite(eventId: eventId, roomId: roomId));
            }),
        GoRoute(
            redirect: testRedirect,
            path: '/settings/feed',
            builder: (context, state) =>
                ScaffoldWithNavigation(child: const FollowFeedSettings())),
        GoRoute(
            redirect: testRedirect,
            path: '/settings/ownfeeds',
            builder: (context, state) =>
                ScaffoldWithNavigation(child: const OwnFeedSettings())),
        GoRoute(
            path: '/auth/host',
            builder: (context, state) => const AuthFlow(authPageRoute: 'host')),
        GoRoute(
            path: '/auth/login',
            builder: (context, state) =>
                const AuthFlow(authPageRoute: 'login')),
        GoRoute(
          path: '/login-callback',
          builder: (context, state) {
             return Scaffold(
               body: FutureBuilder<void>(
                 future: () async {
                    final token = state.uri.queryParameters['loginToken'];
                    final homeserverStr = state.uri.queryParameters['homeserver'];
                    
                    print("Callback params: token=${token != null ? 'YES' : 'NO'}, hs=$homeserverStr");

                    if (token == null) {
                      throw Exception("No login token received");
                    }

                    final client = Provider.of<Client>(context, listen: false);
                    
                    // Configure homeserver if provided and not set
                    if (homeserverStr != null) {
                      client.homeserver = Uri.parse(homeserverStr);
                      print("Configured client homeserver to: $homeserverStr");
                    } else if (client.homeserver == null) {
                       print("Warning: No homeserver configured for token login!");
                    }

                    print("[SSO] Attempting login with token...");
                    try {
                      // Fix: m.login.token requires 'token' parameter, not 'password'
                      // Add timeout to detect hangs
                      await client.login(LoginType.mLoginToken, token: token)
                          .timeout(const Duration(seconds: 15), onTimeout: () {
                             throw TimeoutException("Login timed out after 15 seconds");
                          });
                      print("[SSO] Login successful!");
                    } catch (e, stack) {
                      print("[SSO] Login ERROR: $e");
                      print(stack);
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
                             Text("Login Failed", style: Theme.of(context).textTheme.titleLarge),
                             Padding(
                               padding: const EdgeInsets.all(16.0),
                               child: Text(snapshot.error.toString(), textAlign: TextAlign.center),
                             ),
                             ElevatedButton(
                               onPressed: () => context.go('/auth/login'), 
                               child: const Text("Back to Login")
                             )
                           ],
                         ),
                       );
                     }
                     // Success - Show manual continue button
                     return Center(
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           const Icon(Icons.check_circle, color: Colors.green, size: 64),
                           const SizedBox(height: 24),
                           Text("Login Successful!", style: Theme.of(context).textTheme.headlineSmall),
                           const SizedBox(height: 8),
                           const Text("You can now proceed to the app."),
                           const SizedBox(height: 32),
                           FilledButton.icon(
                             onPressed: () {
                               print("User clicked Continue button. Navigating to /");
                               context.go('/');
                             }, 
                             icon: const Icon(Icons.arrow_forward),
                             label: const Text("Continue to App")
                           )
                         ],
                       ),
                     );
                   }
                   return const Center(child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       CircularProgressIndicator(),
                       SizedBox(height: 16),
                       Text("Logging in...")
                     ],
                   ));
                 },
               ),
             );
          },
        ),
      ]);

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
    matrixDatabase = await MatrixSdkDatabase.init(
      "Substitution",
    );
  }

  final client = Client(
    "Substitution",
    database: matrixDatabase,
  );

  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await client.init();

  runApp(EasyLocalization(
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('de', 'DE'),
        Locale('fr', 'FR')
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      child: SubstitutionApp(client: client, router: router)));
}

class SubstitutionApp extends StatelessWidget {
  final Client client;
  final GoRouter router;

  const SubstitutionApp(
      {super.key, required this.client, required this.router});

  // TODO: more or less the same as in settings/pages/followfeeds.dart so make it a mixin
  Future<List<Map<String, dynamic>>> _getJoinedRooms() async {
    List<Map<String, dynamic>> newData = [];

    for (String roomId in await client.getJoinedRooms()) {
      Room r = client.getRoomById(roomId)!;
      bool isInSubstitution = false;

      // get if in substitution, stolen from _fetchRooms, todo: make it a function or so...
      // todo: this only works with logged in clients!
      try {
        isInSubstitution = (await client.getAccountDataPerRoom(
                client.userID!, roomId, "substitution"))["joined"] ==
            true;
      } catch (_) {} // we cannot get the account data

      if (!isInSubstitution) {
        continue;
      }

      Map<String, dynamic> add = {
        // todo: do it with a typedef https://stackoverflow.com/questions/24762414/is-there-anything-like-a-struct-in-dart
        "name": r.name,
        "id": r.id,
        "isInsideSubstitution": isInSubstitution,
        "joined": true,
      };

      newData.add(add);
    }

    return newData;
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
        routerDelegate: router.routerDelegate,
        routeInformationParser: router.routeInformationParser,
        routeInformationProvider: router.routeInformationProvider,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.green, //brightness: Brightness.dark
          //primarySwatch: Colors.grey,
          //brightness: Brightness.dark,
        ),
        builder: (context, child) => MultiProvider(
              providers: [
                Provider<Client>(create: (context) => client),
                //Provider<Box<dynamic>>(create: (context) => settingsDB),
                // TODO: Hier weiter...
                // Ich brauche das ja garnicht! Man muss einfach bei jedem Server, dem man folgt, dem space beitreten
                // und jedem Raum, dem man folgt, beitreten. Somit bruache ich keine lokalen daten speichern und clients können sich immer wieder selbst "wiederherstellen"
              ],
              child: child,
            ));
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
          image: const Image(image: AssetImage('assets/icon/logo.png')),
          bodyWidget: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text("intro.welcome.desc").tr(),
            ]),
          ]),
        ),
        PageViewModel(
          title: "intro.account.title".tr(),
          bodyWidget: Column(
              //mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Text("intro.account.desc").tr(),
              ]),
        ),
        PageViewModel(
            title: "intro.host.title".tr(),
            bodyWidget: Column(children: [
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
                    child:
                        Icon(Icons.check, size: 60, color: Colors.grey[800])),
                const SizedBox(height: 30),
                const Text("intro.isLoggedIn").tr()
              ] else ...[
                HostPage(onComplete: () => {_introKey.currentState?.next()})
              ],
            ])),
        PageViewModel(
          title: "intro.login.title".tr(),
          bodyWidget: Column(children: [
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
                  child: Icon(Icons.check, size: 60, color: Colors.grey[800])),
              const SizedBox(height: 30),
              const Text("intro.isLoggedIn").tr()
            ] else
              LoginPage(onComplete: () {
                _introKey.currentState?.next();
                setState(() {});
              })
          ]),
        ),
        PageViewModel(
          title: "intro.finished.title".tr(),
          bodyWidget: Column(children: [
            if (!client.isLogged()) ...[
              const Text("intro.isNotLoggedIn").tr()
            ] else ...[
              const Text("intro.finished.desc").tr(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  String id =
                      "#substitution.art:matrix.org"; // TODO: change this to a real starting room

                  try {
                    // try, so it'll not fail if we already joined the room. TODO; make this an optional step and handle, if we don't follow any rooms

                    await client.joinRoom(id, serverName: ["matrix.org"]);
                    await client.setAccountDataPerRoom(
                        client.userID!, id, "substitution", {"joined": true});

                    if (!mounted) return;
                  } catch (e) {} // TODO: error handling...

                  context.go("/");
                },
                child: const Text("intro.finished.buttons.add_to_room_and_go")
                    .tr(),
              ),
              ElevatedButton(
                // todo: nicer button...
                onPressed: () async {
                  // todo: adapted from settings/pages/followFeeds.dart -> make it a mixin
                  context.go("/");
                },
                child: Row(children: [
                  const Icon(Icons.east),
                  const Text("intro.finished.buttons.go").tr()
                ]),
              ),
            ],
          ]),
        ),
      ],
      canProgress: (int toPage) {
        // TODO: splitted up for readability... Dose this has an effect on the performance?
        if (toPage < 2) {
          // only allow manual navigation to < 3
          return true;
        } else if (toPage == 2 &&
            client.homeserver != null &&
            client.homeserver.toString() != "") {
          return true;
        } else if (toPage == 3 && client.isLogged()) {
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
