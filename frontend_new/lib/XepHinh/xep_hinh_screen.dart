import 'package:flutter/material.dart';
import 'mode_selection_screen.dart';
import 'sliding_puzzle/sliding_puzzle_screen.dart';
import 'jigsaw_puzzle/jigsaw_puzzle_screen.dart';
import 'phaseshift/phaseshift_screen.dart';
import 'shared/models/difficulty.dart';
import '../core/realtime/match_models.dart';
import '../pvp/pvp_lobby_screen.dart';

class XepHinhScreen extends StatelessWidget {
  const XepHinhScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xếp Hình Master'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade600, Colors.purple.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: const Column(
                  children: [
                    Icon(Icons.extension_rounded, size: 64, color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Game Xếp Hình & PhaseShift',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Thử thách trí tuệ với các chế độ xếp hình đa dạng!',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _buildMenuCard(
                      context: context,
                      title: 'Chọn Chế Độ Chơi',
                      subtitle: 'Sliding Puzzle, Jigsaw, PhaseShift',
                      icon: Icons.play_circle_fill_rounded,
                      color: Colors.indigo,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ModeSelectionScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildMenuCard(
                      context: context,
                      title: 'Chơi Nhanh - Sliding Puzzle',
                      subtitle: 'Bắt đầu ngay với bản đồ 3x3',
                      icon: Icons.flash_on_rounded,
                      color: Colors.orange.shade800,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SlidingPuzzleScreen(
                              difficulty: GameDifficulty.easy,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildMenuCard(
                      context: context,
                      title: 'Đua Xếp số với người khác',
                      subtitle: 'Cùng một đề, ai xếp xong trước thắng (online)',
                      icon: Icons.sports_score_rounded,
                      color: Colors.teal.shade700,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PvpLobbyScreen(
                              initialGame: kGamePuzzle,
                              embedded: false,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildMenuCard(
                      context: context,
                      title: 'Chơi Nhanh - Jigsaw Puzzle',
                      subtitle: 'Bắt đầu ngay với mảnh ghép 3x3',
                      icon: Icons.extension,
                      color: Colors.teal.shade700,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const JigsawPuzzleScreen(
                              difficulty: GameDifficulty.easy,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildMenuCard(
                      context: context,
                      title: 'Chế Độ PhaseShift',
                      subtitle: 'Mô phỏng chuyển thể vật chất',
                      icon: Icons.science_rounded,
                      color: Colors.purple.shade700,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PhaseShiftScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha(30),
                radius: 28,
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
