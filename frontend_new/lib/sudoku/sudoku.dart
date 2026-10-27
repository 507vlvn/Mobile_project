/// Thư viện tổng hợp toàn bộ tính năng trò chơi Sudoku.
///
/// Cấu trúc module:
/// - `models/`: Các lớp dữ liệu Sudoku & CrossMath.
/// - `logic/`: Thuật toán sinh bàn cờ, bộ điều khiển trò chơi và quản lý dữ liệu/tiến trình.
/// - `screens/`: Các màn hình giao diện (Trang chủ, Chơi đơn, Học tập, Giải cùng nhau Co-op, Toán chéo).
/// - `widgets/`: Các thành phần giao diện nhỏ (Bàn cờ, Bàn phím số, Bảng thống kê).
library;

// Models
export 'models/sudoku_models.dart';
export 'models/crossmath_models.dart';

// Logic
export 'logic/sudoku_generator.dart';
export 'logic/sudoku_controller.dart';
export 'logic/sudoku_learning_manager.dart';
export 'logic/sudoku_stats_manager.dart';
export 'logic/crossmath_levels.dart';

// Screens
export 'screens/sudoku_home_screen.dart';
export 'screens/sudoku_screen.dart';
export 'screens/sudoku_learning_screen.dart';
export 'screens/sudoku_coop_screen.dart';
export 'screens/crossmath_screen.dart';

// Widgets
export 'widgets/sudoku_board.dart';
export 'widgets/sudoku_keypad.dart';
export 'widgets/sudoku_stats_view.dart';
