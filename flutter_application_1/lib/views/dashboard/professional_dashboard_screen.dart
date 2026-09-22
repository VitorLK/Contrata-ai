import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/work_session_model.dart';
import '../../services/work_repository.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/professional_profile_viewmodel.dart';
import '../../viewmodels/services_list_viewmodel.dart' show LoadStatus;
import '../../widgets/error_state_view.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/profile_completion_bar.dart';
import '../professionals/my_professional_profile_screen.dart';
import 'service_receipt_screen.dart';

class ProfessionalDashboardScreen extends StatefulWidget {
  const ProfessionalDashboardScreen({super.key});

  @override
  State<ProfessionalDashboardScreen> createState() =>
      _ProfessionalDashboardScreenState();
}

class _ProfessionalDashboardScreenState
    extends State<ProfessionalDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final profileViewModel = context.read<ProfessionalProfileViewModel>();
    final dashboardViewModel = context.read<DashboardViewModel>();
    await profileViewModel.load();
    final id = profileViewModel.profile?.userId;
    await Future.wait([
      dashboardViewModel.loadPerformance(),
      if (id != null) dashboardViewModel.loadRating(id),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final profileViewModel = context.watch<ProfessionalProfileViewModel>();
    final viewModel = context.watch<DashboardViewModel>();
    final profile = profileViewModel.profile;

    if (profile == null && profileViewModel.status == LoadStatus.error) {
      return SafeArea(
        child: ErrorStateView(
          message: profileViewModel.errorMessage,
          onRetry: _load,
        ),
      );
    }
    if (profile == null ||
        (viewModel.performance == null && viewModel.isLoadingPerformance)) {
      return const SafeArea(child: LoadingOverlay());
    }

    final performance = viewModel.performance;
    final week = performance?.week ?? const PerformanceSummaryModel();
    final month = performance?.monthSummary ?? const PerformanceSummaryModel();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
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
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Meu desempenho',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Horas e valores vêm somente de jornadas confirmadas.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (viewModel.rating?.average != null)
                          _RatingSeal(
                            average: viewModel.rating!.average!,
                            total: viewModel.rating!.total,
                          ),
                      ],
                    ),
                    if (profile.profileCompletion < 100) ...[
                      const SizedBox(height: AppSpacing.lg),
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('Meu perfil')),
                              body: const MyProfessionalProfileScreen(),
                            ),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(10),
                        child: ProfileCompletionBar(
                          percentage: profile.profileCompletion,
                          missingItems: const [
                            'Complete o perfil para melhorar sua posição na busca',
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Esta semana',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = constraints.maxWidth >= 760
                            ? (constraints.maxWidth - 32) / 3
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _MetricCard(
                                icon: Icons.assignment_turned_in_outlined,
                                label: 'Serviços realizados',
                                value: '${week.serviceCount}',
                                detail: 'jornadas confirmadas',
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _MetricCard(
                                icon: Icons.schedule_outlined,
                                label: 'Horas trabalhadas',
                                value: _hours(week.totalMinutes),
                                detail:
                                    '${week.totalMinutes} minutos registrados',
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _MetricCard(
                                icon: Icons.payments_outlined,
                                label: 'Total arrecadado',
                                value: _money(week.totalAmount),
                                detail: 'valor confirmado',
                                highlighted: true,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Receita no mês',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_monthName(viewModel.selectedMonth)} · ${_money(month.totalAmount)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton.outlined(
                                  tooltip: 'Mês anterior',
                                  onPressed: viewModel.isLoadingPerformance
                                      ? null
                                      : () => viewModel.changeMonth(-1),
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                IconButton.outlined(
                                  tooltip: 'Próximo mês',
                                  onPressed:
                                      viewModel.isLoadingPerformance ||
                                          !_canGoNext(viewModel.selectedMonth)
                                      ? null
                                      : () => viewModel.changeMonth(1),
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            if (viewModel.isLoadingPerformance)
                              const SizedBox(
                                height: 220,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else
                              _MonthlyChart(
                                month: viewModel.selectedMonth,
                                daily: performance?.daily ?? const [],
                              ),
                            const SizedBox(height: AppSpacing.md),
                            Wrap(
                              spacing: AppSpacing.lg,
                              runSpacing: AppSpacing.sm,
                              children: [
                                _ChartSummary(
                                  label: 'Serviços no mês',
                                  value: '${month.serviceCount}',
                                ),
                                _ChartSummary(
                                  label: 'Horas no mês',
                                  value: _hours(month.totalMinutes),
                                ),
                                _ChartSummary(
                                  label: 'Média por serviço',
                                  value: month.serviceCount == 0
                                      ? _money(0)
                                      : _money(
                                          month.totalAmount /
                                              month.serviceCount,
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Histórico e comprovantes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Abra um serviço confirmado para emitir seu comprovante não fiscal.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if ((performance?.history ?? const []).isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            'Seu histórico aparecerá depois da primeira jornada confirmada.',
                          ),
                        ),
                      )
                    else
                      for (final session in performance!.history)
                        _HistoryTile(
                          session: session,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ServiceReceiptScreen(
                                sessionId: session.id,
                                workRepository: context.read<WorkRepository>(),
                              ),
                            ),
                          ),
                        ),
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

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final bool highlighted;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = highlighted ? Colors.white : AppColors.textPrimary;
    return Card(
      color: highlighted ? AppColors.primaryDark : AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: highlighted ? AppColors.primaryLight : AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: highlighted ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: foreground),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: highlighted ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingSeal extends StatelessWidget {
  final double average;
  final int total;

  const _RatingSeal({required this.average, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: AppColors.accent),
          const SizedBox(width: AppSpacing.xs),
          Text(
            average.toStringAsFixed(1),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(' · $total', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  final DateTime month;
  final List<DailyPerformanceModel> daily;

  const _MonthlyChart({required this.month, required this.daily});

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 40,
              color: AppColors.textDisabled,
            ),
            SizedBox(height: AppSpacing.sm),
            Text('Ainda não há valores confirmados neste mês.'),
          ],
        ),
      );
    }
    return Semantics(
      label: 'Gráfico diário de receita em ${_monthName(month)}',
      child: SizedBox(
        height: 220,
        child: CustomPaint(
          painter: _RevenueChartPainter(month: month, daily: daily),
        ),
      ),
    );
  }
}

class _RevenueChartPainter extends CustomPainter {
  final DateTime month;
  final List<DailyPerformanceModel> daily;

  _RevenueChartPainter({required this.month, required this.daily});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 8.0;
    const top = 8.0;
    const bottom = 28.0;
    final chartHeight = size.height - top - bottom;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final values = List<double>.filled(daysInMonth, 0);
    for (final item in daily) {
      if (item.day.month == month.month && item.day.day <= daysInMonth) {
        values[item.day.day - 1] = item.totalAmount;
      }
    }
    final maxValue = values.fold<double>(0, math.max);
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var index = 0; index <= 3; index++) {
      final y = top + chartHeight * index / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), gridPaint);
    }

    final slot = (size.width - left) / daysInMonth;
    final barPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    for (var index = 0; index < daysInMonth; index++) {
      final height = maxValue == 0
          ? 0.0
          : (values[index] / maxValue) * (chartHeight - 8);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left + index * slot + slot * 0.18,
          top + chartHeight - height,
          math.max(2, slot * 0.64),
          height,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, barPaint);
    }

    final labelStyle = const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
    for (final day in <int>{1, 8, 15, 22, daysInMonth}) {
      final painter = TextPainter(
        text: TextSpan(text: '$day', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = left + (day - 0.5) * slot - painter.width / 2;
      painter.paint(canvas, Offset(x, size.height - 18));
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) {
    return oldDelegate.month != month || oldDelegate.daily != daily;
  }
}

class _ChartSummary extends StatelessWidget {
  final String label;
  final String value;

  const _ChartSummary({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label · $value'),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final WorkSessionModel session;
  final VoidCallback onTap;

  const _HistoryTile({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.receipt_long_outlined,
            color: AppColors.primaryDark,
          ),
        ),
        title: Text(session.serviceTitle ?? 'Serviço'),
        subtitle: Text(
          '${session.endedAt == null ? '' : _shortDate(session.endedAt!)} · ${_hours(session.durationMinutes ?? 0)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _money(session.amount ?? 0),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

bool _canGoNext(DateTime selected) {
  final now = DateTime.now();
  return selected.year < now.year ||
      (selected.year == now.year && selected.month < now.month);
}

String _hours(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return '${hours}h ${remainder.toString().padLeft(2, '0')}';
}

String _money(double value) => 'R\$ ${value.toStringAsFixed(2)}';

String _shortDate(DateTime value) {
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _monthName(DateTime date) {
  const months = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  return '${months[date.month - 1]} ${date.year}';
}
