import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/application_model.dart';
import '../models/service_model.dart';

/// Badge de status do serviço, com a linguagem visual de um carimbo de
/// ordem de serviço: contorno na cor do status, texto em versalete com
/// tracking largo. Cada status tem uma "tinta" própria e reconhecível
/// (ver AppColors.status*) em vez de uma variação arbitrária de cor.
class StatusBadge extends StatelessWidget {
  final ServiceStatus status;

  const StatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case ServiceStatus.aberto:
        return AppColors.statusAberto;
      case ServiceStatus.agendado:
        return AppColors.primary;
      case ServiceStatus.emAndamento:
        return AppColors.statusEmAndamento;
      case ServiceStatus.concluido:
        return AppColors.statusConcluido;
      case ServiceStatus.cancelado:
        return AppColors.statusCancelado;
    }
  }

  @override
  Widget build(BuildContext context) =>
      _StampBadge(text: status.label, color: _color);
}

/// Badge de status de uma candidatura — mesma linguagem de carimbo do
/// StatusBadge, reaproveitando as mesmas 3 tintas (pendente lê como
/// "em andamento", aceito como "concluído", recusado como "cancelado"),
/// para manter o significado de cor consistente em todo o app.
class ApplicationStatusBadge extends StatelessWidget {
  final ApplicationStatus status;

  const ApplicationStatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case ApplicationStatus.pendente:
        return AppColors.statusEmAndamento;
      case ApplicationStatus.aceito:
        return AppColors.statusConcluido;
      case ApplicationStatus.recusado:
        return AppColors.statusCancelado;
    }
  }

  @override
  Widget build(BuildContext context) =>
      _StampBadge(text: status.label, color: _color);
}

class _StampBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StampBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
