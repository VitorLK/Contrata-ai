class MapConstants {
  MapConstants._();

  /// Pode ser trocado em produção com
  /// --dart-define=MAP_TILE_URL=https://seu-provedor/{z}/{x}/{y}.png
  static const tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const attributionUrl = 'https://www.openstreetmap.org/copyright';
  static const userAgentPackageName = 'br.edu.contrataai.tcc';
}
