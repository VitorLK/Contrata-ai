import 'package:flutter/material.dart';

/// Indicador de carregamento centralizado, usado como corpo de tela
/// enquanto uma ViewModel busca dados.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
