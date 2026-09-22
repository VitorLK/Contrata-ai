import 'package:flutter/material.dart';

import '../core/constants/api_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/name_utils.dart';

/// Avatar circular do profissional: mostra a foto (via URL do back-end) ou
/// as iniciais do nome quando ainda não há foto. O que acontece ao tocar
/// (abrir o seletor de imagem) fica a cargo de quem usa o widget, para
/// poder tratar erro/feedback fora daqui.
class PhotoPickerAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final bool isUploading;
  final VoidCallback onTap;

  const PhotoPickerAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    required this.onTap,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: photoUrl != null
                ? NetworkImage(ApiConstants.resolveUrl(photoUrl!))
                : null,
            child: photoUrl == null
                ? Text(
                    initialsFor(name),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  )
                : null,
          ),
          if (isUploading)
            const CircleAvatar(
              radius: 48,
              backgroundColor: Colors.black38,
              child: CircularProgressIndicator(color: Colors.white),
            ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Icon(
                Icons.camera_alt,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
