import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_tokens.dart';

/// Viền khi ô đang focus VÀ đang lỗi (theme chung chưa định nghĩa nên tự đặt,
/// nếu không viền sẽ biến mất).
OutlineInputBorder focusedErrorBorderOf(BuildContext context) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide:
          BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
    );

/// Ô nhập có nhãn hiển thị rõ, kiểm tra lỗi khi rời ô (blur) và khi gửi form.
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String helper;
  final IconData icon;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final bool obscure;
  final String? Function(String value) validator;
  final VoidCallback? onSubmitted;
  final FocusNode? focusNode;
  final bool enabled;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.helper,
    required this.icon,
    required this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.autofillHints = const [],
    this.obscure = false,
    this.onSubmitted,
    this.focusNode,
    this.enabled = true,
  });

  @override
  State<AuthTextField> createState() => AuthTextFieldState();
}

class AuthTextFieldState extends State<AuthTextField> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _hidden = true;
  bool _hadFocus = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      _hadFocus = true;
    } else if (_hadFocus) {
      _fieldKey.currentState?.validate(); // kiểm tra khi rời ô
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextFormField(
      key: _fieldKey,
      controller: widget.controller,
      focusNode: _focus,
      enabled: widget.enabled,
      obscureText: widget.obscure && _hidden,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      autocorrect: false,
      enableSuggestions: !widget.obscure,
      inputFormatters: [LengthLimitingTextInputFormatter(120)],
      validator: (v) => widget.validator(v ?? ''),
      // Khi đang hiện lỗi, xóa lỗi ngay khi người dùng sửa đúng
      onChanged: (_) {
        final s = _fieldKey.currentState;
        if (s != null && s.hasError) s.validate();
      },
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        helperMaxLines: 2,
        errorMaxLines: 3,
        focusedErrorBorder: focusedErrorBorderOf(context),
        prefixIcon: Icon(widget.icon),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                constraints: const BoxConstraints(
                    minWidth: kMinTouchTarget, minHeight: kMinTouchTarget),
                icon: Icon(
                  _hidden
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}

/// Khung báo lỗi ngay phía trên nút: icon + nội dung + gợi ý khắc phục.
class InlineErrorBanner extends StatelessWidget {
  final String message;
  final String? hint;

  const InlineErrorBanner({super.key, required this.message, this.hint});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded,
                color: scheme.onErrorContainer, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      hint!,
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onErrorContainer),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gợi ý cách khắc phục tuỳ loại lỗi.
String? errorHintFor(String message) {
  if (message.contains('mạng') || message.contains('máy chủ')) {
    return 'Bật Wi-Fi/4G rồi bấm lại. Bạn vẫn có thể chơi với tư cách khách.';
  }
  if (message.contains('quá nhanh')) {
    return 'Chờ khoảng một phút rồi thử lại.';
  }
  if (message.toLowerCase().contains('mật khẩu') ||
      message.toLowerCase().contains('đăng nhập')) {
    return 'Kiểm tra lại tên đăng nhập/email và mật khẩu (có phân biệt chữ hoa, chữ thường).';
  }
  return null;
}
