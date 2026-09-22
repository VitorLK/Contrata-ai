import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../models/location_model.dart';

class LocationRepository {
  static const _baseUrl = 'https://servicodados.ibge.gov.br/api/v1/localidades';
  static const _cachePrefix = 'ibge_cities_v1_';

  final http.Client _client;
  final ApiClient apiClient;

  LocationRepository({required this.apiClient, http.Client? client})
    : _client = client ?? http.Client();

  Future<List<String>> listCities(String stateCode) async {
    final normalizedState = stateCode.trim().toUpperCase();
    final preferences = await SharedPreferences.getInstance();
    final cacheKey = '$_cachePrefix$normalizedState';

    try {
      final uri = Uri.parse(
        '$_baseUrl/estados/$normalizedState/municipios?orderBy=nome',
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw const FormatException(
          'Resposta inválida do serviço de localidades.',
        );
      }

      final decoded = jsonDecode(response.body) as List<dynamic>;
      final cities = decoded
          .map(
            (item) => (item as Map<String, dynamic>)['nome']?.toString() ?? '',
          )
          .where((name) => name.isNotEmpty)
          .toList(growable: false);
      await preferences.setStringList(cacheKey, cities);
      return cities;
    } catch (_) {
      final cached = preferences.getStringList(cacheKey);
      if (cached != null && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<GeoPoint> geocodeAddress({
    required String address,
    required String city,
    required String state,
  }) async {
    final path = Uri(
      path: '/locations/geocode',
      queryParameters: {'address': address, 'city': city, 'state': state},
    ).toString();
    final data = await apiClient.get(path, auth: true);
    return GeoPoint.fromJson(data as Map<String, dynamic>);
  }
}
