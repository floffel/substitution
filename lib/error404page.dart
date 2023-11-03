import 'package:flutter/material.dart';

// TODO: in most cases, we don't need a 404 but rather a "loading" page. Implement that one and use it wherever a 404 is not applicable

@immutable
class Error404Page extends StatefulWidget {
  const Error404Page({super.key});

  static Error404PageState of(BuildContext context) {
    return context.findAncestorStateOfType<Error404PageState>()!;
  }

  @override
  Error404PageState createState() => Error404PageState();
}

class Error404PageState extends State<Error404Page> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("404"), centerTitle: true),
        body: const Text("Das ist ein Fehler..."));
  }
}
