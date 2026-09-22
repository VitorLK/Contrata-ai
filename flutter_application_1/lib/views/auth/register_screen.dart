import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/input_formatters.dart';
import '../../models/user_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_shell.dart';
import '../../widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  final UserRole initialRole;

  const RegisterScreen({super.key, this.initialRole = UserRole.cliente});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  late UserRole _role;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final authViewModel = context.read<AuthViewModel>();
    final success = await authViewModel.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _role,
      phone: _phoneController.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authViewModel.errorMessage ?? 'Não foi possível cadastrar.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();

    return AuthShell(
      eyebrow: 'Comece por aqui',
      title: 'Crie sua conta.',
      subtitle: 'Escolha como deseja usar a plataforma. Você poderá completar seu perfil depois.',
      onBack: () => Navigator.of(context).pop(),
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Já possui uma conta?'),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entrar'),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'COMO VOCÊ QUER USAR O APP?',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _RoleOption(
                      selected: _role == UserRole.cliente,
                      icon: Icons.business_center_outlined,
                      title: 'Contratar',
                      subtitle: 'Publicar serviços',
                      onTap: () => setState(() => _role = UserRole.cliente),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RoleOption(
                      selected: _role == UserRole.profissional,
                      icon: Icons.engineering_outlined,
                      title: 'Trabalhar',
                      subtitle: 'Oferecer serviços',
                      onTap: () =>
                          setState(() => _role = UserRole.profissional),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: _nameController,
                label: 'Nome completo',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                inputFormatters: [LengthLimitingTextInputFormatter(150)],
                validator: (value) => (value == null || value.trim().length < 3)
                    ? 'Informe seu nome completo'
                    : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _emailController,
                label: 'E-mail',
                hintText: 'voce@exemplo.com',
                prefixIcon: const Icon(Icons.mail_outline_rounded),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  return !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                      ? 'Informe um e-mail válido'
                      : null;
                },
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _passwordController,
                label: 'Senha',
                helperText: 'Use pelo menos 6 caracteres.',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                autocorrect: false,
                enableSuggestions: false,
                validator: (value) => (value == null || value.length < 6)
                    ? 'A senha deve ter no mínimo 6 caracteres'
                    : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _phoneController,
                label: 'Telefone (opcional)',
                hintText: '(47) 99999-9999',
                prefixIcon: const Icon(Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: const [BrazilianPhoneFormatter()],
                validator: (value) {
                  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                  return digits.isNotEmpty && digits.length < 10
                      ? 'Informe um telefone válido'
                      : null;
                },
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _role == UserRole.cliente
                    ? 'Criar conta para contratar'
                    : 'Criar conta profissional',
                icon: Icons.arrow_forward_rounded,
                isLoading: authViewModel.status == AuthStatus.loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              Text(
                'Ao continuar, você concorda em usar seus dados somente para a operação e segurança da plataforma.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $subtitle',
      child: Material(
        color: selected ? AppColors.primaryLight : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
                const SizedBox(height: 7),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
