import 'package:substitution/auth/pages/login.dart';
import 'package:substitution/auth/pages/host.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

@immutable
class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key, required this.authPageRoute});

  final String authPageRoute;

  static AuthFlowState of(BuildContext context) {
    return context.findAncestorStateOfType<AuthFlowState>()!;
  }

  @override
  AuthFlowState createState() => AuthFlowState();
}

class AuthFlowState extends State<AuthFlow> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
  }

  /*void _onDiscoveryComplete() {
    _navigatorKey.currentState!.pushNamed(routeDeviceSetupSelectDevicePage);
  }

  void _onDeviceSelected(String deviceId) {
    _navigatorKey.currentState!.pushNamed(routeDeviceSetupConnectingPage);
  }

  void _onConnectionEstablished() {
    _navigatorKey.currentState!.pushNamed(routeDeviceSetupFinishedPage);
  }*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Authentification"),
        ),
        body: widget.authPageRoute == 'host'
            ? HostPage(onComplete: () => {context.push("/auth/login")})
            : LoginPage(onComplete: () => {context.push("/")}));
  }
}
