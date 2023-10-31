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
          title: "Welcome to the ...",
          bodyWidget: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text("...dem [neuen] soziale Netzwerk auf Basis von "),
              SvgPicture.string(
                  '''<svg width="66" height="28" viewBox="0 0 66 28" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M0.975097 0.640961V27.359H2.89517V28H0.238281V0H2.89517V0.640961H0.975097Z" fill="#2D2D2D"/>
              <path d="M8.37266 9.11071V10.4628H8.4111C8.7712 9.94812 9.20494 9.54849 9.71306 9.26518C10.2208 8.98235 10.8029 8.84036 11.4586 8.84036C12.0885 8.84036 12.664 8.96298 13.1846 9.2074C13.7054 9.45223 14.1009 9.88336 14.371 10.5015C14.6665 10.0638 15.0683 9.67744 15.5764 9.34266C16.0842 9.00804 16.6852 8.84036 17.3797 8.84036C17.9069 8.84036 18.3953 8.90487 18.8457 9.03365C19.2955 9.16242 19.6812 9.36843 20.0027 9.65166C20.3239 9.93515 20.5746 10.3053 20.755 10.7621C20.9349 11.2196 21.025 11.7698 21.025 12.4139V19.0966H18.2861V13.4373C18.2861 13.1027 18.2734 12.7872 18.2475 12.4908C18.2216 12.1949 18.1512 11.9375 18.0354 11.7183C17.9196 11.4996 17.7491 11.3256 17.5243 11.1967C17.2993 11.0684 16.9938 11.0037 16.6081 11.0037C16.2225 11.0037 15.9106 11.0782 15.6727 11.2257C15.4346 11.374 15.2483 11.5673 15.1134 11.8052C14.9784 12.0438 14.8884 12.314 14.8435 12.6168C14.7982 12.9192 14.7759 13.2252 14.7759 13.5342V19.0966H12.0372V13.4955C12.0372 13.1994 12.0305 12.9063 12.0181 12.6168C12.005 12.3269 11.9506 12.0598 11.8539 11.815C11.7575 11.5706 11.5967 11.374 11.3717 11.2257C11.1467 11.0782 10.8156 11.0037 10.3785 11.0037C10.2497 11.0037 10.0794 11.0327 9.86746 11.0908C9.65528 11.1487 9.44941 11.2584 9.25027 11.4191C9.05071 11.5802 8.88053 11.812 8.73908 12.1143C8.59754 12.4171 8.5269 12.8128 8.5269 13.3021V19.0966H5.78833V9.11071H8.37266Z" fill="#2D2D2D"/>
              <path fill-rule="evenodd" clip-rule="evenodd" d="M23.8596 9.55506C23.4223 9.81286 23.0621 10.1539 22.7794 10.5789C22.4962 11.0036 22.3357 11.5382 22.2974 12.1818H25.036C25.0872 11.6412 25.2676 11.2547 25.5761 11.023C25.8847 10.7912 26.309 10.6752 26.8491 10.6752C27.0931 10.6752 27.3215 10.6917 27.5338 10.7234C27.7458 10.7558 27.9322 10.8202 28.093 10.9167C28.2537 11.0132 28.3823 11.1487 28.4787 11.3224C28.5752 11.4962 28.6233 11.7313 28.6233 12.0273C28.6359 12.3108 28.5523 12.5264 28.3726 12.6745C28.1924 12.8227 27.9483 12.9352 27.6397 13.0124C27.3311 13.0897 26.9774 13.1477 26.5789 13.1864C26.1802 13.225 25.7753 13.2766 25.3638 13.3408C24.9523 13.4056 24.5441 13.4923 24.1392 13.6016C23.734 13.711 23.374 13.8752 23.0592 14.094C22.7437 14.3131 22.4867 14.6059 22.2876 14.9731C22.0879 15.3398 21.9884 15.8067 21.9884 16.3731C21.9884 16.8879 22.0753 17.3326 22.2489 17.706C22.4225 18.0793 22.6635 18.3884 22.9722 18.6327C23.2807 18.8778 23.6406 19.0579 24.0522 19.1739C24.4636 19.2896 24.9072 19.3476 25.3831 19.3476C26.0003 19.3476 26.6046 19.2572 27.1963 19.0774C27.7873 18.897 28.3018 18.5815 28.739 18.1308C28.7517 18.2983 28.7741 18.4625 28.8065 18.6232C28.8385 18.7843 28.8804 18.9418 28.932 19.0965H31.7091C31.5805 18.8906 31.4903 18.5815 31.4393 18.1693C31.3877 17.7573 31.362 17.3264 31.362 16.8751V11.6798C31.362 11.0745 31.227 10.5883 30.957 10.2214C30.6868 9.85459 30.3398 9.56787 29.9155 9.36194C29.4911 9.15619 29.0217 9.0176 28.5074 8.94652C27.9931 8.87594 27.4854 8.84036 26.9838 8.84036C26.431 8.84036 25.8812 8.89531 25.3348 9.00463C24.7882 9.1142 24.2966 9.2976 23.8596 9.55506ZM27.6302 14.5965C27.8293 14.5578 28.0159 14.5096 28.1893 14.4518C28.363 14.3937 28.5076 14.3134 28.6235 14.21V15.2339C28.6235 15.3884 28.6072 15.5944 28.5754 15.8519C28.5431 16.1098 28.4562 16.3636 28.3149 16.6146C28.1732 16.8659 27.9548 17.0817 27.6592 17.2618C27.3632 17.4423 26.9455 17.5322 26.4055 17.5322C26.1868 17.5322 25.9747 17.5129 25.7692 17.4742C25.5632 17.4358 25.3833 17.368 25.2291 17.2715C25.0748 17.175 24.9525 17.0431 24.8625 16.8754C24.7724 16.7084 24.7275 16.502 24.7275 16.2576C24.7275 16.0001 24.7724 15.7876 24.8625 15.6201C24.9525 15.4531 25.0713 15.3145 25.2194 15.205C25.3671 15.0956 25.5407 15.0089 25.7402 14.9441C25.9393 14.88 26.1418 14.828 26.3476 14.7897C26.566 14.7511 26.7846 14.719 27.0034 14.693C27.2219 14.6674 27.4308 14.6352 27.6302 14.5965Z" fill="#2D2D2D"/>
              <path d="M38.5753 9.11176V10.9467H36.5696V15.8914C36.5696 16.3547 36.6467 16.6639 36.8011 16.8183C36.9552 16.9728 37.264 17.05 37.7268 17.05C37.8812 17.05 38.0288 17.0437 38.1704 17.0307C38.3117 17.0181 38.4468 16.9985 38.5753 16.9729V19.0975C38.3439 19.1362 38.0866 19.1618 37.8039 19.1749C37.521 19.1873 37.2446 19.194 36.9746 19.194C36.5503 19.194 36.1484 19.1649 35.7692 19.1069C35.3897 19.0491 35.0555 18.9367 34.7663 18.7691C34.4769 18.602 34.2486 18.3635 34.0816 18.0544C33.9143 17.7457 33.8308 17.3399 33.8308 16.8375V10.9467H32.1722V9.11176H33.8308V6.11795H36.5696V9.11176H38.5753Z" fill="#2D2D2D"/>
              <path d="M42.4905 9.11088V10.9652H42.5291C42.6575 10.6559 42.831 10.3697 43.0498 10.1055C43.2684 9.84179 43.519 9.61625 43.8019 9.42953C44.0845 9.24315 44.3869 9.09824 44.7086 8.99491C45.0297 8.89207 45.3642 8.84036 45.7115 8.84036C45.8914 8.84036 46.0905 8.87278 46.3093 8.93705V11.4868C46.1806 11.4608 46.0263 11.4382 45.8465 11.4191C45.6663 11.3997 45.4928 11.39 45.3256 11.39C44.8242 11.39 44.3999 11.474 44.0529 11.6411C43.7057 11.8086 43.4262 12.0369 43.2139 12.3267C43.0018 12.6166 42.8504 12.9544 42.7605 13.3408C42.6706 13.727 42.6256 14.1457 42.6256 14.5963V19.0966H39.8869V9.11088H42.4905Z" fill="#2D2D2D"/>
              <path fill-rule="evenodd" clip-rule="evenodd" d="M47.467 5.3064V7.56622H50.2059V5.3064H47.467ZM50.2054 19.0974V9.11166H47.4665V19.0974H50.2054Z" fill="#2D2D2D"/>
              <path d="M51.6319 9.1106H54.7563L56.5115 11.7181L58.2473 9.1106H61.2753L57.9966 13.7849L61.6805 19.0964H58.5559L56.4729 15.9482L54.3898 19.0964H51.3235L54.9107 13.843L51.6319 9.1106Z" fill="#2D2D2D"/>
              <path d="M65.0246 27.359V0.640961H63.1046V0H65.7616V28H63.1046V27.359H65.0246Z" fill="#2D2D2D"/>
              </svg>'''),
              // TODO: img taken from https://github.com/matrix-org/matrix.to/blob/main/images/matrix-logo.svg - ask for permission
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
      next: const Text("Next"),
      back: const Text("Back"),
      onDone: () {
        context.go("/");
      },
    );
  }
}
