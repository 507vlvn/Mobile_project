import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../model/cube_model.dart';
import '../render/rubik_3d_view.dart';
import '../practice/practice_screen.dart';
import 'scan_solve_screen.dart';

/// Màn chọn chế độ Rubik: Luyện giải / Quét & giải.
class RubikHomeScreen extends StatefulWidget {
  const RubikHomeScreen({super.key});

  @override
  State<RubikHomeScreen> createState() => _RubikHomeScreenState();
}

class _RubikHomeScreenState extends State<RubikHomeScreen> {
  final _previewState = Cube3DState();

  void _openPractice() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PracticeScreen()),
    );
  }

  void _openScan() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScanSolveScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      appBar: AppBar(title: const Text('Rubik 3D')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.xl,
          ),
          children: [
            // Khối Rubik minh hoạ — có thể vuốt để xoay góc nhìn
            Container(
              height: (width * 0.7).clamp(220.0, 320.0),
              decoration: BoxDecoration(
                color: context.palette.stage,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              alignment: Alignment.center,
              child: Rubik3DView(
                state: _previewState,
                size: (width * 0.7).clamp(220.0, 320.0),
                enableInteraction: true,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Chọn chế độ', style: text.titleLarge),
            const SizedBox(height: AppSpacing.md),
            _ModeCard(
              icon: Icons.swipe_rounded,
              title: 'Luyện giải',
              description:
                  'App xáo đề theo độ khó, bạn tự vuốt để giải. Bí thì dùng gợi ý (mỗi lần trừ 15% điểm).',
              highlight: true,
              onTap: _openPractice,
            ),
            const SizedBox(height: AppSpacing.md),
            _ModeCard(
              icon: Icons.photo_camera_rounded,
              title: 'Quét & giải',
              description:
                  'Quét 6 mặt khối Rubik thật bằng camera, app chỉ từng bước để giải.',
              onTap: _openScan,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Mẹo: vuốt ở vùng trống quanh khối để xoay góc nhìn.',
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool highlight;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final bg = highlight ? scheme.primary : scheme.surface;
    final fg = highlight ? scheme.onPrimary : scheme.onSurface;
    final fgMuted = highlight
        ? scheme.onPrimary.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;

    return Material(
      color: bg,
      clipBehavior: Clip.antiAlias,
      elevation: highlight && scheme.brightness == Brightness.light ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: highlight
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: highlight
                      ? scheme.onPrimary.withValues(alpha: 0.18)
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color:
                      highlight ? scheme.onPrimary : scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium?.copyWith(color: fg)),
                    const SizedBox(height: 2),
                    Text(description,
                        style: text.bodyMedium?.copyWith(color: fgMuted)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.arrow_forward_rounded, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
