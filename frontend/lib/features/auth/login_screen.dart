import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_controller.dart';
import 'auth_widgets.dart';
import 'register_screen.dart';

/// Màn đăng nhập. Trả về `true` qua Navigator.pop khi đăng nhập thành công.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthController>().clearError();
    });
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthController>();
    if (auth.busy) return;
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final ok = await auth.login(_user.text, _pass.text);
    if (!mounted || !ok) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text('Xin chào, ${auth.currentUser?.displayName ?? ''}!'),
    ));
    Navigator.of(context).pop(true);
  }

  Future<void> _openRegister() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (!mounted) return;
    // true: đăng ký xong; false: chọn chơi khách ở màn đăng ký
    if (ok == true) Navigator.of(context).pop(true);
    if (ok == false) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final error = auth.lastError;

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                Text('Chào mừng trở lại', style: text.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Đăng nhập để lưu điểm và lên bảng xếp hạng.',
                  style:
                      text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xl),
                AuthTextField(
                  controller: _user,
                  label: 'Tên đăng nhập hoặc email',
                  helper: 'Ví dụ: an_nguyen hoặc an@email.com',
                  icon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  enabled: !auth.busy,
                  validator: (v) => v.trim().isEmpty
                      ? 'Vui lòng nhập tên đăng nhập hoặc email'
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthTextField(
                  controller: _pass,
                  label: 'Mật khẩu',
                  helper: 'Có phân biệt chữ hoa, chữ thường',
                  icon: Icons.lock_outline_rounded,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  enabled: !auth.busy,
                  onSubmitted: _submit,
                  validator: (v) => v.isEmpty ? 'Vui lòng nhập mật khẩu' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (error != null) ...[
                  InlineErrorBanner(message: error, hint: errorHintFor(error)),
                  const SizedBox(height: AppSpacing.lg),
                ],
                PrimaryButton(
                  label: 'Đăng nhập',
                  icon: Icons.login_rounded,
                  loading: auth.busy,
                  onPressed: auth.busy ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text('Chưa có tài khoản?',
                          style: text.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                    TextButton(
                      onPressed: auth.busy ? null : _openRegister,
                      child: const Text('Đăng ký'),
                    ),
                  ],
                ),
                TextButton(
                  onPressed:
                      auth.busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Chơi với tư cách khách'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
