import 'package:flutter/material.dart';

import '../../views/auth/login_screen.dart';
import '../../views/auth/register_screen.dart';
import '../../views/home/home_shell.dart';
import '../../views/landing/landing_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const landing = '/landing';
}

class AppRouter {
  AppRouter._();

  static Map<String, WidgetBuilder> routes = {
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.register: (_) => const RegisterScreen(),
    AppRoutes.home: (_) => const HomeShell(),
    AppRoutes.landing: (_) => const LandingScreen(),
  };
}
