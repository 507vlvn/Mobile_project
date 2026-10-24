import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/primary_button.dart';
import '../model/cube_model.dart';
import '../render/rubik_3d_view.dart';
import '../scanner/camera_scanner_view.dart';
import '../services/cube_validator.dart';
import '../services/offline_rubik_solver.dart';
import '../widgets/cube_net.dart';
import 'solve_player_screen.dart';

enum _StageView { cube3d, net }

/// Quét & giải: Quét 6 mặt → Kiểm tra (sơ đồ phẳng + báo lỗi cụ thể) → Giải.
class ScanSolveScreen extends StatefulWidget {
  const ScanSolveScreen({super.key});

  @override
  State<ScanSolveScreen> createState() => _ScanSolveScreenState();
}

class _ScanSolveScreenState extends State<ScanSolveScreen> {
  final _cubeKey = GlobalKey<Rubik3DViewState>();
  Cube3DState _cube = Cube3DState();
  bool _hasInput = false; // đã quét / tô ít nhất một lần
  bool _paintMode = false;
  Color _pen = RubikColors.red;
  _StageView _view = _StageView.cube3d;
  bool _solving = false;
  List<CubeIssue> _issues = const [];
  bool _showAllIssues = false;

  int get _step => !_hasInput ? 0 : (_issues.isEmpty ? 2 : 1);

  void _revalidate() {
    _issues = validateCube(_cube);
  }

  void _changed() {
    setState(() {
      _hasInput = true;
      _revalidate();
    });
  }

  Future<void> _openCameraScanner() async {
    final result = await Navigator.push<Cube3DState>(
      context,
      MaterialPageRoute(builder: (_) => CameraScannerView(initialState: _cube)),
    );
    if (result == null || !mounted) return;
    setState(() {
      _cube = result;
      _view = _StageView.net;
      _paintMode = false;
    });
    _changed();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(_issues.isEmpty
            ? 'Đã nhận 6 mặt — khối hợp lệ, sẵn sàng giải!'
            : 'Đã nhận 6 mặt — có ${_issues.length} chỗ cần kiểm tra lại.'),
      ));
  }

  Future<void> _editFace(String face) async {
    final colors =
        await showFaceEditor(context, face: face, colors: _cube.faces[face]!);
    if (colors == null || !mounted) return;
    _cube.faces[face] = colors;
    _changed();
  }

  void _paint(String face, int index) {
    if (index == 4) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Ô tâm cố định, không đổi màu được.')));
      return;
    }
    _cube.setColor(face, index, _pen);
    _changed();
  }

  void _scrambleDemo() {
    final rnd = math.Random();
    final cube = Cube3DState();
    for (var i = 0; i < 20; i++) {
      cube.applyMove(kFaceMoves[rnd.nextInt(kFaceMoves.length)]);
    }
    setState(() => _cube = cube);
    _changed();
  }

  Future<void> _reset() async {
    if (_hasInput) {
      final ok = await confirmExit(
        context,
        title: 'Đặt lại khối?',
        message: 'Kết quả quét và các ô đã tô sẽ bị xoá.',
        confirmLabel: 'Đặt lại',
        cancelLabel: 'Giữ lại',
      );
      if (!ok) return;
    }
    setState(() {
      _cube = Cube3DState();
      _hasInput = false;
      _issues = const [];
      _view = _StageView.cube3d;
    });
    _cubeKey.currentState?.resetCamera();
  }

  Future<void> _solve() async {
    if (_cube.isSolved) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text(
              'Khối đang ở trạng thái đã giải. Hãy quét khối thật của bạn trước.'),
        ));
      return;
    }
    setState(() => _solving = true);
    final result =
        await OfflineRubikSolver.solveFromSideColors(_cube.toSideColorCode());
    if (!mounted) return;
    setState(() => _solving = false);
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result.errorMessage ?? 'Không giải được khối này.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SolvePlayerScreen(
          initialCubeState: _cube.clone(),
          moves: result.moves,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasInput,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmExit(
          context,
          title: 'Thoát màn Quét & giải?',
          message: 'Kết quả quét hiện tại sẽ bị bỏ.',
          confirmLabel: 'Thoát',
          cancelLabel: 'Ở lại',
        );
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quét & giải'),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Tuỳ chọn',
              onSelected: (v) {
                if (v == 'demo') _scrambleDemo();
                if (v == 'reset') _reset();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'demo',
                  child: ListTile(
                    leading: Icon(Icons.shuffle_rounded),
                    title: Text('Xáo ngẫu nhiên (thử nghiệm)'),
                  ),
                ),
                PopupMenuItem(
                  value: 'reset',
                  child: ListTile(
                    leading: Icon(Icons.restart_alt_rounded),
                    title: Text('Đặt lại khối'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                child: _StepIndicator(current: _step),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<_StageView>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: _StageView.cube3d,
                            icon: Icon(Icons.view_in_ar_rounded),
                            label: Text('Khối 3D'),
                          ),
                          ButtonSegment(
                            value: _StageView.net,
                            icon: Icon(Icons.grid_view_rounded),
                            label: Text('Sơ đồ phẳng'),
                          ),
                        ],
                        selected: {_view},
                        onSelectionChanged: (s) =>
                            setState(() => _view = s.first),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _buildStage()),
              _buildIssues(),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStage() {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final highlighted = {for (final i in _issues) ...i.stickers};

    if (_view == _StageView.net) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: CubeNet(
                  state: _cube,
                  highlighted: highlighted,
                  onFaceTap: _editFace,
                ),
              ),
            ),
            Text(
              'Chạm vào một mặt để sửa màu',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final size =
          math.min(c.maxWidth - AppSpacing.screen * 2, c.maxHeight - 64);
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Rubik3DView(
                key: _cubeKey,
                state: _cube,
                size: size.clamp(160.0, 420.0),
                onStickerTap: _paintMode ? _paint : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: Row(
              children: [
                FilterChip(
                  avatar: Icon(
                      _paintMode ? Icons.brush_rounded : Icons.brush_outlined,
                      size: 18),
                  label: const Text('Tô màu'),
                  selected: _paintMode,
                  showCheckmark: false,
                  onSelected: (v) => setState(() => _paintMode = v),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _paintMode
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final c in RubikColors.all)
                                _PaletteDot(
                                  color: c,
                                  selected: c == _pen,
                                  onTap: () => setState(() => _pen = c),
                                ),
                            ],
                          ),
                        )
                      : Text(
                          'Vuốt để xoay góc nhìn',
                          style: text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildIssues() {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final palette = context.palette;

    Widget child;
    if (!_hasInput) {
      child = _InfoCard(
        key: const ValueKey('intro'),
        icon: Icons.photo_camera_outlined,
        color: scheme.primary,
        title: 'Bắt đầu bằng việc quét 6 mặt',
        body:
            'Cầm khối với tâm Đỏ hướng về bạn, tâm Vàng ở trên. Hoặc bật "Tô màu" để nhập tay.',
      );
    } else if (_issues.isEmpty) {
      child = _InfoCard(
        key: const ValueKey('ok'),
        icon: Icons.check_circle_rounded,
        color: palette.success,
        title: 'Khối hợp lệ',
        body:
            'Mọi màu đều đủ 9 ô và từng viên đều tồn tại. Bấm "Giải khối" để xem lời giải.',
      );
    } else {
      final shown = _showAllIssues ? _issues : _issues.take(1).toList();
      child = Container(
        key: ValueKey('issues-${_issues.length}-$_showAllIssues'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: scheme.error.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final issue in shown) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: scheme.error, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(issue.message,
                            style: text.labelLarge
                                ?.copyWith(color: scheme.onErrorContainer)),
                        Text(issue.hint,
                            style: text.bodySmall
                                ?.copyWith(color: scheme.onErrorContainer)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            if (_issues.length > 1)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      setState(() => _showAllIssues = !_showAllIssues),
                  child: Text(_showAllIssues
                      ? 'Thu gọn'
                      : 'Xem thêm ${_issues.length - 1} lỗi'),
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, 0),
      child: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.normal),
        child: child,
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _openCameraScanner,
            icon: const Icon(Icons.photo_camera_rounded),
            label: Text(_hasInput ? 'Quét lại' : 'Quét'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: PrimaryButton(
              label: 'Giải khối',
              icon: Icons.auto_awesome_rounded,
              loading: _solving,
              onPressed: _hasInput && _issues.isEmpty ? _solve : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    const labels = ['Quét', 'Kiểm tra', 'Giải'];

    return Semantics(
      label: 'Bước ${current + 1} trên 3: ${labels[current]}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  color: i <= current ? scheme.primary : scheme.outlineVariant,
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: i <= current
                      ? scheme.primary
                      : scheme.surfaceContainerHigh,
                  child: i < current
                      ? Icon(Icons.check_rounded,
                          size: 16, color: scheme.onPrimary)
                      : Text(
                          '${i + 1}',
                          style: text.labelMedium?.copyWith(
                            color: i <= current
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                Text(
                  labels[i],
                  style: text.labelLarge?.copyWith(
                    color: i == current
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _InfoCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.labelLarge),
                Text(body,
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _PaletteDot(
      {required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Bút màu ${RubikColors.nameOf(color)}',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: SizedBox.square(
          dimension: kMinTouchTarget,
          child: Center(
            child: Container(
              width: selected ? 36 : 30,
              height: selected ? 36 : 30,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outline,
                  width: selected ? 3 : 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
