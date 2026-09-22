import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/browser_navigation.dart';
import '../../models/professional_profile_model.dart';
import '../../models/service_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/service_detail_viewmodel.dart';
import '../../viewmodels/services_list_viewmodel.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/service_location_map.dart';
import 'create_service_screen.dart';
import 'service_applications_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  final String serviceId;
  final ServiceModel? initialService;
  final bool canApply;
  final bool isClientView;

  const ServiceDetailScreen({
    super.key,
    required this.serviceId,
    this.initialService,
    this.canApply = false,
    this.isClientView = false,
  });

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final _messageController = TextEditingController();
  final _reviewCommentController = TextEditingController();
  bool _isApplying = false;
  bool _isUpdatingStatus = false;
  bool _isSubmittingReview = false;
  int _reviewRating = 0;
  bool _hasSubmittedReview = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    return context.read<ServiceDetailViewModel>().load(widget.serviceId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _reviewCommentController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() => _isApplying = true);
    try {
      await context.read<ServicesListViewModel>().applyToService(
        widget.serviceId,
        message: _messageController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Candidatura enviada com sucesso!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível enviar a candidatura: $e')),
      );
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  Future<void> _cancelService() async {
    setState(() => _isUpdatingStatus = true);
    try {
      await context.read<ServiceDetailViewModel>().cancel();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Serviço cancelado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível cancelar o serviço: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmittingReview = true);
    try {
      await context.read<ServiceDetailViewModel>().submitReview(
        rating: _reviewRating,
        comment: _reviewCommentController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _hasSubmittedReview = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avaliação enviada. Obrigado pelo feedback!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível enviar a avaliação: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  Future<void> _editService(ServiceModel service) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateServiceScreen(initialService: service),
      ),
    );
    if (changed == true && mounted) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alterações salvas com sucesso.')),
      );
    }
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
        title: const Text('Cancelar serviço?'),
        content: const Text(
          'As candidaturas pendentes serão recusadas automaticamente. Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Manter serviço'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sim, cancelar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _cancelService();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ServiceDetailViewModel>();
    final currentUserId = context.watch<AuthViewModel>().currentUser?.id;
    final service = viewModel.service ?? widget.initialService;

    Widget body;
    if (service == null && viewModel.status == LoadStatus.error) {
      body = ErrorStateView(message: viewModel.errorMessage, onRetry: _load);
    } else if (service == null) {
      body = const LoadingOverlay();
    } else {
      body = LayoutBuilder(
        builder: (context, viewport) {
          final pagePadding = viewport.maxWidth >= 700 ? 32.0 : 16.0;
          return RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 56),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ServiceHero(service: service),
                      const SizedBox(height: 22),
                      LayoutBuilder(
                        builder: (context, content) {
                          final isDesktop = content.maxWidth >= 880;
                          final details = _DetailsColumn(service: service);
                          final summary = _buildSummary(
                            context,
                            service,
                            currentUserId,
                          );
                          if (!isDesktop) {
                            return Column(
                              children: [
                                details,
                                const SizedBox(height: 18),
                                summary,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: details),
                              const SizedBox(width: 24),
                              SizedBox(width: 340, child: summary),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do serviço')),
      body: SafeArea(child: body),
    );
  }

  Widget _buildSummary(
    BuildContext context,
    ServiceModel service,
    String? currentUserId,
  ) {
    return Column(
      children: [
        _SummaryCard(service: service),
        if (widget.isClientView || widget.canApply) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildActions(context, service, currentUserId),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    ServiceModel service,
    String? currentUserId,
  ) {
    final actions = <Widget>[];
    if (widget.isClientView) {
      actions.add(
        Text(
          'Gerenciar serviço',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      );
      actions.add(const SizedBox(height: 6));
      actions.add(
        Text(
          _clientActionDescription(service),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
      actions.add(const SizedBox(height: 18));

      if (service.status == ServiceStatus.aberto) {
        actions.add(
          PrimaryButton(
            label: service.applicationCount == 1
                ? 'Ver 1 candidato'
                : 'Ver ${service.applicationCount} candidatos',
            icon: Icons.groups_outlined,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ServiceApplicationsScreen(serviceId: service.id),
              ),
            ),
          ),
        );
        actions.add(const SizedBox(height: 10));
        actions.add(
          SecondaryButton(
            label: 'Editar serviço',
            icon: Icons.edit_outlined,
            onPressed: () => _editService(service),
          ),
        );
      }
      if (service.status == ServiceStatus.emAndamento) {
        actions.add(
          _InfoBanner(
            icon: Icons.punch_clock_outlined,
            color: AppColors.warning,
            text: 'O profissional foi contratado. A conclusão será feita pelo registro da jornada.',
          ),
        );
      }
      if (service.status == ServiceStatus.agendado) {
        actions.add(
          const _InfoBanner(
            icon: Icons.event_available_outlined,
            color: AppColors.primary,
            text: 'Profissional confirmado. O período está reservado e o trabalho começa pelo Play na Agenda.',
          ),
        );
      }
      if (service.status == ServiceStatus.aberto ||
          service.status == ServiceStatus.agendado ||
          service.status == ServiceStatus.emAndamento) {
        actions.add(const SizedBox(height: 10));
        actions.add(
          SecondaryButton(
            label: 'Cancelar serviço',
            icon: Icons.cancel_outlined,
            isDanger: true,
            isLoading: _isUpdatingStatus,
            onPressed: _confirmCancel,
          ),
        );
      }
      if (service.status == ServiceStatus.concluido) {
        actions.addAll(_buildReviewActions(context));
      }
      return actions;
    }

    if (widget.canApply) {
      if (currentUserId != null &&
          service.acceptedProfessionalId == currentUserId) {
        return [
          const _InfoBanner(
            icon: Icons.check_circle_outline,
            color: AppColors.success,
            text: 'Você foi contratado para este serviço!',
          ),
        ];
      }
      if (service.status != ServiceStatus.aberto) {
        return const [
          _InfoBanner(
            icon: Icons.info_outline,
            color: AppColors.textSecondary,
            text: 'Este serviço não está mais recebendo candidaturas.',
          ),
        ];
      }
      return [
        Text(
          'Enviar candidatura',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Apresente rapidamente sua experiência e disponibilidade.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _messageController,
          label: 'Mensagem (opcional)',
          hintText: 'Ex.: Tenho experiência e posso atender nesta data.',
          maxLines: 4,
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'Candidatar-me',
          icon: Icons.send_outlined,
          isLoading: _isApplying,
          onPressed: _apply,
        ),
        const SizedBox(height: 10),
        Text(
          'O contratante receberá seu perfil profissional junto da mensagem.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ];
    }
    return actions;
  }

  List<Widget> _buildReviewActions(BuildContext context) {
    if (_hasSubmittedReview) {
      return const [
        _InfoBanner(
          icon: Icons.check_circle_outline,
          color: AppColors.success,
          text: 'Você avaliou este serviço. Obrigado pelo feedback!',
        ),
      ];
    }
    return [
      Text(
        'Avaliar profissional',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 6),
      Text(
        'Sua avaliação ajuda outras pessoas a contratar com mais segurança.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 14),
      RatingStars(
        rating: _reviewRating,
        onChanged: (value) => setState(() => _reviewRating = value),
      ),
      const SizedBox(height: 12),
      AppTextField(
        controller: _reviewCommentController,
        label: 'Comentário (opcional)',
        maxLines: 3,
      ),
      const SizedBox(height: 14),
      PrimaryButton(
        label: 'Enviar avaliação',
        icon: Icons.star_outline_rounded,
        isLoading: _isSubmittingReview,
        onPressed: _reviewRating == 0 ? null : _submitReview,
      ),
    ];
  }
}

class _ServiceHero extends StatelessWidget {
  final ServiceModel service;

  const _ServiceHero({required this.service});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: service.imageUrl == null
          ? 'Ilustração de serviço sem foto cadastrada'
          : 'Foto do serviço ${service.title}',
      child: Container(
        height: 286,
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (service.imageUrl != null)
              Image.network(
                ApiConstants.resolveUrl(service.imageUrl!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _ServiceHeroFallback(),
              )
            else
              const _ServiceHeroFallback(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xB8142F2B)],
                  stops: [0.38, 1],
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 22,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (service.category != null)
                    _HeroTag(
                      icon: Icons.handyman_outlined,
                      label: service.category!,
                    ),
                  _HeroTag(
                    icon: service.serviceMode == null
                        ? Icons.work_outline
                        : _modeIcon(service.serviceMode!),
                    label: service.serviceMode?.label ?? 'A combinar',
                  ),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: StatusBadge(status: service.status),
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

class _ServiceHeroFallback extends StatelessWidget {
  const _ServiceHeroFallback();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _WorkshopPainter())),
        Align(
          alignment: const Alignment(0.72, -0.12),
          child: Icon(
            Icons.handyman_outlined,
            size: 122,
            color: Colors.white.withValues(alpha: 0.16),
          ),
        ),
      ],
    );
  }
}

class _WorkshopPainter extends CustomPainter {
  const _WorkshopPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.primaryDark, Color(0xFF3A5B8C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);
    final lines = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const gap = 30.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), lines);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), lines);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsColumn extends StatelessWidget {
  final ServiceModel service;

  const _DetailsColumn({required this.service});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  service.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Publicado em ${_formatDate(service.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(height: 34),
                Text(
                  'Sobre o serviço',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  service.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _LocationCard(service: service),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  final ServiceModel service;

  const _LocationCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final isRemote = service.serviceMode?.apiValue == 'remoto';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isRemote
                        ? Icons.laptop_outlined
                        : Icons.location_on_outlined,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRemote
                            ? 'Atendimento remoto'
                            : 'Localização do serviço',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        service.fullLocationLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isRemote) ...[
              const SizedBox(height: 18),
              if (service.hasCoordinates)
                ServiceLocationMap(
                  latitude: service.latitude,
                  longitude: service.longitude,
                  height: 230,
                  semanticsLabel:
                      'Mapa da localização aproximada de ${service.locationLabel}',
                )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.location_off_outlined,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Este serviço foi criado antes da seleção pelo mapa. Edite-o para definir o ponto.',
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                'A posição exibida é aproximada. Dados exatos podem ser combinados com o profissional contratado.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (service.hasCoordinates) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _DirectionsButton(service: service),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ServiceModel service;

  const _SummaryCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'RESUMO DA OPORTUNIDADE',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 14),
            Text(
              service.budget == null
                  ? 'Valor a combinar'
                  : _currency(service.budget!),
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: AppColors.primaryDark),
            ),
            const SizedBox(height: 3),
            Text(
              service.budget == null
                  ? 'Combine o valor antes de iniciar'
                  : 'Orçamento fixo informado',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 30),
            _SummaryRow(
              icon: Icons.event_outlined,
              label: 'Data prevista',
              value: _formatDate(service.scheduledDate),
            ),
            _SummaryRow(
              icon: Icons.location_on_outlined,
              label: 'Local',
              value: service.locationLabel,
            ),
            _SummaryRow(
              icon: Icons.person_outline_rounded,
              label: 'Contratante',
              value: service.clientName ?? 'Cliente da plataforma',
            ),
            if (service.applicationCount > 0)
              _SummaryRow(
                icon: Icons.groups_outlined,
                label: 'Interesse',
                value: service.applicationCount == 1
                    ? '1 candidatura'
                    : '${service.applicationCount} candidaturas',
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 1),
                Text(value, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        border: Border.all(color: color.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

String _clientActionDescription(ServiceModel service) {
  switch (service.status) {
    case ServiceStatus.aberto:
      return 'Compare candidatos, edite informações ou encerre a oportunidade.';
    case ServiceStatus.agendado:
      return 'O profissional aceitou e o período está reservado na agenda.';
    case ServiceStatus.emAndamento:
      return 'Acompanhe a execução e aguarde o encerramento da jornada.';
    case ServiceStatus.concluido:
      return 'O trabalho foi concluído. Registre sua experiência.';
    case ServiceStatus.cancelado:
      return 'Esta oportunidade foi encerrada e não aceita novas ações.';
  }
}

class _DirectionsButton extends StatelessWidget {
  final ServiceModel service;

  const _DirectionsButton({required this.service});

  @override
  Widget build(BuildContext context) {
    Widget button(VoidCallback? onPressed) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.directions_outlined),
        label: const Text('Abrir rota no Google Maps'),
      );
    }

    if (kIsWeb) {
      return button(() => navigateBrowserTo(_googleMapsDirectionsUri(service)));
    }

    return button(() => _openDirections(context, service));
  }
}

Uri _googleMapsDirectionsUri(ServiceModel service) {
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '${service.latitude},${service.longitude}',
    'travelmode': 'driving',
  });
}

Future<void> _openDirections(BuildContext context, ServiceModel service) async {
  if (!service.hasCoordinates) return;

  try {
    final opened = await launchUrl(
      _googleMapsDirectionsUri(service),
      mode: LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível abrir a rota no Google Maps.'),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível abrir a rota no Google Maps.'),
      ),
    );
  }
}

IconData _modeIcon(ServiceMode mode) {
  switch (mode.apiValue) {
    case 'remoto':
      return Icons.laptop_outlined;
    case 'hibrido':
      return Icons.sync_alt_rounded;
    default:
      return Icons.location_on_outlined;
  }
}

String _formatDate(DateTime date) {
  const months = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}

String _currency(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final grouped = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return 'R\$ $grouped,${parts[1]}';
}
