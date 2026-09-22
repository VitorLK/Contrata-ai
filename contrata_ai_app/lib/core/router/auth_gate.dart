import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../../views/home/home_shell.dart';
import '../../views/landing/landing_screen.dart';

/// Decide, com base no estado de sessão, se mostra a tela de login ou a
/// home pública ou a área interna — e reage automaticamente a login/logout,
/// sem navegação
/// manual entre as duas.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthViewModel>().isLoggedIn;
    return isLoggedIn ? const HomeShell() : const LandingScreen();
  }
}
