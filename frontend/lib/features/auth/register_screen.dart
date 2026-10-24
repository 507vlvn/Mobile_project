import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_controller.dart';
import 'auth_widgets.dart';

/// Màn đăng ký. Trả về `true` qua Navigator.pop khi thành công.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _fullName = TextEditingController();
  final _pass = TextEditingController();

  static final _usernameRe = RegExp(r'^[a-zA-Z0-9_]+$');
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthController>().clearError();
    });
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _fullName.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthController>();
    if (auth.busy) return;
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final ok = await auth.register(
      username: _username.text,
      email: _email.text,
      password: _pass.text,
      fullName: _fullName.text,
    );
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Xin chào, ${auth.currentUser?.displayName ?? ''}!'),
    ));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final error = auth.lastError;

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                Text('Tạo tài khoản', style: text.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Miễn phí, chỉ mất một phút.',
                  style:
                      text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xl),
                AuthTextField(
                  controller: _username,
                  label: 'Tên đăng nhập',
                  helper: '3–50 ký tự: chữ, số hoặc dấu gạch dưới',
                  icon: Icons.person_outline_rounded,
                  autofillHints: const [AutofillHints.newUsername],
                  enabled: !auth.busy,
                  validator: (v) {
                    final s = v.trim();
                    if (s.isEmpty) return 'Vui lòng nhập tên đăng nhập';
                    if (s.length < 3 || s.length > 50) {
                      return 'Tên đăng nhập phải từ 3 đến 50 ký tự';
                    }
                    if (!_usernameRe.hasMatch(s)) {
                      return 'Chỉ dùng chữ, số và dấu gạch dưới (không dấu cách)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthTextField(
                  controller: _email,
                  label: 'Email',
                  helper: 'Dùng để khôi phục tài khoản',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  enabled: !auth.busy,
                  validator: (v) {
                    final s = v.trim();
                    if (s.isEmpty) return 'Vui lòng nhập email';
                    if (!_emailRe.hasMatch(s)) {
                      return 'Email chưa đúng, ví dụ: ten@email.com';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthTextField(
                  controller: _fullName,
                  label: 'Tên hiển thị (không bắt buộc)',
                  helper: 'Tên sẽ hiện trên bảng xếp hạng',
                  icon: Icons.badge_outlined,
                  autofillHints: const [AutofillHints.name],
                  enabled: !auth.busy,
                  validator: (v) => v.trim().length > 100
                      ? 'Tên hiển thị tối đa 100 ký tự'
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthTextField(
                  controller: _pass,
                  label: 'Mật khẩu',
                  helper: 'Từ 6 đến 72 ký tự',
                  icon: Icons.lock_outline_rounded,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  enabled: !auth.busy,
                  onSubmitted: _submit,
                  validator: (v) {
                    if (v.isEmpty) return 'Vui lòng nhập mật khẩu';
                    if (v.length < 6) {
                      return 'Mật khẩu phải có ít nhất 6 ký tự';
                    }
                    if (v.length > 72) return 'Mật khẩu tối đa 72 ký tự';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                if (error != null) ...[
                  InlineErrorBanner(message: error, hint: errorHintFor(error)),
                  const SizedBox(height: AppSpacing.lg),
                ],
                PrimaryButton(
                  label: 'Đăng ký',
                  icon: Icons.person_add_alt_1_rounded,
                  loading: auth.busy,
                  onPressed: auth.busy ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text('Đã có tài khoản?',
                          style: text.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                    TextButton(
                      onPressed: auth.busy
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      child: const Text('Đăng nhập'),
                    ),
                  ],
                ),
                TextButton(
                  onPressed:
                      auth.busy ? null : () => Navigator.of(context).pop(false),
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
