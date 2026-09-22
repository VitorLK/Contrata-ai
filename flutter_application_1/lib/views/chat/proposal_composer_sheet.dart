import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/professional_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/input_formatters.dart';
import '../../models/professional_profile_model.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/location_selector.dart';

class ProposalDraft {
  final String title;
  final String description;
  final String category;
  final ServiceMode serviceMode;
  final String? city;
  final String? state;
  final String? address;
  final PricingType pricingType;
  final double amount;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final bool isAllDay;

  const ProposalDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.serviceMode,
    this.city,
    this.state,
    this.address,
    required this.pricingType,
    required this.amount,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.isAllDay,
  });
}

Future<ProposalDraft?> showProposalComposer(BuildContext context) {
  return showModalBottomSheet<ProposalDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    builder: (_) => const _ProposalComposerSheet(),
  );
}

class _ProposalComposerSheet extends StatefulWidget {
  const _ProposalComposerSheet();

  @override
  State<_ProposalComposerSheet> createState() => _ProposalComposerSheetState();
}

class _ProposalComposerSheetState extends State<_ProposalComposerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _addressController = TextEditingController();

  String? _category;
  String? _state;
  String? _city;
  ServiceMode _serviceMode = ServiceMode.presencial;
  PricingType _pricingType = PricingType.empreitada;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 12, minute: 0);
  bool _isAllDay = false;
  bool _endsNextDay = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      helpText: 'Data da proposta',
      confirmText: 'Escolher',
      cancelText: 'Cancelar',
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _pickTime({required bool start}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      helpText: start ? 'Início do trabalho' : 'Término do trabalho',
      confirmText: 'Usar horário',
      cancelText: 'Cancelar',
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        _start = selected;
      } else {
        _end = selected;
      }
      _endsNextDay = _minutes(_end) <= _minutes(_start);
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_category == null) {
      return _message('Escolha o tipo de serviço.');
    }
    if (_serviceMode != ServiceMode.remoto &&
        (_state == null || _city == null)) {
      return _message('Informe a cidade onde o trabalho será realizado.');
    }
    final amount = BrazilianCurrencyFormatter.parse(_amountController.text);
    if (amount == null || amount <= 0) {
      return _message('Informe um valor maior que zero.');
    }

    final day = DateTime(_date.year, _date.month, _date.day);
    late DateTime start;
    late DateTime end;
    if (_isAllDay) {
      start = day;
      end = day.add(const Duration(days: 1));
    } else {
      start = DateTime(
        day.year,
        day.month,
        day.day,
        _start.hour,
        _start.minute,
      );
      end = DateTime(
        day.year,
        day.month,
        day.day,
        _end.hour,
        _end.minute,
      );
      if (_endsNextDay || !end.isAfter(start)) {
        end = end.add(const Duration(days: 1));
      }
    }

    Navigator.of(context).pop(
      ProposalDraft(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category!,
        serviceMode: _serviceMode,
        city: _serviceMode == ServiceMode.remoto ? null : _city,
        state: _serviceMode == ServiceMode.remoto ? null : _state,
        address: _serviceMode == ServiceMode.remoto
            ? null
            : _addressController.text.trim(),
        pricingType: _pricingType,
        amount: amount,
        scheduledStart: start,
        scheduledEnd: end,
        isAllDay: _isAllDay,
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: .94,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.request_quote_outlined,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Proposta de contratação',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'O horário só será reservado quando o profissional aceitar.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                  AppTextField(
                    controller: _titleController,
                    label: 'Título do trabalho',
                    hintText: 'Ex.: Limpeza completa do apartamento',
                    prefixIcon: const Icon(Icons.work_outline),
                    validator: (value) => (value?.trim().length ?? 0) < 5
                        ? 'Use pelo menos 5 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de serviço',
                      prefixIcon: Icon(Icons.handyman_outlined),
                    ),
                    items: ProfessionalCatalog.categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _category = value),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _descriptionController,
                    label: 'O que precisa ser feito?',
                    hintText: 'Descreva escopo, materiais e resultado esperado.',
                    maxLines: 4,
                    maxLength: 2000,
                    validator: (value) => (value?.trim().length ?? 0) < 10
                        ? 'Descreva o trabalho em pelo menos 10 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  Text('PERÍODO', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(_dateLabel(_date)),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _isAllDay,
                    title: const Text('Período ainda a combinar'),
                    subtitle: const Text('Reserva o dia inteiro se a proposta for aceita.'),
                    onChanged: (value) => setState(() => _isAllDay = value),
                  ),
                  if (!_isAllDay) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _TimeButton(
                            label: 'Início',
                            value: _timeLabel(_start),
                            onTap: () => _pickTime(start: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TimeButton(
                            label: 'Término',
                            value:
                                '${_timeLabel(_end)}${_endsNextDay ? ' · +1 dia' : ''}',
                            onTap: () => _pickTime(start: false),
                          ),
                        ),
                      ],
                    ),
                    if (_endsNextDay)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'O período atravessa a meia-noite.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'CONDIÇÕES',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<PricingType>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: PricingType.porHora,
                        label: Text('Por hora'),
                        icon: Icon(Icons.schedule_outlined),
                      ),
                      ButtonSegment(
                        value: PricingType.empreitada,
                        label: Text('Empreitada'),
                        icon: Icon(Icons.inventory_2_outlined),
                      ),
                    ],
                    selected: {_pricingType},
                    onSelectionChanged: (value) =>
                        setState(() => _pricingType = value.first),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _amountController,
                    label: _pricingType == PricingType.porHora
                        ? 'Valor por hora (R\$)'
                        : 'Valor fechado (R\$)',
                    hintText: 'Ex.: 150,00',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'ATENDIMENTO',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
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
                    selected: {_serviceMode},
                    onSelectionChanged: (value) =>
                        setState(() => _serviceMode = value.first),
                  ),
                  if (_serviceMode != ServiceMode.remoto) ...[
                    const SizedBox(height: 14),
                    LocationSelector(
                      stateCode: _state,
                      city: _city,
                      required: true,
                      onStateChanged: (value) => setState(() {
                        _state = value;
                        _city = null;
                      }),
                      onCityChanged: (value) => setState(() => _city = value),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _addressController,
                      label: 'Bairro ou referência',
                      hintText: 'Evite número e complemento nesta etapa.',
                      prefixIcon: const Icon(Icons.place_outlined),
                      maxLength: 220,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Enviar proposta'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

String _timeLabel(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
