import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/availability_model.dart';

class WeeklyAvailabilityEditor extends StatelessWidget {
  final ProfessionalAvailabilityModel value;
  final ValueChanged<ProfessionalAvailabilityModel> onChanged;

  const WeeklyAvailabilityEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  void _emit({
    int? bufferMinutes,
    bool? variableHours,
    List<AvailabilitySlotModel>? slots,
  }) {
    onChanged(
      ProfessionalAvailabilityModel(
        bufferMinutes: bufferMinutes ?? value.bufferMinutes,
        variableHours: variableHours ?? value.variableHours,
        slots: slots ?? value.slots,
      ),
    );
  }

  void _toggleDay(int weekday, bool enabled) {
    final slots = [...value.slots];
    slots.removeWhere((slot) => slot.weekday == weekday);
    if (enabled) {
      slots.add(
        AvailabilitySlotModel(
          weekday: weekday,
          startTime: '08:00',
          endTime: '12:00',
        ),
      );
    }
    _emit(slots: slots);
  }

  void _replaceSlot(
    AvailabilitySlotModel current,
    AvailabilitySlotModel replacement,
  ) {
    final slots = [...value.slots];
    final index = slots.indexOf(current);
    if (index >= 0) slots[index] = replacement;
    _emit(slots: slots);
  }

  Future<String?> _pickTime(BuildContext context, String current) async {
    final parts = current.split(':');
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 8,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
      ),
      helpText: 'Escolha o horário',
      cancelText: 'Cancelar',
      confirmText: 'Usar horário',
    );
    if (selected == null) return null;
    return '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bufferOptions = <int>{
      0,
      15,
      30,
      60,
      120,
      value.bufferMinutes,
    }.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.forum_outlined, color: AppColors.primaryDark),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meus horários variam',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      'O contratante consulta você pelo chat antes de reservar.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value.variableHours,
                onChanged: (selected) => _emit(variableHours: selected),
              ),
            ],
          ),
        ),
        if (!value.variableHours) ...[
          const SizedBox(height: AppSpacing.md),
          for (var weekday = 1; weekday <= 7; weekday++) ...[
            _DayAvailabilityRow(
              weekday: weekday,
              slots: value.forWeekday(weekday),
              onToggle: (enabled) => _toggleDay(weekday, enabled),
              onAdd: () => _emit(
                slots: [
                  ...value.slots,
                  AvailabilitySlotModel(
                    weekday: weekday,
                    startTime: '13:00',
                    endTime: '17:00',
                  ),
                ],
              ),
              onDelete: (slot) {
                final slots = [...value.slots]..remove(slot);
                _emit(slots: slots);
              },
              onStart: (slot) async {
                final time = await _pickTime(context, slot.startTime);
                if (time != null) {
                  _replaceSlot(slot, slot.copyWith(startTime: time));
                }
              },
              onEnd: (slot) async {
                final time = await _pickTime(context, slot.endTime);
                if (time == null) return;
                final startParts = slot.startTime
                    .split(':')
                    .map(int.parse)
                    .toList();
                final endParts = time.split(':').map(int.parse).toList();
                final startMinutes = startParts[0] * 60 + startParts[1];
                final endMinutes = endParts[0] * 60 + endParts[1];
                _replaceSlot(
                  slot,
                  slot.copyWith(
                    endTime: time,
                    endsNextDay: endMinutes <= startMinutes,
                  ),
                );
              },
            ),
            if (weekday != 7) const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            initialValue: value.bufferMinutes,
            decoration: const InputDecoration(
              labelText: 'Pausa mínima entre serviços',
              prefixIcon: Icon(Icons.hourglass_bottom_outlined),
            ),
            items: bufferOptions
                .map(
                  (minutes) => DropdownMenuItem(
                    value: minutes,
                    child: Text(
                      minutes == 0
                          ? 'Sem intervalo extra'
                          : minutes == 60
                          ? '1 hora'
                          : minutes == 120
                          ? '2 horas'
                          : '$minutes minutos',
                    ),
                  ),
                )
                .toList(),
            onChanged: (minutes) {
              if (minutes != null) _emit(bufferMinutes: minutes);
            },
          ),
        ],
      ],
    );
  }
}

class _DayAvailabilityRow extends StatelessWidget {
  final int weekday;
  final List<AvailabilitySlotModel> slots;
  final ValueChanged<bool> onToggle;
  final VoidCallback onAdd;
  final ValueChanged<AvailabilitySlotModel> onDelete;
  final ValueChanged<AvailabilitySlotModel> onStart;
  final ValueChanged<AvailabilitySlotModel> onEnd;

  const _DayAvailabilityRow({
    required this.weekday,
    required this.slots,
    required this.onToggle,
    required this.onAdd,
    required this.onDelete,
    required this.onStart,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = slots.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: enabled ? AppColors.surface : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  weekdayShortLabel(weekday),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: enabled
                        ? AppColors.primaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  enabled
                      ? '${slots.length} ${slots.length == 1 ? 'período' : 'períodos'}'
                      : 'Indisponível',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Switch.adaptive(value: enabled, onChanged: onToggle),
            ],
          ),
          if (enabled) ...[
            const Divider(height: AppSpacing.md),
            for (final slot in slots)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onStart(slot),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(slot.startTime),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward, size: 16),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onEnd(slot),
                        icon: const Icon(Icons.stop_rounded, size: 18),
                        label: Text(
                          '${slot.endTime}${slot.endsNextDay ? ' +1' : ''}',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remover período',
                      onPressed: () => onDelete(slot),
                      icon: const Icon(Icons.close, size: 19),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: slots.length >= 5 ? null : onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar período'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
