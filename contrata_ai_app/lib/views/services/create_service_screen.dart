import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/professional_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/input_formatters.dart';
import '../../models/professional_profile_model.dart';
import '../../models/service_model.dart';
import '../../viewmodels/create_service_viewmodel.dart';
import '../../viewmodels/location_viewmodel.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/location_selector.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';
import '../../widgets/service_location_map.dart';

class CreateServiceScreen extends StatefulWidget {
  final ServiceModel? initialService;

  const CreateServiceScreen({super.key, this.initialService});

  @override
  State<CreateServiceScreen> createState() => _CreateServiceScreenState();
}

class _CreateServiceScreenState extends State<CreateServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _addressController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _category;
  DateTime _scheduledDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);
  bool _endsNextDay = false;
  bool _isAllDay = false;
  ServiceMode _serviceMode = ServiceMode.presencial;
  String? _state;
  String? _city;
  double? _latitude;
  double? _longitude;
  Uint8List? _imageBytes;
  String? _imageFilename;
  String? _imageContentType;
  bool _pickingImage = false;

  bool get _isEditing => widget.initialService != null;

  @override
  void initState() {
    super.initState();
    final service = widget.initialService;
    if (service != null) {
      _titleController.text = service.title;
      _descriptionController.text = service.description;
      _budgetController.text = service.budget == null
          ? ''
          : BrazilianCurrencyFormatter.format(service.budget!);
      _addressController.text = service.address ?? '';
      _category = service.category;
      _scheduledDate = service.scheduledDate;
      _isAllDay = service.isAllDay;
      final start = service.scheduledStart?.toLocal();
      final end = service.scheduledEnd?.toLocal();
      if (start != null && end != null) {
        _startTime = TimeOfDay(hour: start.hour, minute: start.minute);
        _endTime = TimeOfDay(hour: end.hour, minute: end.minute);
        _endsNextDay = DateTime(
          end.year,
          end.month,
          end.day,
        ).isAfter(DateTime(start.year, start.month, start.day));
      }
      _serviceMode = service.serviceMode ?? ServiceMode.presencial;
      _state = service.state;
      _city = service.city;
      _latitude = service.latitude;
      _longitude = service.longitude;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _scheduledDate.isBefore(today) ? today : _scheduledDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(now.year + 2),
      helpText: 'Data prevista para o serviço',
      cancelText: 'Cancelar',
      confirmText: 'Escolher data',
    );
    if (selected != null) setState(() => _scheduledDate = selected);
  }

  Future<void> _pickStartTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'Horário de início',
      confirmText: 'Usar horário',
      cancelText: 'Cancelar',
    );
    if (selected != null) {
      setState(() {
        _startTime = selected;
        _endsNextDay = _minutes(_endTime) <= _minutes(_startTime);
      });
    }
  }

  Future<void> _pickEndTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _endTime,
      helpText: 'Horário de término',
      confirmText: 'Usar horário',
      cancelText: 'Cancelar',
    );
    if (selected != null) {
      setState(() {
        _endTime = selected;
        _endsNextDay = _minutes(selected) <= _minutes(_startTime);
      });
    }
  }

  ({DateTime start, DateTime end}) get _scheduleInterval {
    if (_isAllDay) {
      final start = DateTime(
        _scheduledDate.year,
        _scheduledDate.month,
        _scheduledDate.day,
      );
      return (start: start, end: start.add(const Duration(days: 1)));
    }
    final start = DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    var end = DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _endTime.hour,
      _endTime.minute,
    );
    if (_endsNextDay || !end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }
    return (start: start, end: end);
  }

  Future<void> _pickImage() async {
    setState(() => _pickingImage = true);
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 86,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 5 * 1024 * 1024) {
        _message('A imagem deve ter no máximo 5 MB.');
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageFilename = file.name;
        _imageContentType = file.mimeType ?? _inferImageContentType(file.name);
      });
    } catch (_) {
      if (mounted) _message('Não foi possível abrir esta imagem.');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _locateAddress() async {
    final address = _addressController.text.trim();
    if (_state == null || _city == null || address.length < 4) {
      _message('Informe estado, cidade e bairro antes de localizar.');
      return;
    }

    final point = await context.read<LocationViewModel>().geocodeAddress(
      address: address,
      city: _city!,
      state: _state!,
    );
    if (!mounted) return;
    if (point == null) {
      _message(
        context.read<LocationViewModel>().geocodingError ??
            'Não foi possível localizar este endereço.',
      );
      return;
    }
    setState(() {
      _latitude = point.latitude;
      _longitude = point.longitude;
    });
    _message('Local encontrado. Ajuste o marcador se necessário.');
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      _message('Revise os campos destacados antes de continuar.');
      return;
    }
    if (_category == null) {
      return _message('Selecione a profissão necessária.');
    }
    if (_serviceMode != ServiceMode.remoto &&
        (_state == null || _city == null)) {
      return _message('Selecione a cidade onde o serviço será realizado.');
    }
    if (_serviceMode != ServiceMode.remoto &&
        (_latitude == null || _longitude == null)) {
      return _message('Localize o serviço no mapa antes de publicar.');
    }

    final budget = BrazilianCurrencyFormatter.parse(_budgetController.text);
    if (_budgetController.text.isNotEmpty && (budget == null || budget <= 0)) {
      return _message('Informe um valor fixo maior que zero.');
    }

    final viewModel = context.read<CreateServiceViewModel>();
    final schedule = _scheduleInterval;
    final service = await viewModel.submit(
      serviceId: widget.initialService?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _category,
      budget: budget,
      scheduledDate: _scheduledDate,
      scheduledStart: schedule.start,
      scheduledEnd: schedule.end,
      isAllDay: _isAllDay,
      serviceMode: _serviceMode,
      city: _serviceMode == ServiceMode.remoto ? null : _city,
      state: _serviceMode == ServiceMode.remoto ? null : _state,
      address: _serviceMode == ServiceMode.remoto
          ? null
          : _addressController.text.trim(),
      latitude: _serviceMode == ServiceMode.remoto ? null : _latitude,
      longitude: _serviceMode == ServiceMode.remoto ? null : _longitude,
      imageBytes: _imageBytes,
      imageFilename: _imageFilename,
      imageContentType: _imageContentType,
    );

    if (!mounted) return;
    if (service != null) {
      Navigator.of(context).pop(true);
    } else {
      _message(
        viewModel.errorMessage ??
            'Não foi possível ${_isEditing ? 'salvar' : 'criar'} o serviço.',
      );
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _hasDescription =>
      _titleController.text.trim().length >= 5 &&
      _descriptionController.text.trim().length >= 20 &&
      _category != null;

  bool get _hasLocation =>
      _serviceMode == ServiceMode.remoto ||
      (_state != null &&
          _city != null &&
          _latitude != null &&
          _longitude != null);

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CreateServiceViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar serviço' : 'Nova ordem de serviço'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final pagePadding = viewport.maxWidth >= 700 ? 32.0 : 16.0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(pagePadding, 20, pagePadding, 56),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: () => setState(() {}),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PageHeading(isEditing: _isEditing),
                        const SizedBox(height: 28),
                        LayoutBuilder(
                          builder: (context, content) {
                            final isDesktop = content.maxWidth >= 900;
                            final formColumn = _buildFormColumn();
                            final summary = _PublishSummary(
                              isEditing: _isEditing,
                              hasImage:
                                  _imageBytes != null ||
                                  widget.initialService?.imageUrl != null,
                              hasDescription: _hasDescription,
                              hasLocation: _hasLocation,
                              dateLabel: _formatDate(_scheduledDate),
                              isSubmitting: viewModel.isSubmitting,
                              onSubmit: _submit,
                            );
                            if (!isDesktop) {
                              return Column(
                                children: [
                                  formColumn,
                                  const SizedBox(height: 20),
                                  summary,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: formColumn),
                                const SizedBox(width: 24),
                                SizedBox(width: 310, child: summary),
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
        ),
      ),
    );
  }

  Widget _buildFormColumn() {
    final locationViewModel = context.watch<LocationViewModel>();
    return Column(
      children: [
        SectionCard(
          icon: Icons.image_outlined,
          title: 'Imagem de destaque',
          description: 'Uma foto do local ajuda o profissional a entender o trabalho antes de se candidatar.',
          child: _ServiceImagePicker(
            bytes: _imageBytes,
            currentImageUrl: widget.initialService?.imageUrl,
            isLoading: _pickingImage,
            onPick: _pickImage,
            onClearSelection: _imageBytes == null
                ? null
                : () => setState(() {
                    _imageBytes = null;
                    _imageFilename = null;
                    _imageContentType = null;
                  }),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          icon: Icons.assignment_outlined,
          title: 'Descrição do trabalho',
          description: 'Seja específico sobre o problema, o tamanho e o resultado esperado.',
          child: Column(
            children: [
              AppTextField(
                controller: _titleController,
                label: 'Título do serviço',
                hintText: 'Ex.: Roçar o gramado do quintal',
                prefixIcon: const Icon(Icons.title_rounded),
                textInputAction: TextInputAction.next,
                inputFormatters: [LengthLimitingTextInputFormatter(150)],
                validator: (value) => (value == null || value.trim().length < 5)
                    ? 'Use um título com pelo menos 5 caracteres'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Profissão necessária',
                  prefixIcon: Icon(Icons.handyman_outlined),
                ),
                items: ProfessionalCatalog.categories
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(growable: false),
                validator: (value) =>
                    value == null ? 'Selecione uma profissão' : null,
                onChanged: (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _descriptionController,
                label: 'Descrição detalhada',
                hintText: 'Informe medidas, condições do local, materiais disponíveis e o resultado esperado.',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 86),
                  child: Icon(Icons.notes_rounded),
                ),
                maxLines: 6,
                maxLength: 1200,
                validator: (value) =>
                    (value == null || value.trim().length < 20)
                    ? 'Descreva o trabalho com pelo menos 20 caracteres'
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          icon: Icons.event_outlined,
          title: 'Prazo e localização',
          description: 'A oportunidade entra na busca do dia agendado e pode ser renovada depois.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                label: 'Selecionar data do serviço',
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data prevista',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      suffixIcon: Icon(Icons.edit_calendar_outlined),
                    ),
                    child: Text(_formatDate(_scheduledDate)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isAllDay,
                title: const Text('Horário ainda não definido'),
                subtitle: const Text(
                  'Reserva o dia inteiro até vocês combinarem um período.',
                ),
                onChanged: (value) => setState(() => _isAllDay = value),
              ),
              if (!_isAllDay) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ScheduleTimeField(
                        label: 'Começa',
                        value: _formatTime(_startTime),
                        icon: Icons.play_arrow_rounded,
                        onTap: _pickStartTime,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ScheduleTimeField(
                        label: 'Termina',
                        value:
                            '${_formatTime(_endTime)}${_endsNextDay ? ' · dia seguinte' : ''}',
                        icon: Icons.stop_rounded,
                        onTap: _pickEndTime,
                      ),
                    ),
                  ],
                ),
                if (_endsNextDay)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Este trabalho atravessa a meia-noite e também ocupará parte do dia seguinte.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.primaryDark),
                    ),
                  ),
              ],
              const SizedBox(height: 22),
              Text(
                'FORMA DE ATENDIMENTO',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 10),
              SegmentedButton<ServiceMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ServiceMode.presencial,
                    label: Text('Presencial'),
                    icon: Icon(Icons.location_on_outlined),
                  ),
                  ButtonSegment(
                    value: ServiceMode.remoto,
                    label: Text('Remoto'),
                    icon: Icon(Icons.laptop_outlined),
                  ),
                  ButtonSegment(
                    value: ServiceMode.hibrido,
                    label: Text('Híbrido'),
                    icon: Icon(Icons.sync_alt_rounded),
                  ),
                ],
                selected: {_serviceMode},
                onSelectionChanged: (selection) => setState(() {
                  _serviceMode = selection.first;
                }),
              ),
              if (_serviceMode != ServiceMode.remoto) ...[
                const SizedBox(height: 22),
                LocationSelector(
                  stateCode: _state,
                  city: _city,
                  required: true,
                  onStateChanged: (value) => setState(() {
                    _state = value;
                    _latitude = null;
                    _longitude = null;
                  }),
                  onCityChanged: (value) => setState(() {
                    _city = value;
                    _latitude = null;
                    _longitude = null;
                  }),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _addressController,
                  label: 'Bairro ou endereço de referência',
                  hintText: 'Ex.: Bairro América, próximo à praça',
                  helperText: 'Por segurança, evite informar número e complemento antes de contratar.',
                  prefixIcon: const Icon(Icons.place_outlined),
                  inputFormatters: [LengthLimitingTextInputFormatter(220)],
                  onChanged: (_) {
                    if (_latitude != null || _longitude != null) {
                      setState(() {
                        _latitude = null;
                        _longitude = null;
                      });
                    }
                  },
                  validator: (value) =>
                      _serviceMode != ServiceMode.remoto &&
                          (value == null || value.trim().length < 4)
                      ? 'Informe ao menos o bairro ou um ponto de referência'
                      : null,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: locationViewModel.isGeocoding
                        ? null
                        : _locateAddress,
                    icon: locationViewModel.isGeocoding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _latitude == null
                                ? Icons.travel_explore_rounded
                                : Icons.check_circle_outline_rounded,
                          ),
                    label: Text(
                      _latitude == null
                          ? 'Localizar no mapa'
                          : 'Localizar novamente',
                    ),
                  ),
                ),
                if (locationViewModel.geocodingError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    locationViewModel.geocodingError!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: 14),
                ServiceLocationMap(
                  latitude: _latitude,
                  longitude: _longitude,
                  onPointChanged: (point) => setState(() {
                    _latitude = point.latitude;
                    _longitude = point.longitude;
                  }),
                  semanticsLabel:
                      'Mapa para definir a localização aproximada do serviço',
                ),
                const SizedBox(height: 8),
                Text(
                  _latitude == null
                      ? 'Busque o endereço ou toque diretamente no mapa para posicionar o marcador.'
                      : 'Ponto definido. Você pode tocar no mapa para ajustar a posição.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _latitude == null
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          icon: Icons.payments_outlined,
          title: 'Orçamento',
          description: 'Opcional. Se não houver valor por hora acordado, este será usado como valor fixo.',
          child: AppTextField(
            controller: _budgetController,
            label: 'Valor fixo',
            hintText: '0,00',
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              child: Text('R\$', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [BrazilianCurrencyFormatter()],
            validator: (value) {
              if (value == null || value.isEmpty) return null;
              final parsed = BrazilianCurrencyFormatter.parse(value);
              return parsed == null || parsed <= 0
                  ? 'Informe um valor maior que zero'
                  : null;
            },
          ),
        ),
      ],
    );
  }
}

class _PageHeading extends StatelessWidget {
  final bool isEditing;

  const _PageHeading({required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.description_outlined,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing
                    ? 'Atualize sua oportunidade'
                    : 'Publique uma oportunidade clara',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 5),
              Text(
                isEditing
                    ? 'As alterações ficam disponíveis para os profissionais assim que você salvar.'
                    : 'Quanto melhor o briefing, mais alinhadas serão as candidaturas recebidas.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceImagePicker extends StatelessWidget {
  final Uint8List? bytes;
  final String? currentImageUrl;
  final bool isLoading;
  final VoidCallback onPick;
  final VoidCallback? onClearSelection;

  const _ServiceImagePicker({
    required this.bytes,
    required this.currentImageUrl,
    required this.isLoading,
    required this.onPick,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = bytes != null || currentImageUrl != null;
    return Semantics(
      label: hasImage
          ? 'Prévia da imagem do serviço'
          : 'Adicionar imagem do serviço',
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes!, fit: BoxFit.cover)
            else if (currentImageUrl != null)
              Image.network(
                ApiConstants.resolveUrl(currentImageUrl!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _ImageFallback(),
              )
            else
              const _ImageFallback(),
            Positioned(
              right: 12,
              bottom: 12,
              child: Wrap(
                spacing: 8,
                children: [
                  if (onClearSelection != null)
                    IconButton.filledTonal(
                      tooltip: 'Desfazer nova imagem',
                      onPressed: onClearSelection,
                      icon: const Icon(Icons.undo_rounded),
                    ),
                  FilledButton.icon(
                    onPressed: isLoading ? null : onPick,
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(hasImage ? 'Trocar imagem' : 'Escolher imagem'),
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

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE1EEEC), Color(0xFFE8E5DD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add_photo_alternate_outlined,
              size: 38,
              color: AppColors.primaryDark,
            ),
            const SizedBox(height: 8),
            Text(
              'JPEG, PNG ou WEBP · até 5 MB',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishSummary extends StatelessWidget {
  final bool isEditing;
  final bool hasImage;
  final bool hasDescription;
  final bool hasLocation;
  final String dateLabel;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _PublishSummary({
    required this.isEditing,
    required this.hasImage,
    required this.hasDescription,
    required this.hasLocation,
    required this.dateLabel,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.fact_check_outlined,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEditing ? 'Pronto para salvar?' : 'Antes de publicar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Confira se a oportunidade tem informações suficientes para uma boa decisão.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            _CheckItem(
              complete: hasDescription,
              label: 'Descrição e profissão',
            ),
            _CheckItem(
              complete: hasLocation,
              label: 'Modalidade e localização',
            ),
            _CheckItem(
              complete: hasImage,
              label: 'Imagem de apoio (opcional)',
              optional: true,
            ),
            const Divider(height: 30),
            Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: isEditing ? 'Salvar alterações' : 'Publicar serviço',
              icon: isEditing ? Icons.save_outlined : Icons.publish_outlined,
              isLoading: isSubmitting,
              onPressed: onSubmit,
            ),
            const SizedBox(height: 10),
            Text(
              isEditing ? 'As candidaturas existentes serão preservadas.' : 'Você poderá acompanhar e gerenciar as candidaturas depois.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final bool complete;
  final String label;
  final bool optional;

  const _CheckItem({
    required this.complete,
    required this.label,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 19,
            color: complete ? AppColors.success : AppColors.textDisabled,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (optional)
            Text('opcional', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _ScheduleTimeField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _ScheduleTimeField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
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
  final now = DateTime.now();
  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;
  return '${isToday ? 'Hoje · ' : ''}${date.day} ${months[date.month - 1]} ${date.year}';
}

int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

String _formatTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String _inferImageContentType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}
