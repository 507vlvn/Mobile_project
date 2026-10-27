import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../core/widgets/feedback_states.dart';
import 'profile_controller.dart';
import 'profile_screen.dart';

/// Toàn bộ lịch sử trận, tự tải trang tiếp khi cuộn gần cuối.
/// Dùng chung [ProfileController] với màn Hồ sơ nên không tải lại trang đầu.
class MatchHistoryScreen extends StatelessWidget {
  final ProfileController pc;
  const MatchHistoryScreen({super.key, required this.pc});

  /// Cách đáy bao nhiêu px thì tải trang tiếp.
  static const _loadAheadPx = 400.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử trận đấu')),
      body: ListenableBuilder(
        listenable: pc,
        builder: (context, _) {
          if (pc.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (pc.matches.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                if (pc.error != null)
                  ErrorState(message: pc.error!, onRetry: pc.load)
                else
                  const MatchHistoryEmpty(),
              ],
            );
          }
          final matches = pc.matches;
          return NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < _loadAheadPx) pc.loadMore();
              return false;
            },
            child: RefreshIndicator(
              onRefresh: pc.load,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.screen),
                itemCount: matches.length + 2,
                itemBuilder: (context, i) {
                  if (i == 0) return _Header(shown: matches.length, total: pc.totalMatches);
                  if (i <= matches.length) return MatchHistoryTile(match: matches[i - 1]);
                  return _Footer(pc: pc);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int shown;
  final int total;
  const _Header({required this.shown, required this.total});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        'Đã tải $shown / $total trận',
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// Đang tải: vòng xoay. Còn trang (ví dụ danh sách chưa đầy màn hình,
/// hoặc lần tải trước lỗi): nút tải thêm. Hết: dòng kết thúc.
class _Footer extends StatelessWidget {
  final ProfileController pc;
  const _Footer({required this.pc});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (pc.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (pc.hasMoreMatches) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(kMinTouchTarget),
            foregroundColor: scheme.secondary,
          ),
          onPressed: pc.loadMore,
          child: const Text('Tải thêm'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        'Đã hiện hết lịch sử',
        textAlign: TextAlign.center,
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
