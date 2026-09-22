import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/availability_model.dart';
import 'package:flutter_application_1/models/service_model.dart';

void main() {
  test('lê disponibilidade que atravessa a meia-noite', () {
    final schedule = ProfessionalAvailabilityModel.fromJson({
      'buffer_minutes': 30,
      'variable_hours': false,
      'slots': [
        {
          'weekday': 5,
          'start_time': '18:00:00',
          'end_time': '02:00:00',
          'ends_next_day': true,
        },
      ],
    });

    expect(schedule.bufferMinutes, 30);
    expect(schedule.slots.single.rangeLabel, '18:00–02:00 (+1 dia)');
    expect(schedule.summary, contains('1 dia por semana'));
  });

  test('serviço atravessando a meia-noite ocupa os dois dias', () {
    final service = ServiceModel.fromJson({
      'id': 'service-1',
      'client_id': 'client-1',
      'title': 'Entrega noturna',
      'description': 'Trabalho de teste que continua após a meia-noite.',
      'status': 'agendado',
      'created_at': '2026-09-20T12:00:00Z',
      'scheduled_date': '2026-09-20',
      'scheduled_start': '2026-09-20T21:00:00Z',
      'scheduled_end': '2026-09-21T05:00:00Z',
      'is_all_day': false,
    });

    final localStart = service.scheduledStart!;
    expect(service.status, ServiceStatus.agendado);
    expect(service.overlapsDay(localStart), isTrue);
    expect(
      service.overlapsDay(localStart.add(const Duration(days: 1))),
      isTrue,
    );
  });
}
