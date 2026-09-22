import 'package:flutter/material.dart';

import '../core/constants/api_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/professional_profile_model.dart';

/// Grade de imagens de portfólio, com um tile de "adicionar" e confirmação
/// antes de remover um item existente.
class PortfolioGrid extends StatelessWidget {
  final List<PortfolioItemModel> items;
  final bool isUploading;
  final VoidCallback onAdd;
  final void Function(PortfolioItemModel item) onDelete;

  const PortfolioGrid({
    super.key,
    required this.items,
    required this.onAdd,
    required this.onDelete,
    this.isUploading = false,
  });

  Future<void> _confirmDelete(
    BuildContext context,
    PortfolioItemModel item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover imagem?'),
        content: const Text('Essa imagem será removida do seu portfólio.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete(item);
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) {
          return _AddTile(
            isUploading: isUploading,
            onTap: isUploading ? null : onAdd,
          );
        }
        final item = items[index];
        return GestureDetector(
          onLongPress: () => _confirmDelete(context, item),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              ApiConstants.resolveUrl(item.imageUrl),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
}

class _AddTile extends StatelessWidget {
  final bool isUploading;
  final VoidCallback? onTap;

  const _AddTile({required this.isUploading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: isUploading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppColors.textSecondary,
                ),
        ),
      ),
    );
  }
}
