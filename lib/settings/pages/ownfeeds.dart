import 'package:flutter/material.dart';

@immutable
class AddFeedSettings extends StatefulWidget {
  const AddFeedSettings({super.key});

  static AddFeedSettingsState of(BuildContext context) {
    return context.findAncestorStateOfType<AddFeedSettingsState>()!;
  }

  @override
  AddFeedSettingsState createState() => AddFeedSettingsState();
}

/*
TODO: hier sollen die _eigenen_ feeds gemanaged werden, also quasi für "influencer",
also so sachen wie "löschen" des feeds, vielleicht "automatische konfiguration", etc.
*/

class AddFeedSettingsState extends State<AddFeedSettings> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // ich will mindestens ein Ergebnis von jedem server, dann soll man aber durchscrollen können durch alle Ergebnisse
    // eine suchbar, bei der man aber auch ganz manuell eingeben kann, damit bspw. copy/paste von räumen möglich ist

    return const Column(children: [
      Padding(padding: EdgeInsets.all(16.0), child: Column(children: [])),

      // TODO: hier was zum adden/suchen von neuen räumen hinzufügen, auch von servern
      // das hier am besten nach servern aufteilen. Vielleicht auch nach servern filtern?
      //ListView(children: [])
    ]);

    /*FutureBuilder(
          future: eventTimelineTuple,
          builder: (ctx, snapshot) {
            if (snapshot.data != null) {
              return PostPage(
                  event: (snapshot.data!.$1), timeline: (snapshot.data!.$2));
            }
            return const Error404Page(); // TODO: some better error handling
          }),*/
  }
}
