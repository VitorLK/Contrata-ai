import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/admin_models.dart';
import '../../viewmodels/admin_viewmodel.dart';

enum _AdminSection { overview, users, companies, services }

class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  _AdminSection _section = _AdminSection.overview;
  String _userQuery = '';
  String _userRole = 'todos';
  String _companyQuery = '';
  String _companyStatus = 'todas';
  String _serviceQuery = '';
  String _serviceStatus = 'todos';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminViewModel>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminViewModel>();
    if (viewModel.status == AdminLoadStatus.loading &&
        viewModel.overview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.status == AdminLoadStatus.error &&
        viewModel.overview == null) {
      return _AdminError(
        message:
            viewModel.errorMessage ?? 'Não foi possível carregar o painel.',
        onRetry: () => viewModel.loadAll(force: true),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          48,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CommandHeader(overview: viewModel.overview),
                  const SizedBox(height: AppSpacing.md),
                  _SectionNavigation(
                    selected: _section,
                    onSelected: (section) => setState(() => _section = section),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey(_section),
                      child: _buildSection(viewModel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(AdminViewModel viewModel) {
    return switch (_section) {
      _AdminSection.overview => _OverviewSection(overview: viewModel.overview),
      _AdminSection.users => _buildUsers(viewModel),
      _AdminSection.companies => _buildCompanies(viewModel),
      _AdminSection.services => _buildServices(viewModel),
    };
  }

  Widget _buildUsers(AdminViewModel viewModel) {
    final normalizedQuery = _userQuery.trim().toLowerCase();
    final users = viewModel.users.where((user) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          user.name.toLowerCase().contains(normalizedQuery) ||
          user.email.toLowerCase().contains(normalizedQuery);
      final matchesRole = _userRole == 'todos' || user.role == _userRole;
      return matchesQuery && matchesRole;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(
          eyebrow: 'PESSOAS E ACESSOS',
          title: 'Quem movimenta a plataforma',
          subtitle: 'Consulte perfis, ajuste dados essenciais e interrompa acessos sem perder o histórico operacional.',
          countLabel: '${users.length} de ${viewModel.users.length}',
        ),
        const SizedBox(height: AppSpacing.md),
        _FilterBar(
          searchHint: 'Buscar por nome ou e-mail',
          onSearch: (value) => setState(() => _userQuery = value),
          filterValue: _userRole,
          filterItems: const {
            'todos': 'Todos os perfis',
            'cliente': 'Contratantes',
            'profissional': 'Profissionais',
          },
          onFilter: (value) => setState(() => _userRole = value ?? 'todos'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (users.isEmpty)
          const _EmptyAdminState(
            icon: Icons.person_search_outlined,
            title: 'Nenhum usuário encontrado',
            message: 'Ajuste a busca ou o filtro de perfil.',
          )
        else
          ...users.map(
            (user) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _UserCard(
                user: user,
                onEdit: () => _showUserDialog(viewModel, user),
                onDelete: () => _confirmDeleteUser(viewModel, user),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompanies(AdminViewModel viewModel) {
    final normalizedQuery = _companyQuery.trim().toLowerCase();
    final companies = viewModel.companies.where((company) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          company.displayName.toLowerCase().contains(normalizedQuery) ||
          company.legalName.toLowerCase().contains(normalizedQuery) ||
          company.document.contains(
            normalizedQuery.replaceAll(RegExp(r'\D'), ''),
          );
      final matchesStatus =
          _companyStatus == 'todas' || company.status == _companyStatus;
      return matchesQuery && matchesStatus;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(
          eyebrow: 'ORGANIZAÇÕES',
          title: 'Empresas verificáveis, responsáveis visíveis',
          subtitle: 'Mantenha CNPJ, contato, localização e responsável vinculados em um único registro.',
          countLabel: '${companies.length} empresas',
          action: FilledButton.icon(
            onPressed: () => _showCompanyDialog(viewModel),
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Cadastrar empresa'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _FilterBar(
          searchHint: 'Buscar empresa ou CNPJ',
          onSearch: (value) => setState(() => _companyQuery = value),
          filterValue: _companyStatus,
          filterItems: const {
            'todas': 'Todas as situações',
            'ativa': 'Ativas',
            'suspensa': 'Suspensas',
          },
          onFilter: (value) =>
              setState(() => _companyStatus = value ?? 'todas'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (companies.isEmpty)
          _EmptyAdminState(
            icon: Icons.apartment_outlined,
            title: 'Nenhuma empresa encontrada',
            message: 'Cadastre a primeira organização ou ajuste os filtros.',
            actionLabel: 'Cadastrar empresa',
            onAction: () => _showCompanyDialog(viewModel),
          )
        else
          ...companies.map(
            (company) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CompanyCard(
                company: company,
                onEdit: () => _showCompanyDialog(viewModel, company: company),
                onDelete: () => _confirmDeleteCompany(viewModel, company),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildServices(AdminViewModel viewModel) {
    final normalizedQuery = _serviceQuery.trim().toLowerCase();
    final services = viewModel.services.where((service) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          service.title.toLowerCase().contains(normalizedQuery) ||
          service.clientName.toLowerCase().contains(normalizedQuery);
      final matchesStatus =
          _serviceStatus == 'todos' || service.status == _serviceStatus;
      return matchesQuery && matchesStatus;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(
          eyebrow: 'REGISTROS CRÍTICOS',
          title: 'Serviços sob supervisão',
          subtitle: 'Corrija data, orçamento e situação com justificativa obrigatória. Cada mudança entra na auditoria.',
          countLabel: '${services.length} registros',
        ),
        const SizedBox(height: AppSpacing.md),
        _FilterBar(
          searchHint: 'Buscar serviço ou contratante',
          onSearch: (value) => setState(() => _serviceQuery = value),
          filterValue: _serviceStatus,
          filterItems: const {
            'todos': 'Todos os status',
            'aberto': 'Abertos',
            'agendado': 'Agendados',
            'em_andamento': 'Em andamento',
            'concluido': 'Concluídos',
            'cancelado': 'Cancelados',
          },
          onFilter: (value) =>
              setState(() => _serviceStatus = value ?? 'todos'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (services.isEmpty)
          const _EmptyAdminState(
            icon: Icons.manage_search_outlined,
            title: 'Nenhum registro encontrado',
            message: 'Ajuste a busca ou o filtro de situação.',
          )
        else
          ...services.map(
            (service) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ServiceRecordCard(
                service: service,
                onEdit: () => _showServiceDialog(viewModel, service),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showUserDialog(AdminViewModel viewModel, AdminUser user) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    final phoneController = TextEditingController(text: user.phone ?? '');
    var role = user.role;
    var isActive = user.isActive;
    var saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar acesso e cadastro'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 3
                          ? 'Informe pelo menos 3 caracteres.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value?.trim() ?? '')
                          ? 'Informe um e-mail válido.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Telefone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(
                        labelText: 'Perfil de acesso',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'cliente',
                          child: Text('Contratante'),
                        ),
                        DropdownMenuItem(
                          value: 'profissional',
                          child: Text('Profissional'),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => role = value ?? role),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Conta ativa'),
                      subtitle: Text(
                        isActive
                            ? 'O usuário pode entrar e usar a plataforma.'
                            : 'O acesso fica bloqueado até a reativação.',
                      ),
                      value: isActive,
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => saving = true);
                      final success = await viewModel.updateUser(user.id, {
                        'name': nameController.text.trim(),
                        'email': emailController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'role': role,
                        'is_active': isActive,
                      });
                      if (!dialogContext.mounted) return;
                      if (success) Navigator.pop(dialogContext);
                      if (mounted) _showActionFeedback(viewModel, success);
                      if (dialogContext.mounted) {
                        setDialogState(() => saving = false);
                      }
                    },
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Salvar alterações'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
  }

  Future<void> _confirmDeleteUser(
    AdminViewModel viewModel,
    AdminUser user,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.person_remove_outlined, color: AppColors.error),
        title: const Text('Excluir este usuário?'),
        content: Text(
          '${user.name} perderá o acesso. Se houver serviços, candidaturas ou pagamentos vinculados, a conta será desativada e o histórico será preservado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Manter usuário'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir acesso'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await viewModel.deleteUser(user.id);
    if (mounted) _showActionFeedback(viewModel, success);
  }

  Future<void> _showCompanyDialog(
    AdminViewModel viewModel, {
    AdminCompany? company,
  }) async {
    final formKey = GlobalKey<FormState>();
    final legalName = TextEditingController(text: company?.legalName ?? '');
    final tradeName = TextEditingController(text: company?.tradeName ?? '');
    final document = TextEditingController(text: company?.document ?? '');
    final email = TextEditingController(text: company?.email ?? '');
    final phone = TextEditingController(text: company?.phone ?? '');
    final city = TextEditingController(text: company?.city ?? '');
    final state = TextEditingController(text: company?.state ?? '');
    var status = company?.status ?? 'ativa';
    String? ownerId = company?.ownerUserId;
    var saving = false;
    final clients = viewModel.users
        .where((user) => user.role == 'cliente' && user.isActive)
        .toList();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(company == null ? 'Cadastrar empresa' : 'Editar empresa'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: legalName,
                      decoration: const InputDecoration(
                        labelText: 'Razão social',
                        prefixIcon: Icon(Icons.apartment_outlined),
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 3
                          ? 'Informe a razão social.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: tradeName,
                      decoration: const InputDecoration(
                        labelText: 'Nome fantasia',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: document,
                      decoration: const InputDecoration(
                        labelText: 'CNPJ',
                        hintText: 'Somente 14 dígitos',
                        prefixIcon: Icon(Icons.domain_verification_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          (value ?? '').replaceAll(RegExp(r'\D'), '').length !=
                              14
                          ? 'Informe os 14 dígitos do CNPJ.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: ownerId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Responsável na plataforma',
                        prefixIcon: Icon(Icons.person_pin_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Sem responsável vinculado'),
                        ),
                        ...clients.map(
                          (user) => DropdownMenuItem<String?>(
                            value: user.id,
                            child: Text('${user.name} · ${user.email}'),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => ownerId = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: email,
                      decoration: const InputDecoration(
                        labelText: 'E-mail corporativo',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: city,
                            decoration: const InputDecoration(
                              labelText: 'Cidade',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: state,
                            decoration: const InputDecoration(labelText: 'UF'),
                            maxLength: 2,
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Situação',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ativa', child: Text('Ativa')),
                        DropdownMenuItem(
                          value: 'suspensa',
                          child: Text('Suspensa'),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => status = value ?? status),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => saving = true);
                      final success = await viewModel.saveCompany(
                        id: company?.id,
                        values: {
                          'legal_name': legalName.text.trim(),
                          'trade_name': tradeName.text.trim(),
                          'document': document.text.trim(),
                          'owner_user_id': ownerId,
                          'email': email.text.trim(),
                          'phone': phone.text.trim(),
                          'city': city.text.trim(),
                          'state': state.text.trim(),
                          'status': status,
                        },
                      );
                      if (!dialogContext.mounted) return;
                      if (success) Navigator.pop(dialogContext);
                      if (mounted) _showActionFeedback(viewModel, success);
                      if (dialogContext.mounted) {
                        setDialogState(() => saving = false);
                      }
                    },
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(company == null ? 'Cadastrar' : 'Salvar alterações'),
            ),
          ],
        ),
      ),
    );

    legalName.dispose();
    tradeName.dispose();
    document.dispose();
    email.dispose();
    phone.dispose();
    city.dispose();
    state.dispose();
  }

  Future<void> _confirmDeleteCompany(
    AdminViewModel viewModel,
    AdminCompany company,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.domain_disabled_outlined,
          color: AppColors.error,
        ),
        title: const Text('Excluir esta empresa?'),
        content: Text(
          'O registro de ${company.displayName} será excluído. A conta do responsável e seus serviços não serão apagados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir empresa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await viewModel.deleteCompany(company.id);
    if (mounted) _showActionFeedback(viewModel, success);
  }

  Future<void> _showServiceDialog(
    AdminViewModel viewModel,
    AdminServiceRecord service,
  ) async {
    final formKey = GlobalKey<FormState>();
    final budget = TextEditingController(
      text: service.budget?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
    );
    final date = TextEditingController(text: _apiDate(service.scheduledDate));
    final reason = TextEditingController();
    var status = service.status;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajustar registro de serviço'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Contratante: ${service.clientName}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Status do serviço',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'aberto',
                          child: Text('Aberto'),
                        ),
                        DropdownMenuItem(
                          value: 'agendado',
                          child: Text('Agendado'),
                        ),
                        DropdownMenuItem(
                          value: 'em_andamento',
                          child: Text('Em andamento'),
                        ),
                        DropdownMenuItem(
                          value: 'concluido',
                          child: Text('Concluído'),
                        ),
                        DropdownMenuItem(
                          value: 'cancelado',
                          child: Text('Cancelado'),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => status = value ?? status),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: budget,
                      decoration: const InputDecoration(
                        labelText: 'Orçamento',
                        prefixText: 'R\$ ',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) return null;
                        final parsed = double.tryParse(
                          value!.replaceAll(',', '.'),
                        );
                        return parsed == null || parsed <= 0
                            ? 'Informe um valor maior que zero.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: date,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Data agendada',
                        prefixIcon: const Icon(Icons.event_outlined),
                        suffixIcon: IconButton(
                          tooltip: 'Escolher data',
                          onPressed: () async {
                            final selected = await showDatePicker(
                              context: dialogContext,
                              initialDate: service.scheduledDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (selected != null) {
                              date.text = _apiDate(selected);
                            }
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reason,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Motivo da alteração',
                        hintText: 'Ex.: Correção solicitada pelo contratante',
                        prefixIcon: Icon(Icons.fact_check_outlined),
                        helperText:
                            'A justificativa ficará registrada na auditoria.',
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 8
                          ? 'Explique o motivo em pelo menos 8 caracteres.'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => saving = true);
                      final parsedBudget = budget.text.trim().isEmpty
                          ? null
                          : double.tryParse(budget.text.replaceAll(',', '.'));
                      final success = await viewModel.updateService(
                        service.id,
                        {
                          'status': status,
                          'budget': parsedBudget,
                          'scheduled_date': date.text,
                          'reason': reason.text.trim(),
                        },
                      );
                      if (!dialogContext.mounted) return;
                      if (success) Navigator.pop(dialogContext);
                      if (mounted) _showActionFeedback(viewModel, success);
                      if (dialogContext.mounted) {
                        setDialogState(() => saving = false);
                      }
                    },
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined),
              label: const Text('Salvar com auditoria'),
            ),
          ],
        ),
      ),
    );

    budget.dispose();
    date.dispose();
    reason.dispose();
  }

  void _showActionFeedback(AdminViewModel viewModel, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? viewModel.actionMessage ?? 'Alteração concluída.'
              : viewModel.errorMessage ?? 'Não foi possível concluir a ação.',
        ),
        backgroundColor: success ? AppColors.textPrimary : AppColors.error,
      ),
    );
  }
}

class _CommandHeader extends StatelessWidget {
  final AdminOverview? overview;

  const _CommandHeader({required this.overview});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final introduction = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'OPERAÇÃO / ADMIN',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: .76),
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Central de comando',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontSize: compact ? 25 : 30,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pessoas, empresas e serviços em uma leitura operacional única.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Colors.white.withValues(alpha: .74)),
              ),
            ],
          );
          final pulse = Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .14)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monitor_heart_outlined,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${overview?.activeUsers ?? 0} acessos ativos',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: Colors.white),
                    ),
                    Text(
                      '${overview?.inProgressServices ?? 0} serviços em andamento',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: .68),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [introduction, const SizedBox(height: 18), pulse],
            );
          }
          return Row(
            children: [
              Expanded(child: introduction),
              const SizedBox(width: 24),
              pulse,
            ],
          );
        },
      ),
    );
  }
}

class _SectionNavigation extends StatelessWidget {
  final _AdminSection selected;
  final ValueChanged<_AdminSection> onSelected;

  const _SectionNavigation({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const items = [
      (_AdminSection.overview, Icons.space_dashboard_outlined, 'Visão geral'),
      (_AdminSection.users, Icons.groups_outlined, 'Pessoas'),
      (_AdminSection.companies, Icons.apartment_outlined, 'Empresas'),
      (_AdminSection.services, Icons.fact_check_outlined, 'Serviços'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            _SectionButton(
              icon: item.$2,
              label: item.$3,
              selected: selected == item.$1,
              onTap: () => onSelected(item.$1),
            ),
            if (item != items.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SectionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  final AdminOverview? overview;

  const _OverviewSection({required this.overview});

  @override
  Widget build(BuildContext context) {
    final data = overview;
    if (data == null) return const SizedBox.shrink();
    final metrics = [
      _MetricData(
        icon: Icons.groups_2_outlined,
        value: data.totalUsers.toString(),
        label: 'Usuários cadastrados',
        detail: '+${data.newUsers30d} nos últimos 30 dias',
        color: AppColors.primary,
      ),
      _MetricData(
        icon: Icons.engineering_outlined,
        value: data.professionals.toString(),
        label: 'Trabalhadores',
        detail: '${data.clients} contratantes',
        color: AppColors.secondary,
      ),
      _MetricData(
        icon: Icons.apartment_outlined,
        value: data.totalCompanies.toString(),
        label: 'Empresas',
        detail: '${data.activeCompanies} em operação',
        color: AppColors.accent,
      ),
      _MetricData(
        icon: Icons.task_alt_outlined,
        value: data.completedServices.toString(),
        label: 'Serviços executados',
        detail: '${data.completionRate.toStringAsFixed(0)}% de conclusão',
        color: AppColors.success,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(
          eyebrow: 'LEITURA DA PLATAFORMA',
          title: 'O que está acontecendo agora',
          subtitle: 'Indicadores reais para acompanhar crescimento, execução e saúde da operação.',
          countLabel: 'Atualizado agora',
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            const gap = 12.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: metrics
                  .map(
                    (metric) => SizedBox(
                      width: width,
                      child: _MetricCard(data: metric),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _OperationLedger(overview: data),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final chart = _PulseChart(points: data.monthly);
            final distribution = _ServiceDistribution(overview: data);
            if (constraints.maxWidth < 820) {
              return Column(
                children: [
                  chart,
                  const SizedBox(height: AppSpacing.md),
                  distribution,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: chart),
                const SizedBox(width: AppSpacing.md),
                Expanded(flex: 2, child: distribution),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _ActivityFeed(items: data.recentActivity),
      ],
    );
  }
}

class _OperationLedger extends StatelessWidget {
  final AdminOverview overview;

  const _OperationLedger({required this.overview});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 14,
        children: [
          _LedgerItem(
            label: 'Volume confirmado',
            value: _currency(overview.transactedAmount),
          ),
          _LedgerItem(
            label: 'Horas registradas',
            value: _duration(overview.workedMinutes),
          ),
          _LedgerItem(
            label: 'Jornadas confirmadas',
            value: overview.completedSessions.toString(),
          ),
          _LedgerItem(
            label: 'Serviços publicados',
            value: overview.totalServices.toString(),
          ),
        ],
      ),
    );
  }
}

class _LedgerItem extends StatelessWidget {
  final String label;
  final String value;

  const _LedgerItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _MetricData {
  final IconData icon;
  final String value;
  final String label;
  final String detail;
  final Color color;

  const _MetricData({
    required this.icon,
    required this.value,
    required this.label,
    required this.detail,
    required this.color,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;

  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 21),
          ),
          const SizedBox(height: 18),
          Text(
            data.value,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontSize: 29),
          ),
          const SizedBox(height: 3),
          Text(data.label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(data.detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PulseChart extends StatelessWidget {
  final List<AdminMonthlyPoint> points;

  const _PulseChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<int>(1, (current, point) {
      return math.max(
        current,
        math.max(point.newUsers, point.completedServices),
      );
    });
    return _Panel(
      title: 'Pulso da operação',
      subtitle: 'Cadastros e entregas confirmadas nos últimos seis meses',
      trailing: const Wrap(
        spacing: 12,
        children: [
          _ChartLegend(color: AppColors.primary, label: 'Cadastros'),
          _ChartLegend(color: AppColors.accent, label: 'Entregas'),
        ],
      ),
      child: SizedBox(
        height: 190,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final point in points)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _ChartBar(
                                heightFactor: point.newUsers / maxValue,
                                color: AppColors.primary,
                                value: point.newUsers,
                              ),
                              const SizedBox(width: 4),
                              _ChartBar(
                                heightFactor:
                                    point.completedServices / maxValue,
                                color: AppColors.accent,
                                value: point.completedServices,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _monthLabel(point.month),
                        style: Theme.of(context).textTheme.labelSmall,
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

class _ChartBar extends StatelessWidget {
  final double heightFactor;
  final Color color;
  final int value;

  const _ChartBar({
    required this.heightFactor,
    required this.color,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: value.toString(),
      child: Container(
        width: 12,
        height: math.max(5, 125 * heightFactor),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ServiceDistribution extends StatelessWidget {
  final AdminOverview overview;

  const _ServiceDistribution({required this.overview});

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, overview.totalServices);
    final rows = [
      ('Abertos', overview.openServices, AppColors.secondary),
      ('Em andamento', overview.inProgressServices, AppColors.warning),
      ('Concluídos', overview.completedServices, AppColors.success),
      ('Cancelados', overview.cancelledServices, AppColors.error),
    ];
    return _Panel(
      title: 'Carteira de serviços',
      subtitle: '${overview.totalServices} registros na plataforma',
      child: Column(
        children: [
          for (final row in rows) ...[
            _DistributionRow(
              label: row.$1,
              value: row.$2,
              fraction: row.$2 / total,
              color: row.$3,
            ),
            if (row != rows.last) const SizedBox(height: 15),
          ],
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  final String label;
  final int value;
  final double fraction;
  final Color color;

  const _DistributionRow({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 7,
            color: color,
            backgroundColor: AppColors.border.withValues(alpha: .55),
          ),
        ),
      ],
    );
  }
}

class _ActivityFeed extends StatelessWidget {
  final List<AdminActivity> items;

  const _ActivityFeed({required this.items});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Rastro recente',
      subtitle: 'Cadastros, publicações e decisões administrativas',
      child: items.isEmpty
          ? const Text(
              'A atividade aparecerá aqui conforme a plataforma for utilizada.',
            )
          : Column(
              children: [
                for (var index = 0; index < items.length; index++)
                  _ActivityRow(
                    item: items[index],
                    isLast: index == items.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final AdminActivity item;
  final bool isLast;

  const _ActivityRow({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.kind) {
      'usuario' => Icons.person_add_alt_1_outlined,
      'empresa' => Icons.add_business_outlined,
      'servico' => Icons.work_outline,
      _ => Icons.policy_outlined,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: AppColors.primaryDark),
            ),
            if (!isLast)
              Container(width: 1, height: 28, color: AppColors.border),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${_humanize(item.detail)} · ${_relativeTime(item.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget child;

  const _Panel({
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final String countLabel;
  final Widget? action;

  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.countLabel,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eyebrow, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 5),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
        );
        final right = Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                countLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            ?action,
          ],
        );
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 14), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: text),
            const SizedBox(width: 20),
            right,
          ],
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String searchHint;
  final ValueChanged<String> onSearch;
  final String filterValue;
  final Map<String, String> filterItems;
  final ValueChanged<String?> onFilter;

  const _FilterBar({
    required this.searchHint,
    required this.onSearch,
    required this.filterValue,
    required this.filterItems,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: searchHint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
          );
          final filter = DropdownButtonFormField<String>(
            initialValue: filterValue,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.tune),
              isDense: true,
            ),
            items: filterItems.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: onFilter,
          );
          if (constraints.maxWidth < 620) {
            return Column(
              children: [search, const SizedBox(height: 10), filter],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 10),
              SizedBox(width: 230, child: filter),
            ],
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final roleLabel = user.role == 'profissional'
        ? 'Profissional'
        : 'Contratante';
    final location = [
      user.city,
      user.state,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return _EntityCard(
      leading: _EntityAvatar(
        icon: user.role == 'profissional'
            ? Icons.engineering_outlined
            : Icons.person_outline,
        color: user.role == 'profissional'
            ? AppColors.secondary
            : AppColors.primary,
      ),
      title: user.name,
      subtitle: user.email,
      badges: [
        _Badge(
          label: roleLabel,
          color: user.role == 'profissional'
              ? AppColors.secondary
              : AppColors.primary,
        ),
        _Badge(
          label: user.isActive ? 'Ativo' : 'Inativo',
          color: user.isActive ? AppColors.success : AppColors.error,
        ),
      ],
      details: [
        _Detail(
          icon: Icons.work_outline,
          text: '${user.serviceCount} serviços vinculados',
        ),
        if (user.role == 'profissional')
          _Detail(
            icon: Icons.task_alt_outlined,
            text: '${user.completedCount} concluídos',
          ),
        if (location.isNotEmpty)
          _Detail(icon: Icons.place_outlined, text: location),
        if (user.companyName?.isNotEmpty == true)
          _Detail(icon: Icons.apartment_outlined, text: user.companyName!),
        _Detail(
          icon: Icons.event_outlined,
          text: 'Desde ${_formatDate(user.createdAt)}',
        ),
      ],
      actions: [
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Editar'),
        ),
        TextButton.icon(
          onPressed: onDelete,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          icon: const Icon(Icons.person_remove_outlined, size: 18),
          label: const Text('Excluir'),
        ),
      ],
    );
  }
}

class _CompanyCard extends StatelessWidget {
  final AdminCompany company;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CompanyCard({
    required this.company,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final location = [
      company.city,
      company.state,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return _EntityCard(
      leading: _EntityAvatar(
        icon: Icons.apartment_outlined,
        color: AppColors.accent,
      ),
      title: company.displayName,
      subtitle: company.tradeName?.isNotEmpty == true
          ? company.legalName
          : _formatCnpj(company.document),
      badges: [
        _Badge(
          label: company.status == 'ativa' ? 'Ativa' : 'Suspensa',
          color: company.status == 'ativa'
              ? AppColors.success
              : AppColors.error,
        ),
        _Badge(
          label: _formatCnpj(company.document),
          color: AppColors.secondary,
        ),
      ],
      details: [
        _Detail(
          icon: Icons.person_pin_outlined,
          text: company.ownerName ?? 'Sem responsável vinculado',
        ),
        _Detail(
          icon: Icons.work_outline,
          text: '${company.serviceCount} serviços publicados',
        ),
        if (location.isNotEmpty)
          _Detail(icon: Icons.place_outlined, text: location),
        if (company.email?.isNotEmpty == true)
          _Detail(icon: Icons.mail_outline, text: company.email!),
      ],
      actions: [
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Editar'),
        ),
        TextButton.icon(
          onPressed: onDelete,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Excluir'),
        ),
      ],
    );
  }
}

class _ServiceRecordCard extends StatelessWidget {
  final AdminServiceRecord service;
  final VoidCallback onEdit;

  const _ServiceRecordCard({required this.service, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final location = [
      service.city,
      service.state,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return _EntityCard(
      leading: _EntityAvatar(
        icon: Icons.handyman_outlined,
        color: _statusColor(service.status),
      ),
      title: service.title,
      subtitle:
          '${service.clientName} · ${service.category ?? 'Sem categoria'}',
      badges: [
        _Badge(
          label: _statusLabel(service.status),
          color: _statusColor(service.status),
        ),
        if (service.workStatus != null)
          _Badge(
            label: _humanize(service.workStatus!),
            color: AppColors.primary,
          ),
      ],
      details: [
        _Detail(
          icon: Icons.event_outlined,
          text: _formatDate(service.scheduledDate),
        ),
        _Detail(
          icon: Icons.payments_outlined,
          text: service.budget == null
              ? 'Valor não informado'
              : _currency(service.budget!),
        ),
        if (location.isNotEmpty)
          _Detail(icon: Icons.place_outlined, text: location),
        _Detail(
          icon: Icons.engineering_outlined,
          text: service.professionalName ?? 'Profissional ainda não definido',
        ),
      ],
      actions: [
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Ajustar registro'),
        ),
      ],
    );
  }
}

class _EntityCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final List<Widget> badges;
  final List<Widget> details;
  final List<Widget> actions;

  const _EntityCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.badges,
    required this.details,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 9),
                    Wrap(spacing: 6, runSpacing: 6, children: badges),
                  ],
                ),
              ),
            ],
          );
          final detailWrap = Wrap(
            spacing: 18,
            runSpacing: 9,
            children: details,
          );
          final actionWrap = Wrap(spacing: 8, runSpacing: 8, children: actions);
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 14),
                detailWrap,
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerLeft, child: actionWrap),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 300, child: identity),
              const SizedBox(width: 18),
              Expanded(child: detailWrap),
              const SizedBox(width: 18),
              actionWrap,
            ],
          );
        },
      ),
    );
  }
}

class _EntityAvatar extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _EntityAvatar({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Detail({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EmptyAdminState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyAdminState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppColors.textDisabled),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _AdminError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AdminError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _apiDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _currency(double value) =>
    'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

String _duration(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return '${hours}h ${remainder.toString().padLeft(2, '0')}min';
}

String _monthLabel(String value) {
  const labels = [
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
  final month = int.tryParse(value.split('-').last) ?? 1;
  return labels[(month - 1).clamp(0, 11)];
}

String _relativeTime(DateTime date) {
  final difference = DateTime.now().difference(date.toLocal());
  if (difference.inMinutes < 1) return 'agora';
  if (difference.inHours < 1) return 'há ${difference.inMinutes} min';
  if (difference.inDays < 1) return 'há ${difference.inHours} h';
  if (difference.inDays < 7) return 'há ${difference.inDays} dias';
  return _formatDate(date.toLocal());
}

String _formatCnpj(String digits) {
  final value = digits.replaceAll(RegExp(r'\D'), '');
  if (value.length != 14) return digits;
  return '${value.substring(0, 2)}.${value.substring(2, 5)}.${value.substring(5, 8)}/${value.substring(8, 12)}-${value.substring(12)}';
}

String _humanize(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

String _statusLabel(String status) => switch (status) {
  'aberto' => 'Aberto',
  'agendado' => 'Agendado',
  'em_andamento' => 'Em andamento',
  'concluido' => 'Concluído',
  'cancelado' => 'Cancelado',
  _ => _humanize(status),
};

Color _statusColor(String status) => switch (status) {
  'aberto' => AppColors.secondary,
  'agendado' => AppColors.primary,
  'em_andamento' => AppColors.warning,
  'concluido' => AppColors.success,
  'cancelado' => AppColors.error,
  _ => AppColors.textSecondary,
};
