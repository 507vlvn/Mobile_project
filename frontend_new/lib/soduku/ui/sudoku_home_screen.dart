import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_controller.dart';
import '../../core/models/presence.dart';
import '../../core/network/api_client.dart';
import '../../core/network/models.dart';
import '../../core/realtime/match_models.dart';
import '../../core/widgets/user_avatar.dart';
import '../../pvp/pvp_common.dart';
import '../logic/sudoku_controller.dart';
import '../logic/sudoku_models.dart';
import '../logic/sudoku_stats_manager.dart';
import 'sudoku_learning_screen.dart';
import 'sudoku_screen.dart';
import 'sudoku_stats_view.dart';

class SudokuHomeScreen extends StatefulWidget {
  const SudokuHomeScreen({super.key});

  @override
  State<SudokuHomeScreen> createState() => _SudokuHomeScreenState();
}

class _SudokuHomeScreenState extends State<SudokuHomeScreen> {
  final SudokuController _controller = SudokuController.instance;
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
    // Khởi tạo ván mặc định nếu chưa có (không chạy timer nền)
    if (!_controller.hasOngoingGame && _controller.board.isEmpty) {
      _controller.startNewGame(
        difficulty: SudokuDifficulty.medium,
        autoStartTimer: false,
      );
    }

    // Tải ván cờ dở dang từ Database nếu có
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final auth = context.read<AuthController>();
        if (!auth.isAuthenticated) {
          // Khách / Chưa đăng nhập: làm mới ván cờ, tuyệt đối không lấy từ tài khoản trước
          _controller.onUserChanged(null);
          return;
        }

        final api = context.read<ApiClient>();
        _controller.onUserChanged(auth.currentUser?.userId);
        SudokuStatsManager.instance.switchUser(auth.currentUser?.userId);
        SudokuStatsManager.instance.syncWithServer();
        final saved = await api.getSudokuSavedGame(mode: 'CLASSIC');
        if (saved != null && mounted) {
          _controller.restoreFromSavedGame(saved);
        } else if (mounted) {
          _controller.resetToNewGame();
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.pauseTimer();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _continueGame() {
    _controller.resumeTimer();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SudokuScreen(controller: _controller),
      ),
    ).then((_) {
      _controller.pauseTimer();
      if (mounted) setState(() {});
    });
  }

  void _startNewGame(SudokuDifficulty difficulty) {
    try {
      final api = context.read<ApiClient>();
      _controller.deleteGameFromServer(api);
    } catch (_) {}

    _controller.startNewGame(difficulty: difficulty);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SudokuScreen(controller: _controller),
      ),
    ).then((_) {
      _controller.pauseTimer();
      if (mounted) setState(() {});
    });
  }

  void _openLearningMode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SudokuLearningScreen()),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openCoopFriendsPicker() {
    final auth = context.read<AuthController>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để chơi Sudoku cùng bạn bè')),
      );
      return;
    }
    _showSudokuCoopDialog();
  }

  void _showSudokuCoopDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final api = context.read<ApiClient>();
    final session = maybeMatchSessionOf(context);

    int selectedDifficulty = 2; // Vừa
    List<FriendInfo>? friendsList;
    bool loading = true;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (loading && friendsList == null && error == null) {
            api.friends().then((list) {
              setSheetState(() {
                loading = false;
                friendsList = list;
              });
            }).catchError((e) {
              setSheetState(() {
                loading = false;
                error = 'Không thể tải danh sách bạn bè';
              });
            });
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_alt_rounded, color: Color(0xFF2563EB), size: 26),
                          const SizedBox(width: 8),
                          Text(
                            'Sudoku Đồng Đội (Co-op)',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hai bạn cùng nhìn một bảng và giải Sudoku theo thời gian thực',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Chọn độ khó:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    for (final d in const [1, 2, 3, 4])
                      ButtonSegment(value: d, label: Text(sudokuDifficultyLabel(d))),
                  ],
                  selected: {selectedDifficulty},
                  onSelectionChanged: (v) => setSheetState(() => selectedDifficulty = v.first),
                ),
                const SizedBox(height: 20),
                Text(
                  'Chọn bạn bè để mời cùng chơi:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : error != null
                          ? Center(child: Text(error!))
                          : (friendsList == null || friendsList!.isEmpty)
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_add_rounded, size: 48, color: isDark ? Colors.white38 : Colors.grey),
                                      const SizedBox(height: 8),
                                      const Text('Chưa có bạn bè nào trong danh sách'),
                                      const SizedBox(height: 4),
                                      const Text('Hãy kết bạn ở mục Bạn bè để cùng chơi!', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: friendsList!.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (ctx, i) {
                                    final f = friendsList![i];
                                    final isOnline = f.presence == PresenceStatus.online;
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Stack(
                                        children: [
                                          UserAvatar(name: f.displayName, size: 40),
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      title: Text(f.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                        isOnline ? 'Đang online' : 'Ngoại tuyến',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                                        ),
                                      ),
                                      trailing: FilledButton.tonal(
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          if (session == null) return;
                                          final ok = await session.invite(f.summary, kGameSudoku, selectedDifficulty);
                                          if (ok && mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Đã gửi lời mời tới ${f.displayName}! Chờ 30 giây...')),
                                            );
                                          }
                                        },
                                        child: const Text('Mời chơi'),
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDifficultyPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Chọn Độ Khó Sudoku',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Chế độ Cổ điển
              for (final diff in SudokuDifficulty.values) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startNewGame(diff);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            diff.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: diff == SudokuDifficulty.nightmare
                                  ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2))
                                  : (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEEF2FF)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${diff.clues} ô cho sẵn',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: diff == SudokuDifficulty.nightmare
                                    ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
                                    : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF4F46E5)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ongoingTime = _controller.elapsedFormatted;
    final ongoingDifficulty = _controller.difficulty.label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _selectedNavIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedNavIndex != 0) {
          setState(() => _selectedNavIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FBFE),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _selectedNavIndex == 1
                    ? SudokuStatsView(
                        embedded: true,
                        onBack: () => setState(() => _selectedNavIndex = 0),
                        showBackButton: true,
                      )
                    : Column(
                        children: [
                          // Thanh công cụ trên cùng (Mũi tên quay lại)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                                  tooltip: 'Quay lại',
                                  onPressed: () {
                                    if (Navigator.canPop(context)) {
                                      Navigator.pop(context);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Phần thân cuộn được
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Column(
                                children: [
                    const SizedBox(height: 16),

                    // Tiêu đề App (Killer Sudoku / Sudoku Classic)
                    Text(
                      'Sudoku Classic',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'by GameHub',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),

                    const SizedBox(height: 44),

                    // Nút 1: Tiếp tục Trò chơi (Pill Blue)
                    Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _continueGame,
                          borderRadius: BorderRadius.circular(32),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Tiếp tục Trò chơi',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.access_time_rounded,
                                      size: 13,
                                      color: Color(0xFFDBEAFE),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$ongoingTime - $ongoingDifficulty',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFFDBEAFE),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Nút 2: Trò chơi Mới (Pill Adaptive)
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showDifficultyPicker,
                          borderRadius: BorderRadius.circular(32),
                          child: Center(
                            child: Text(
                              'Trò chơi Mới',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Nút: Chơi Cùng Bạn Bè (Sudoku Co-op)
                    Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openCoopFriendsPicker,
                          borderRadius: BorderRadius.circular(32),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.people_alt_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Chơi Cùng Bạn Bè (Co-op)',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        '2 người cùng giải 1 ván Sudoku thời gian thực',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFFEDE9FE),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Đồng đội',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Nút 3: Toán Chéo (CrossMath) - Bên dưới Trò chơi Mới
                    Container(
                      width: double.infinity,
                      height: 62,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openLearningMode,
                          borderRadius: BorderRadius.circular(32),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.grid_4x4_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Toán Chéo (CrossMath)',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        '30 Màn chơi đan chéo • Thử thách toán học',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFFDBEAFE),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Màn 1-30',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

              // Thanh điều hướng đáy (Chính, Thử thách, Thống kê)
              _buildBottomNav(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            width: 1.2,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_rounded, 'Chính', isDark),
          _buildNavItem(1, Icons.bar_chart_rounded, 'Thống kê', isDark),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _selectedNavIndex == index;
    final color = isSelected
        ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
        : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8));

    return InkWell(
      onTap: () {
        setState(() => _selectedNavIndex = index);
        if (index == 1) {
          SudokuStatsManager.instance.syncWithServer();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
