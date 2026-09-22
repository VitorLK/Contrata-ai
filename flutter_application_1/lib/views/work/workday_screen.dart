import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/service_model.dart';
import '../../models/work_session_model.dart';
import '../../services/professional_repository.dart' show inferImageContentType;
import '../../viewmodels/services_list_viewmodel.dart' show LoadStatus;
import '../../viewmodels/workday_viewmodel.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/loading_overlay.dart';

class WorkdayScreen extends StatefulWidget {
  const WorkdayScreen({super.key});

  @override
  State<WorkdayScreen> createState() => _WorkdayScreenState();
}

class _WorkdayScreenState extends State<WorkdayScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkdayViewModel>().load();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _start(WorkAssignmentModel assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.play_circle_outline, size: 40),
        title: const Text('Iniciar jornada?'),
        content: Text(
          'O horário será registrado agora para “${assignment.service.title}”.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Agora não'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<WorkdayViewModel>().start(assignment.service.id);
    } catch (error) {
      if (!mounted) return;
      _message('Não foi possível iniciar: $error');
    }
  }

  Future<void> _finish(WorkAssignmentModel assignment) async {
    final session = assignment.session;
    if (session == null) return;

    final noteController = TextEditingController();
    final picker = ImagePicker();
    Uint8List? evidenceBytes;
    String? evidenceFilename;
    String? evidenceContentType;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Encerrar jornada',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Registre observações e evidências importantes antes de enviar ao contratante.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: noteController,
                    maxLines: 4,
                    maxLength: 1200,
                    decoration: const InputDecoration(
                      labelText: 'Observação (opcional)',
                      hintText: 'Ex.: Serviço concluído; a janela já estava trincada ao chegar.',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (evidenceBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        evidenceBytes!,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  OutlinedButton.icon(
                    onPressed: () async {
                      final file = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 82,
                      );
                      if (file == null) return;
                      final bytes = await file.readAsBytes();
                      setSheetState(() {
                        evidenceBytes = bytes;
                        evidenceFilename = file.name;
                        evidenceContentType =
                            file.mimeType ?? inferImageContentType(file.name);
                      });
                    },
                    icon: Icon(
                      evidenceBytes == null
                          ? Icons.add_a_photo_outlined
                          : Icons.change_circle_outlined,
                    ),
                    label: Text(
                      evidenceBytes == null
                          ? 'Adicionar foto de ocorrência'
                          : 'Trocar foto',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Finalizar e enviar'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (submitted != true || !mounted) {
      noteController.dispose();
      return;
    }

    try {
      final result = await context.read<WorkdayViewModel>().finish(
        sessionId: session.id,
        note: noteController.text.trim(),
        evidenceBytes: evidenceBytes,
        evidenceFilename: evidenceFilename,
        evidenceContentType: evidenceContentType,
      );
      if (!mounted) return;
      _message(
        result.status == WorkSessionStatus.aguardandoConfirmacao
            ? 'Jornada enviada para confirmação do contratante.'
            : 'Jornada finalizada e confirmada automaticamente.',
      );
    } catch (error) {
      if (mounted) _message('Não foi possível finalizar: $error');
    } finally {
      noteController.dispose();
    }
  }

  Future<void> _withdraw(WorkAssignmentModel assignment) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desistir deste trabalho?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O contratante será avisado e o horário de “${assignment.service.title}” ficará livre novamente.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                hintText: 'Explique brevemente o imprevisto.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Manter agendamento'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 5) Navigator.of(dialogContext).pop(value);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirmar desistência'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    try {
      await context.read<WorkdayViewModel>().withdraw(
        serviceId: assignment.service.id,
        reason: reason,
      );
      if (mounted) _message('Desistência registrada e horário liberado.');
    } catch (error) {
      if (mounted) _message('Não foi possível registrar: $error');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WorkdayViewModel>();

    if (viewModel.status == LoadStatus.loading ||
        viewModel.status == LoadStatus.idle) {
      return const SafeArea(child: LoadingOverlay());
    }
    if (viewModel.status == LoadStatus.error) {
      return SafeArea(
        child: ErrorStateView(
          message: viewModel.errorMessage,
          onRetry: viewModel.load,
        ),
      );
    }

    final active = viewModel.activeAssignment;
    final dayAssignments = viewModel.selectedDayAssignments;
    final queued = dayAssignments
        .where((item) => item.session == null)
        .toList();
    final pending = dayAssignments
        .where(
          (item) =>
              item.session?.status == WorkSessionStatus.aguardandoConfirmacao,
        )
        .toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            64,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1020),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WorkdayHeader(
                      date: viewModel.selectedDay,
                      active: active != null,
                      readyCount: queued.length,
                      pendingCount: pending.length,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _AgendaWeekStrip(viewModel: viewModel),
                    const SizedBox(height: AppSpacing.lg),
                    if (active != null ||
                        queued.isNotEmpty ||
                        pending.isNotEmpty) ...[
                      _WorkJourney(
                        phase: active != null
                            ? 1
                            : pending.isNotEmpty
                            ? 2
                            : 0,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (active != null)
                      _ActiveClockCard(
                        assignment: active,
                        now: _now,
                        isBusy: viewModel.isMutating,
                        onFinish: () => _finish(active),
                      )
                    else if (queued.isEmpty && pending.isEmpty)
                      SizedBox(
                        height: 360,
                        child: EmptyStateView(
                          icon: Icons.event_available_outlined,
                          title: viewModel.selectedDayIsToday
                              ? 'Nenhum trabalho agendado para hoje'
                              : 'Agenda livre neste dia',
                          message:
                              'Quando uma proposta ou candidatura for aceita, o compromisso aparecerá aqui no horário combinado.',
                        ),
                      ),
                    if (queued.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _SectionHeading(
                        icon: Icons.play_circle_outline_rounded,
                        title: 'Prontos para começar',
                        description: active == null
                            ? 'Confira os dados antes de registrar o início.'
                            : 'Finalize a jornada atual antes de iniciar outra.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final item in queued)
                        _QueuedWorkCard(
                          assignment: item,
                          enabled:
                              viewModel.canStart(item, _now) &&
                              !viewModel.isMutating,
                          disabledLabel: active != null
                              ? 'Outra jornada ativa'
                              : 'Disponível no horário',
                          onStart: () => _start(item),
                          onWithdraw: () => _withdraw(item),
                        ),
                    ],
                    if (pending.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const _SectionHeading(
                        icon: Icons.verified_outlined,
                        title: 'Aguardando confirmação',
                        description: 'A jornada já foi enviada e não exige outra ação agora.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final item in pending)
                        _PendingWorkCard(assignment: item),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkdayHeader extends StatelessWidget {
  final DateTime date;
  final bool active;
  final int readyCount;
  final int pendingCount;

  const _WorkdayHeader({
    required this.date,
    required this.active,
    required this.readyCount,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    final status = active
        ? 'Jornada em andamento'
        : readyCount > 0
        ? '$readyCount ${readyCount == 1 ? 'serviço pronto' : 'serviços prontos'}'
        : pendingCount > 0
        ? 'Entrega enviada'
        : 'Agenda livre';
    final statusIcon = active
        ? Icons.timer_outlined
        : readyCount > 0
        ? Icons.play_arrow_rounded
        : pendingCount > 0
        ? Icons.hourglass_top_rounded
        : Icons.event_available_outlined;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _longDate(date),
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Agenda profissional',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Registre sua jornada, ocorrências e o valor do serviço em um só lugar.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Colors.white.withValues(alpha: .76)),
              ),
            ],
          );
          final statusBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: Colors.white, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  status,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Colors.white),
                ),
              ],
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: AppSpacing.lg),
                statusBadge,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: AppSpacing.lg),
              statusBadge,
            ],
          );
        },
      ),
    );
  }
}

class _AgendaWeekStrip extends StatelessWidget {
  final WorkdayViewModel viewModel;

  const _AgendaWeekStrip({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (index) => viewModel.weekStart.add(Duration(days: index)),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Semana anterior',
                onPressed: viewModel.previousWeek,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${_shortDate(days.first)} — ${_shortDate(days.last)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: viewModel.goToToday,
                child: const Text('Hoje'),
              ),
              IconButton(
                tooltip: 'Próxima semana',
                onPressed: viewModel.nextWeek,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: _AgendaDayButton(
                    day: day,
                    selected: _sameCalendarDay(day, viewModel.selectedDay),
                    isToday: _sameCalendarDay(day, DateTime.now()),
                    count: viewModel.countForDay(day),
                    onTap: () => viewModel.selectDay(day),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgendaDayButton extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final bool isToday;
  final int count;
  final VoidCallback onTap;

  const _AgendaDayButton({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const weekdays = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${weekdays[day.weekday - 1]}, dia ${day.day}, $count compromissos',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isToday && !selected
                  ? Border.all(color: AppColors.primary)
                  : null,
            ),
            child: Column(
              children: [
                Text(
                  weekdays[day.weekday - 1],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: count > 0 ? 16 : 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: count > 0
                        ? (selected ? Colors.white : AppColors.accent)
                        : (selected ? Colors.white38 : AppColors.border),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkJourney extends StatelessWidget {
  final int phase;

  const _WorkJourney({required this.phase});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FLUXO DA JORNADA',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _WorkJourneyNode(
                  icon: Icons.fact_check_outlined,
                  label: 'Preparar',
                  active: phase >= 0,
                  current: phase == 0,
                ),
                _WorkJourneyLine(active: phase >= 1),
                _WorkJourneyNode(
                  icon: Icons.timer_outlined,
                  label: 'Executar',
                  active: phase >= 1,
                  current: phase == 1,
                ),
                _WorkJourneyLine(active: phase >= 2),
                _WorkJourneyNode(
                  icon: Icons.verified_outlined,
                  label: 'Confirmar',
                  active: phase >= 2,
                  current: phase == 2,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkJourneyNode extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool current;

  const _WorkJourneyNode({
    required this.icon,
    required this.label,
    required this.active,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label${current ? ', etapa atual' : ''}',
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: current ? AppColors.accent : AppColors.border,
                  width: current ? 3 : 1,
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: active ? Colors.white : AppColors.textDisabled,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: active ? AppColors.textPrimary : AppColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkJourneyLine extends StatelessWidget {
  final bool active;

  const _WorkJourneyLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 3,
        margin: const EdgeInsets.only(bottom: 24),
        color: active ? AppColors.primary : AppColors.border,
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryDark, size: 21),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActiveClockCard extends StatelessWidget {
  final WorkAssignmentModel assignment;
  final DateTime now;
  final bool isBusy;
  final VoidCallback onFinish;

  const _ActiveClockCard({
    required this.assignment,
    required this.now,
    required this.isBusy,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final session = assignment.session!;
    final elapsed = now.difference(session.startedAt.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final details = Column(
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'JORNADA EM ANDAMENTO',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: AppColors.warning),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  assignment.service.title,
                  textAlign: compact ? TextAlign.center : TextAlign.left,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${assignment.service.clientName ?? 'Contratante'} · ${assignment.service.locationLabel}',
                  textAlign: compact ? TextAlign.center : TextAlign.left,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Início registrado às ${_time(session.startedAt.toLocal())}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: compact
                      ? WrapAlignment.center
                      : WrapAlignment.start,
                  children: [
                    if (assignment.service.category != null)
                      _WorkMeta(
                        icon: Icons.handyman_outlined,
                        label: assignment.service.category!,
                      ),
                    _WorkMeta(
                      icon: Icons.payments_outlined,
                      label: assignment.service.budget == null
                          ? 'Valor a combinar'
                          : _money(assignment.service.budget!),
                    ),
                  ],
                ),
              ],
            );
            final clock = _PunchClock(
              elapsed: elapsed.isNegative ? Duration.zero : elapsed,
              isBusy: isBusy,
              onFinish: onFinish,
            );
            if (compact) {
              return Column(
                children: [
                  details,
                  const SizedBox(height: AppSpacing.xl),
                  clock,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: AppSpacing.xl),
                clock,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PunchClock extends StatelessWidget {
  final Duration elapsed;
  final bool isBusy;
  final VoidCallback onFinish;

  const _PunchClock({
    required this.elapsed,
    required this.isBusy,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 224,
      height: 224,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryLight,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
          width: 2,
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryDark,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_outlined, color: Colors.white70),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _duration(elapsed),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 31,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: isBusy ? null : onFinish,
              icon: const Icon(Icons.stop_rounded),
              label: Text(isBusy ? 'Finalizando…' : 'Finalizar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueuedWorkCard extends StatelessWidget {
  final WorkAssignmentModel assignment;
  final bool enabled;
  final VoidCallback onStart;
  final VoidCallback onWithdraw;
  final String disabledLabel;

  const _QueuedWorkCard({
    required this.assignment,
    required this.enabled,
    required this.onStart,
    required this.onWithdraw,
    required this.disabledLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final information = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateTile(date: assignment.service.scheduledDate),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.service.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        assignment.service.clientName ?? 'Contratante',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _WorkMeta(
                            icon: Icons.location_on_outlined,
                            label: assignment.service.locationLabel,
                          ),
                          if (assignment.service.category != null)
                            _WorkMeta(
                              icon: Icons.handyman_outlined,
                              label: assignment.service.category!,
                            ),
                          _WorkMeta(
                            icon: Icons.payments_outlined,
                            label: assignment.service.budget == null
                                ? 'Valor a combinar'
                                : _money(assignment.service.budget!),
                          ),
                          _WorkMeta(
                            icon: Icons.schedule_outlined,
                            label: _serviceScheduleLabel(assignment.service),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
            final buttons = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: enabled ? onStart : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(enabled ? 'Iniciar jornada' : disabledLabel),
                ),
                TextButton.icon(
                  onPressed: onWithdraw,
                  icon: const Icon(Icons.event_busy_outlined, size: 18),
                  label: const Text('Desistir'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  information,
                  const SizedBox(height: AppSpacing.lg),
                  buttons,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: information),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(width: 210, child: buttons),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PendingWorkCard extends StatelessWidget {
  final WorkAssignmentModel assignment;

  const _PendingWorkCard({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final session = assignment.session!;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          assignment.service.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ENVIADO',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _WorkMeta(
                        icon: Icons.schedule_outlined,
                        label: _minutes(session.durationMinutes ?? 0),
                      ),
                      _WorkMeta(
                        icon: Icons.payments_outlined,
                        label: _money(session.amount ?? 0),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'O contratante recebeu o encerramento. Você será avisado assim que houver confirmação.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final DateTime date;

  const _DateTile({required this.date});

  @override
  Widget build(BuildContext context) {
    const months = [
      'JAN',
      'FEV',
      'MAR',
      'ABR',
      'MAI',
      'JUN',
      'JUL',
      'AGO',
      'SET',
      'OUT',
      'NOV',
      'DEZ',
    ];
    final local = date.toLocal();
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            months[local.month - 1],
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: AppColors.primaryDark),
          ),
          Text(
            local.day.toString().padLeft(2, '0'),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: AppColors.primaryDark),
          ),
        ],
      ),
    );
  }
}

class _WorkMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _WorkMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

String _duration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _time(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _minutes(int total) {
  final hours = total ~/ 60;
  final minutes = total % 60;
  if (hours == 0) return '${minutes}min';
  return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
}

String _money(double value) => 'R\$ ${value.toStringAsFixed(2)}';

String _serviceScheduleLabel(ServiceModel service) {
  if (service.isAllDay) return 'Dia inteiro';
  final start = service.scheduledStart;
  final end = service.scheduledEnd;
  if (start == null || end == null) return 'Horário a combinar';
  final crossesDay = !_sameCalendarDay(start, end);
  return '${_time(start)}–${_time(end)}${crossesDay ? ' (+1 dia)' : ''}';
}

bool _sameCalendarDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';

String _longDate(DateTime value) {
  const weekdays = [
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo',
  ];
  const months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  final local = value.toLocal();
  return '${weekdays[local.weekday - 1]}, ${local.day} de ${months[local.month - 1]}';
}
