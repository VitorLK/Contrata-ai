import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';

/// Camada de armazenamento da sessão (token JWT + usuário logado).
///
/// É a "fonte da verdade" persistida em disco; a [AuthViewModel] é quem
/// expõe esse estado para a UI e notifica os listeners quando ele muda.
class SessionManager {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  String? _token;
  UserModel? _user;

  String? get token => _token;
  UserModel? get user => _user;
  bool get isLoggedIn => _token != null && _user != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _user = UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    }
  }

  Future<void> save(String token, UserModel user) async {
    _token = token;
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> clear() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
