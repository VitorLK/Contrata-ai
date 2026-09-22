class AvailabilitySlotModel {
  final String? id;
  final int weekday;
  final String startTime;
  final String endTime;
  final bool endsNextDay;

  const AvailabilitySlotModel({
    this.id,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    this.endsNextDay = false,
  });

  factory AvailabilitySlotModel.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlotModel(
      id: json['id']?.toString(),
      weekday: int.tryParse(json['weekday']?.toString() ?? '') ?? 1,
      startTime: _shortTime(json['start_time']?.toString() ?? '08:00'),
      endTime: _shortTime(json['end_time']?.toString() ?? '12:00'),
      endsNextDay: json['ends_next_day'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'weekday': weekday,
    'start_time': startTime,
    'end_time': endTime,
    'ends_next_day': endsNextDay,
  };

  AvailabilitySlotModel copyWith({
    String? id,
    int? weekday,
    String? startTime,
    String? endTime,
    bool? endsNextDay,
  }) {
    return AvailabilitySlotModel(
      id: id ?? this.id,
      weekday: weekday ?? this.weekday,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      endsNextDay: endsNextDay ?? this.endsNextDay,
    );
  }

  String get rangeLabel =>
      '$startTime–$endTime${endsNextDay ? ' (+1 dia)' : ''}';
}

class ProfessionalAvailabilityModel {
  final int bufferMinutes;
  final bool variableHours;
  final List<AvailabilitySlotModel> slots;

  const ProfessionalAvailabilityModel({
    this.bufferMinutes = 0,
    this.variableHours = false,
    this.slots = const [],
  });

  factory ProfessionalAvailabilityModel.fromJson(Map<String, dynamic> json) {
    return ProfessionalAvailabilityModel(
      bufferMinutes:
          int.tryParse(json['buffer_minutes']?.toString() ?? '') ?? 0,
      variableHours: json['variable_hours'] as bool? ?? false,
      slots: (json['slots'] as List? ?? const [])
          .map(
            (item) => AvailabilitySlotModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'buffer_minutes': bufferMinutes,
    'variable_hours': variableHours,
    'slots': slots.map((slot) => slot.toJson()).toList(),
  };

  List<AvailabilitySlotModel> forWeekday(int weekday) =>
      slots.where((slot) => slot.weekday == weekday).toList();

  String get summary {
    if (variableHours) return 'Horários variáveis · combinar pelo chat';
    if (slots.isEmpty) return 'Agenda ainda não configurada';
    final activeDays = slots.map((slot) => slot.weekday).toSet().length;
    final buffer = bufferMinutes > 0 ? ' · pausa de ${bufferMinutes}min' : '';
    return '$activeDays ${activeDays == 1 ? 'dia' : 'dias'} por semana$buffer';
  }
}

String weekdayShortLabel(int weekday) => switch (weekday) {
  1 => 'SEG',
  2 => 'TER',
  3 => 'QUA',
  4 => 'QUI',
  5 => 'SEX',
  6 => 'SÁB',
  _ => 'DOM',
};

String weekdayLabel(int weekday) => switch (weekday) {
  1 => 'Segunda-feira',
  2 => 'Terça-feira',
  3 => 'Quarta-feira',
  4 => 'Quinta-feira',
  5 => 'Sexta-feira',
  6 => 'Sábado',
  _ => 'Domingo',
};

String _shortTime(String value) => value.length >= 5 ? value.substring(0, 5) : value;
