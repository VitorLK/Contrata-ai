import 'package:flutter/foundation.dart';

import '../services/location_repository.dart';
import '../core/network/api_client.dart';
import '../models/location_model.dart';

class LocationViewModel extends ChangeNotifier {
  final LocationRepository locationRepository;

  LocationViewModel({required this.locationRepository});

  final Map<String, List<String>> _citiesByState = {};
  final Set<String> _loadingStates = {};
  final Map<String, String> _errorsByState = {};
  bool isGeocoding = false;
  String? geocodingError;

  List<String> citiesFor(String? stateCode) =>
      stateCode == null ? const [] : _citiesByState[stateCode] ?? const [];

  bool isLoading(String? stateCode) =>
      stateCode != null && _loadingStates.contains(stateCode);

  String? errorFor(String? stateCode) =>
      stateCode == null ? null : _errorsByState[stateCode];

  Future<void> loadCities(String stateCode, {bool force = false}) async {
    if (!force && (_citiesByState[stateCode]?.isNotEmpty ?? false)) return;
    if (_loadingStates.contains(stateCode)) return;

    _loadingStates.add(stateCode);
    _errorsByState.remove(stateCode);
    notifyListeners();

    try {
      _citiesByState[stateCode] = await locationRepository.listCities(
        stateCode,
      );
    } catch (_) {
      _errorsByState[stateCode] = 'Não foi possível carregar os municípios. Verifique a internet e tente novamente.';
    } finally {
      _loadingStates.remove(stateCode);
      notifyListeners();
    }
  }

  Future<GeoPoint?> geocodeAddress({
    required String address,
    required String city,
    required String state,
  }) async {
    if (isGeocoding) return null;
    isGeocoding = true;
    geocodingError = null;
    notifyListeners();
    try {
      return await locationRepository.geocodeAddress(
        address: address,
        city: city,
        state: state,
      );
    } on ApiException catch (error) {
      geocodingError = error.message;
      return null;
    } catch (_) {
      geocodingError = 'Não foi possível localizar este endereço.';
      return null;
    } finally {
      isGeocoding = false;
      notifyListeners();
    }
  }
}
