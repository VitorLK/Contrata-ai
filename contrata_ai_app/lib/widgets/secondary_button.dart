import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Botão secundário — mesma estrutura do PrimaryButton (largura total,
/// altura 48, estado de carregamento embutido), mas usando o estilo
/// outlined do tema. Reservado para ações de segundo plano como
/// recusar/cancelar, que não devem competir visualmente com a ação
/// principal da tela.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isDanger;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: isDanger
            ? OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              )
            : null,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : icon == null
            ? Text(label)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 19),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              ),
      ),
    );
  }
}
