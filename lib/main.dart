import 'package:substitution/auth/auth.dart'; // auth subroute
import 'package:substitution/feed/feed.dart'; // feed subroute
import 'package:substitution/post/post.dart'; // post subroute
import 'package:substitution/settings/pages/followfeeds.dart'; // feedsettings subroute
import 'package:substitution/write/pages/textmessage.dart';
import 'package:substitution/write/pages/filemessage.dart';
import 'package:substitution/write/pages/roomselect.dart';

import 'package:flutter/material.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart'; // init matrix

import 'package:provider/provider.dart'; // provide the client across widgets/pages/routes
import 'package:go_router/go_router.dart';

import 'package:introduction_screen/introduction_screen.dart';

import 'package:flutter_svg/flutter_svg.dart';

import 'package:substitution/auth/pages/host.dart';
import 'package:substitution/auth/pages/login.dart';

import 'package:easy_localization/easy_localization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await Hive.initFlutter();

  final client = Client(
    "Substitution",
    databaseBuilder: (_) async {
      final HiveCollectionsDatabase db;

      if (const bool.fromEnvironment('dart.library.js_util')) {
        // we are in web -> do not use an temp directory
        db = HiveCollectionsDatabase('Substitution', null);
      } else {
        // for all other platforms: get a tmp directory
        final dir =
            await getApplicationSupportDirectory(); // Recommend path_provider package
        db = HiveCollectionsDatabase('Substitution', dir.path);
      }

      await db.open();
      return db;
    },
  );

  await client.init();
  runApp(EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('de', 'DE')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      child: SubstitutionApp(client: client)));
}

class SubstitutionApp extends StatelessWidget {
  final Client client;

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

  const SubstitutionApp({required this.client, Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation:
              '/', // TODO: checken ob wir eingeloggt sind und mindestens einem Raum beigetreten

          routes: [
            GoRoute(
              path: '/',
              redirect: (BuildContext context, GoRouterState state) async {
                if (!Provider.of<Client>(context, listen: false).isLogged() ||
                    (await _getJoinedRooms()).isEmpty) {
                  return '/intro';
                } else {
                  return null;
                }
              },
              builder: (context, state) {
                return const Feed();
              },
            ),
            GoRoute(
              path: '/intro',
              builder: (context, state) => const IntroductionPage(),
            ),
            GoRoute(
              path: '/feed/:roomId',
              builder: (context, state) =>
                  state.pathParameters['roomId']!.startsWith("!")
                      ? Feed(roomId: state.pathParameters['roomId']!)
                      : Feed(roomId: "#${state.pathParameters['roomId']!}"),
            ),
            GoRoute(
              path: '/post/:id',
              builder: (context, state) {
                final eventId = state.pathParameters['id']!;
                final roomId = state.uri.queryParameters['room']!;
                return Post(eventId: eventId, roomId: roomId);
              },
            ),
            GoRoute(
                path: '/write/select/room',
                builder: (context, state) {
                  return const RoomSelectPage();
                }),
            GoRoute(
                path: '/write/:roomid',
                builder: (contxt, state) {
                  final String? eventId = state.uri.queryParameters['event'];
                  final String roomId = state.pathParameters['roomid']!;
                  return TextMessageWrite(eventId: eventId, roomId: roomId);
                }),
            GoRoute(
                path: '/file/:roomid',
                builder: (contxt, state) {
                  final String? eventId = state.uri.queryParameters['event'];
                  final String roomId = state.pathParameters['roomid']!;
                  return FileMessageWrite(eventId: eventId, roomId: roomId);
                }),
            GoRoute(
                path: '/auth/host',
                builder: (context, state) =>
                    const AuthFlow(authPageRoute: 'host')),
            GoRoute(
                path: '/auth/login',
                builder: (context, state) =>
                    const AuthFlow(authPageRoute: 'login')),
            GoRoute(
                path: '/settings/feed',
                builder: (context, state) => const FollowFeedSettings()),
          ],
        ),
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
          title: "Welcome to Substitution...",
          // todo: remove string and include the svg as an asset
          image:  Image(image: AssetImage('assets/icon/logo.png')),
          bodyWidget: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text("...dem [neuen] soziale Netzwerk auf Basis von Matrix"), // todo: intl
            ]),
          ]),
          //image: const Center(child: Icon(Icons.android)),
        ),
        PageViewModel(
          title: "Matrix Accounts",
          bodyWidget: Column(
              //mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Text(
                    "Um zu speichern, welchen Räumen du beigetreten bist wird ein Account bei einem der vielen Anbieter für Matrix verwendet. \nBitte logge dich im folgenden Schritt ein. \n\nUm mehr über Matrix Server zu erfahren, [klicke hier]. Für eine Liste von Servern [klicke hier]."),
                const SizedBox(height: 10),
                Text(
                    "Tipps:\n- Du kannst von jedem Server auf jeden anderen Zugreifen (Stichwort federation) \n- Das spätere Übertragen von Benutzerinformationen ist noch nicht möglich, an diesem Feature wird jedoch gearbeitet [siehe hier]."),
              ]),
        ),
        PageViewModel(
            title: "Choose Host",
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
                Text("Super, du bist eingelogged."),
                Text("Fahre einfach mit demnächsten Schritt fort")
              ] else ...[
                HostPage(onComplete: () => {_introKey.currentState?.next()})
              ],
            ])),
        PageViewModel(
          title: "Login",
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
              Text("Super, du bist eingelogged."),
              Text("Fahre einfach mit demnächsten Schritt fort")
            ] else
              LoginPage(onComplete: () {
                _introKey.currentState?.next();
                setState(() {});
              })
          ]),
        ),
        PageViewModel(
          title: "Los gehts",
          bodyWidget: Column(children: [
            if (!client.isLogged()) ...[
              Text("Bitte logge dich erst ein")
            ] else ...[
              Text("Super! Es bleibt der letzte Schritt:"),
              Text(
                  "Du wirst dem Raum #.... beigetreten werden, damit es nicht so leer aussieht."),
              Text("Anschließend kommst du auf die Startseite."),
              Text("Viel Spass mit [...]!"),
              SizedBox(height: 20),
              FilledButton(
                // todo: nicer button...
                onPressed: () async {
                  // todo: adapted from settings/pages/followFeeds.dart -> make it a mixin
                  String id =
                      "#photo_art:matrix.org"; // TODO: change this to a real starting room

                  try {
                    // try, so it'll not fail if we already joined the room. TODO; make this an optional step and handle, if we don't follow any rooms

                    await client.joinRoom(id, serverName: ["matrix.org"]);
                    await client.setAccountDataPerRoom(
                        client.userID!, id, "substitution", {"joined": true});

                    if (!mounted) return;
                  } catch (e) {} // TODO: error handling...

                  context.go("/");
                },
                child:
                    Row(children: [const Icon(Icons.east), Text("Let's go")]),
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
      next: const Text("Next"), // TODO intl
      back: const Text("Back"),
      onDone: () {
        context.go("/");
      },
    );
  }
}
