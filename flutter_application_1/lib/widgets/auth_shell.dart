import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Estrutura compartilhada pelas telas de autenticação. Em desktop vira uma
/// composição em dois painéis; em telas menores mantém somente o formulário
/// para reduzir distrações e preservar áreas de toque confortáveis.
class AuthShell extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget footer;
  final VoidCallback? onBack;

  const AuthShell({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final isDesktop = viewport.maxWidth >= 900;
            return SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 32 : 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: viewport.maxHeight - (isDesktop ? 64 : 32),
                ),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(isDesktop ? 20 : 14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textPrimary.withValues(alpha: 0.08),
                          blurRadius: 34,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isDesktop
                        ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Expanded(flex: 10, child: _TrustPanel()),
                                Expanded(
                                  flex: 9,
                                  child: _FormPanel(
                                    eyebrow: eyebrow,
                                    title: title,
                                    subtitle: subtitle,
                                    footer: footer,
                                    onBack: onBack,
                                    child: child,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _FormPanel(
                            eyebrow: eyebrow,
                            title: title,
                            subtitle: subtitle,
                            footer: footer,
                            onBack: onBack,
                            child: child,
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget footer;
  final VoidCallback? onBack;

  const _FormPanel({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  tooltip: 'Voltar',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              else
                const _CompactBrand(),
            ],
          ),
          const SizedBox(height: 34),
          Text(
            eyebrow.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: AppColors.primary, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          child,
          const SizedBox(height: 22),
          const Divider(),
          const SizedBox(height: 10),
          footer,
        ],
      ),
    );
  }
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Contrata Aí',
      header: true,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.handyman_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Text('Contrata Aí', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _TrustPanel extends StatelessWidget {
  const _TrustPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.primaryDark),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _BlueprintPainter()),
          ),
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.handyman_rounded,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Contrata Aí',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Text(
                  'Serviço bem combinado.\nTrabalho bem reconhecido.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.16,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Da oportunidade ao comprovante: acompanhe cada etapa com clareza e segurança.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                const _TrustItem(
                  icon: Icons.verified_user_outlined,
                  label: 'Perfis e avaliações para decidir melhor',
                ),
                const _TrustItem(
                  icon: Icons.schedule_outlined,
                  label: 'Jornada registrada do início ao fim',
                ),
                const _TrustItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Histórico e comprovantes organizados',
                ),
                const Spacer(),
                Text(
                  'FEITO PARA QUEM CONTRATA E PARA QUEM FAZ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.64),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrustItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFFA9D6CF)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlueprintPainter extends CustomPainter {
  const _BlueprintPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const gap = 28.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
