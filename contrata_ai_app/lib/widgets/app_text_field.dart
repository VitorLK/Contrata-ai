import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final String? hintText;
  final String? helperText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final bool enableSuggestions;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool enabled;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
    this.hintText,
    this.helperText,
    this.textInputAction,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.autofillHints,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.inputFormatters,
    this.maxLength,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: obscureText ? 1 : maxLines,
      textInputAction: textInputAction,
      onChanged: onChanged,
      autofillHints: autofillHints,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
