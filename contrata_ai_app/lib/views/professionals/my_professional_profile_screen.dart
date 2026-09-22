import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/professional_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../models/professional_profile_model.dart';
import '../../models/availability_model.dart';
import '../../services/professional_repository.dart' show inferImageContentType;
import '../../viewmodels/professional_profile_viewmodel.dart';
import '../../viewmodels/services_list_viewmodel.dart' show LoadStatus;
import '../../widgets/app_text_field.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/location_selector.dart';
import '../../widgets/photo_picker_avatar.dart';
import '../../widgets/portfolio_grid.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/profile_completion_bar.dart';
import '../../widgets/section_card.dart';
import '../../widgets/weekly_availability_editor.dart';
import 'professional_public_profile_screen.dart';

class MyProfessionalProfileScreen extends StatefulWidget {
  const MyProfessionalProfileScreen({super.key});

  @override
  State<MyProfessionalProfileScreen> createState() =>
      _MyProfessionalProfileScreenState();
}

class _MyProfessionalProfileScreenState
    extends State<MyProfessionalProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _projectRateController = TextEditingController();
  final _experienceController = TextEditingController();
  final _phoneController = TextEditingController();
  final _skillInputController = TextEditingController();
  final _imagePicker = ImagePicker();

  List<String> _skills = [];
  ServiceMode? _serviceMode;
  PricingType _pricingType = PricingType.porHora;
  String? _state;
  String? _city;
  ProfessionalAvailabilityModel _availabilitySchedule =
      const ProfessionalAvailabilityModel();
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => context.read<ProfessionalProfileViewModel>().load();

  @override
  void dispose() {
    _bioController.dispose();
    _hourlyRateController.dispose();
    _projectRateController.dispose();
    _experienceController.dispose();
    _phoneController.dispose();
    _skillInputController.dispose();
    super.dispose();
  }

  void _populateControllers(ProfessionalProfileModel profile) {
    _bioController.text = profile.bio ?? '';
    _hourlyRateController.text = profile.hourlyRate?.toStringAsFixed(2) ?? '';
    _projectRateController.text = profile.projectRate?.toStringAsFixed(2) ?? '';
    _experienceController.text = profile.experience ?? '';
    _phoneController.text = profile.phone ?? '';
    _skills = List<String>.from(profile.skills);
    _serviceMode = profile.serviceMode;
    _pricingType = profile.pricingType;
    _state = profile.state;
    _city = profile.city;
    _availabilitySchedule = profile.availabilitySchedule.slots.isEmpty &&
            (profile.availability?.isNotEmpty ?? false)
        ? const ProfessionalAvailabilityModel(variableHours: true)
        : profile.availabilitySchedule;
  }

  void _toggleSkill(String skill, bool selected) {
    if (selected && _skills.length >= ProfessionalCatalog.maxSkills) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha no máximo 6 áreas principais.')),
      );
      return;
    }
    setState(() => selected ? _skills.add(skill) : _skills.remove(skill));
  }

  void _addCustomSkill() {
    final value = _skillInputController.text.trim();
    if (value.isEmpty ||
        _skills.any((skill) => skill.toLowerCase() == value.toLowerCase())) {
      return;
    }
    if (_skills.length >= ProfessionalCatalog.maxSkills) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remova uma área antes de adicionar outra.'),
        ),
      );
      return;
    }
    setState(() {
      _skills.add(value);
      _skillInputController.clear();
    });
  }

  Future<void> _save() async {
    final formIsValid = _formKey.currentState?.validate() ?? false;
    if (!formIsValid) {
      return;
    }
    if (_skills.isEmpty) {
      return _validationMessage('Escolha pelo menos uma área de atuação.');
    }
    if (_state == null || _city == null) {
      return _validationMessage('Selecione seu estado e sua cidade.');
    }
    if (_serviceMode == null) {
      return _validationMessage('Informe como você realiza os atendimentos.');
    }
    if (!_availabilitySchedule.variableHours &&
        _availabilitySchedule.slots.isEmpty) {
      return _validationMessage(
        'Escolha ao menos um período ou marque que seus horários variam.',
      );
    }

    final hourlyRateText = _hourlyRateController.text.trim().replaceAll(
      ',',
      '.',
    );
    final hourlyRate = hourlyRateText.isEmpty
        ? null
        : double.tryParse(hourlyRateText);
    final projectRateText = _projectRateController.text.trim().replaceAll(
      ',',
      '.',
    );
    final projectRate = projectRateText.isEmpty
        ? null
        : double.tryParse(projectRateText);
    if (_pricingType == PricingType.porHora &&
        (hourlyRate == null || hourlyRate <= 0)) {
      return _validationMessage('Informe um valor por hora maior que zero.');
    }
    if (_pricingType == PricingType.empreitada &&
        (projectRate == null || projectRate <= 0)) {
      return _validationMessage(
        'Informe um valor de empreitada maior que zero.',
      );
    }

    try {
      await context.read<ProfessionalProfileViewModel>().save(
        bio: _bioController.text.trim(),
        skills: _skills,
        hourlyRate: _pricingType == PricingType.porHora ? hourlyRate : null,
        pricingType: _pricingType,
        projectRate: _pricingType == PricingType.empreitada
            ? projectRate
            : null,
        experience: _experienceController.text.trim(),
        city: _city!,
        state: _state!,
        serviceMode: _serviceMode,
        availability: _availabilitySchedule.variableHours
            ? 'Somente com agendamento'
            : 'Agenda nesta semana',
        availabilitySchedule: _availabilitySchedule,
        phone: _phoneController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Alterações salvas. Seu perfil público já foi atualizado.',
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

  void _validationMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAndUploadPhoto() async {
    final viewModel = context.read<ProfessionalProfileViewModel>();
    final xfile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xfile == null) return;
    try {
      await viewModel.uploadPhoto(
        bytes: await xfile.readAsBytes(),
        filename: xfile.name,
        contentType: xfile.mimeType ?? inferImageContentType(xfile.name),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Foto atualizada.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível enviar a foto: $error')),
      );
    }
  }

  Future<void> _pickAndAddPortfolioItem() async {
    final viewModel = context.read<ProfessionalProfileViewModel>();
    final xfile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xfile == null) return;
    try {
      await viewModel.addPortfolioItem(
        bytes: await xfile.readAsBytes(),
        filename: xfile.name,
        contentType: xfile.mimeType ?? inferImageContentType(xfile.name),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível adicionar ao portfólio: $error'),
        ),
      );
    }
  }

  Future<void> _deletePortfolioItem(PortfolioItemModel item) async {
    try {
      await context.read<ProfessionalProfileViewModel>().deletePortfolioItem(
        item.id,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível remover a imagem: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProfessionalProfileViewModel>();
    final profile = viewModel.profile;

    if (profile == null && viewModel.status == LoadStatus.error) {
      return SafeArea(
        child: ErrorStateView(message: viewModel.errorMessage, onRetry: _load),
      );
    }
    if (profile == null) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    if (!_controllersInitialized) {
      _populateControllers(profile);
      _controllersInitialized = true;
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          48,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sua vitrine profissional',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Mostre com clareza o que você faz, onde atende e quando pode começar.',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 860;
                    final identity = _buildIdentity(profile, viewModel);
                    final form = _buildForm(profile, viewModel);
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 280, child: identity),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(child: form),
                            ],
                          )
                        : Column(
                            children: [
                              identity,
                              const SizedBox(height: AppSpacing.lg),
                              form,
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
  }

  Widget _buildIdentity(
    ProfessionalProfileModel profile,
    ProfessionalProfileViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                PhotoPickerAvatar(
                  photoUrl: profile.photoUrl,
                  name: profile.name,
                  isUploading: viewModel.isUploadingPhoto,
                  onTap: _pickAndUploadPhoto,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  profile.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _skills.isEmpty
                      ? 'Defina suas áreas de atuação'
                      : _skills.take(2).join(' · '),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfessionalPublicProfileScreen(
                        professionalId: profile.userId,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Ver perfil público'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ProfileCompletionBar(
          percentage: profile.profileCompletion,
          missingItems: _missingItems(profile),
        ),
      ],
    );
  }

  Widget _buildForm(
    ProfessionalProfileModel profile,
    ProfessionalProfileViewModel viewModel,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            icon: Icons.badge_outlined,
            title: 'Apresentação',
            description: 'Conte o que você resolve e por que um cliente deve confiar no seu trabalho.',
            child: Column(
              children: [
                AppTextField(
                  controller: _bioController,
                  label: 'Resumo profissional',
                  hintText: 'Ex.: Atuo há 8 anos com instalações e manutenção residencial…',
                  helperText: 'Mínimo de 60 caracteres.',
                  maxLines: 4,
                  validator: (value) {
                    if ((value ?? '').trim().length <
                        ProfessionalCatalog.minBioLength) {
                      return 'Escreva ao menos ${ProfessionalCatalog.minBioLength} caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _experienceController,
                  label: 'Experiência e diferenciais',
                  hintText: 'Formação, certificações, tipos de projeto e tempo de atuação.',
                  maxLines: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            icon: Icons.build_outlined,
            title: 'Áreas de atuação',
            description: 'Escolha até 6 áreas principais. Elas são usadas pelo mecanismo de busca.',
            trailing: Text(
              '${_skills.length}/${ProfessionalCatalog.maxSkills}',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: ProfessionalCatalog.categories
                      .map((skill) {
                        return FilterChip(
                          label: Text(skill),
                          selected: _skills.contains(skill),
                          onSelected: (selected) =>
                              _toggleSkill(skill, selected),
                        );
                      })
                      .toList(growable: false),
                ),
                if (_skills.any(
                  (skill) => !ProfessionalCatalog.categories.contains(skill),
                )) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _skills
                        .where(
                          (skill) =>
                              !ProfessionalCatalog.categories.contains(skill),
                        )
                        .map(
                          (skill) => InputChip(
                            label: Text(skill),
                            selected: true,
                            onDeleted: () =>
                                setState(() => _skills.remove(skill)),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _skillInputController,
                        label: 'Outra especialidade',
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.filledTonal(
                      onPressed: _addCustomSkill,
                      tooltip: 'Adicionar especialidade',
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            icon: Icons.route_outlined,
            title: 'Atendimento e região',
            description:
                'Esses dados definem em quais buscas seu perfil pode aparecer.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Forma de atendimento',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<ServiceMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ServiceMode.presencial,
                      label: Text('Presencial'),
                    ),
                    ButtonSegment(
                      value: ServiceMode.remoto,
                      label: Text('Remoto'),
                    ),
                    ButtonSegment(
                      value: ServiceMode.hibrido,
                      label: Text('Híbrido'),
                    ),
                  ],
                  selected: _serviceMode == null ? {} : {_serviceMode!},
                  emptySelectionAllowed: true,
                  onSelectionChanged: (selection) => setState(() {
                    _serviceMode = selection.isEmpty ? null : selection.first;
                  }),
                ),
                const SizedBox(height: AppSpacing.lg),
                LocationSelector(
                  stateCode: _state,
                  city: _city,
                  required: true,
                  onStateChanged: (value) => setState(() => _state = value),
                  onCityChanged: (value) => setState(() => _city = value),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Como você cobra pelo trabalho?',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    for (final type in PricingType.values) ...[
                      Expanded(
                        child: _PricingOption(
                          type: type,
                          selected: _pricingType == type,
                          onTap: () => setState(() => _pricingType = type),
                        ),
                      ),
                      if (type != PricingType.values.last)
                        const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _pricingType == PricingType.porHora
                      ? AppTextField(
                          key: const ValueKey('hourly-rate'),
                          controller: _hourlyRateController,
                          label: 'Valor por hora (R\$)',
                          hintText: 'Ex.: 75,00',
                          helperText:
                              'O total será calculado pelo tempo registrado.',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        )
                      : AppTextField(
                          key: const ValueKey('project-rate'),
                          controller: _projectRateController,
                          label: 'Valor da empreitada (R\$)',
                          hintText: 'Ex.: 850,00',
                          helperText:
                              'Preço de referência para o trabalho completo.',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            icon: Icons.calendar_month_outlined,
            title: 'Quando posso trabalhar',
            description:
                'Defina períodos reais. Você pode ter vários atendimentos no mesmo dia e horários que terminam após meia-noite.',
            child: WeeklyAvailabilityEditor(
              value: _availabilitySchedule,
              onChanged: (value) =>
                  setState(() => _availabilitySchedule = value),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            icon: Icons.contact_phone_outlined,
            title: 'Contato',
            description:
                'Use um número que você acompanhe durante o horário informado.',
            child: AppTextField(
              controller: _phoneController,
              label: 'Telefone ou WhatsApp',
              hintText: '(47) 99999-9999',
              keyboardType: TextInputType.phone,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            icon: Icons.collections_outlined,
            title: 'Portfólio',
            description: 'Adicione trabalhos reais. Pressione uma imagem para removê-la.',
            child: PortfolioGrid(
              items: profile.portfolio,
              isUploading: viewModel.isUploadingPortfolioItem,
              onAdd: _pickAndAddPortfolioItem,
              onDelete: _deletePortfolioItem,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: PrimaryButton(
                label: 'Salvar alterações',
                isLoading: viewModel.isSaving,
                onPressed: _save,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _missingItems(ProfessionalProfileModel profile) {
    final missing = <String>[];
    if (profile.photoUrl == null) missing.add('Adicione uma foto profissional');
    if ((profile.bio ?? '').trim().length < ProfessionalCatalog.minBioLength) {
      missing.add('Complete sua apresentação');
    }
    if (profile.skills.isEmpty) missing.add('Escolha suas áreas de atuação');
    if (profile.city == null || profile.state == null) {
      missing.add('Informe sua região de atendimento');
    }
    if (profile.serviceMode == null) {
      missing.add('Defina a forma de atendimento');
    }
    if (profile.availability == null || profile.availability!.isEmpty) {
      missing.add('Informe sua disponibilidade');
    }
    if (profile.pricingType == PricingType.porHora &&
        profile.hourlyRate == null) {
      missing.add('Informe seu valor por hora');
    }
    if (profile.pricingType == PricingType.empreitada &&
        profile.projectRate == null) {
      missing.add('Informe o valor da empreitada');
    }
    if (profile.portfolio.isEmpty) {
      missing.add('Mostre um trabalho no portfólio');
    }
    return missing;
  }
}

class _PricingOption extends StatelessWidget {
  final PricingType type;
  final bool selected;
  final VoidCallback onTap;

  const _PricingOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryLight : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    type == PricingType.porHora
                        ? Icons.schedule_rounded
                        : Icons.inventory_2_outlined,
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textSecondary,
                  ),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 20,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textDisabled,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(type.label, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(
                type == PricingType.porHora
                    ? 'Tempo registrado'
                    : 'Preço fechado',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
