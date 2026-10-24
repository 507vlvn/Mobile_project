import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bộ đếm thời gian ván chơi: start / pause / resume / reset.
class GameClock extends ChangeNotifier {
  final Stopwatch _sw = Stopwatch();
  Duration _offset = Duration.zero;
  Timer? _ticker;

  bool get isRunning => _sw.isRunning;
  bool get hasStarted => _sw.isRunning || elapsed > Duration.zero;
  Duration get elapsed => _offset + _sw.elapsed;
  int get seconds => elapsed.inSeconds;

  void start() {
    if (_sw.isRunning) return;
    _sw.start();
    _ticker ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      notifyListeners();
    });
    notifyListeners();
  }

  void pause() {
    if (!_sw.isRunning) return;
    _sw.stop();
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void reset({Duration startAt = Duration.zero}) {
    _sw
      ..stop()
      ..reset();
    _offset = startAt;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Hiển thị đồng hồ với chữ số đều độ rộng.
class GameTimerText extends StatelessWidget {
  final GameClock clock;
  final TextStyle? style;

  const GameTimerText({super.key, required this.clock, this.style});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: clock,
      builder: (context, _) {
        final text = formatDuration(clock.elapsed);
        return Semantics(
          label: 'Thời gian $text',
          excludeSemantics: true,
          child: Text(
            text,
            style: (style ?? Theme.of(context).textTheme.titleMedium)
                ?.copyWith(fontFeatures: kTabularFigures),
          ),
        );
      },
    );
  }
}
