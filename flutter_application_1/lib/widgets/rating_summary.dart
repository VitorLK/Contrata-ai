import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/professional_profile_model.dart';
import 'rating_stars.dart';

/// Média + total + distribuição por estrela de um profissional. Sem lib
/// de gráfico: as barras de distribuição são só Container com largura
/// proporcional dentro de um LinearProgressIndicator.
class RatingSummary extends StatelessWidget {
  final RatingSummaryModel rating;

  const RatingSummary({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    if (rating.total == 0 || rating.average == null) {
      return Text(
        'Ainda sem avaliações.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              rating.average!.toStringAsFixed(1),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(width: 8),
            RatingStars(rating: rating.average!.round(), size: 20),
            const SizedBox(width: 8),
            Text(
              '(${rating.total})',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var star = 5; star >= 1; star--)
          _DistributionBar(
            star: star,
            count: rating.distribution['$star'] ?? 0,
            total: rating.total,
          ),
      ],
    );
  }
}

class _DistributionBar extends StatelessWidget {
  final int star;
  final int count;
  final int total;

  const _DistributionBar({
    required this.star,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Text('$star', style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text('$count', style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
