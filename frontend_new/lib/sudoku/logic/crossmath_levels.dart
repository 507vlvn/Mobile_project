import 'dart:math';
import '../models/crossmath_models.dart';

class CrossMathLevelProvider {
  static CrossMathLevelData getLevel(int level) {
    if (level < 1) level = 1;
    if (level > 30) level = 30;

    switch (level) {
      case 1:
        return _buildLevel1();
      case 2:
        return _buildLevel2();
      case 3:
        return _buildLevel3();
      case 4:
        return _buildLevel4();
      case 5:
        return _buildLevel5();
      default:
        return _generateProceduralLevel(level);
    }
  }

  /// Level 1: Khớp chính xác 100% hình ảnh thực tế của người dùng:
  /// Lưới 11 hàng x 9 cột, đan chéo nhiều phương trình:
  /// 1)  12 + [24] = 36             [22]
  ///      ÷     ÷     ÷               +
  /// 2)  [8] -  [4] =  4     [55]    23
  ///      x     =     =       ÷       =
  /// 3)  [7]    6    [9] [x]  5 =   [45]
  ///      =                   =
  /// 4)  56    20 -  [9] =   11       3
  ///            +     x               x
  /// 5)  84 ÷  [12] = [7]            13
  ///            =     =               =
  /// 6)        [32]  63 -    [24] = [39]
  static CrossMathLevelData _buildLevel1() {
    final cells = <CrossMathCell>[
      // Row 0
      CrossMathCell(row: 0, col: 0, type: CrossMathCellType.fixedNumber, label: '12'),
      CrossMathCell(row: 0, col: 1, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 0, col: 2, type: CrossMathCellType.blank, targetText: '24'),
      CrossMathCell(row: 0, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 0, col: 4, type: CrossMathCellType.fixedNumber, label: '36'),
      CrossMathCell(row: 0, col: 8, type: CrossMathCellType.blank, targetText: '22'),

      // Row 1
      CrossMathCell(row: 1, col: 2, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 1, col: 4, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 1, col: 8, type: CrossMathCellType.operator, label: '+'),

      // Row 2
      CrossMathCell(row: 2, col: 0, type: CrossMathCellType.blank, targetText: '8'),
      CrossMathCell(row: 2, col: 1, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 2, col: 2, type: CrossMathCellType.blank, targetText: '4'),
      CrossMathCell(row: 2, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 2, col: 4, type: CrossMathCellType.fixedNumber, label: '4'),
      CrossMathCell(row: 2, col: 6, type: CrossMathCellType.blank, targetText: '55'),
      CrossMathCell(row: 2, col: 8, type: CrossMathCellType.fixedNumber, label: '23'),

      // Row 3
      CrossMathCell(row: 3, col: 0, type: CrossMathCellType.operator, label: 'x'),
      CrossMathCell(row: 3, col: 2, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 4, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 6, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 3, col: 8, type: CrossMathCellType.operator, label: '='),

      // Row 4
      CrossMathCell(row: 4, col: 0, type: CrossMathCellType.blank, targetText: '7'),
      CrossMathCell(row: 4, col: 2, type: CrossMathCellType.fixedNumber, label: '6'),
      CrossMathCell(row: 4, col: 4, type: CrossMathCellType.blank, targetText: '9'),
      CrossMathCell(row: 4, col: 5, type: CrossMathCellType.blank, targetText: 'x'),
      CrossMathCell(row: 4, col: 6, type: CrossMathCellType.fixedNumber, label: '5'),
      CrossMathCell(row: 4, col: 7, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 4, col: 8, type: CrossMathCellType.blank, targetText: '45'),

      // Row 5
      CrossMathCell(row: 5, col: 0, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 5, col: 6, type: CrossMathCellType.operator, label: '='),

      // Row 6
      CrossMathCell(row: 6, col: 0, type: CrossMathCellType.fixedNumber, label: '56'),
      CrossMathCell(row: 6, col: 2, type: CrossMathCellType.fixedNumber, label: '20'),
      CrossMathCell(row: 6, col: 3, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 6, col: 4, type: CrossMathCellType.blank, targetText: '9'),
      CrossMathCell(row: 6, col: 5, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 6, col: 6, type: CrossMathCellType.fixedNumber, label: '11'),
      CrossMathCell(row: 6, col: 8, type: CrossMathCellType.fixedNumber, label: '3'),

      // Row 7
      CrossMathCell(row: 7, col: 2, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 7, col: 4, type: CrossMathCellType.operator, label: 'x'),
      CrossMathCell(row: 7, col: 8, type: CrossMathCellType.operator, label: 'x'),

      // Row 8
      CrossMathCell(row: 8, col: 0, type: CrossMathCellType.fixedNumber, label: '84'),
      CrossMathCell(row: 8, col: 1, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 8, col: 2, type: CrossMathCellType.blank, targetText: '12'),
      CrossMathCell(row: 8, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 8, col: 4, type: CrossMathCellType.blank, targetText: '7'),
      CrossMathCell(row: 8, col: 8, type: CrossMathCellType.fixedNumber, label: '13'),

      // Row 9
      CrossMathCell(row: 9, col: 2, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 9, col: 4, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 9, col: 8, type: CrossMathCellType.operator, label: '='),

      // Row 10
      CrossMathCell(row: 10, col: 2, type: CrossMathCellType.blank, targetText: '32'),
      CrossMathCell(row: 10, col: 4, type: CrossMathCellType.fixedNumber, label: '63'),
      CrossMathCell(row: 10, col: 5, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 10, col: 6, type: CrossMathCellType.blank, targetText: '24'),
      CrossMathCell(row: 10, col: 7, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 10, col: 8, type: CrossMathCellType.blank, targetText: '39'),
    ];

    final pool = [
      '22', '32', '7', '39', '24', '9',
      '12', '45', '8', 'x', '9', '55',
      '4', '7', '24'
    ];

    return CrossMathLevelData(
      level: 1,
      rows: 11,
      cols: 9,
      cells: cells,
      numberPool: pool,
    );
  }

  /// Level 2: Lưới 9x9 đan chéo
  static CrossMathLevelData _buildLevel2() {
    final cells = <CrossMathCell>[
      // Row 0
      CrossMathCell(row: 0, col: 0, type: CrossMathCellType.fixedNumber, label: '16'),
      CrossMathCell(row: 0, col: 1, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 0, col: 2, type: CrossMathCellType.blank, targetText: '18'),
      CrossMathCell(row: 0, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 0, col: 4, type: CrossMathCellType.fixedNumber, label: '34'),
      CrossMathCell(row: 0, col: 8, type: CrossMathCellType.blank, targetText: '42'),

      // Row 1
      CrossMathCell(row: 1, col: 0, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 1, col: 2, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 1, col: 4, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 1, col: 8, type: CrossMathCellType.operator, label: '+'),

      // Row 2
      CrossMathCell(row: 2, col: 0, type: CrossMathCellType.blank, targetText: '4'),
      CrossMathCell(row: 2, col: 1, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 2, col: 2, type: CrossMathCellType.blank, targetText: '3'),
      CrossMathCell(row: 2, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 2, col: 4, type: CrossMathCellType.blank, targetText: '7'),
      CrossMathCell(row: 2, col: 8, type: CrossMathCellType.blank, targetText: '12'),

      // Row 3
      CrossMathCell(row: 3, col: 0, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 2, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 4, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 8, type: CrossMathCellType.operator, label: '='),

      // Row 4
      CrossMathCell(row: 4, col: 0, type: CrossMathCellType.fixedNumber, label: '4'),
      CrossMathCell(row: 4, col: 2, type: CrossMathCellType.fixedNumber, label: '6'),
      CrossMathCell(row: 4, col: 4, type: CrossMathCellType.fixedNumber, label: '27'),
      CrossMathCell(row: 4, col: 5, type: CrossMathCellType.operator, label: 'x'),
      CrossMathCell(row: 4, col: 6, type: CrossMathCellType.fixedNumber, label: '2'),
      CrossMathCell(row: 4, col: 7, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 4, col: 8, type: CrossMathCellType.blank, targetText: '54'),

      // Row 5
      CrossMathCell(row: 5, col: 4, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 5, col: 8, type: CrossMathCellType.operator, label: '+'),

      // Row 6
      CrossMathCell(row: 6, col: 2, type: CrossMathCellType.blank, targetText: '15'),
      CrossMathCell(row: 6, col: 4, type: CrossMathCellType.blank, targetText: '8'),
      CrossMathCell(row: 6, col: 5, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 6, col: 6, type: CrossMathCellType.blank, targetText: '11'),
      CrossMathCell(row: 6, col: 7, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 6, col: 8, type: CrossMathCellType.fixedNumber, label: '19'),

      // Row 7
      CrossMathCell(row: 7, col: 2, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 7, col: 4, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 7, col: 8, type: CrossMathCellType.operator, label: '='),

      // Row 8
      CrossMathCell(row: 8, col: 2, type: CrossMathCellType.blank, targetText: '3'),
      CrossMathCell(row: 8, col: 4, type: CrossMathCellType.blank, targetText: '35'),
      CrossMathCell(row: 8, col: 8, type: CrossMathCellType.blank, targetText: '73'),
    ];

    final pool = [
      '18', '4', '3', '7', '42', '12',
      '54', '15', '8', '11', '3', '35',
      '73', '25', '9'
    ];
    pool.shuffle(Random(202));

    return CrossMathLevelData(
      level: 2,
      rows: 9,
      cols: 9,
      cells: cells,
      numberPool: pool,
    );
  }

  /// Level 3: Lưới 11x9 với nhiều phép nhân chia đan chéo (Đã sửa hoàn toàn đúng toán học)
  static CrossMathLevelData _buildLevel3() {
    final cells = <CrossMathCell>[
      // Row 0
      CrossMathCell(row: 0, col: 0, type: CrossMathCellType.blank, targetText: '40'),
      CrossMathCell(row: 0, col: 1, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 0, col: 2, type: CrossMathCellType.fixedNumber, label: '5'),
      CrossMathCell(row: 0, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 0, col: 4, type: CrossMathCellType.blank, targetText: '8'),
      CrossMathCell(row: 0, col: 8, type: CrossMathCellType.fixedNumber, label: '130'),

      // Row 1
      CrossMathCell(row: 1, col: 0, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 1, col: 4, type: CrossMathCellType.operator, label: 'x'),
      CrossMathCell(row: 1, col: 8, type: CrossMathCellType.operator, label: '-'),

      // Row 2
      CrossMathCell(row: 2, col: 0, type: CrossMathCellType.fixedNumber, label: '15'),
      CrossMathCell(row: 2, col: 1, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 2, col: 2, type: CrossMathCellType.blank, targetText: '9'),
      CrossMathCell(row: 2, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 2, col: 4, type: CrossMathCellType.blank, targetText: '24'),
      CrossMathCell(row: 2, col: 6, type: CrossMathCellType.blank, targetText: '75'),
      CrossMathCell(row: 2, col: 8, type: CrossMathCellType.blank, targetText: '8'),

      // Row 3
      CrossMathCell(row: 3, col: 0, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 4, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 6, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 3, col: 8, type: CrossMathCellType.operator, label: '='),

      // Row 4
      CrossMathCell(row: 4, col: 0, type: CrossMathCellType.blank, targetText: '25'),
      CrossMathCell(row: 4, col: 2, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 4, col: 4, type: CrossMathCellType.fixedNumber, label: '192'),
      CrossMathCell(row: 4, col: 5, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 4, col: 6, type: CrossMathCellType.fixedNumber, label: '70'),
      CrossMathCell(row: 4, col: 7, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 4, col: 8, type: CrossMathCellType.blank, targetText: '122'),

      // Row 5
      CrossMathCell(row: 5, col: 2, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 5, col: 6, type: CrossMathCellType.operator, label: '='),

      // Row 6
      CrossMathCell(row: 6, col: 0, type: CrossMathCellType.fixedNumber, label: '18'),
      CrossMathCell(row: 6, col: 1, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 6, col: 2, type: CrossMathCellType.blank, targetText: '34'),
      CrossMathCell(row: 6, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 6, col: 4, type: CrossMathCellType.blank, targetText: '52'),
      CrossMathCell(row: 6, col: 6, type: CrossMathCellType.fixedNumber, label: '5'),
      CrossMathCell(row: 6, col: 8, type: CrossMathCellType.fixedNumber, label: '8'),

      // Row 7
      CrossMathCell(row: 7, col: 2, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 7, col: 4, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 7, col: 8, type: CrossMathCellType.operator, label: 'x'),

      // Row 8
      CrossMathCell(row: 8, col: 0, type: CrossMathCellType.blank, targetText: '27'),
      CrossMathCell(row: 8, col: 1, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 8, col: 2, type: CrossMathCellType.fixedNumber, label: '14'),
      CrossMathCell(row: 8, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 8, col: 4, type: CrossMathCellType.fixedNumber, label: '13'),
      CrossMathCell(row: 8, col: 8, type: CrossMathCellType.blank, targetText: '7'),

      // Row 9
      CrossMathCell(row: 9, col: 2, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 9, col: 4, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 9, col: 8, type: CrossMathCellType.operator, label: '='),

      // Row 10
      CrossMathCell(row: 10, col: 2, type: CrossMathCellType.blank, targetText: '20'),
      CrossMathCell(row: 10, col: 4, type: CrossMathCellType.blank, targetText: '4'),
      CrossMathCell(row: 10, col: 5, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 10, col: 6, type: CrossMathCellType.blank, targetText: '52'),
      CrossMathCell(row: 10, col: 7, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 10, col: 8, type: CrossMathCellType.blank, targetText: '56'),
    ];

    final pool = [
      '40', '8', '9', '24', '75', '8',
      '25', '122', '34', '52', '27', '7',
      '20', '4', '52', '56'
    ];
    pool.shuffle(Random(303));

    return CrossMathLevelData(
      level: 3,
      rows: 11,
      cols: 9,
      cells: cells,
      numberPool: pool,
    );
  }

  /// Level 4: Lưới 11x9 (Đã sửa hoàn toàn đúng toán học)
  static CrossMathLevelData _buildLevel4() {
    final cells = <CrossMathCell>[
      // Row 0
      CrossMathCell(row: 0, col: 0, type: CrossMathCellType.fixedNumber, label: '21'),
      CrossMathCell(row: 0, col: 1, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 0, col: 2, type: CrossMathCellType.blank, targetText: '19'),
      CrossMathCell(row: 0, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 0, col: 4, type: CrossMathCellType.blank, targetText: '40'),
      CrossMathCell(row: 0, col: 8, type: CrossMathCellType.fixedNumber, label: '43'),

      // Row 1
      CrossMathCell(row: 1, col: 2, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 1, col: 4, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 1, col: 8, type: CrossMathCellType.operator, label: '-'),

      // Row 2
      CrossMathCell(row: 2, col: 0, type: CrossMathCellType.blank, targetText: '15'),
      CrossMathCell(row: 2, col: 1, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 2, col: 2, type: CrossMathCellType.blank, targetText: '7'),
      CrossMathCell(row: 2, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 2, col: 4, type: CrossMathCellType.fixedNumber, label: '8'),
      CrossMathCell(row: 2, col: 6, type: CrossMathCellType.blank, targetText: '26'),
      CrossMathCell(row: 2, col: 8, type: CrossMathCellType.blank, targetText: '8'),

      // Row 3
      CrossMathCell(row: 3, col: 0, type: CrossMathCellType.operator, label: 'x'),
      CrossMathCell(row: 3, col: 2, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 4, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 6, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 3, col: 8, type: CrossMathCellType.operator, label: '='),

      // Row 4
      CrossMathCell(row: 4, col: 0, type: CrossMathCellType.fixedNumber, label: '4'),
      CrossMathCell(row: 4, col: 2, type: CrossMathCellType.fixedNumber, label: '12'),
      CrossMathCell(row: 4, col: 4, type: CrossMathCellType.blank, targetText: '5'),
      CrossMathCell(row: 4, col: 5, type: CrossMathCellType.operator, label: 'x'),
      CrossMathCell(row: 4, col: 6, type: CrossMathCellType.fixedNumber, label: '7'),
      CrossMathCell(row: 4, col: 7, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 4, col: 8, type: CrossMathCellType.blank, targetText: '35'),

      // Row 5
      CrossMathCell(row: 5, col: 0, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 5, col: 6, type: CrossMathCellType.operator, label: '='),

      // Row 6
      CrossMathCell(row: 6, col: 0, type: CrossMathCellType.blank, targetText: '60'),
      CrossMathCell(row: 6, col: 2, type: CrossMathCellType.fixedNumber, label: '30'),
      CrossMathCell(row: 6, col: 3, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 6, col: 4, type: CrossMathCellType.blank, targetText: '11'),
      CrossMathCell(row: 6, col: 5, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 6, col: 6, type: CrossMathCellType.fixedNumber, label: '19'),
      CrossMathCell(row: 6, col: 8, type: CrossMathCellType.fixedNumber, label: '9'),

      // Row 7
      CrossMathCell(row: 7, col: 2, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 7, col: 4, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 7, col: 8, type: CrossMathCellType.operator, label: 'x'),

      // Row 8
      CrossMathCell(row: 8, col: 0, type: CrossMathCellType.fixedNumber, label: '45'),
      CrossMathCell(row: 8, col: 1, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 8, col: 2, type: CrossMathCellType.blank, targetText: '9'),
      CrossMathCell(row: 8, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 8, col: 4, type: CrossMathCellType.blank, targetText: '5'),
      CrossMathCell(row: 8, col: 8, type: CrossMathCellType.fixedNumber, label: '4'),

      // Row 9
      CrossMathCell(row: 9, col: 2, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 9, col: 4, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 9, col: 8, type: CrossMathCellType.operator, label: '='),

      // Row 10
      CrossMathCell(row: 10, col: 2, type: CrossMathCellType.blank, targetText: '39'),
      CrossMathCell(row: 10, col: 4, type: CrossMathCellType.blank, targetText: '16'),
      CrossMathCell(row: 10, col: 5, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 10, col: 6, type: CrossMathCellType.blank, targetText: '20'),
      CrossMathCell(row: 10, col: 7, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 10, col: 8, type: CrossMathCellType.blank, targetText: '36'),
    ];

    final pool = [
      '19', '40', '15', '7', '26', '8',
      '5', '35', '60', '11', '9', '5',
      '39', '16', '20', '36'
    ];
    pool.shuffle(Random(404));

    return CrossMathLevelData(
      level: 4,
      rows: 11,
      cols: 9,
      cells: cells,
      numberPool: pool,
    );
  }

  /// Level 5: Lưới 11x9 (Đã sửa hoàn toàn đúng toán học)
  static CrossMathLevelData _buildLevel5() {
    final cells = <CrossMathCell>[
      // Row 0
      CrossMathCell(row: 0, col: 0, type: CrossMathCellType.blank, targetText: '50'),
      CrossMathCell(row: 0, col: 1, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 0, col: 2, type: CrossMathCellType.blank, targetText: '18'),
      CrossMathCell(row: 0, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 0, col: 4, type: CrossMathCellType.fixedNumber, label: '32'),
      CrossMathCell(row: 0, col: 8, type: CrossMathCellType.blank, targetText: '90'),

      // Row 1
      CrossMathCell(row: 1, col: 2, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 1, col: 4, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 1, col: 8, type: CrossMathCellType.operator, label: '÷'),

      // Row 2
      CrossMathCell(row: 2, col: 0, type: CrossMathCellType.fixedNumber, label: '7'),
      CrossMathCell(row: 2, col: 1, type: CrossMathCellType.operator, label: 'x'),
      CrossMathCell(row: 2, col: 2, type: CrossMathCellType.blank, targetText: '6'),
      CrossMathCell(row: 2, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 2, col: 4, type: CrossMathCellType.blank, targetText: '42'),
      CrossMathCell(row: 2, col: 6, type: CrossMathCellType.blank, targetText: '48'),
      CrossMathCell(row: 2, col: 8, type: CrossMathCellType.fixedNumber, label: '9'),

      // Row 3
      CrossMathCell(row: 3, col: 0, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 2, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 4, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 3, col: 6, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 3, col: 8, type: CrossMathCellType.operator, label: '='),

      // Row 4
      CrossMathCell(row: 4, col: 0, type: CrossMathCellType.blank, targetText: '42'),
      CrossMathCell(row: 4, col: 2, type: CrossMathCellType.fixedNumber, label: '3'),
      CrossMathCell(row: 4, col: 4, type: CrossMathCellType.fixedNumber, label: '4'),
      CrossMathCell(row: 4, col: 5, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 4, col: 6, type: CrossMathCellType.fixedNumber, label: '6'),
      CrossMathCell(row: 4, col: 7, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 4, col: 8, type: CrossMathCellType.blank, targetText: '10'),

      // Row 5
      CrossMathCell(row: 5, col: 6, type: CrossMathCellType.operator, label: '='),

      // Row 6
      CrossMathCell(row: 6, col: 2, type: CrossMathCellType.fixedNumber, label: '25'),
      CrossMathCell(row: 6, col: 3, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 6, col: 4, type: CrossMathCellType.blank, targetText: '17'),
      CrossMathCell(row: 6, col: 5, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 6, col: 6, type: CrossMathCellType.blank, targetText: '8'),
      CrossMathCell(row: 6, col: 8, type: CrossMathCellType.fixedNumber, label: '5'),

      // Row 7
      CrossMathCell(row: 7, col: 2, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 7, col: 4, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 7, col: 8, type: CrossMathCellType.operator, label: 'x'),

      // Row 8
      CrossMathCell(row: 8, col: 0, type: CrossMathCellType.fixedNumber, label: '72'),
      CrossMathCell(row: 8, col: 1, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 8, col: 2, type: CrossMathCellType.blank, targetText: '8'),
      CrossMathCell(row: 8, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 8, col: 4, type: CrossMathCellType.blank, targetText: '9'),
      CrossMathCell(row: 8, col: 8, type: CrossMathCellType.fixedNumber, label: '12'),

      // Row 9
      CrossMathCell(row: 9, col: 2, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 9, col: 4, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 9, col: 8, type: CrossMathCellType.operator, label: '='),

      // Row 10
      CrossMathCell(row: 10, col: 2, type: CrossMathCellType.blank, targetText: '33'),
      CrossMathCell(row: 10, col: 4, type: CrossMathCellType.blank, targetText: '26'),
      CrossMathCell(row: 10, col: 5, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 10, col: 6, type: CrossMathCellType.blank, targetText: '34'),
      CrossMathCell(row: 10, col: 7, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 10, col: 8, type: CrossMathCellType.blank, targetText: '60'),
    ];

    final pool = [
      '50', '18', '90', '6', '42', '48',
      '42', '10', '17', '8', '8', '9',
      '33', '26', '34', '60'
    ];
    pool.shuffle(Random(505));

    return CrossMathLevelData(
      level: 5,
      rows: 11,
      cols: 9,
      cells: cells,
      numberPool: pool,
    );
  }

  /// Sinh cấp độ thuật toán từ màn 6 đến 30: Đảm bảo 100% đúng toán học
  static CrossMathLevelData _generateProceduralLevel(int level) {
    final rand = Random(level * 7919 + 42);

    // Hàng 0: a1 + a2 = a3
    final a1 = rand.nextInt(20) + 10;
    final a2 = rand.nextInt(15) + 5;
    final a3 = a1 + a2;

    // Hàng 2: b1 + b2 = b3 (với b3 < a3 để cột 4 làm phép trừ)
    final b3 = rand.nextInt(a3 - 5) + 3;
    final b1 = rand.nextInt(b3 - 1) + 1;
    final b2 = b3 - b1;

    // Cột 4 (dọc, row 0..4): a3 - b3 = d1
    final d1 = a3 - b3;

    // Hàng 4 (ngang, col 4..8): d1 + d2 = d3
    final d2 = rand.nextInt(20) + 5;
    final d3 = d1 + d2;

    // Cột 8 (dọc, row 0..4): r1 - r2 = d3
    final r2 = rand.nextInt(15) + 3;
    final r1 = d3 + r2;

    // Cột 6 (dọc, row 2..6): m1 x m2 = m3 (cắt H4 tại col 6 -> m2 = d2)
    final m1 = rand.nextInt(3) + 2;
    final m3 = m1 * d2;

    // Hàng 6 (ngang, col 2..6): k1 + k2 = m3
    final k1 = rand.nextInt(m3 - 1) + 1;
    final k2 = m3 - k1;

    // Cột 0 (dọc, row 0..4): a1 + b1 = c1 (hoặc a1 - b1 nếu a1 > b1)
    final bool c0IsSub = a1 > b1;
    final String c0Op = c0IsSub ? '-' : '+';
    final int c1 = c0IsSub ? (a1 - b1) : (a1 + b1);

    // Cột 2 (dọc, row 0..4): a2 + b2 = c2
    final c2 = a2 + b2;

    // Cột 2 (dọc, row 6..10): k1 + p1 = p2
    final p1 = rand.nextInt(15) + 3;
    final p2 = k1 + p1;

    // Hàng 8 (ngang, col 0..4): q1 + p1 = q3
    final q1 = rand.nextInt(25) + 5;
    final q3 = q1 + p1;

    // Cột 4 (dọc, row 6..10): k2 + q3 = f2
    final f2 = k2 + q3;

    // Hàng 10 (ngang, col 4..8): f2 + g1 = g2
    final g1 = rand.nextInt(20) + 5;
    final g2 = f2 + g1;

    // Cột 8 (dọc, row 6..10): w1 + w2 = g2
    final w1 = rand.nextInt(g2 - 2) + 1;
    final w2 = g2 - w1;

    final cells = <CrossMathCell>[
      // Hàng 0
      CrossMathCell(row: 0, col: 0, type: CrossMathCellType.blank, targetText: '$a1'),
      CrossMathCell(row: 0, col: 1, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 0, col: 2, type: CrossMathCellType.blank, targetText: '$a2'),
      CrossMathCell(row: 0, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 0, col: 4, type: CrossMathCellType.fixedNumber, label: '$a3'),
      CrossMathCell(row: 0, col: 8, type: CrossMathCellType.fixedNumber, label: '$r1'),

      // Hàng 1
      CrossMathCell(row: 1, col: 0, type: CrossMathCellType.operator, label: c0Op),
      CrossMathCell(row: 1, col: 2, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 1, col: 4, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 1, col: 8, type: CrossMathCellType.operator, label: '-'),

      // Hàng 2
      CrossMathCell(row: 2, col: 0, type: CrossMathCellType.fixedNumber, label: '$b1'),
      CrossMathCell(row: 2, col: 1, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 2, col: 2, type: CrossMathCellType.blank, targetText: '$b2'),
      CrossMathCell(row: 2, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 2, col: 4, type: CrossMathCellType.blank, targetText: '$b3'),
      CrossMathCell(row: 2, col: 6, type: CrossMathCellType.blank, targetText: '$m1'),
      CrossMathCell(row: 2, col: 8, type: CrossMathCellType.blank, targetText: '$r2'),

      // Hàng 3
      CrossMathCell(row: 3, col: 0, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 2, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 4, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 6, type: CrossMathCellType.operator, label: 'x'),
      CrossMathCell(row: 3, col: 8, type: CrossMathCellType.operator, label: '='),

      // Hàng 4
      CrossMathCell(row: 4, col: 0, type: CrossMathCellType.blank, targetText: '$c1'),
      CrossMathCell(row: 4, col: 2, type: CrossMathCellType.fixedNumber, label: '$c2'),
      CrossMathCell(row: 4, col: 4, type: CrossMathCellType.fixedNumber, label: '$d1'),
      CrossMathCell(row: 4, col: 5, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 4, col: 6, type: CrossMathCellType.blank, targetText: '$d2'),
      CrossMathCell(row: 4, col: 7, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 4, col: 8, type: CrossMathCellType.blank, targetText: '$d3'),

      // Hàng 5
      CrossMathCell(row: 5, col: 6, type: CrossMathCellType.operator, label: '='),

      // Hàng 6
      CrossMathCell(row: 6, col: 2, type: CrossMathCellType.fixedNumber, label: '$k1'),
      CrossMathCell(row: 6, col: 3, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 6, col: 4, type: CrossMathCellType.blank, targetText: '$k2'),
      CrossMathCell(row: 6, col: 5, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 6, col: 6, type: CrossMathCellType.fixedNumber, label: '$m3'),
      CrossMathCell(row: 6, col: 8, type: CrossMathCellType.fixedNumber, label: '$w1'),

      // Hàng 7
      CrossMathCell(row: 7, col: 2, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 7, col: 4, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 7, col: 8, type: CrossMathCellType.operator, label: '+'),

      // Hàng 8
      CrossMathCell(row: 8, col: 0, type: CrossMathCellType.fixedNumber, label: '$q1'),
      CrossMathCell(row: 8, col: 1, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 8, col: 2, type: CrossMathCellType.blank, targetText: '$p1'),
      CrossMathCell(row: 8, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 8, col: 4, type: CrossMathCellType.blank, targetText: '$q3'),
      CrossMathCell(row: 8, col: 8, type: CrossMathCellType.blank, targetText: '$w2'),

      // Hàng 9
      CrossMathCell(row: 9, col: 2, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 9, col: 4, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 9, col: 8, type: CrossMathCellType.operator, label: '='),

      // Hàng 10
      CrossMathCell(row: 10, col: 2, type: CrossMathCellType.blank, targetText: '$p2'),
      CrossMathCell(row: 10, col: 4, type: CrossMathCellType.fixedNumber, label: '$f2'),
      CrossMathCell(row: 10, col: 5, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 10, col: 6, type: CrossMathCellType.blank, targetText: '$g1'),
      CrossMathCell(row: 10, col: 7, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 10, col: 8, type: CrossMathCellType.blank, targetText: '$g2'),
    ];

    final pool = cells
        .where((c) => c.isBlank && c.targetText != null)
        .map((c) => c.targetText!)
        .toList();

    while (pool.length < 16) {
      pool.add('${rand.nextInt(50) + 2}');
    }
    pool.shuffle(rand);

    return CrossMathLevelData(
      level: level,
      rows: 11,
      cols: 9,
      cells: cells,
      numberPool: pool,
    );
  }
}
