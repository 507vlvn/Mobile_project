import '../models/difficulty.dart';
import '../models/score.dart';

/// Kết quả ván chơi (khớp cột History.result phía server).
enum GameOutcome {
  completed('COMPLETED'),
  win('WIN'),
  lose('LOSE'),
  draw('DRAW'),
  abandoned('ABANDONED');

  const GameOutcome(this.apiValue);
  final String apiValue;
}

/// Một ván chơi đã kết thúc, chuẩn bị gửi lên server.
class GameRecord {
  /// RUBIK | SUDOKU | PUZZLE | CARO
  final String gameCode;
  final Difficulty difficulty;

  /// Mức riêng của game vượt quá 3 mức chung (Sudoku: 4 Chuyên gia, 5 Ác mộng).
  /// Có thì gửi số này thay cho [difficulty].
  final int? level;
  final int timeSeconds;
  final int mistakes;
  final int moves;
  final int hints;
  final GameOutcome outcome;
  final int? challengeId;

  const GameRecord({
    required this.gameCode,
    required this.difficulty,
    required this.timeSeconds,
    required this.mistakes,
    required this.outcome,
    this.level,
    this.moves = 0,
    this.hints = 0,
    this.challengeId,
  });

  /// Số độ khó gửi lên server (cột GameLevels.difficulty).
  int get difficultyValue => level ?? difficulty.value;

  Map<String, dynamic> toJson() => {
        'gameCode': gameCode,
        'difficulty': difficultyValue,
        'timeSpentSeconds': timeSeconds,
        'mistakesCount': mistakes,
        'movesCount': moves,
        'hintsUsed': hints,
        'result': outcome.apiValue,
        if (challengeId != null) 'challengeId': challengeId,
      };

  factory GameRecord.fromJson(Map<String, dynamic> j) => GameRecord(
        gameCode: j['gameCode'] as String,
        difficulty: Difficulty.fromValue(j['difficulty'] as int?),
        level: switch (j['difficulty']) { final int d when d > 3 => d, _ => null },
        timeSeconds: j['timeSpentSeconds'] as int,
        mistakes: j['mistakesCount'] as int,
        moves: j['movesCount'] as int? ?? 0,
        hints: j['hintsUsed'] as int? ?? 0,
        outcome: GameOutcome.values.firstWhere(
          (o) => o.apiValue == j['result'],
          orElse: () => GameOutcome.completed,
        ),
        challengeId: j['challengeId'] as int?,
      );

  /// Điểm tính tại máy (cùng công thức v2 với server) — dùng khi chưa gửi được.
  /// Thua / bỏ cuộc = 0; Caro hòa = 30% điểm.
  int get localScore {
    final won =
        outcome == GameOutcome.completed || outcome == GameOutcome.win;
    final draw = outcome == GameOutcome.draw;
    final full = computeScore(
      gameCode: gameCode,
      difficulty: difficulty,
      level: level,
      timeSeconds: timeSeconds,
      mistakes: mistakes,
      moves: moves,
      hints: hints,
      completed: won || draw,
    );
    if (!draw) return full;
    return gameCode == 'CARO' ? (full * kCaroDrawShare).round() : full ~/ 2;
  }
}

/// Kết quả sau khi nộp điểm.
class ReportOutcome {
  final int score;
  final bool isPersonalBest;

  /// true = server đã lưu; false = lưu tạm trên máy (khách / mất mạng)
  final bool synced;

  /// Thông điệp ngắn để hiển thị (vd: "Đăng nhập để lưu điểm")
  final String? message;

  const ReportOutcome({
    required this.score,
    this.isPersonalBest = false,
    this.synced = false,
    this.message,
  });
}

/// Mọi game gọi `context.read<ScoreReporter>().submit(record)` khi kết thúc ván.
/// Không bao giờ ném lỗi — luôn trả về [ReportOutcome] (có điểm tại máy nếu lỗi mạng).
abstract class ScoreReporter {
  Future<ReportOutcome> submit(GameRecord record);
}

/// Bản mặc định khi chưa có tài khoản/API: chỉ tính điểm tại máy.
class LocalScoreReporter implements ScoreReporter {
  @override
  Future<ReportOutcome> submit(GameRecord record) async => ReportOutcome(
        score: record.localScore,
        message: 'Đăng nhập để lưu điểm lên bảng xếp hạng',
      );
}
