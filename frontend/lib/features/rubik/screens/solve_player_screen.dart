import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../model/cube_model.dart';
import '../render/rubik_3d_view.dart';
import '../services/move_describer.dart';

/// Trình phát lời giải từng bước có hoạt ảnh 3D.
class SolvePlayerScreen extends StatefulWidget {
  final Cube3DState initialCubeState;
  final List<String> moves;

  const SolvePlayerScreen({
    super.key,
    required this.initialCubeState,
    required this.moves,
  });

  @override
  State<SolvePlayerScreen> createState() => _SolvePlayerScreenState();
}

enum _Speed {
  slow('0.5×', Duration(milliseconds: 900)),
  normal('1×', Duration(milliseconds: 500)),
  fast('2×', Duration(milliseconds: 250));

  const _Speed(this.label, this.duration);
  final String label;
  final Duration duration;
}

class _SolvePlayerScreenState extends State<SolvePlayerScreen> {
  final _cubeKey = GlobalKey<Rubik3DViewState>();
  final _stripController = ScrollController();

  late final Cube3DState _initial = widget.initialCubeState.clone();
  late Cube3DState _display = _initial.clone();

  int _step = 0;
  bool _playing = false;
  bool _busy = false;
  _Speed _speed = _Speed.normal;

  List<String> get _moves => widget.moves;
  bool get _finished => _step >= _moves.length;

  @override
  void dispose() {
    _playing = false;
    _stripController.dispose();
    super.dispose();
  }

  void _scrollStripToCurrent() {
    if (!_stripController.hasClients) return;
    const itemExtent = 56.0;
    final target = (_step * itemExtent) -
        (_stripController.position.viewportDimension / 2) +
        itemExtent / 2;
    _stripController.animateTo(
      target.clamp(0.0, _stripController.position.maxScrollExtent),
      duration: AppMotion.of(context, AppMotion.normal),
      curve: AppMotion.standard,
    );
  }

  Future<void> _next() async {
    if (_finished || _busy) return;
    final view = _cubeKey.currentState;
    if (view == null) return;
    _busy = true;
    await view.animateMove(_moves[_step], duration: _speed.duration);
    _busy = false;
    if (!mounted) return;
    setState(() => _step++);
    _scrollStripToCurrent();
    if (_finished) {
      _playing = false;
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _previous() async {
    if (_step <= 0 || _busy) return;
    setState(() => _playing = false);
    final view = _cubeKey.currentState;
    if (view == null) return;
    _busy = true;
    await view.animateMove(_moves[_step - 1],
        duration: _speed.duration, isReverse: true);
    _busy = false;
    if (!mounted) return;
    setState(() => _step--);
    _scrollStripToCurrent();
  }

  void _jumpTo(int target) {
    if (_busy) return;
    setState(() {
      _playing = false;
      _step = target.clamp(0, _moves.length);
      _display = _initial.clone()..applyMoves(_moves.take(_step));
    });
    _scrollStripToCurrent();
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      setState(() => _playing = false);
      return;
    }
    if (_finished) _jumpTo(0);
    setState(() => _playing = true);
    while (_playing && !_finished && mounted) {
      await _next();
      if (!_playing || !mounted) break;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final front = RubikColors.nameOf(_initial.faces['front']![4]);
    final top = RubikColors.nameOf(_initial.faces['top']![4]);
    final idle = !_playing && !_busy && !_finished;

    return Scaffold(
      appBar: AppBar(
        title: Text('Lời giải · ${_moves.length} bước'),
        actions: [
          IconButton(
            tooltip: 'Đặt lại góc nhìn',
            icon: const Icon(Icons.threed_rotation_rounded),
            onPressed: () => _cubeKey.currentState?.resetCamera(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Tư thế cầm khối
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
              child: Row(
                children: [
                  Icon(Icons.pan_tool_alt_outlined,
                      size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Cầm khối: tâm $front hướng về bạn, tâm $top ở trên',
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildStepCard(),
            const SizedBox(height: AppSpacing.sm),
            _buildMoveStrip(),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final size = (c.maxWidth - AppSpacing.screen * 2)
                    .clamp(160.0, c.maxHeight);
                return Center(
                  child: Rubik3DView(
                    key: _cubeKey,
                    state: _display,
                    size: size,
                    hintMove: idle ? _moves[_step] : null,
                  ),
                );
              }),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard() {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final palette = context.palette;

    final finished = _finished;
    final move = finished ? null : _moves[_step];
    final d = move == null ? null : describeMove(move, _display);
    final bg = finished
        ? palette.success.withValues(alpha: 0.15)
        : scheme.primaryContainer;
    final fg = finished ? scheme.onSurface : scheme.onPrimaryContainer;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: finished ? palette.success : scheme.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: finished
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 32)
                : Text(move!,
                    style:
                        text.headlineSmall?.copyWith(color: scheme.onPrimary)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finished
                      ? 'Hoàn thành!'
                      : 'Bước ${_step + 1} / ${_moves.length}',
                  style: text.labelLarge
                      ?.copyWith(color: fg, fontFeatures: kTabularFigures),
                ),
                Text(
                  finished ? 'Khối Rubik đã được giải.' : d!.title,
                  style: text.titleSmall?.copyWith(color: fg),
                ),
                if (!finished)
                  Text(d!.action, style: text.bodyMedium?.copyWith(color: fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveStrip() {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 48,
      child: ListView.builder(
        controller: _stripController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        itemExtent: 56,
        itemCount: _moves.length,
        itemBuilder: (context, i) {
          final done = i < _step;
          final current = i == _step;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              button: true,
              selected: current,
              label: 'Bước ${i + 1}: ${_moves[i]}${done ? ', đã xong' : ''}',
              excludeSemantics: true,
              child: Material(
                color: current
                    ? scheme.primary
                    : (done ? scheme.surfaceContainerHigh : scheme.surface),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  side: BorderSide(
                    color: current ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: () => _jumpTo(i),
                  child: Center(
                    child: Text(
                      _moves[i],
                      style: text.labelLarge?.copyWith(
                        color: current
                            ? scheme.onPrimary
                            : (done
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface),
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControls() {
    final scheme = Theme.of(context).colorScheme;
    final total = _moves.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: _step.toDouble(),
            min: 0,
            max: total > 0 ? total.toDouble() : 1,
            divisions: total > 0 ? total : 1,
            label: '$_step / $total',
            onChanged: (v) => _jumpTo(v.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'Về đầu',
                icon: const Icon(Icons.first_page_rounded),
                onPressed: _step > 0 ? () => _jumpTo(0) : null,
              ),
              IconButton(
                tooltip: 'Bước trước',
                iconSize: 32,
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: _step > 0 ? _previous : null,
              ),
              IconButton.filled(
                tooltip: _playing
                    ? 'Tạm dừng'
                    : (_finished ? 'Phát lại từ đầu' : 'Tự động phát'),
                iconSize: 36,
                style: IconButton.styleFrom(minimumSize: const Size(64, 64)),
                icon: Icon(_playing
                    ? Icons.pause_rounded
                    : (_finished
                        ? Icons.replay_rounded
                        : Icons.play_arrow_rounded)),
                onPressed: total > 0 ? _togglePlay : null,
              ),
              IconButton(
                tooltip: 'Bước tiếp',
                iconSize: 32,
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: !_finished ? _next : null,
              ),
              IconButton(
                tooltip: 'Đến cuối',
                icon: const Icon(Icons.last_page_rounded),
                onPressed: !_finished ? () => _jumpTo(total) : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<_Speed>(
            showSelectedIcon: false,
            segments: [
              for (final s in _Speed.values)
                ButtonSegment(value: s, label: Text(s.label)),
            ],
            selected: {_speed},
            onSelectionChanged: (s) => setState(() => _speed = s.first),
          ),
        ],
      ),
    );
  }
}
