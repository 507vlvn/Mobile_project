import 'package:flutter/material.dart';

import '../caro/caro_screen.dart';
import '../soduku/ui/sudoku_home_screen.dart';
import '../core/theme/app_tokens.dart';
import '../rubik/screens/rubik_home_screen.dart';
import '../XepHinh/xep_hinh_screen.dart';

/// Thông tin một game hiển thị trên Hub.
class _GameEntry {
  final String code;
  final String name;
  final String tagline;
  final IconData icon;
  final Color color;

  const _GameEntry({
    required this.code,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.color,
  });
}

final _games = <_GameEntry>[
  const _GameEntry(
    code: 'RUBIK',
    name: 'Rubik 3D',
    tagline: 'Vuốt để xoay tầng, luyện giải hoặc quét khối thật',
    icon: Icons.view_in_ar_rounded,
    color: Color(0xFF7C3AED),
  ),
  const _GameEntry(
    code: 'SUDOKU',
    name: 'Sudoku',
    tagline: 'Điền số 1–9, mỗi đề chỉ có một lời giải',
    icon: Icons.grid_3x3_rounded,
    color: Color(0xFF2563EB),
  ),
  const _GameEntry(
    code: 'PUZZLE',
    name: 'Xếp hình & PhaseShift',
    tagline: 'Xếp số trượt, ghép hình Jigsaw và phản ứng nguyên tố',
    icon: Icons.apps_rounded,
    color: Color(0xFFD97706),
  ),
  const _GameEntry(
    code: 'CARO',
    name: 'Caro',
    tagline: 'Đấu trí với máy, 5 quân liên tiếp là thắng',
    icon: Icons.grid_on_rounded,
    color: Color(0xFF0D9488),
  ),
];

class HubScreen extends StatelessWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.xl,
              AppSpacing.screen,
              AppSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chọn trò chơi', style: text.headlineMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Giải nhanh, ít lỗi để lên bảng xếp hạng',
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              0,
              AppSpacing.screen,
              AppSpacing.xl,
            ),
            sliver: SliverList.separated(
              itemCount: _games.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) => _GameCard(entry: _games[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final _GameEntry entry;
  const _GameCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (entry.code == 'RUBIK') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RubikHomeScreen()),
            );
          } else if (entry.code == 'CARO') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CaroScreen()),
            );
          } else if (entry.code == 'SUDOKU') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SudokuHomeScreen()),
            );
          } else if (entry.code == 'PUZZLE') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const XepHinhScreen()),
            );
          } else {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('${entry.name} đang được phát triển, sắp ra mắt!'),
                ),
              );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: entry.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(entry.icon, size: 32, color: entry.color),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.name, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      entry.tagline,
                      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
