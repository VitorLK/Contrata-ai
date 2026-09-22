import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/name_utils.dart';
import '../../models/chat_models.dart';
import '../../models/professional_profile_model.dart';
import '../../models/user_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../viewmodels/services_list_viewmodel.dart' show LoadStatus;
import '../../widgets/error_state_view.dart';
import '../../widgets/loading_overlay.dart';
import 'proposal_composer_sheet.dart';

class ConversationScreen extends StatefulWidget {
  final ConversationModel conversation;

  const ConversationScreen({super.key, required this.conversation});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _load();
      _scrollToEnd();
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted) {
          context.read<ChatViewModel>().loadThread(
            widget.conversation.id,
            silent: true,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() =>
      context.read<ChatViewModel>().loadThread(widget.conversation.id);

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    try {
      await context.read<ChatViewModel>().sendMessage(
        widget.conversation.id,
        text,
      );
      _scrollToEnd();
    } on ApiException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Não foi possível enviar a mensagem.');
    }
  }

  Future<void> _composeProposal() async {
    final draft = await showProposalComposer(context);
    if (draft == null || !mounted) return;
    try {
      await context.read<ChatViewModel>().createProposal(
        conversationId: widget.conversation.id,
        title: draft.title,
        description: draft.description,
        category: draft.category,
        serviceMode: draft.serviceMode,
        city: draft.city,
        state: draft.state,
        address: draft.address,
        pricingType: draft.pricingType,
        amount: draft.amount,
        scheduledStart: draft.scheduledStart,
        scheduledEnd: draft.scheduledEnd,
        isAllDay: draft.isAllDay,
      );
      if (!mounted) return;
      _message('Proposta enviada. O horário ainda não está reservado.');
      _scrollToEnd();
    } on ApiException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Não foi possível enviar a proposta.');
    }
  }

  Future<void> _respond(JobProposalModel proposal, bool accept) async {
    if (accept) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reservar este horário?'),
          content: Text(
            'Ao aceitar “${proposal.title}”, este período entra na sua Agenda e não poderá receber outro trabalho sobreposto. Mesmo fora do horário padrão do perfil, esta confirmação será válida.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Aceitar e reservar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    try {
      await context.read<ChatViewModel>().respondToProposal(
        conversationId: widget.conversation.id,
        proposalId: proposal.id,
        accept: accept,
      );
      if (!mounted) return;
      _message(
        accept
            ? 'Proposta aceita. O trabalho já está na sua Agenda.'
            : 'Proposta recusada. Vocês ainda podem negociar pelo chat.',
      );
    } on ApiException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Não foi possível responder à proposta.');
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();
    final user = context.watch<AuthViewModel>().currentUser;
    final currentUserId = user?.id ?? '';
    final isClient = user?.role == UserRole.cliente;
    final peerName = widget.conversation.peerName(currentUserId);
    final isProfessionalPeer = currentUserId == widget.conversation.clientId;
    final peerPhotoUrl = isProfessionalPeer
        ? widget.conversation.professionalPhotoUrl
        : null;
    final isDesktop = MediaQuery.sizeOf(context).width >= 960;
    final thread = viewModel.thread?.conversation.id == widget.conversation.id
        ? viewModel.thread
        : null;

    Widget body;
    if (thread == null &&
        (viewModel.threadStatus == LoadStatus.loading ||
            viewModel.threadStatus == LoadStatus.idle)) {
      body = const LoadingOverlay();
    } else if (thread == null && viewModel.threadStatus == LoadStatus.error) {
      body = ErrorStateView(message: viewModel.errorMessage, onRetry: _load);
    } else {
      final timeline = _timeline(thread!);
      body = Column(
        children: [
          _ReservationNotice(compact: !isDesktop),
          Expanded(
            child: ColoredBox(
              color: AppColors.background.withValues(alpha: .68),
              child: timeline.isEmpty
                  ? _ConversationStart(peerName: peerName, isClient: isClient)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 28 : 14,
                        16,
                        isDesktop ? 28 : 14,
                        24,
                      ),
                      itemCount: timeline.length,
                      itemBuilder: (context, index) {
                        final item = timeline[index];
                        final showDate =
                            index == 0 ||
                            !_sameDay(
                              timeline[index - 1].createdAt,
                              item.createdAt,
                            );
                        final itemWidget = item.message != null
                            ? _MessageBubble(
                                message: item.message!,
                                isMine: item.message!.senderId == currentUserId,
                              )
                            : _ProposalCard(
                                proposal: item.proposal!,
                                canRespond:
                                    !isClient &&
                                    item.proposal!.status ==
                                        ProposalStatus.pendente,
                                isBusy: viewModel.isMutating,
                                onAccept: () => _respond(item.proposal!, true),
                                onDecline: () =>
                                    _respond(item.proposal!, false),
                              );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDate) _DayDivider(date: item.createdAt),
                            itemWidget,
                          ],
                        );
                      },
                    ),
            ),
          ),
          _Composer(
            controller: _messageController,
            isClient: isClient,
            showProposalButton: !isDesktop,
            isBusy: viewModel.isMutating,
            onSend: _send,
            onProposal: _composeProposal,
          ),
        ],
      );
    }

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              toolbarHeight: 68,
              titleSpacing: 4,
              title: _CompactPeerHeader(
                name: peerName,
                role: isClient ? 'Profissional' : 'Contratante',
                photoUrl: peerPhotoUrl,
              ),
            ),
      body: SafeArea(
        child: isDesktop
            ? _DesktopConversationLayout(
                name: peerName,
                role: isClient ? 'Profissional' : 'Contratante',
                photoUrl: peerPhotoUrl,
                isClient: isClient,
                onBack: () => Navigator.of(context).maybePop(),
                onProposal: _composeProposal,
                isBusy: viewModel.isMutating,
                child: body,
              )
            : body,
      ),
    );
  }
}

class _DesktopConversationLayout extends StatelessWidget {
  final String name;
  final String role;
  final String? photoUrl;
  final bool isClient;
  final bool isBusy;
  final VoidCallback onBack;
  final VoidCallback onProposal;
  final Widget child;

  const _DesktopConversationLayout({
    required this.name,
    required this.role,
    required this.photoUrl,
    required this.isClient,
    required this.isBusy,
    required this.onBack,
    required this.onProposal,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 286,
                child: _ConversationContextRail(
                  name: name,
                  role: role,
                  photoUrl: photoUrl,
                  isClient: isClient,
                  isBusy: isBusy,
                  onBack: onBack,
                  onProposal: onProposal,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _DesktopChatHeader(
                        name: name,
                        role: role,
                        photoUrl: photoUrl,
                      ),
                      const Divider(),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationContextRail extends StatelessWidget {
  final String name;
  final String role;
  final String? photoUrl;
  final bool isClient;
  final bool isBusy;
  final VoidCallback onBack;
  final VoidCallback onProposal;

  const _ConversationContextRail({
    required this.name,
    required this.role,
    required this.photoUrl,
    required this.isClient,
    required this.isBusy,
    required this.onBack,
    required this.onProposal,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Todas as conversas'),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _ChatPeerAvatar(name: name, photoUrl: photoUrl, radius: 34),
              const SizedBox(height: 14),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(role, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Contato pelo Contrata Aí',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ACORDO DE TRABALHO',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: AppColors.accent),
              ),
              const SizedBox(height: 8),
              Text(
                'Da conversa para a agenda',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 18),
              const _ContextStep(
                icon: Icons.chat_bubble_outline_rounded,
                text: 'Alinhe os detalhes do serviço',
              ),
              const _ContextStep(
                icon: Icons.request_quote_outlined,
                text: 'Formalize valor, data e horário',
              ),
              const _ContextStep(
                icon: Icons.event_available_outlined,
                text: 'O aceite reserva o período na Agenda',
              ),
              if (isClient) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : onProposal,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: const Text('Criar proposta'),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Você poderá aceitar ou recusar a proposta sem sair desta conversa.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Colors.white.withValues(alpha: .66)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ContextStep extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContextStep({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryLight, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Colors.white.withValues(alpha: .82)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopChatHeader extends StatelessWidget {
  final String name;
  final String role;
  final String? photoUrl;

  const _DesktopChatHeader({
    required this.name,
    required this.role,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Row(
        children: [
          _ChatPeerAvatar(name: name, photoUrl: photoUrl, radius: 23),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                Text(role, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 7),
                Text(
                  'Horário ainda não reservado',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactPeerHeader extends StatelessWidget {
  final String name;
  final String role;
  final String? photoUrl;

  const _CompactPeerHeader({
    required this.name,
    required this.role,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ChatPeerAvatar(name: name, photoUrl: photoUrl, radius: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(role, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatPeerAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;

  const _ChatPeerAvatar({
    required this.name,
    required this.photoUrl,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPhoto = photoUrl == null
        ? null
        : ApiConstants.resolveUrl(photoUrl!);
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryLight,
      foregroundImage: resolvedPhoto == null
          ? null
          : NetworkImage(resolvedPhoto),
      onForegroundImageError: resolvedPhoto == null ? null : (_, _) {},
      child: Text(
        initialsFor(name),
        style: TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
          fontSize: radius * .48,
        ),
      ),
    );
  }
}

class _ReservationNotice extends StatelessWidget {
  final bool compact;

  const _ReservationNotice({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(compact ? 12 : 18, 12, compact ? 12 : 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Conversa não reserva horário. Só uma proposta aceita entra na Agenda.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  final DateTime date;

  const _DayDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              _dayLabel(date),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _TimelineItem {
  final ChatMessageModel? message;
  final JobProposalModel? proposal;
  final DateTime createdAt;

  _TimelineItem.message(ChatMessageModel value)
    : message = value,
      proposal = null,
      createdAt = value.createdAt;

  _TimelineItem.proposal(JobProposalModel value)
    : proposal = value,
      message = null,
      createdAt = value.createdAt;
}

List<_TimelineItem> _timeline(ConversationThreadModel thread) {
  final items = <_TimelineItem>[
    ...thread.messages.map(_TimelineItem.message),
    ...thread.proposals.map(_TimelineItem.proposal),
  ];
  items.sort((first, second) => first.createdAt.compareTo(second.createdAt));
  return items;
}

class _ConversationStart extends StatelessWidget {
  final String peerName;
  final bool isClient;

  const _ConversationStart({required this.peerName, required this.isClient});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.forum_outlined,
                size: 30,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Converse com $peerName',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              isClient
                  ? 'Explique o serviço e tire dúvidas. Quando tudo estiver claro, envie uma proposta com data, horário e valor.'
                  : 'Pergunte o que precisar antes de assumir o trabalho. O horário só será bloqueado quando você aceitar a proposta.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: IntrinsicWidth(
        child: Container(
          constraints: const BoxConstraints(minWidth: 88, maxWidth: 560),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: isMine ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isMine ? 14 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 14),
            ),
            border: isMine ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  message.body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isMine ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _time(message.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isMine ? Colors.white70 : AppColors.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final JobProposalModel proposal;
  final bool canRespond;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _ProposalCard({
    required this.proposal,
    required this.canRespond,
    required this.isBusy,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (proposal.status) {
      ProposalStatus.aceita => AppColors.success,
      ProposalStatus.recusada || ProposalStatus.cancelada => AppColors.error,
      ProposalStatus.pendente => AppColors.accent,
    };
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 660),
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withValues(alpha: .45)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: .1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.request_quote_outlined, color: statusColor),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'PROPOSTA DE TRABALHO',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: statusColor),
                    ),
                  ),
                  Text(
                    proposal.status.label,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: statusColor),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proposal.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(proposal.description),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ProposalFact(
                        icon: Icons.calendar_month_outlined,
                        text: _proposalPeriod(proposal),
                      ),
                      _ProposalFact(
                        icon: Icons.payments_outlined,
                        text:
                            '${_money(proposal.amount)} ${proposal.pricingType == PricingType.porHora ? '/ hora' : 'fechado'}',
                      ),
                      _ProposalFact(
                        icon: Icons.location_on_outlined,
                        text: proposal.serviceMode == ServiceMode.remoto
                            ? 'Remoto'
                            : '${proposal.city ?? ''}/${proposal.state ?? ''}',
                      ),
                    ],
                  ),
                  if (canRespond) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isBusy ? null : onDecline,
                            child: const Text('Recusar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: isBusy ? null : onAccept,
                            icon: const Icon(Icons.event_available_outlined),
                            label: const Text('Aceitar e reservar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProposalFact extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ProposalFact({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool isClient;
  final bool showProposalButton;
  final bool isBusy;
  final VoidCallback onSend;
  final VoidCallback onProposal;

  const _Composer({
    required this.controller,
    required this.isClient,
    required this.showProposalButton,
    required this.isBusy,
    required this.onSend,
    required this.onProposal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isClient && showProposalButton)
              IconButton.filledTonal(
                tooltip: 'Enviar proposta de trabalho',
                onPressed: isBusy ? null : onProposal,
                icon: const Icon(Icons.request_quote_outlined),
              ),
            if (isClient && showProposalButton) const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Escreva uma mensagem…',
                  counterText: '',
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Enviar mensagem',
              onPressed: isBusy ? null : onSend,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';

String _proposalPeriod(JobProposalModel proposal) {
  if (proposal.isAllDay) {
    return '${_date(proposal.scheduledStart)} · dia inteiro';
  }
  final crossesDay =
      proposal.scheduledStart.day != proposal.scheduledEnd.day ||
      proposal.scheduledStart.month != proposal.scheduledEnd.month;
  return '${_date(proposal.scheduledStart)} · ${_time(proposal.scheduledStart)}–${_time(proposal.scheduledEnd)}${crossesDay ? ' (+1 dia)' : ''}';
}

String _money(double value) =>
    'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _dayLabel(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(value.year, value.month, value.day);
  if (day == today) {
    return 'HOJE';
  }
  if (day == today.subtract(const Duration(days: 1))) {
    return 'ONTEM';
  }
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
