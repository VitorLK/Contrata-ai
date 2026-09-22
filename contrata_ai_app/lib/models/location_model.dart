class BrazilianState {
  final String code;
  final String name;

  const BrazilianState(this.code, this.name);

  String get label => '$name ($code)';
}

class BrazilLocations {
  BrazilLocations._();

  static const states = <BrazilianState>[
    BrazilianState('AC', 'Acre'),
    BrazilianState('AL', 'Alagoas'),
    BrazilianState('AP', 'Amapá'),
    BrazilianState('AM', 'Amazonas'),
    BrazilianState('BA', 'Bahia'),
    BrazilianState('CE', 'Ceará'),
    BrazilianState('DF', 'Distrito Federal'),
    BrazilianState('ES', 'Espírito Santo'),
    BrazilianState('GO', 'Goiás'),
    BrazilianState('MA', 'Maranhão'),
    BrazilianState('MT', 'Mato Grosso'),
    BrazilianState('MS', 'Mato Grosso do Sul'),
    BrazilianState('MG', 'Minas Gerais'),
    BrazilianState('PA', 'Pará'),
    BrazilianState('PB', 'Paraíba'),
    BrazilianState('PR', 'Paraná'),
    BrazilianState('PE', 'Pernambuco'),
    BrazilianState('PI', 'Piauí'),
    BrazilianState('RJ', 'Rio de Janeiro'),
    BrazilianState('RN', 'Rio Grande do Norte'),
    BrazilianState('RS', 'Rio Grande do Sul'),
    BrazilianState('RO', 'Rondônia'),
    BrazilianState('RR', 'Roraima'),
    BrazilianState('SC', 'Santa Catarina'),
    BrazilianState('SP', 'São Paulo'),
    BrazilianState('SE', 'Sergipe'),
    BrazilianState('TO', 'Tocantins'),
  ];
}

class GeoPoint {
  final double latitude;
  final double longitude;
  final String? displayName;

  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.displayName,
  });

  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    return GeoPoint(
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      displayName: json['display_name'] as String?,
    );
  }
}
