import 'package:flutter/material.dart';
import 'shared/models/difficulty.dart';
import 'sliding_puzzle/sliding_puzzle_screen.dart';
import 'jigsaw_puzzle/jigsaw_puzzle_screen.dart';
import 'phaseshift/phaseshift_screen.dart';
import 'phaseshift/widgets/phaseshift_rules.dart';

enum GameMode { sliding, jigsaw, phaseShift }

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  GameMode _selectedMode = GameMode.sliding;
  GameDifficulty _selectedDifficulty = GameDifficulty.easy;
  bool _enableTimeLimit = false;

  void _startGame() {
    Widget targetScreen;
    switch (_selectedMode) {
      case GameMode.sliding:
        targetScreen = SlidingPuzzleScreen(difficulty: _selectedDifficulty);
        break;
      case GameMode.jigsaw:
        targetScreen = JigsawPuzzleScreen(difficulty: _selectedDifficulty);
        break;
      case GameMode.phaseShift:
        targetScreen = PhaseShiftScreen(
          difficulty: _selectedDifficulty,
          enableTimeLimit: _enableTimeLimit,
        );
        break;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => targetScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn Chế Độ Chơi'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Chọn trò chơi',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildModeTile(
              mode: GameMode.sliding,
              title: 'Sliding Puzzle (Xếp số trượt)',
              subtitle: 'Sắp xếp các ô số theo thứ tự từ 1 đến hết.',
              icon: Icons.grid_on_rounded,
              color: Colors.indigo,
            ),
            const SizedBox(height: 10),
            _buildModeTile(
              mode: GameMode.jigsaw,
              title: 'Jigsaw Puzzle (Ghép mảnh hình)',
              subtitle: 'Đổi vị trí các mảnh ghép để hoàn chỉnh hình ảnh.',
              icon: Icons.extension_rounded,
              color: Colors.orange.shade800,
            ),
            const SizedBox(height: 10),
            _buildModeTile(
              mode: GameMode.phaseShift,
              title: 'PhaseShift (Xếp khối nguyên tố)',
              subtitle: 'Thả khối vật liệu & kích hoạt phản ứng combo!',
              icon: Icons.science_rounded,
              color: Colors.teal.shade700,
            ),
            const SizedBox(height: 28),
            Text(
              '2. Chọn độ khó',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: GameDifficulty.values.map((difficulty) {
                final isSelected = _selectedDifficulty == difficulty;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          _selectedMode == GameMode.phaseShift
                              ? difficulty.displayName
                              : '${difficulty.displayName}\n(${difficulty.gridSize}x${difficulty.gridSize})',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedDifficulty = difficulty;
                          });
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            if (_selectedMode == GameMode.phaseShift) ...[
              Card(
                child: SwitchListTile(
                  title: const Text('Giới hạn thời gian (3 phút)'),
                  subtitle: const Text('Thua cuộc khi đồng hồ đếm ngược về 0'),
                  value: _enableTimeLimit,
                  onChanged: (val) {
                    setState(() {
                      _enableTimeLimit = val;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showPhaseShiftRules(context),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('Luật chơi PhaseShift'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text(
                  'Bắt Đầu Chơi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTile({
    required GameMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedMode == mode;

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        onTap: () {
          setState(() {
            _selectedMode = mode;
          });
        },
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(38),
          radius: 26,
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(
          isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
          color: isSelected ? color : Colors.grey,
        ),
      ),
    );
  }
}
