import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/cube_model.dart';
import 'cube_3d_painter.dart';
import 'cube_geometry.dart';
import 'turn_gesture.dart';

enum _GestureMode { idle, pending, turning, orbit, multiOrbit }

/// Khối Rubik 3D tương tác.
///
/// Cử chỉ:
/// - Đặt ngón tay lên một ô rồi vuốt → xoay tầng chứa ô đó theo ngón tay,
///   thả ra tự khớp vào nấc 90° gần nhất (vuốt nhanh → xoay luôn 1 nấc).
///   Chỉ bật khi [enableLayerTurns] = true.
/// - Vuốt ở vùng nền hoặc dùng 2 ngón → xoay góc nhìn ([enableInteraction]).
/// - Chạm 1 lần vào ô → [onStickerTap] (chế độ tô màu).
/// - Chạm đúp ở nền → đặt lại góc nhìn (khi không ở chế độ tô màu).
class Rubik3DView extends StatefulWidget {
  final Cube3DState state;
  final double size;
  final bool enableInteraction;
  final bool enableLayerTurns;
  final void Function(String face, int index)? onStickerTap;

  /// Gọi sau khi người dùng xoay xong một tầng (đã cập nhật [state]).
  final ValueChanged<String>? onMove;

  /// Gọi ngay khi người dùng bắt đầu kéo một tầng (để khởi động đồng hồ).
  final VoidCallback? onTurnStart;

  /// Nước đi đang được gợi ý: tầng tương ứng nhấp nháy và "nhún" theo chiều cần xoay.
  final String? hintMove;

  final double? initialPitch;
  final double? initialYaw;

  const Rubik3DView({
    super.key,
    required this.state,
    this.size = 300,
    this.enableInteraction = true,
    this.enableLayerTurns = false,
    this.onStickerTap,
    this.onMove,
    this.onTurnStart,
    this.hintMove,
    this.initialPitch,
    this.initialYaw,
  });

  @override
  Rubik3DViewState createState() => Rubik3DViewState();
}

class Rubik3DViewState extends State<Rubik3DView> with TickerProviderStateMixin {
  static const double _defaultPitch = -0.45;
  static const double _defaultYaw = -0.65; // lộ mặt Trên, Trước, Phải
  static const double _turnSlop = 10; // dp — ngưỡng chống vuốt nhầm
  static const double _orbitSpeed = 0.012;

  late double _pitch = widget.initialPitch ?? _defaultPitch;
  late double _yaw = widget.initialYaw ?? _defaultYaw;

  // ----- Hoạt ảnh xoay tầng (khớp nấc / nước đi tự động) -----
  late final AnimationController _anim;
  LayerTurn? _turn;
  LayerTurn? _animBase;
  double _animFrom = 0;
  double _animTo = 0;
  Curve _animCurve = Curves.easeOutCubic;
  CubeMove? _animCommit;
  bool _animFromUser = false;
  Completer<void>? _animDone;

  // ----- Gợi ý -----
  late final AnimationController _hint;

  // ----- Theo dõi chạm -----
  final Map<int, Offset> _pointers = {};
  _GestureMode _mode = _GestureMode.idle;
  StickerRef? _touchSticker;
  Offset _drag = Offset.zero;
  TurnGesturePlan? _plan;
  VelocityTracker? _velocity;
  Duration? _lastTapTime;
  Offset? _lastTapPos;

  CubeGeometry? _geometry;

  bool get isAnimating => _anim.isAnimating || _mode == _GestureMode.turning;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this)
      ..addListener(_onAnimTick)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _completeAnimation();
      });
    _hint = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _syncHint();
  }

  @override
  void didUpdateWidget(Rubik3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPitch != null && widget.initialPitch != oldWidget.initialPitch) {
      _pitch = widget.initialPitch!;
    }
    if (widget.initialYaw != null && widget.initialYaw != oldWidget.initialYaw) {
      _yaw = widget.initialYaw!;
    }
    if (widget.hintMove != oldWidget.hintMove) _syncHint();
  }

  @override
  void dispose() {
    _anim.dispose();
    _hint.dispose();
    super.dispose();
  }

  void _syncHint() {
    if (widget.hintMove != null && CubeMove.tryParse(widget.hintMove!) != null) {
      if (!_hint.isAnimating) _hint.repeat();
    } else {
      _hint.stop();
      _hint.value = 0;
    }
  }

  // =========================================================================
  // API công khai
  // =========================================================================

  /// Diễn hoạt một nước đi rồi cập nhật [Rubik3DView.state].
  /// [isReverse] = true → diễn hoạt và áp dụng nước ngược lại.
  Future<void> animateMove(
    String move, {
    Duration duration = const Duration(milliseconds: 400),
    bool isReverse = false,
  }) {
    final parsed = CubeMove.tryParse(move);
    if (!mounted || parsed == null || isAnimating) return Future.value();
    final m = isReverse ? parsed.inverse : parsed;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final d = reduceMotion
        ? const Duration(milliseconds: 1)
        : (m.turns == 2 ? duration * 1.3 : duration);
    return _runTurnAnimation(
      base: m.toLayerTurn(progress: 0),
      from: 0,
      to: m.angle,
      duration: d,
      curve: Curves.easeInOutCubic,
      commit: m,
      fromUser: false,
    );
  }

  void resetCamera() {
    setState(() {
      _pitch = _defaultPitch;
      _yaw = _defaultYaw;
    });
  }

  /// Chuyển nhanh góc nhìn tới 1 mặt cụ thể
  void viewFace(String face) {
    setState(() {
      switch (face.toLowerCase()) {
        case 'front':
          _pitch = 0;
          _yaw = 0;
        case 'right':
          _pitch = 0;
          _yaw = -math.pi / 2;
        case 'back':
          _pitch = 0;
          _yaw = -math.pi;
        case 'left':
          _pitch = 0;
          _yaw = math.pi / 2;
        case 'top':
          _pitch = -math.pi / 2 + 0.05;
          _yaw = 0;
        case 'bottom':
          _pitch = math.pi / 2 - 0.05;
          _yaw = 0;
        default:
          _pitch = _defaultPitch;
          _yaw = _defaultYaw;
      }
    });
  }

  // =========================================================================
  // Hoạt ảnh
  // =========================================================================

  Future<void> _runTurnAnimation({
    required LayerTurn base,
    required double from,
    required double to,
    required Duration duration,
    required Curve curve,
    required CubeMove? commit,
    required bool fromUser,
  }) {
    _animBase = base;
    _animFrom = from;
    _animTo = to;
    _animCurve = curve;
    _animCommit = commit;
    _animFromUser = fromUser;
    _animDone = Completer<void>();
    _turn = base.withAngle(from);
    _anim.duration = duration;
    _anim.forward(from: 0);
    return _animDone!.future;
  }

  void _onAnimTick() {
    final base = _animBase;
    if (base == null) return;
    final t = _animCurve.transform(_anim.value);
    setState(() {
      _turn = base.withAngle(_animFrom + (_animTo - _animFrom) * t);
    });
  }

  void _completeAnimation() {
    if (_animBase == null) return;
    final commit = _animCommit;
    final fromUser = _animFromUser;
    _animBase = null;
    _animCommit = null;
    if (commit != null) widget.state.applyCubeMove(commit);
    if (mounted) setState(() => _turn = null);
    final done = _animDone;
    _animDone = null;
    done?.complete();
    if (commit != null && fromUser) {
      HapticFeedback.selectionClick();
      widget.onMove?.call(commit.notation);
    }
  }

  /// Người dùng chạm khi tầng đang khớp nấc → kết thúc ngay để nhận cử chỉ mới.
  void _finishAnimationNow() {
    if (_animBase == null) return;
    _anim.stop();
    _completeAnimation();
  }

  void _snapTo(int quarterTurns) {
    final plan = _plan;
    final current = _turn;
    if (plan == null || current == null) {
      setState(() => _turn = null);
      return;
    }
    final target = quarterTurns * math.pi / 2;
    final delta = (target - current.angle).abs();
    final ms = 90 + (160 * math.min(1.0, delta / (math.pi / 2))).round();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _runTurnAnimation(
      base: current,
      from: current.angle,
      to: target,
      duration: Duration(milliseconds: reduceMotion ? 1 : ms),
      curve: Curves.easeOutCubic,
      commit: CubeMove.fromRotation(
        axis: plan.axis,
        layer: plan.layer,
        quarterTurns: quarterTurns,
      ),
      fromUser: true,
    );
  }

  // =========================================================================
  // Xử lý chạm
  // =========================================================================

  bool get _acceptsInput =>
      widget.enableInteraction || widget.enableLayerTurns || widget.onStickerTap != null;

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;

    if (_pointers.length == 1) {
      // Tầng đang khớp nấc do người dùng → hoàn tất ngay (hoạt ảnh ngắt được)
      if (_animBase != null && _animFromUser) _finishAnimationNow();

      _drag = Offset.zero;
      _plan = null;
      _velocity = VelocityTracker.withKind(e.kind)
        ..addPosition(e.timeStamp, e.localPosition);
      final canTurn = widget.enableLayerTurns && _animBase == null;
      _touchSticker = canTurn ? _geometry?.hitTest(e.localPosition) : null;
      _mode = _GestureMode.pending;
    } else {
      // Ngón thứ hai: huỷ xoay tầng (trả về vị trí cũ) và chuyển sang xoay góc nhìn
      if (_mode == _GestureMode.turning) _snapTo(0);
      _mode = widget.enableInteraction ? _GestureMode.multiOrbit : _GestureMode.idle;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    final last = _pointers[e.pointer];
    if (last == null) return;
    final delta = e.localPosition - last;
    _pointers[e.pointer] = e.localPosition;

    if (_mode == _GestureMode.multiOrbit) {
      _orbit(delta / _pointers.length.toDouble());
      return;
    }

    _velocity?.addPosition(e.timeStamp, e.localPosition);
    _drag += delta;

    switch (_mode) {
      case _GestureMode.pending:
        if (_drag.distance < _turnSlop) return;
        final sticker = _touchSticker;
        if (sticker != null && _geometry != null) {
          _plan = TurnGesturePlan.resolve(
            camera: _geometry!.camera,
            sticker: sticker,
            drag: _drag,
          );
          _mode = _GestureMode.turning;
          widget.onTurnStart?.call();
          setState(() => _turn = _plan!.toLayerTurn(_plan!.angleFor(_drag)));
        } else if (widget.enableInteraction) {
          _mode = _GestureMode.orbit;
          _orbit(_drag);
        } else {
          _mode = _GestureMode.idle;
        }
      case _GestureMode.turning:
        setState(() => _turn = _plan!.toLayerTurn(_plan!.angleFor(_drag)));
      case _GestureMode.orbit:
        _orbit(delta);
      default:
        break;
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isNotEmpty) return;

    switch (_mode) {
      case _GestureMode.turning:
        final v = _velocity?.getVelocity().pixelsPerSecond ?? Offset.zero;
        final q = resolveQuarterTurns(
          angle: _turn?.angle ?? 0,
          angularVelocity: _plan!.angularVelocity(v),
        );
        _snapTo(q);
      case _GestureMode.pending:
        _handleTap(e.localPosition, e.timeStamp);
      default:
        break;
    }
    _mode = _GestureMode.idle;
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isNotEmpty) return;
    if (_mode == _GestureMode.turning) _snapTo(0);
    _mode = _GestureMode.idle;
  }

  void _handleTap(Offset pos, Duration time) {
    if (widget.onStickerTap != null) {
      final sticker = _geometry?.hitTest(pos);
      if (sticker != null) {
        HapticFeedback.selectionClick();
        widget.onStickerTap!(sticker.face, sticker.index);
      }
      return;
    }
    if (!widget.enableInteraction) return;
    // Chạm đúp → đặt lại góc nhìn
    final lastT = _lastTapTime, lastP = _lastTapPos;
    if (lastT != null &&
        lastP != null &&
        time - lastT < kDoubleTapTimeout &&
        (pos - lastP).distance < kDoubleTapSlop) {
      _lastTapTime = null;
      resetCamera();
    } else {
      _lastTapTime = time;
      _lastTapPos = pos;
    }
  }

  void _orbit(Offset delta) {
    if (!widget.enableInteraction) return;
    setState(() {
      _yaw += delta.dx * _orbitSpeed;
      // Kéo xuống → mặt trước đi xuống, lộ mặt trên (giống cầm khối thật)
      _pitch = (_pitch - delta.dy * _orbitSpeed)
          .clamp(-math.pi / 2 + 0.05, math.pi / 2 - 0.05);
    });
  }

  // =========================================================================
  // Vẽ
  // =========================================================================

  /// Tầng gợi ý "nhún" nhẹ theo chiều cần xoay khi người dùng đang không chạm.
  (LayerTurn?, LayerTurn?, double) _hintVisual(bool reduceMotion) {
    final hint = widget.hintMove == null ? null : CubeMove.tryParse(widget.hintMove!);
    if (hint == null || hint.isWholeCube) return (null, null, 0);
    final layer = hint.toLayerTurn(progress: 0);
    final t = _hint.value;
    final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    if (reduceMotion || _mode != _GestureMode.idle || _turn != null) {
      return (null, layer, reduceMotion ? 1 : pulse);
    }
    // 0 → 0.35: nhún tới; 0.35 → 0.7: trở lại; 0.7 → 1: nghỉ
    double wiggle;
    if (t < 0.35) {
      wiggle = Curves.easeOut.transform(t / 0.35);
    } else if (t < 0.7) {
      wiggle = 1 - Curves.easeIn.transform((t - 0.35) / 0.35);
    } else {
      wiggle = 0;
    }
    final dir = hint.angle.sign;
    return (layer.withAngle(dir * 0.32 * wiggle), layer, pulse);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    Widget cube = AnimatedBuilder(
      animation: _hint,
      builder: (context, _) {
        final (hintTurn, hintLayer, pulse) = _hintVisual(reduceMotion);
        final camera = CubeCamera(
          size: Size.square(widget.size),
          pitch: _pitch,
          yaw: _yaw,
        );
        final geometry = CubeGeometry.build(
          state: widget.state,
          camera: camera,
          turn: _turn ?? hintTurn,
          highlight: hintLayer,
        );
        _geometry = geometry;
        return CustomPaint(
          size: Size.square(widget.size),
          painter: Cube3DPainter(
            geometry: geometry,
            highlightPulse: hintLayer == null ? 0 : pulse,
            highlightColor: const Color(0xFF22D3EE),
          ),
        );
      },
    );

    cube = RepaintBoundary(child: cube);

    if (_acceptsInput) {
      // EagerGestureRecognizer: giành quyền cử chỉ ngay khi chạm vào khối,
      // tránh việc cuộn trang cha "cướp" thao tác vuốt.
      cube = RawGestureDetector(
        gestures: {
          EagerGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
            EagerGestureRecognizer.new,
            (_) {},
          ),
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: cube,
        ),
      );
    }

    return Semantics(
      label: widget.enableLayerTurns
          ? 'Khối Rubik 3D. Vuốt trên một ô để xoay tầng, vuốt ở nền để xoay góc nhìn.'
          : 'Khối Rubik 3D. Vuốt để xoay góc nhìn.',
      child: SizedBox.square(dimension: widget.size, child: cube),
    );
  }
}
