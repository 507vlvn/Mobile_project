import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/feedback_states.dart';
import 'game_meta.dart';

/// Lịch sử chơi của tôi: lọc theo game, tải thêm khi cuộn gần cuối.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _pageSize = 20;

  final _scroll = ScrollController();
  final List<HistoryItem> _items = [];
  String? _filter; // null = tất cả
  int _page = 0;
  int _total = 0;
  bool _loading = false; // đang tải trang đầu
  bool _loadingMore = false;
  String? _error; // lỗi trang đầu
  String? _moreError; // lỗi khi tải thêm
  int _requestId = 0; // bỏ qua phản hồi cũ khi đổi bộ lọc

  bool get _hasMore => _items.length < _total;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirst();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 300) _loadMore();
  }

  Future<void> _loadFirst() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _moreError = null;
      _loadingMore = false;
    });
    try {
      final r = await context
          .read<ApiClient>()
          .myHistory(gameCode: _filter, page: 1, pageSize: _pageSize);
      if (!mounted || id != _requestId) return;
      setState(() {
        _items
          ..clear()
          ..addAll(r.items);
        _page = 1;
        _total = r.total;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _error != null) return;
    final id = _requestId;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final r = await context
          .read<ApiClient>()
          .myHistory(gameCode: _filter, page: _page + 1, pageSize: _pageSize);
      if (!mounted || id != _requestId) return;
      setState(() {
        _items.addAll(r.items);
        _page += 1;
        _total = r.total;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _moreError = e.message;
        _loadingMore = false;
      });
    }
  }

  void _setFilter(String? code) {
    if (code == _filter) return;
    _filter = code;
    _loadFirst();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử chơi')),
      body: Column(
        children: [
          _FilterBar(selected: _filter, onSelected: _setFilter),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _loadFirst);
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFirst,
        child: LayoutBuilder(
          builder: (context, c) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: c.maxHeight,
                child: EmptyState(
                  icon: Icons.history_rounded,
                  title: _filter == null
                      ? 'Chưa có ván nào'
                      : 'Chưa có ván nào của game này',
                  message: 'Chơi một ván rồi quay lại đây để xem kết quả.',
                ),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFirst,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xl),
        itemCount: _items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) {
          if (i < _items.length) return HistoryRow(item: _items[i]);
          return _Footer(
            loading: _loadingMore,
            error: _moreError,
            hasMore: _hasMore,
            onRetry: _loadMore,
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;
  const _FilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screen, vertical: AppSpacing.sm),
        children: [
          _chip('Tất cả', null, null),
          for (final g in GameMeta.all) _chip(g.name, g.code, g.icon),
        ],
      ),
    );
  }

  Widget _chip(String label, String? code, IconData? icon) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        avatar: icon == null ? null : Icon(icon, size: 18),
        selected: selected == code,
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        onSelected: (_) => onSelected(code),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final bool loading;
  final String? error;
  final bool hasMore;
  final VoidCallback onRetry;
  const _Footer({
    required this.loading,
    required this.error,
    required this.hasMore,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
      );
    }
    if (error != null) {
      return Column(
        children: [
          Text(error!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.error)),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      );
    }
    if (!hasMore) return const SizedBox(height: AppSpacing.sm);
    return const SizedBox(height: AppSpacing.lg);
  }
}

/// Một dòng lịch sử.
class HistoryRow extends StatelessWidget {
  final HistoryItem item;
  const HistoryRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final meta = GameMeta.of(item.gameCode);
    final muted = scheme.onSurfaceVariant;
    final diff = item.difficultyName;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(meta.icon, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diff == null ? meta.name : '${meta.name} · $diff',
                    style: text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ResultChip(result: item.result),
                      _Meta(Icons.timer_outlined,
                          formatDuration(item.timeSpentSeconds),
                          semantic:
                              'Thời gian ${formatDuration(item.timeSpentSeconds)}'),
                      _Meta(Icons.close_rounded, '${item.mistakesCount}',
                          semantic: '${item.mistakesCount} lỗi'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(relativeTimeVi(item.playedAt),
                      style: text.bodySmall?.copyWith(color: muted)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.score}',
                  style: text.titleMedium?.copyWith(
                    fontFeatures: kTabularFigures,
                    color: scheme.secondary,
                  ),
                ),
                Text('điểm', style: text.bodySmall?.copyWith(color: muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String value;
  final String semantic;
  const _Meta(this.icon, this.value, {required this.semantic});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: semantic,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: muted),
            const SizedBox(width: 2),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: muted, fontFeatures: kTabularFigures)),
          ],
        ),
      ),
    );
  }
}

/// Chip kết quả: luôn có icon + chữ (không chỉ dựa vào màu).
class ResultChip extends StatelessWidget {
  final String result;
  const ResultChip({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final (String label, IconData icon, Color color) = switch (result) {
      'COMPLETED' => (
          'Hoàn thành',
          Icons.check_circle_rounded,
          palette.success
        ),
      'WIN' => ('Thắng', Icons.emoji_events_rounded, palette.success),
      'LOSE' => ('Thua', Icons.cancel_rounded, scheme.error),
      'DRAW' => ('Hòa', Icons.drag_handle_rounded, palette.warning),
      'ABANDONED' => ('Bỏ cuộc', Icons.flag_rounded, palette.onSurfaceMuted),
      _ => (result, Icons.help_outline_rounded, palette.onSurfaceMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: scheme.onSurface)),
        ],
      ),
    );
  }
}
