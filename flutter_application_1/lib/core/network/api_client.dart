import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../constants/api_constants.dart';
import '../session/session_manager.dart';

/// Erro lançado por [ApiClient] tanto para respostas HTTP de erro quanto
/// para falhas de conexão, sempre com uma mensagem amigável para exibir
/// direto na UI.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Camada "Model" de acesso à rede: sabe montar URLs, cabeçalhos de
/// autenticação e traduzir respostas HTTP em dados ou em [ApiException].
/// Os repositórios (services/) são a única camada que fala com o [ApiClient].
class ApiClient {
  final SessionManager sessionManager;

  ApiClient({required this.sessionManager});

  Uri _uri(String path) => Uri.parse('${ApiConstants.baseUrl}$path');

  Map<String, String> _headers({bool auth = false}) {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = sessionManager.token;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> get(String path, {bool auth = false}) {
    return _send(() => http.get(_uri(path), headers: _headers(auth: auth)));
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) {
    return _send(
      () => http.post(
        _uri(path),
        headers: _headers(auth: auth),
        body: jsonEncode(body),
      ),
    );
  }

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) {
    return _send(
      () => http.put(
        _uri(path),
        headers: _headers(auth: auth),
        body: jsonEncode(body),
      ),
    );
  }

  Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) {
    return _send(
      () => http.patch(
        _uri(path),
        headers: _headers(auth: auth),
        body: jsonEncode(body),
      ),
    );
  }

  Future<dynamic> delete(String path, {bool auth = false}) {
    return _send(() => http.delete(_uri(path), headers: _headers(auth: auth)));
  }

  /// Upload multipart (foto de perfil, portfólio). Recebe os bytes já
  /// lidos — não um caminho de arquivo (dart:io File) — porque o app roda
  /// também na web, onde não existe sistema de arquivos local; XFile do
  /// image_picker sabe ler seus próprios bytes em qualquer plataforma.
  Future<dynamic> postMultipart(
    String path, {
    required String fieldName,
    required List<int> bytes,
    required String filename,
    required String contentType,
    Map<String, String> fields = const {},
    bool auth = false,
  }) async {
    return _sendMultipart(
      'POST',
      path,
      fieldName: fieldName,
      bytes: bytes,
      filename: filename,
      contentType: contentType,
      fields: fields,
      auth: auth,
    );
  }

  Future<dynamic> putMultipart(
    String path, {
    required String fieldName,
    required List<int> bytes,
    required String filename,
    required String contentType,
    Map<String, String> fields = const {},
    bool auth = false,
  }) {
    return _sendMultipart(
      'PUT',
      path,
      fieldName: fieldName,
      bytes: bytes,
      filename: filename,
      contentType: contentType,
      fields: fields,
      auth: auth,
    );
  }

  Future<dynamic> _sendMultipart(
    String method,
    String path, {
    required String fieldName,
    required List<int> bytes,
    required String filename,
    required String contentType,
    required Map<String, String> fields,
    required bool auth,
  }) async {
    final request = http.MultipartRequest(method, _uri(path));
    if (auth) {
      final token = sessionManager.token;
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }
    request.fields.addAll(fields);
    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ),
    );

    late http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await request.send();
    } catch (_) {
      throw ApiException(
        'Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.',
      );
    }
    return _handle(await http.Response.fromStream(streamedResponse));
  }

  Future<dynamic> _send(Future<http.Response> Function() action) async {
    late http.Response response;
    try {
      response = await action();
    } catch (_) {
      throw ApiException(
        'Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.',
      );
    }
    return _handle(response);
  }

  dynamic _handle(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    final isJson = contentType.contains('application/json');
    final decoded = (response.body.isNotEmpty && isJson)
        ? jsonDecode(response.body)
        : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final message = (decoded is Map && decoded['error'] != null)
        ? decoded['error'].toString()
        : 'Erro ao comunicar com o servidor (${response.statusCode}).';
    throw ApiException(message, statusCode: response.statusCode);
  }
}
