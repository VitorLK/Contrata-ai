import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/work_session_model.dart';
import '../../services/service_repository.dart';
import '../../viewmodels/client_work_center_viewmodel.dart';
import '../../viewmodels/services_list_viewmodel.dart' show LoadStatus;
import '../../widgets/error_state_view.dart';
import '../../widgets/loading_overlay.dart';

class ClientWorkCenterScreen extends StatefulWidget {
  const ClientWorkCenterScreen({super.key});

  @override
  State<ClientWorkCenterScreen> createState() => _ClientWorkCenterScreenState();
}

class _ClientWorkCenterScreenState extends State<ClientWorkCenterScreen> {
  bool _showAllNotifications = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientWorkCenterViewModel>().load();
    });
  }

  Future<void> _toggleConfirmation(bool value) async {
    try {
      await context.read<ClientWorkCenterViewModel>().setRequireConfirmation(
        value,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Confirmação manual ativada.'
                : 'As próximas jornadas serão confirmadas automaticamente.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar: $error')),
      );
    }
  }

  Future<void> _confirm(WorkSessionModel session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.fact_check_outlined, size: 40),
        title: const Text('Confirmar jornada?'),
        content: Text(
          'Você confirma ${_minutes(session.durationMinutes ?? 0)} de trabalho e o valor de ${_money(session.amount ?? 0)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Revisar depois'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final completed = await context.read<ClientWorkCenterViewModel>().confirm(
        session.id,
      );
      if (!mounted) return;
      final reviewed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ServiceRatingSheet(session: completed),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reviewed == true ? 'Avaliação enviada. Obrigado pelo retorno!' : 'Jornada confirmada. Você pode avaliar depois nos detalhes do serviço.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível confirmar: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClientWorkCenterViewModel>();

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

    final historyNotifications = viewModel.historyNotifications;
    final visibleNotifications = _showAllNotifications
        ? historyNotifications
        : historyNotifications.take(5).toList();

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
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Central de trabalho',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Confirme entregas e acompanhe os avisos dos seus serviços.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (viewModel.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              viewModel.unreadCount == 1
                                  ? '1 nova'
                                  : '${viewModel.unreadCount} novas',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Card(
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.all(AppSpacing.md),
                        secondary: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.verified_user_outlined,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        title: const Text(
                          'Confirmar jornada antes de concluir',
                        ),
                        subtitle: Text(
                          viewModel.preferences.requireConfirmation
                              ? 'O serviço só será concluído depois da sua validação.'
                              : 'Você receberá o aviso, mas a conclusão será automática.',
                        ),
                        value: viewModel.preferences.requireConfirmation,
                        onChanged: viewModel.isSavingPreference
                            ? null
                            : _toggleConfirmation,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Aguardando sua confirmação',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (viewModel.pending.isEmpty)
                      const _PendingEmptyState()
                    else
                      for (final session in viewModel.pending)
                        _ConfirmationCard(
                          session: session,
                          isConfirming:
                              viewModel.confirmingSessionId == session.id,
                          onConfirm: () => _confirm(session),
                        ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Histórico de notificações',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (historyNotifications.isNotEmpty)
                          Text(
                            '${historyNotifications.length} ${historyNotifications.length == 1 ? 'registro' : 'registros'}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Avisos já visualizados ficam guardados aqui sem ocupar a área de ações.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (historyNotifications.isEmpty)
                      const Text('Nenhum aviso no histórico por enquanto.')
                    else
                      for (final notification in visibleNotifications)
                        _NotificationTile(
                          notification: notification,
                          onTap: () => viewModel.markRead(notification),
                        ),
                    if (historyNotifications.length > 5) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton.icon(
                          onPressed: () => setState(
                            () =>
                                _showAllNotifications = !_showAllNotifications,
                          ),
                          icon: Icon(
                            _showAllNotifications
                                ? Icons.expand_less
                                : Icons.history,
                          ),
                          label: Text(
                            _showAllNotifications
                                ? 'Mostrar menos'
                                : 'Ver todo o histórico',
                          ),
                        ),
                      ),
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

class _ServiceRatingSheet extends StatefulWidget {
  final WorkSessionModel session;

  const _ServiceRatingSheet({required this.session});

  @override
  State<_ServiceRatingSheet> createState() => _ServiceRatingSheetState();
}

class _ServiceRatingSheetState extends State<_ServiceRatingSheet> {
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Escolha de 1 a 5 estrelas.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await context.read<ServiceRepository>().submitReview(
        serviceId: widget.session.serviceId,
        rating: _rating,
        comment: _commentController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = 'Não foi possível enviar a avaliação. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                size: 32,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Serviço concluído',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Como foi trabalhar com ${widget.session.professionalName ?? 'este profissional'}?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              label: _rating == 0
                  ? 'Nenhuma nota selecionada'
                  : 'Nota $_rating de 5',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      tooltip: '$star ${star == 1 ? 'estrela' : 'estrelas'}',
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() {
                              _rating = star;
                              _error = null;
                            }),
                      iconSize: 39,
                      icon: Icon(
                        star <= _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: star <= _rating
                            ? AppColors.accent
                            : AppColors.textDisabled,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              _ratingLabel(_rating),
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: AppColors.primaryDark),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _commentController,
              enabled: !_isSubmitting,
              maxLines: 3,
              maxLength: 400,
              decoration: const InputDecoration(
                labelText: 'Conte mais (opcional)',
                hintText: 'Pontualidade, qualidade e comunicação…',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isSubmitting ? 'Enviando…' : 'Enviar avaliação'),
              ),
            ),
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Agora não'),
            ),
          ],
        ),
      ),
    );
  }
}

String _ratingLabel(int rating) => switch (rating) {
  1 => 'Muito abaixo do esperado',
  2 => 'Pode melhorar',
  3 => 'Bom trabalho',
  4 => 'Ótimo trabalho',
  5 => 'Excelente!',
  _ => 'Toque nas estrelas para avaliar',
};

class _PendingEmptyState extends StatelessWidget {
  const _PendingEmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.task_alt,
                color: AppColors.primaryDark,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tudo conferido',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Nenhuma jornada precisa da sua validação agora.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
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

class _ConfirmationCard extends StatelessWidget {
  final WorkSessionModel session;
  final bool isConfirming;
  final VoidCallback onConfirm;

  const _ConfirmationCard({
    required this.session,
    required this.isConfirming,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.hourglass_top,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.serviceTitle ?? 'Serviço',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Profissional: ${session.professionalName ?? 'Não informado'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  _money(session.amount ?? 0),
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: AppColors.primaryDark),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                _Info(
                  icon: Icons.schedule,
                  text: _minutes(session.durationMinutes ?? 0),
                ),
                _Info(icon: Icons.login, text: _dateTime(session.startedAt)),
                if (session.endedAt != null)
                  _Info(icon: Icons.logout, text: _dateTime(session.endedAt!)),
              ],
            ),
            if (session.providerNote != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Observação: ${session.providerNote}'),
              ),
            ],
            if (session.evidencePhotoUrl != null) ...[
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  ApiConstants.resolveUrl(session.evidencePhotoUrl!),
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 80,
                    child: Center(child: Text('Foto indisponível')),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: isConfirming ? null : onConfirm,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  isConfirming ? 'Confirmando…' : 'Confirmar jornada',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = notification.readAt == null;
    final resolved = notification.isResolvedConfirmation;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: unread ? AppColors.primaryLight : AppColors.surface,
      child: ListTile(
        onTap: unread ? onTap : null,
        leading: Icon(
          resolved
              ? Icons.task_alt
              : unread
              ? Icons.notifications_active_outlined
              : Icons.notifications_none,
          color: resolved
              ? AppColors.success
              : unread
              ? AppColors.primary
              : AppColors.textSecondary,
        ),
        title: Text(resolved ? 'Jornada já conferida' : notification.title),
        subtitle: Text(
          resolved
              ? _resolvedConfirmationMessage(notification.message)
              : notification.message,
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _shortDate(notification.createdAt),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (resolved) ...[
              const SizedBox(height: 4),
              Text(
                'Resolvida',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Info({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

String _minutes(int total) {
  final hours = total ~/ 60;
  final minutes = total % 60;
  if (hours == 0) return '${minutes}min';
  return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
}

String _money(double value) => 'R\$ ${value.toStringAsFixed(2)}';

String _dateTime(DateTime value) {
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _shortDate(DateTime value) {
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

String _resolvedConfirmationMessage(String message) {
  return message.replaceFirst(
    RegExp(r'Confira os dados e confirme\.?$', caseSensitive: false),
    'A confirmação já foi concluída.',
  );
}
