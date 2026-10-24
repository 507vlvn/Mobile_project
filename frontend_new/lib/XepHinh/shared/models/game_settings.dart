import 'difficulty.dart';

class GameSettings {
  final GameDifficulty difficulty;
  final bool soundEnabled;
  final bool timerEnabled;
  final bool showPreview;

  const GameSettings({
    this.difficulty = GameDifficulty.easy,
    this.soundEnabled = true,
    this.timerEnabled = true,
    this.showPreview = true,
  });

  GameSettings copyWith({
    GameDifficulty? difficulty,
    bool? soundEnabled,
    bool? timerEnabled,
    bool? showPreview,
  }) {
    return GameSettings(
      difficulty: difficulty ?? this.difficulty,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      timerEnabled: timerEnabled ?? this.timerEnabled,
      showPreview: showPreview ?? this.showPreview,
    );
  }
}
