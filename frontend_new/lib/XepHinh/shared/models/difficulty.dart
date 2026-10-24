enum GameDifficulty { easy, medium, hard }

extension GameDifficultyExtension on GameDifficulty {
  String get displayName {
    switch (this) {
      case GameDifficulty.easy:
        return 'Dễ';
      case GameDifficulty.medium:
        return 'Trung bình';
      case GameDifficulty.hard:
        return 'Khó';
    }
  }

  int get gridSize {
    switch (this) {
      case GameDifficulty.easy:
        return 3;
      case GameDifficulty.medium:
        return 4;
      case GameDifficulty.hard:
        return 5;
    }
  }

  int? get timeLimitSeconds {
    switch (this) {
      case GameDifficulty.easy:
        return 300;
      case GameDifficulty.medium:
        return 180;
      case GameDifficulty.hard:
        return 120;
    }
  }
}
