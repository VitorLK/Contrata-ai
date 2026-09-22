import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/applications_viewmodel.dart';
import '../../viewmodels/services_list_viewmodel.dart' show LoadStatus;
import '../../widgets/application_card.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/loading_overlay.dart';
import '../professionals/professional_public_profile_screen.dart';

/// Tela do cliente para ver quem se candidatou a um serviço próprio e
/// decidir (aceitar/recusar). Primeira tela do fluxo de máquina de
/// estados construído nas Etapas 7-9 do plano.
class ServiceApplicationsScreen extends StatefulWidget {
  final String serviceId;

  const ServiceApplicationsScreen({super.key, required this.serviceId});

  @override
  State<ServiceApplicationsScreen> createState() =>
      _ServiceApplicationsScreenState();
}

class _ServiceApplicationsScreenState extends State<ServiceApplicationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    return context.read<ApplicationsViewModel>().loadForService(
      widget.serviceId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ApplicationsViewModel>();

    Widget body;
    if (viewModel.status == LoadStatus.loading ||
        viewModel.status == LoadStatus.idle) {
      body = const LoadingOverlay();
    } else if (viewModel.status == LoadStatus.error) {
      body = ErrorStateView(message: viewModel.errorMessage, onRetry: _load);
    } else if (viewModel.applications.isEmpty) {
      body = const EmptyStateView(
        icon: Icons.people_outline,
        title: 'Nenhuma candidatura ainda',
        message:
            'Assim que alguém se candidatar a este serviço, aparecerá aqui.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: viewModel.applications.length,
          itemBuilder: (context, index) {
            final application = viewModel.applications[index];
            return ApplicationCard(
              application: application,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfessionalPublicProfileScreen(
                    professionalId: application.professionalId,
                  ),
                ),
              ),
              onAccept: () =>
                  context.read<ApplicationsViewModel>().accept(application.id),
              onReject: () =>
                  context.read<ApplicationsViewModel>().reject(application.id),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Candidatos')),
      body: SafeArea(child: body),
    );
  }
}
