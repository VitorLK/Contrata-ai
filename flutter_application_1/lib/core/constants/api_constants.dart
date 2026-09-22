import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// Endereço base da API REST do back-end (Node.js + Express).
///
/// O emulador Android enxerga a máquina host como 10.0.2.2, não como
/// localhost. Em uma build Web de produção, o frontend usa a mesma origem
/// que o entregou; assim o modo de demonstração funciona com uma única URL
/// pública. API_BASE_URL permite substituir o endereço sem editar o código.
class ApiConstants {
  ApiConstants._();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.trim().isNotEmpty) {
      return _withoutTrailingSlash(_configuredBaseUrl.trim());
    }

    if (kIsWeb) {
      // flutter run continua usando a API local. A build gerada para a
      // demonstração é servida pelo mesmo Express que expõe a API.
      return kReleaseMode ? Uri.base.origin : 'http://localhost:3000';
    }
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  static String _withoutTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  /// O back-end devolve caminhos relativos para arquivos enviados (ex.:
  /// "/uploads/xxx.png"). Prefixa com baseUrl para virar algo que
  /// Image.network consiga carregar.
  static String resolveUrl(String path) =>
      path.startsWith('http') ? path : '$baseUrl$path';
}
