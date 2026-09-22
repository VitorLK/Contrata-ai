import 'package:flutter/services.dart';

/// Formata valores monetários brasileiros enquanto o usuário digita.
/// A fonte de verdade são os centavos, evitando estados inválidos como
/// múltiplas vírgulas ou mais de duas casas decimais.
class BrazilianCurrencyFormatter extends TextInputFormatter {
  const BrazilianCurrencyFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();

    final cents = int.parse(digits);
    final integer = (cents ~/ 100).toString();
    final decimal = (cents % 100).toString().padLeft(2, '0');
    final grouped = integer.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    final value = '$grouped,$decimal';
    return TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  static double? parse(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    return int.parse(digits) / 100;
  }

  static String format(double value) {
    final cents = (value * 100).round();
    final integer = (cents ~/ 100).toString();
    final decimal = (cents % 100).toString().padLeft(2, '0');
    final grouped = integer.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '$grouped,$decimal';
  }
}

class BrazilianPhoneFormatter extends TextInputFormatter {
  const BrazilianPhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    if (limited.isEmpty) return const TextEditingValue();

    final buffer = StringBuffer();
    if (limited.isNotEmpty) buffer.write('(');
    if (limited.length <= 2) {
      buffer.write(limited);
    } else {
      buffer.write('${limited.substring(0, 2)}) ');
      final body = limited.substring(2);
      final split = body.length > 8 ? 5 : 4;
      if (body.length <= split) {
        buffer.write(body);
      } else {
        buffer.write('${body.substring(0, split)}-${body.substring(split)}');
      }
    }
    final value = buffer.toString();
    return TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}
