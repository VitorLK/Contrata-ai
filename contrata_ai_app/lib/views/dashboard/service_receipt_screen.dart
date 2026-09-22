import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/work_session_model.dart';
import '../../services/work_repository.dart';

class ServiceReceiptScreen extends StatefulWidget {
  final String sessionId;
  final WorkRepository workRepository;

  const ServiceReceiptScreen({
    super.key,
    required this.sessionId,
    required this.workRepository,
  });

  @override
  State<ServiceReceiptScreen> createState() => _ServiceReceiptScreenState();
}

class _ServiceReceiptScreenState extends State<ServiceReceiptScreen> {
  late Future<WorkReceiptModel> _receipt;

  @override
  void initState() {
    super.initState();
    _receipt = widget.workRepository.getReceipt(widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comprovante de serviço')),
      body: FutureBuilder<WorkReceiptModel>(
        future: _receipt,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 44,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Não foi possível abrir o comprovante.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('${snapshot.error}'),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _receipt = widget.workRepository.getReceipt(
                          widget.sessionId,
                        );
                      }),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }
          return _ReceiptView(receipt: snapshot.data!);
        },
      ),
    );
  }
}

class _ReceiptView extends StatelessWidget {
  final WorkReceiptModel receipt;

  const _ReceiptView({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final session = receipt.session;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          48,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.handyman,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CONTRATA AÍ',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                'Comprovante de serviço',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white38),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'NÃO FISCAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'NÚMERO DO COMPROVANTE',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          receipt.receiptNumber,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(),
                        const SizedBox(height: AppSpacing.lg),
                        _ReceiptRow(
                          label: 'Serviço',
                          value: session.serviceTitle ?? 'Não informado',
                        ),
                        _ReceiptRow(
                          label: 'Categoria',
                          value: session.category ?? 'Não informada',
                        ),
                        _ReceiptRow(
                          label: 'Contratante',
                          value: session.clientName ?? 'Não informado',
                        ),
                        _ReceiptRow(
                          label: 'Profissional',
                          value: session.professionalName ?? 'Não informado',
                        ),
                        _ReceiptRow(
                          label: 'Data agendada',
                          value: session.scheduledDate == null
                              ? 'Não informada'
                              : _date(session.scheduledDate!),
                        ),
                        _ReceiptRow(
                          label: 'Início',
                          value: _dateTime(session.startedAt),
                        ),
                        _ReceiptRow(
                          label: 'Término',
                          value: session.endedAt == null
                              ? 'Não informado'
                              : _dateTime(session.endedAt!),
                        ),
                        _ReceiptRow(
                          label: 'Tempo trabalhado',
                          value: _hours(session.durationMinutes ?? 0),
                        ),
                        _ReceiptRow(
                          label: 'Forma de cálculo',
                          value: session.amountBasis == 'por_hora'
                              ? '${_money(session.hourlyRateSnapshot ?? 0)} por hora'
                              : 'Valor fixo combinado',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.payments_outlined,
                                color: AppColors.primaryDark,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              const Expanded(child: Text('Valor do serviço')),
                              Text(
                                _money(session.amount ?? 0),
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(color: AppColors.primaryDark),
                              ),
                            ],
                          ),
                        ),
                        if (session.providerNote != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'OBSERVAÇÃO DO PROFISSIONAL',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(session.providerNote!),
                        ],
                        if (session.evidencePhotoUrl != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'REGISTRO FOTOGRÁFICO',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              ApiConstants.resolveUrl(
                                session.evidencePhotoUrl!,
                              ),
                              height: 240,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_outlined,
                              size: 20,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Jornada confirmada em ${session.confirmedAt == null ? 'data não informada' : _dateTime(session.confirmedAt!)}.',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Este documento comprova o registro da prestação no aplicativo. Ele não substitui nota fiscal, recibo tributário ou documento exigido pela legislação aplicável.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.titleSmall),
          ),
        ],
      ),
    );
  }
}

String _money(double value) => 'R\$ ${value.toStringAsFixed(2)}';

String _hours(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return '${hours}h ${remainder.toString().padLeft(2, '0')}min';
}

String _date(DateTime value) {
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _dateTime(DateTime value) {
  final date = value.toLocal();
  return '${_date(date)} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
