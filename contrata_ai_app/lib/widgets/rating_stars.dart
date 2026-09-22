import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Estrelas de avaliação — somente leitura quando [onChanged] é nulo
/// (exibir uma nota já dada), ou interativa quando fornecido (escolher
/// uma nota de 1 a 5).
class RatingStars extends StatelessWidget {
  final int rating;
  final double size;
  final ValueChanged<int>? onChanged;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 24,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final icon = Icon(
          starValue <= rating ? Icons.star : Icons.star_border,
          size: size,
          color: AppColors.accent,
        );
        if (onChanged == null) return icon;
        return InkWell(
          onTap: () => onChanged!(starValue),
          borderRadius: BorderRadius.circular(size),
          child: Padding(padding: const EdgeInsets.all(2), child: icon),
        );
      }),
    );
  }
}
