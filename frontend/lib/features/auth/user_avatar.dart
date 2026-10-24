import 'package:flutter/material.dart';

/// Chữ cái đầu của tên (tối đa 2 ký tự), vd "Nguyễn Văn An" -> "NA".
String initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  String first(String s) => String.fromCharCode(s.runes.first).toUpperCase();
  if (parts.length == 1) return first(parts.first);
  return first(parts.first) + first(parts.last);
}

/// Avatar tròn hiển thị chữ cái đầu.
class UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool highlight;

  const UserAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = highlight ? scheme.primary : scheme.primaryContainer;
    final fg = highlight ? scheme.onPrimary : scheme.onPrimaryContainer;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Text(
          initialsOf(name),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: fg,
                fontSize: size * 0.38 < 12 ? 12 : size * 0.38,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
