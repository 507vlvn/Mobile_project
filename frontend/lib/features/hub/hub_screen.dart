import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../caro/caro_screen.dart';
import '../puzzle/puzzle_screen.dart';
import '../rubik/screens/rubik_home_screen.dart';
import '../sudoku/sudoku_screen.dart';

/// Thông tin một game hiển thị trên Hub.
class _GameEntry {
  final String code;
  final String name;
  final String tagline;
  final IconData icon;
  final Color color;
  final WidgetBuilder? builder; // null = chưa phát hành

  const _GameEntry({
    required this.code,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.color,
    this.builder,
  });
}

final _games = <_GameEntry>[
  _GameEntry(
    code: 'RUBIK',
    name: 'Rubik 3D',
    tagline: 'Vuốt để xoay tầng, luyện giải hoặc quét khối thật',
    icon: Icons.view_in_ar_rounded,
    color: const Color(0xFF7C3AED),
    builder: (_) => const RubikHomeScreen(),
  ),
  _GameEntry(
    code: 'SUDOKU',
    name: 'Sudoku',
    tagline: 'Điền số 1–9, mỗi đề chỉ có một lời giải',
    icon: Icons.grid_3x3_rounded,
    color: const Color(0xFF2563EB),
    builder: (_) => const SudokuScreen(),
  ),
  _GameEntry(
    code: 'PUZZLE',
    name: 'Xếp hình',
    tagline: 'Trượt các ô số về đúng thứ tự',
    icon: Icons.apps_rounded,
    color: const Color(0xFFD97706),
    builder: (_) => const PuzzleScreen(),
  ),
  _GameEntry(
    code: 'CARO',
    name: 'Caro',
    tagline: 'Đấu trí với máy, 5 quân liên tiếp là thắng',
    icon: Icons.grid_on_rounded,
    color: const Color(0xFF0D9488),
    builder: (_) => const CaroScreen(),
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
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
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

  bool get _available => entry.builder != null;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (_available) {
            Navigator.of(context).push(MaterialPageRoute(builder: entry.builder!));
          } else {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text('${entry.name} đang được phát triển, sắp ra mắt!')),
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
                  color: entry.color.withValues(alpha: _available ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(
                  entry.icon,
                  size: 32,
                  color: entry.color.withValues(alpha: _available ? 1 : 0.5),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(entry.name, style: text.titleMedium)),
                        if (!_available) ...[
                          const SizedBox(width: AppSpacing.sm),
                          _Badge(label: 'Sắp ra mắt', color: scheme.onSurfaceVariant),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.tagline,
                      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: _available ? scheme.onSurfaceVariant : scheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
