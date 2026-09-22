import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/work_session_model.dart';

void main() {
  test('identifica confirmação já resolvida e mantém os vínculos', () {
    final notification = AppNotificationModel.fromJson({
      'id': 'notification-1',
      'type': 'confirmacao_pendente',
      'title': 'Confirmação de jornada pendente',
      'message': 'Confira os dados e confirme.',
      'data': {
        'service_id': 'service-1',
        'work_session_id': 'session-1',
      },
      'action_required': false,
      'created_at': '2026-09-20T12:00:00.000Z',
      'read_at': null,
    });

    expect(notification.isResolvedConfirmation, isTrue);
    expect(notification.serviceId, 'service-1');
    expect(notification.workSessionId, 'session-1');

    final viewed = notification.copyWith(
      readAt: DateTime.parse('2026-09-20T13:00:00.000Z'),
    );
    expect(viewed.readAt, isNotNull);
  });

  test('mantém confirmação ativa enquanto ainda exige ação', () {
    final notification = AppNotificationModel.fromJson({
      'id': 'notification-2',
      'type': 'confirmacao_pendente',
      'title': 'Confirmação de jornada pendente',
      'message': 'Confira os dados e confirme.',
      'data': {'work_session_id': 'session-2'},
      'action_required': true,
      'created_at': '2026-09-20T12:00:00.000Z',
    });

    expect(notification.actionRequired, isTrue);
    expect(notification.isResolvedConfirmation, isFalse);
  });
}
