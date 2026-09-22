import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/name_utils.dart';
import '../../models/professional_profile_model.dart'
    show PricingType, PricingTypeX, ServiceModeX;
import '../../models/review_model.dart';
import '../../viewmodels/professional_public_viewmodel.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../viewmodels/services_list_viewmodel.dart' show LoadStatus;
import '../../widgets/error_state_view.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/rating_summary.dart';
import '../chat/conversation_screen.dart';

/// Página pública do profissional — o que o cliente vê antes de decidir
/// contratar. Mostra só dados públicos (sem e-mail).
class ProfessionalPublicProfileScreen extends StatefulWidget {
  final String professionalId;

  const ProfessionalPublicProfileScreen({
    super.key,
    required this.professionalId,
  });

  @override
  State<ProfessionalPublicProfileScreen> createState() =>
      _ProfessionalPublicProfileScreenState();
}

class _ProfessionalPublicProfileScreenState
    extends State<ProfessionalPublicProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    return context.read<ProfessionalPublicViewModel>().load(
      widget.professionalId,
    );
  }

  Future<void> _openConversation() async {
    try {
      final conversation = await context
          .read<ChatViewModel>()
          .openConversation(widget.professionalId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConversationScreen(conversation: conversation),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir a conversa: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProfessionalPublicViewModel>();
    final profile = viewModel.profile;

    Widget body;
    if (profile == null && viewModel.status == LoadStatus.error) {
      body = ErrorStateView(message: viewModel.errorMessage, onRetry: _load);
    } else if (profile == null) {
      body = const LoadingOverlay();
    } else {
      final location = [
        profile.city,
        profile.state,
      ].where((v) => v != null && v.isNotEmpty).join('/');

      body = SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 58,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: profile.photoUrl != null
                    ? NetworkImage(ApiConstants.resolveUrl(profile.photoUrl!))
                    : null,
                child: profile.photoUrl == null
                    ? Text(
                        initialsFor(profile.name),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                profile.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: profile.rating.average == null
                  ? const Chip(
                      avatar: Icon(Icons.auto_awesome_outlined, size: 17),
                      label: Text('Novo profissional'),
                    )
                  : Chip(
                      avatar: const Icon(
                        Icons.star_rounded,
                        color: AppColors.accent,
                        size: 18,
                      ),
                      label: Text(
                        '${profile.rating.average!.toStringAsFixed(1)} · ${profile.rating.total} avaliações',
                      ),
                    ),
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  location,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (profile.skills.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profile.skills
                    .map((skill) => Chip(label: Text(skill)))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],
            if (profile.bio != null && profile.bio!.isNotEmpty) ...[
              Text('Sobre', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(profile.bio!),
              const SizedBox(height: 20),
            ],
            if (profile.experience != null &&
                profile.experience!.isNotEmpty) ...[
              Text(
                'Experiência',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(profile.experience!),
              const SizedBox(height: 20),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile.pricingType == PricingType.porHora &&
                    profile.hourlyRate != null)
                  Expanded(
                    child: _InfoTile(
                      label: profile.pricingType.label,
                      value:
                          'R\$ ${profile.hourlyRate!.toStringAsFixed(2)}/hora',
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                if (profile.pricingType == PricingType.empreitada &&
                    profile.projectRate != null)
                  Expanded(
                    child: _InfoTile(
                      label: profile.pricingType.label,
                      value: 'R\$ ${profile.projectRate!.toStringAsFixed(2)}',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                if (profile.serviceMode != null)
                  Expanded(
                    child: _InfoTile(
                      label: 'Atendimento',
                      value: profile.serviceMode!.label,
                      icon: Icons.route_outlined,
                    ),
                  ),
              ],
            ),
            if (profile.availabilitySchedule.slots.isNotEmpty ||
                profile.availabilitySchedule.variableHours) ...[
              const SizedBox(height: 16),
              _InfoTile(
                label: 'Agenda habitual',
                value: profile.availabilitySchedule.summary,
                icon: Icons.event_available_outlined,
              ),
            ],
            if (profile.portfolio.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Portfólio', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: profile.portfolio.length,
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    ApiConstants.resolveUrl(profile.portfolio[index].imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text('Avaliações', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            RatingSummary(rating: profile.rating),
            if (profile.reviews.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              for (final review in profile.reviews) _ReviewTile(review: review),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil do profissional')),
      body: SafeArea(child: body),
      bottomNavigationBar: profile == null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: FilledButton.icon(
                  onPressed: context.watch<ChatViewModel>().isMutating
                      ? null
                      : _openConversation,
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Conversar e solicitar horário'),
                ),
              ),
            ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ReviewModel review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.clientName ?? 'Cliente',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              RatingStars(rating: review.rating, size: 16),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(review.comment!),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const _InfoTile({required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 21, color: AppColors.primary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
