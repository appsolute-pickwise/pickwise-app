import '../widgets/auth_page_layout.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import 'app_shell.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _guestAccess = false;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    if (session.restoring) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 280, child: PickWiseAuthLogo()),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }
    if (session.loggedIn) {
      _guestAccess = false;
      return const AppShell();
    }
    if (_guestAccess) return const AppShell();
    return LoginScreen(onGuest: () => setState(() => _guestAccess = true));
  }
}
