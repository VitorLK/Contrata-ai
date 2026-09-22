import 'package:flutter/material.dart';

/// Paleta "Oficina" — inspirada em materiais de ofício (lona de avental,
/// tinta carvão, cobre oxidado/verdigris, latão, carimbo de ordem de
/// serviço), fugindo do azul genérico de SaaS. É a única fonte de verdade
/// para cores em toda a UI: qualquer widget que precise de uma cor fora do
/// que o [ThemeData] já expõe (ex.: o badge de status de serviço) deve
/// importar essas constantes em vez de declarar um valor hexadecimal solto.
class AppColors {
  AppColors._();

  // Marca — o verdigris (cobre oxidado) é a única cor "ousada" da UI; tudo
  // ao redor dela fica deliberadamente quieto.
  static const primary = Color(0xFF1C6E63);
  static const primaryDark = Color(0xFF144F47);
  static const primaryLight = Color(0xFFE1EEEC);
  static const secondary = Color(0xFF3A5B8C); // azul-planta (blueprint)
  static const accent = Color(0xFFB9832E); // latão

  // Fundo e superfícies — tom de lona/canvas, com contraste discreto para
  // preservar a identidade própria do produto.
  static const background = Color(0xFFF5F3EF);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE1DED4);

  // Texto
  static const textPrimary = Color(0xFF232B36); // tinta carvão
  static const textSecondary = Color(0xFF6E6A5F);
  static const textDisabled = Color(0xFFA6A296);

  // Feedback — lidos como carimbos de uma ordem de serviço.
  static const success = Color(0xFF2F6B4F); // verde-pátina: "concluído"
  static const warning = Color(0xFFB9832E); // latão: "em andamento"
  static const error = Color(0xFF9C3B2E); // tijolo: "cancelado" / erro

  // Status de serviço — usadas pelo StatusBadge (próxima etapa do plano),
  // pensado como um carimbo: cada status tem uma tinta própria e
  // reconhecível, não uma variação aleatória de cor.
  static const statusAberto = secondary; // azul-planta: aguardando início
  static const statusEmAndamento = warning; // latão: sendo trabalhado
  static const statusConcluido = success; // verde-pátina: entregue
  static const statusCancelado = error; // tijolo: encerrado sem entrega
}

/// Espaçamentos padronizados, para não espalhar números "mágicos" de
/// padding/margin pelas telas.
class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppTheme {
  AppTheme._();

  static const _radius = 10.0;

  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          tertiary: AppColors.accent,
          error: AppColors.error,
          surface: AppColors.surface,
        );

    // Sem fonte customizada (google_fonts): dependeria de download em
    // tempo de execução, um risco real no dia da apresentação sem rede
    // garantida. A personalidade tipográfica vem de peso e tracking sobre
    // a fonte do sistema (Roboto), não da família da fonte.
    const textTheme = TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
        height: 1.25,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: AppColors.textSecondary,
        height: 1.4,
      ),
      // Rótulos em versalete + tracking largo — o mesmo tratamento que uma
      // etiqueta estampada num crachá ou numa caixa de ferramentas. É a
      // base tipográfica que o StatusBadge (próxima etapa) vai herdar.
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.textSecondary,
      ),
    );

    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textDisabled),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primaryLight,
          disabledForegroundColor: AppColors.textDisabled,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          elevation: 0,
        ),
      ),

      // Usado pelo botão secundário (recusar/cancelar) que entra numa
      // próxima etapa do plano.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      // Rótulo em versalete + tracking, como uma etiqueta estampada — a
      // mesma linguagem que o labelMedium do TextTheme já estabelece.
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryLight,
        labelStyle: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),

      drawerTheme: const DrawerThemeData(backgroundColor: AppColors.surface),
    );
  }
}
