import '/auth/pages/login.dart';
import '/auth/pages/host.dart';

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
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return widget.authPageRoute == 'host'
        ? HostPage(onComplete: () => {context.push("/auth/login")})
        : LoginPage(onComplete: () => {context.push("/")});
  }
}
