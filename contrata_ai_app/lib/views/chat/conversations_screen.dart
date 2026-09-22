import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/name_utils.dart';
import '../../models/chat_models.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../viewmodels/services_list_viewmodel.dart' show LoadStatus;
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/loading_overlay.dart';
import 'conversation_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatViewModel>().loadConversations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _open(ConversationModel conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(conversation: conversation),
      ),
    );
    if (mounted) {
      await context.read<ChatViewModel>().loadConversations(silent: true);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  List<ConversationModel> _filter(
    List<ConversationModel> conversations,
    String userId,
  ) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return conversations;
    return conversations.where((conversation) {
      final name = conversation.peerName(userId).toLowerCase();
      final message = conversation.lastMessage?.toLowerCase() ?? '';
      return name.contains(query) || message.contains(query);
    }).toList();
  }

  Widget _buildConversationState({
    required ChatViewModel viewModel,
    required List<ConversationModel> visible,
    required String currentUserId,
    required bool compact,
  }) {
    if (viewModel.listStatus == LoadStatus.loading ||
        viewModel.listStatus == LoadStatus.idle) {
      return const LoadingOverlay();
    }
    if (viewModel.listStatus == LoadStatus.error) {
      return ErrorStateView(
        message: viewModel.errorMessage,
        onRetry: viewModel.loadConversations,
      );
    }
    if (viewModel.conversations.isEmpty) {
      return const EmptyStateView(
        icon: Icons.forum_outlined,
        title: 'Nenhuma conversa ainda',
        message: 'Ao conversar com um profissional ou receber um convite, a negociação fica organizada aqui.',
      );
    }
    if (visible.isEmpty) {
      return EmptyStateView(
        icon: Icons.search_off_rounded,
        title: 'Nenhuma conversa encontrada',
        message: 'Tente buscar por outro nome ou termo da mensagem.',
        actionLabel: 'Limpar busca',
        onAction: _clearSearch,
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.loadConversations,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 18,
          compact ? 4 : 10,
          compact ? 16 : 18,
          28,
        ),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final conversation = visible[index];
          return _ConversationTile(
            conversation: conversation,
            currentUserId: currentUserId,
            compact: compact,
            onTap: () => _open(conversation),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();
    final user = context.watch<AuthViewModel>().currentUser;
    final userId = user?.id ?? '';
    final visible = _filter(viewModel.conversations, userId);
    final unreadCount = viewModel.conversations.fold<int>(
      0,
      (total, conversation) => total + conversation.unreadCount,
    );
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final listState = _buildConversationState(
      viewModel: viewModel,
      visible: visible,
      currentUserId: userId,
      compact: !isDesktop,
    );

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Conversas'),
              actions: [
                IconButton(
                  tooltip: 'Atualizar conversas',
                  onPressed: viewModel.listStatus == LoadStatus.loading
                      ? null
                      : () => viewModel.loadConversations(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 4),
              ],
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            if (!isDesktop) {
              return _MobileInbox(
                searchController: _searchController,
                query: _query,
                unreadCount: unreadCount,
                onSearch: (value) => setState(() => _query = value),
                onClearSearch: _clearSearch,
                child: listState,
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1220),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DesktopPageHeader(
                        isLoading: viewModel.listStatus == LoadStatus.loading,
                        onBack: () => Navigator.of(context).maybePop(),
                        onRefresh: () => viewModel.loadConversations(),
                      ),
                      const SizedBox(height: 22),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 292,
                              child: _ConversationGuide(
                                conversationCount:
                                    viewModel.conversations.length,
                                unreadCount: unreadCount,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: _InboxPanel(
                                searchController: _searchController,
                                query: _query,
                                visibleCount: visible.length,
                                totalCount: viewModel.conversations.length,
                                onSearch: (value) =>
                                    setState(() => _query = value),
                                onClearSearch: _clearSearch,
                                child: listState,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DesktopPageHeader extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _DesktopPageHeader({
    required this.isLoading,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.outlined(
          tooltip: 'Voltar',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CENTRAL DE NEGOCIAÇÃO',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 3),
              Text(
                'Conversas',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: isLoading ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 19),
          label: const Text('Atualizar'),
        ),
      ],
    );
  }
}

class _ConversationGuide extends StatelessWidget {
  final int conversationCount;
  final int unreadCount;

  const _ConversationGuide({
    required this.conversationCount,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.mark_unread_chat_alt_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Combine o trabalho com clareza.',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: Colors.white, height: 1.2),
          ),
          const SizedBox(height: 10),
          Text(
            'Use a conversa para alinhar detalhes. A agenda só é reservada depois que uma proposta é aceita.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: .72),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 26),
          const _GuideStep(
            number: '01',
            title: 'Converse',
            description: 'Explique a necessidade e tire dúvidas.',
          ),
          const _GuideStep(
            number: '02',
            title: 'Formalize',
            description: 'Registre data, horário e valor na proposta.',
          ),
          const _GuideStep(
            number: '03',
            title: 'Reserve',
            description: 'A agenda é bloqueada somente após o aceite.',
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _GuideMetric(
                    value: '$conversationCount',
                    label: conversationCount == 1 ? 'conversa' : 'conversas',
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: Colors.white.withValues(alpha: .14),
                ),
                Expanded(
                  child: _GuideMetric(
                    value: '$unreadCount',
                    label: unreadCount == 1 ? 'não lida' : 'não lidas',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _GuideStep({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Colors.white.withValues(alpha: .62)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideMetric extends StatelessWidget {
  final String value;
  final String label;

  const _GuideMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: Colors.white),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: Colors.white60),
        ),
      ],
    );
  }
}

class _InboxPanel extends StatelessWidget {
  final TextEditingController searchController;
  final String query;
  final int visibleCount;
  final int totalCount;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final Widget child;

  const _InboxPanel({
    required this.searchController,
    required this.query,
    required this.visibleCount,
    required this.totalCount,
    required this.onSearch,
    required this.onClearSearch,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mensagens',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        query.isEmpty
                            ? '$totalCount ${totalCount == 1 ? 'negociação' : 'negociações'} em andamento'
                            : '$visibleCount ${visibleCount == 1 ? 'resultado' : 'resultados'} para sua busca',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 310,
                  child: _ConversationSearch(
                    controller: searchController,
                    query: query,
                    onChanged: onSearch,
                    onClear: onClearSearch,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MobileInbox extends StatelessWidget {
  final TextEditingController searchController;
  final String query;
  final int unreadCount;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final Widget child;

  const _MobileInbox({
    required this.searchController,
    required this.query,
    required this.unreadCount,
    required this.onSearch,
    required this.onClearSearch,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.event_available_outlined,
                size: 20,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'O horário só entra na Agenda depois que uma proposta é aceita.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.primaryDark),
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                _UnreadBadge(count: unreadCount),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _ConversationSearch(
            controller: searchController,
            query: query,
            onChanged: onSearch,
            onClear: onClearSearch,
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _ConversationSearch extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _ConversationSearch({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar conversa',
        prefixIcon: const Icon(Icons.search_rounded, size: 21),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpar busca',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final String currentUserId;
  final bool compact;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = conversation.peerName(currentUserId);
    final isProfessionalPeer = currentUserId == conversation.clientId;
    final photo = isProfessionalPeer ? conversation.professionalPhotoUrl : null;
    final hasUnread = conversation.unreadCount > 0;
    final role = isProfessionalPeer ? 'Profissional' : 'Contratante';

    return Semantics(
      button: true,
      label:
          'Abrir conversa com $name${hasUnread ? ', ${conversation.unreadCount} mensagens não lidas' : ''}',
      child: Material(
        color: hasUnread
            ? AppColors.primaryLight.withValues(alpha: .42)
            : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(
            color: hasUnread
                ? AppColors.primary.withValues(alpha: .3)
                : AppColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 16,
              vertical: compact ? 13 : 15,
            ),
            child: Row(
              children: [
                _PeerAvatar(name: name, photoUrl: photo, radius: 25),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: hasUnread
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (conversation.lastMessageAt != null)
                            Text(
                              _relativeTime(conversation.lastMessageAt!),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: hasUnread
                                        ? AppColors.primaryDark
                                        : AppColors.textSecondary,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        role.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.lastMessage ?? 'Conversa aberta. Envie uma mensagem para começar.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: hasUnread
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontWeight: hasUnread
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 10),
                            _UnreadBadge(count: conversation.unreadCount),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 14),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: hasUnread
                          ? AppColors.primary
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 19,
                      color: hasUnread ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;

  const _PeerAvatar({
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
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _relativeTime(DateTime value) {
  final now = DateTime.now();
  final difference = now.difference(value);
  if (difference.inMinutes < 1) return 'agora';
  if (difference.inHours < 1) return '${difference.inMinutes}min';
  if (difference.inDays < 1) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
}
