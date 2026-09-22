import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../auth/register_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _benefitsKey = GlobalKey();
  final _howItWorksKey = GlobalKey();
  final _trustKey = GlobalKey();
  final _faqKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final targetContext = key.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  void _openRegistration(UserRole role) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegisterScreen(initialRole: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SelectionArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              toolbarHeight: 76,
              backgroundColor: AppColors.background.withValues(alpha: 0.96),
              surfaceTintColor: Colors.transparent,
              titleSpacing: 0,
              title: _PageWidth(
                child: _LandingNavigation(
                  onBenefits: () => _scrollTo(_benefitsKey),
                  onHowItWorks: () => _scrollTo(_howItWorksKey),
                  onTrust: () => _scrollTo(_trustKey),
                  onFaq: () => _scrollTo(_faqKey),
                  onLogin: () =>
                      Navigator.of(context).pushNamed(AppRoutes.login),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _HeroSection(
                    onHire: () => _openRegistration(UserRole.cliente),
                    onWork: () => _openRegistration(UserRole.profissional),
                  ),
                  _TrustRibbon(key: _trustKey),
                  _BenefitsSection(key: _benefitsKey),
                  _HowItWorksSection(key: _howItWorksKey),
                  const _ProofSection(),
                  const _AudienceSection(),
                  _FaqSection(key: _faqKey),
                  _FinalCallToAction(
                    onHire: () => _openRegistration(UserRole.cliente),
                    onWork: () => _openRegistration(UserRole.profissional),
                  ),
                  _LandingFooter(
                    onBenefits: () => _scrollTo(_benefitsKey),
                    onHowItWorks: () => _scrollTo(_howItWorksKey),
                    onFaq: () => _scrollTo(_faqKey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageWidth extends StatelessWidget {
  final Widget child;

  const _PageWidth({required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 600 ? 20.0 : 40.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  final bool light;

  const _BrandMark({this.light = false});

  @override
  Widget build(BuildContext context) {
    final foreground = light ? Colors.white : AppColors.textPrimary;
    return Semantics(
      label: 'Contrata Aí',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: light ? Colors.white : AppColors.primary,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.handyman_rounded,
              size: 21,
              color: light ? AppColors.primaryDark : Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Contrata Aí',
            style: TextStyle(
              color: foreground,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingNavigation extends StatelessWidget {
  final VoidCallback onBenefits;
  final VoidCallback onHowItWorks;
  final VoidCallback onTrust;
  final VoidCallback onFaq;
  final VoidCallback onLogin;

  const _LandingNavigation({
    required this.onBenefits,
    required this.onHowItWorks,
    required this.onTrust,
    required this.onFaq,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showLinks = constraints.maxWidth >= 850;
        return Row(
          children: [
            const _BrandMark(),
            const Spacer(),
            if (showLinks) ...[
              _NavLink(label: 'Benefícios', onPressed: onBenefits),
              _NavLink(label: 'Como funciona', onPressed: onHowItWorks),
              _NavLink(label: 'Confiança', onPressed: onTrust),
              _NavLink(label: 'Dúvidas', onPressed: onFaq),
              const SizedBox(width: 12),
            ],
            OutlinedButton(
              onPressed: onLogin,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primaryDark,
              ),
              child: const Text('Entrar'),
            ),
          ],
        );
      },
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _NavLink({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
      child: Text(label),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final VoidCallback onHire;
  final VoidCallback onWork;

  const _HeroSection({required this.onHire, required this.onWork});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    return Container(
      width: double.infinity,
      color: AppColors.primaryDark,
      child: Stack(
        children: [
          const Positioned.fill(child: _BlueprintPattern()),
          _PageWidth(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: isWide ? 88 : 56),
              child: isWide
                  ? Row(
                      children: [
                        Expanded(
                          flex: 11,
                          child: _HeroCopy(onHire: onHire, onWork: onWork),
                        ),
                        const SizedBox(width: 72),
                        const Expanded(flex: 9, child: _LiveWorkOrder()),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeroCopy(onHire: onHire, onWork: onWork),
                        const SizedBox(height: 48),
                        const _LiveWorkOrder(),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlueprintPattern extends StatelessWidget {
  const _BlueprintPattern();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _BlueprintPainter()));
  }
}

class _BlueprintPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fine = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    final bold = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), fine);
    }
    for (double y = 0; y <= size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), fine);
    }
    for (double x = 0; x <= size.width; x += 140) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), bold);
    }
    for (double y = 0; y <= size.height; y += 140) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), bold);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroCopy extends StatelessWidget {
  final VoidCallback onHire;
  final VoidCallback onWork;

  const _HeroCopy({required this.onHire, required this.onWork});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width >= 1100 ? 62.0 : (width >= 600 ? 50.0 : 39.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow(
          label: 'SERVIÇOS LOCAIS • DO CHAMADO À CONCLUSÃO',
          dark: true,
        ),
        const SizedBox(height: 22),
        Text(
          'O trabalho certo,\ncom começo, meio\ne comprovação.',
          style: TextStyle(
            color: Colors.white,
            fontSize: titleSize,
            height: 0.98,
            fontWeight: FontWeight.w900,
            letterSpacing: -2.2,
          ),
        ),
        const SizedBox(height: 26),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'Encontre profissionais da sua cidade ou novas oportunidades de trabalho. Acompanhe a jornada, registre o que foi feito e encerre cada serviço com clareza.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: width < 600 ? 17 : 19,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 34),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: onHire,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
              ),
              icon: const Icon(Icons.search_rounded),
              label: const Text('Quero contratar'),
            ),
            OutlinedButton.icon(
              onPressed: onWork,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.42)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
              ),
              icon: const Icon(Icons.work_outline_rounded),
              label: const Text('Quero trabalhar'),
            ),
          ],
        ),
        const SizedBox(height: 34),
        Wrap(
          spacing: 22,
          runSpacing: 12,
          children: const [
            _HeroAssurance(icon: Icons.schedule, label: 'Jornada registrada'),
            _HeroAssurance(
              icon: Icons.calculate_outlined,
              label: 'Valor calculado',
            ),
            _HeroAssurance(
              icon: Icons.verified_outlined,
              label: 'Conclusão confirmada',
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroAssurance extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroAssurance({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF97CCC4), size: 18),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.74),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LiveWorkOrder extends StatelessWidget {
  const _LiveWorkOrder();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Exemplo de ordem de serviço em andamento',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -12,
            top: 16,
            bottom: -16,
            left: 18,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFBF7),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 44,
                  offset: const Offset(0, 24),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ORDEM DE SERVIÇO',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Manutenção do jardim',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0D6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'EM ANDAMENTO',
                        style: TextStyle(
                          color: Color(0xFF8A5E18),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      _PulseDot(),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TEMPO DE TRABALHO',
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              '02:18:42',
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontSize: 30,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.pause_rounded,
                        color: AppColors.primaryDark,
                        size: 25,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const _OrderTimelineItem(
                  icon: Icons.play_arrow_rounded,
                  title: 'Início registrado',
                  detail: 'Hoje, 08:12',
                  complete: true,
                ),
                const _OrderTimelineItem(
                  icon: Icons.photo_camera_outlined,
                  title: 'Evidências e observações',
                  detail: 'Adicione ao finalizar',
                  complete: false,
                ),
                const _OrderTimelineItem(
                  icon: Icons.task_alt_rounded,
                  title: 'Confirmação do contratante',
                  detail: 'Próxima etapa',
                  complete: false,
                  last: true,
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Ao concluir, o comprovante fica pronto.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.disableAnimationsOf(context);
    if (disableMotion) {
      return const _StaticPulseDot(scale: 1);
    }
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.86,
        end: 1.12,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: const _StaticPulseDot(scale: 1),
    );
  }
}

class _StaticPulseDot extends StatelessWidget {
  final double scale;

  const _StaticPulseDot({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 13,
        height: 13,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Color(0x5578B7AD), blurRadius: 0, spreadRadius: 6),
          ],
        ),
      ),
    );
  }
}

class _OrderTimelineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final bool complete;
  final bool last;

  const _OrderTimelineItem({
    required this.icon,
    required this.title,
    required this.detail,
    required this.complete,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = complete ? AppColors.primary : AppColors.textDisabled;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: complete
                        ? AppColors.primaryLight
                        : const Color(0xFFF0EEE8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustRibbon extends StatelessWidget {
  const _TrustRibbon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: _PageWidth(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final items = [
                const _RibbonItem(
                  icon: Icons.location_on_outlined,
                  title: 'Busca local',
                  detail: 'profissão, cidade e avaliação',
                ),
                const _RibbonItem(
                  icon: Icons.timer_outlined,
                  title: 'Jornada clara',
                  detail: 'início, duração e encerramento',
                ),
                const _RibbonItem(
                  icon: Icons.description_outlined,
                  title: 'Registro completo',
                  detail: 'foto, observação e comprovante',
                ),
              ];
              if (compact) {
                return Wrap(spacing: 22, runSpacing: 18, children: items);
              }
              return Row(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    Expanded(child: items[index]),
                    if (index < items.length - 1)
                      Container(
                        width: 1,
                        height: 38,
                        margin: const EdgeInsets.symmetric(horizontal: 22),
                        color: AppColors.border,
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RibbonItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _RibbonItem({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 23),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              detail,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BenefitsSection extends StatelessWidget {
  const _BenefitsSection({super.key});

  @override
  Widget build(BuildContext context) {
    const benefits = [
      _BenefitData(
        code: 'ENCONTRE',
        icon: Icons.manage_search_rounded,
        title: 'A escolha começa com contexto.',
        description: 'Filtre por profissão, cidade, nome e avaliação. Veja experiência, áreas de atuação e portfólio antes de decidir.',
      ),
      _BenefitData(
        code: 'COMBINE',
        icon: Icons.handshake_outlined,
        title: 'O combinado fica visível.',
        description: 'Data, formato de cobrança e situação do serviço ficam organizados para os dois lados acompanharem.',
      ),
      _BenefitData(
        code: 'REGISTRE',
        icon: Icons.play_circle_outline_rounded,
        title: 'O trabalho ganha uma linha do tempo.',
        description: 'O profissional inicia a jornada, registra o tempo e inclui observações e fotos quando finaliza.',
      ),
      _BenefitData(
        code: 'COMPROVE',
        icon: Icons.receipt_long_outlined,
        title: 'O encerramento não depende da memória.',
        description: 'Confirmação, cálculo do valor e comprovante reúnem as informações essenciais do serviço realizado.',
      ),
    ];

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            eyebrow: 'MENOS IMPROVISO',
            title: 'Uma jornada profissional\npara um trabalho bem feito.',
            description: 'A plataforma organiza os pontos que mais geram dúvida em uma contratação de serviço local.',
          ),
          const SizedBox(height: 42),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 950
                  ? 4
                  : (constraints.maxWidth >= 600 ? 2 : 1);
              final gap = 16.0;
              final itemWidth =
                  (constraints.maxWidth - (gap * (columns - 1))) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final benefit in benefits)
                    SizedBox(
                      width: itemWidth,
                      child: _BenefitCard(
                        data: benefit,
                        minHeight: columns == 1 ? 0 : 294,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BenefitData {
  final String code;
  final IconData icon;
  final String title;
  final String description;

  const _BenefitData({
    required this.code,
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _BenefitCard extends StatelessWidget {
  final _BenefitData data;
  final double minHeight;

  const _BenefitCard({required this.data, required this.minHeight});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(data.icon, color: AppColors.primaryDark, size: 24),
              ),
              const Spacer(),
              Text(
                data.code,
                style: const TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            data.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1.22,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            data.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.55,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      child: _Section(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeading(
              eyebrow: 'COMO FUNCIONA',
              title: 'Dois lados.\nUm mesmo combinado.',
              description: 'Cada pessoa vê somente o que precisa para avançar, sem perder o contexto do serviço.',
            ),
            const SizedBox(height: 42),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 820;
                const client = _JourneyPanel(
                  role: 'PARA QUEM CONTRATA',
                  title: 'Resolva com mais segurança',
                  color: AppColors.secondary,
                  steps: [
                    _JourneyStep(
                      title: 'Publique ou encontre',
                      description: 'Descreva o serviço ou busque profissionais por critérios relevantes.',
                    ),
                    _JourneyStep(
                      title: 'Compare e escolha',
                      description: 'Avalie perfil, especialidade, reputação e candidaturas recebidas.',
                    ),
                    _JourneyStep(
                      title: 'Acompanhe e confirme',
                      description: 'Receba o encerramento, confira os registros e confirme a conclusão.',
                    ),
                  ],
                );
                const professional = _JourneyPanel(
                  role: 'PARA QUEM TRABALHA',
                  title: 'Transforme ofício em reputação',
                  color: AppColors.primary,
                  steps: [
                    _JourneyStep(
                      title: 'Mostre seu trabalho',
                      description: 'Complete o perfil com atuação, valor por hora, experiência e portfólio.',
                    ),
                    _JourneyStep(
                      title: 'Escolha oportunidades',
                      description: 'Filtre serviços abertos e candidate-se aos que combinam com você.',
                    ),
                    _JourneyStep(
                      title: 'Registre e acompanhe',
                      description: 'Marque sua jornada e acompanhe horas, ganhos e histórico no painel.',
                    ),
                  ],
                );
                if (!wide) {
                  return const Column(
                    children: [client, SizedBox(height: 18), professional],
                  );
                }
                return const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: client),
                    SizedBox(width: 20),
                    Expanded(child: professional),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyStep {
  final String title;
  final String description;

  const _JourneyStep({required this.title, required this.description});
}

class _JourneyPanel extends StatelessWidget {
  final String role;
  final String title;
  final Color color;
  final List<_JourneyStep> steps;

  const _JourneyPanel({
    required this.role,
    required this.title,
    required this.color,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.055),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            role,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 30),
          for (var index = 0; index < steps.length; index++)
            _JourneyStepTile(
              number: index + 1,
              data: steps[index],
              color: color,
              last: index == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _JourneyStepTile extends StatelessWidget {
  final int number;
  final _JourneyStep data;
  final Color color;
  final bool last;

  const _JourneyStepTile({
    required this.number,
    required this.data,
    required this.color,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    color: color.withValues(alpha: 0.28),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofSection extends StatelessWidget {
  const _ProofSection();

  @override
  Widget build(BuildContext context) {
    const proofs = [
      _ProofData(
        label: 'ANTES',
        title: 'Critérios para decidir',
        description: 'Perfil, especialidade, cidade, avaliação, preço e situação do pedido.',
        icon: Icons.fact_check_outlined,
      ),
      _ProofData(
        label: 'DURANTE',
        title: 'Visibilidade para acompanhar',
        description: 'Início da jornada, tempo trabalhado e comunicação do encerramento.',
        icon: Icons.pending_actions_outlined,
      ),
      _ProofData(
        label: 'DEPOIS',
        title: 'Histórico para consultar',
        description: 'Observações, evidências, valor calculado, desempenho e comprovante.',
        icon: Icons.inventory_2_outlined,
      ),
    ];
    return _Section(
      child: Container(
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Container(
          padding: const EdgeInsets.all(34),
          decoration: BoxDecoration(
            color: const Color(0xFF26323A),
            borderRadius: BorderRadius.circular(21),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow(label: 'CONFIANÇA POR EVIDÊNCIA', dark: true),
              const SizedBox(height: 14),
              const Text(
                'Não é só encontrar alguém.\nÉ saber o que aconteceu.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 34),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 800;
                  if (!wide) {
                    return Column(
                      children: [
                        for (final proof in proofs) ...[
                          _ProofCard(data: proof),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < proofs.length; index++) ...[
                        Expanded(child: _ProofCard(data: proofs[index])),
                        if (index < proofs.length - 1)
                          const SizedBox(width: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProofData {
  final String label;
  final String title;
  final String description;
  final IconData icon;

  const _ProofData({
    required this.label,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _ProofCard extends StatelessWidget {
  final _ProofData data;

  const _ProofCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, color: const Color(0xFF97CCC4), size: 22),
              const SizedBox(width: 10),
              Text(
                data.label,
                style: const TextStyle(
                  color: Color(0xFF97CCC4),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            data.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceSection extends StatelessWidget {
  const _AudienceSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      child: _Section(
        child: Column(
          children: [
            const _SectionHeading(
              eyebrow: 'FEITO PARA O TRABALHO REAL',
              title: 'Uma plataforma que respeita\nos dois lados do serviço.',
              description: 'Clareza para quem precisa resolver. Ferramentas de gestão para quem vive do próprio trabalho.',
              centered: true,
            ),
            const SizedBox(height: 42),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: const [
                _ProfessionChip(icon: Icons.grass, label: 'Jardinagem'),
                _ProfessionChip(icon: Icons.plumbing, label: 'Hidráulica'),
                _ProfessionChip(
                  icon: Icons.electrical_services,
                  label: 'Elétrica',
                ),
                _ProfessionChip(
                  icon: Icons.cleaning_services,
                  label: 'Limpeza',
                ),
                _ProfessionChip(icon: Icons.format_paint, label: 'Pintura'),
                _ProfessionChip(icon: Icons.carpenter, label: 'Marcenaria'),
                _ProfessionChip(
                  icon: Icons.home_repair_service,
                  label: 'Reparos',
                ),
                _ProfessionChip(icon: Icons.more_horiz, label: 'E muito mais'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfessionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProfessionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 19),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqSection extends StatelessWidget {
  const _FaqSection({super.key});

  @override
  Widget build(BuildContext context) {
    const questions = [
      (
        'O Contrata Aí serve para quem contrata e para quem trabalha?',
        'Sim. No cadastro você escolhe seu perfil. Contratantes publicam serviços e encontram profissionais; profissionais montam o perfil, encontram oportunidades e acompanham sua jornada e desempenho.',
      ),
      (
        'Como o valor final do serviço é calculado?',
        'Quando há valor por hora, o cálculo considera o tempo registrado na jornada. Em serviços de preço fechado, vale o valor combinado na publicação.',
      ),
      (
        'O que acontece quando o profissional finaliza o trabalho?',
        'Ele pode registrar observações e fotos. O contratante recebe a atualização e, conforme sua preferência, confirma a conclusão ou apenas acompanha a notificação.',
      ),
      (
        'Posso escolher profissionais por cidade e especialidade?',
        'Sim. A busca organiza os profissionais por nome, cidade, área de atuação e avaliação para tornar a escolha mais objetiva.',
      ),
      (
        'Onde o profissional acompanha horas e ganhos?',
        'No painel Meu desempenho, com resumo da semana, horas trabalhadas, total calculado, histórico e visão mensal.',
      ),
    ];
    return _Section(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 850;
          final heading = const _SectionHeading(
            eyebrow: 'PERGUNTAS FREQUENTES',
            title: 'Sem letras miúdas.\nSem pontas soltas.',
            description: 'O essencial para entender como a plataforma organiza a contratação e o trabalho.',
          );
          final list = Column(
            children: [
              for (final question in questions)
                _FaqTile(question: question.$1, answer: question.$2),
            ],
          );
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 34), list],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: heading),
              const SizedBox(width: 68),
              Expanded(flex: 6, child: list),
            ],
          );
        },
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 5,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 52, 20),
            iconColor: AppColors.primary,
            collapsedIconColor: AppColors.textSecondary,
            title: Text(
              question,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  answer,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.55,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinalCallToAction extends StatelessWidget {
  final VoidCallback onHire;
  final VoidCallback onWork;

  const _FinalCallToAction({required this.onHire, required this.onWork});

  @override
  Widget build(BuildContext context) {
    return _PageWidth(
      child: Container(
        margin: const EdgeInsets.only(bottom: 76),
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 48),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          border: Border.all(color: const Color(0xFFC6DFDB)),
          borderRadius: BorderRadius.circular(22),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final copy = const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRONTO PARA COMEÇAR?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Escolha o seu lado do trabalho.',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'O cadastro é simples e você pode completar os detalhes depois.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            );
            final buttons = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton(
                  onPressed: onHire,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 17,
                    ),
                  ),
                  child: const Text('Cadastrar para contratar'),
                ),
                OutlinedButton(
                  onPressed: onWork,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.64),
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 17,
                    ),
                  ),
                  child: const Text('Cadastrar como profissional'),
                ),
              ],
            );
            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [copy, const SizedBox(height: 28), buttons],
              );
            }
            return Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 28),
                buttons,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LandingFooter extends StatelessWidget {
  final VoidCallback onBenefits;
  final VoidCallback onHowItWorks;
  final VoidCallback onFaq;

  const _LandingFooter({
    required this.onBenefits,
    required this.onHowItWorks,
    required this.onFaq,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.textPrimary,
      child: _PageWidth(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 42),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 980;
              final links = Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _FooterLink(label: 'Benefícios', onPressed: onBenefits),
                  _FooterLink(label: 'Como funciona', onPressed: onHowItWorks),
                  _FooterLink(label: 'Perguntas', onPressed: onFaq),
                ],
              );
              final legal = Text(
                '© 2026 Contrata Aí • Projeto acadêmico de conclusão de curso',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BrandMark(light: true),
                    const SizedBox(height: 20),
                    links,
                    const SizedBox(height: 26),
                    legal,
                  ],
                );
              }
              return Row(
                children: [
                  const _BrandMark(light: true),
                  const Spacer(),
                  links,
                  const SizedBox(width: 28),
                  legal,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _FooterLink({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.72),
      ),
      child: Text(label),
    );
  }
}

class _Section extends StatelessWidget {
  final Widget child;

  const _Section({required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return _PageWidth(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: width < 600 ? 68 : 96),
        child: child,
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final String label;
  final bool dark;

  const _Eyebrow({required this.label, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 2,
          color: dark ? const Color(0xFF97CCC4) : AppColors.primary,
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: dark ? const Color(0xFFB7DDD7) : AppColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.15,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final bool centered;

  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.description,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: AppColors.textPrimary,
      fontSize: MediaQuery.sizeOf(context).width < 600 ? 31 : 40,
      height: 1.12,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.2,
    );
    return Align(
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: centered
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            _Eyebrow(label: eyebrow),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: titleStyle,
            ),
            const SizedBox(height: 16),
            Text(
              description,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
