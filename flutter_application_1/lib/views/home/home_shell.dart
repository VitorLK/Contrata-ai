import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/name_utils.dart';
import '../../models/user_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../applications/my_applications_screen.dart';
import '../admin/admin_console_screen.dart';
import '../dashboard/professional_dashboard_screen.dart';
import '../professionals/my_professional_profile_screen.dart';
import '../professionals/professional_search_screen.dart';
import '../services/services_list_screen.dart';
import '../work/client_work_center_screen.dart';
import '../work/workday_screen.dart';
import '../chat/conversations_screen.dart';

class _MenuItem {
  final String label;
  final String compactLabel;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;

  const _MenuItem({
    required this.label,
    required this.compactLabel,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatViewModel>().refreshUnreadCount();
    });
    _messageTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) context.read<ChatViewModel>().refreshUnreadCount();
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  Future<void> _openConversations() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ConversationsScreen()),
    );
    if (mounted) context.read<ChatViewModel>().refreshUnreadCount();
  }

  List<_MenuItem> _itemsFor(UserRole? role) {
    if (role == UserRole.administrador) {
      return [
        _MenuItem(
          label: 'Central administrativa',
          compactLabel: 'Administração',
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
          builder: (_) => const AdminConsoleScreen(),
        ),
      ];
    }
    if (role == UserRole.cliente) {
      return [
        _MenuItem(
          label: 'Meus serviços',
          compactLabel: 'Serviços',
          icon: Icons.work_outline,
          selectedIcon: Icons.work,
          builder: (_) => const ServicesListScreen(isClientView: true),
        ),
        _MenuItem(
          label: 'Buscar profissionais',
          compactLabel: 'Profissionais',
          icon: Icons.person_search_outlined,
          selectedIcon: Icons.person_search,
          builder: (_) => const ProfessionalSearchScreen(),
        ),
        _MenuItem(
          label: 'Central de trabalho',
          compactLabel: 'Central',
          icon: Icons.notifications_none,
          selectedIcon: Icons.notifications_active,
          builder: (_) => const ClientWorkCenterScreen(),
        ),
      ];
    }
    return [
      _MenuItem(
        label: 'Serviços disponíveis',
        compactLabel: 'Explorar',
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore,
        builder: (_) => const ServicesListScreen(isClientView: false),
      ),
      _MenuItem(
        label: 'Agenda profissional',
        compactLabel: 'Agenda',
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month,
        builder: (_) => const WorkdayScreen(),
      ),
      _MenuItem(
        label: 'Minhas candidaturas',
        compactLabel: 'Candidaturas',
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment,
        builder: (_) => const MyApplicationsScreen(),
      ),
      _MenuItem(
        label: 'Meu perfil',
        compactLabel: 'Perfil',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        builder: (_) => const MyProfessionalProfileScreen(),
      ),
      _MenuItem(
        label: 'Meu desempenho',
        compactLabel: 'Painel',
        icon: Icons.insert_chart_outlined,
        selectedIcon: Icons.insert_chart,
        builder: (_) => const ProfessionalDashboardScreen(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final user = authViewModel.currentUser;
    final isClient = user?.role == UserRole.cliente;
    final isAdmin = user?.role == UserRole.administrador;
    final items = _itemsFor(user?.role);
    final selectedIndex = _selectedIndex.clamp(0, items.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: useRail ? 24 : 16,
            title: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.handyman,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Text('Contrata Aí'),
                if (useRail) ...[
                  const SizedBox(width: AppSpacing.md),
                  Container(width: 1, height: 20, color: AppColors.border),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    items[selectedIndex].label,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
            actions: [
              if (!isAdmin)
                Consumer<ChatViewModel>(
                  builder: (context, chat, _) => IconButton(
                    tooltip: 'Conversas',
                    onPressed: _openConversations,
                    icon: Badge(
                      isLabelVisible: chat.unreadCount > 0,
                      label: Text(
                        chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                      ),
                      child: const Icon(Icons.forum_outlined),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: PopupMenuButton<String>(
                  tooltip: 'Conta',
                  onSelected: (value) {
                    if (value == 'logout') {
                      context.read<AuthViewModel>().logout();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? '',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            isAdmin
                                ? 'Administrador'
                                : isClient
                                ? 'Contratante'
                                : 'Profissional',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.logout),
                        title: Text('Sair da conta'),
                      ),
                    ),
                  ],
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      initialsFor(user?.name ?? ''),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: useRail
              ? Row(
                  children: [
                    NavigationRail(
                      extended: constraints.maxWidth >= 1120,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (index) =>
                          setState(() => _selectedIndex = index),
                      backgroundColor: AppColors.surface,
                      indicatorColor: AppColors.primaryLight,
                      labelType: constraints.maxWidth >= 1120
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      destinations: [
                        for (final item in items)
                          NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selectedIcon),
                            label: Text(item.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: items[selectedIndex].builder(context)),
                  ],
                )
              : items[selectedIndex].builder(context),
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  destinations: [
                    for (final item in items)
                      NavigationDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: item.compactLabel,
                      ),
                  ],
                ),
        );
      },
    );
  }
}
