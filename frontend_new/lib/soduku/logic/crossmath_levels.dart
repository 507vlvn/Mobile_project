import 'dart:math';
import 'crossmath_models.dart';

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

    // Khay chứa đúng 15 phần tử theo thứ tự trong ảnh
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

  /// Level 2: Lưới 9x9 đan chéo rộng lớn
  /// 16 + [18] = 34           [30]
  ///  ÷     ÷    -              -
  /// [4] + [3] = [7]          [12]
  ///  =     =    =              =
  ///  4     6    27    x  2 = [54]
  ///             +              +
  ///       [15]  [8] + [11] =  19
  ///        ÷    =              =
  ///       [3]  [35]           [73]
  static CrossMathLevelData _buildLevel2() {
    final cells = <CrossMathCell>[
      // Row 0
      CrossMathCell(row: 0, col: 0, type: CrossMathCellType.fixedNumber, label: '16'),
      CrossMathCell(row: 0, col: 1, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 0, col: 2, type: CrossMathCellType.blank, targetText: '18'),
      CrossMathCell(row: 0, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 0, col: 4, type: CrossMathCellType.fixedNumber, label: '34'),
      CrossMathCell(row: 0, col: 8, type: CrossMathCellType.blank, targetText: '30'),

      // Row 1
      CrossMathCell(row: 1, col: 0, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 1, col: 2, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 1, col: 4, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 1, col: 8, type: CrossMathCellType.operator, label: '-'),

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
      '18', '4', '3', '7', '30', '12',
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

  /// Level 3: Lưới 11x9 với nhiều phép nhân chia đan chéo
  static CrossMathLevelData _buildLevel3() {
    final cells = <CrossMathCell>[
      // Row 0
      CrossMathCell(row: 0, col: 0, type: CrossMathCellType.blank, targetText: '40'),
      CrossMathCell(row: 0, col: 1, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 0, col: 2, type: CrossMathCellType.fixedNumber, label: '5'),
      CrossMathCell(row: 0, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 0, col: 4, type: CrossMathCellType.blank, targetText: '8'),
      CrossMathCell(row: 0, col: 8, type: CrossMathCellType.fixedNumber, label: '48'),

      // Row 1
      CrossMathCell(row: 1, col: 0, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 1, col: 4, type: CrossMathCellType.operator, label: 'x'),
      CrossMathCell(row: 1, col: 8, type: CrossMathCellType.operator, label: '÷'),

      // Row 2
      CrossMathCell(row: 2, col: 0, type: CrossMathCellType.fixedNumber, label: '15'),
      CrossMathCell(row: 2, col: 1, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 2, col: 2, type: CrossMathCellType.blank, targetText: '9'),
      CrossMathCell(row: 2, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 2, col: 4, type: CrossMathCellType.blank, targetText: '24'),
      CrossMathCell(row: 2, col: 6, type: CrossMathCellType.blank, targetText: '14'),
      CrossMathCell(row: 2, col: 8, type: CrossMathCellType.blank, targetText: '6'),

      // Row 3
      CrossMathCell(row: 3, col: 0, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 4, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 6, type: CrossMathCellType.operator, label: 'x'),
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
      CrossMathCell(row: 8, col: 0, type: CrossMathCellType.blank, targetText: '30'),
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
      '40', '8', '9', '24', '14', '6',
      '25', '122', '34', '52', '30', '7',
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

  /// Level 4: Lưới 11x9
  static CrossMathLevelData _buildLevel4() {
    final cells = <CrossMathCell>[
      // Row 0
      CrossMathCell(row: 0, col: 0, type: CrossMathCellType.fixedNumber, label: '21'),
      CrossMathCell(row: 0, col: 1, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 0, col: 2, type: CrossMathCellType.blank, targetText: '19'),
      CrossMathCell(row: 0, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 0, col: 4, type: CrossMathCellType.blank, targetText: '40'),
      CrossMathCell(row: 0, col: 8, type: CrossMathCellType.fixedNumber, label: '64'),

      // Row 1
      CrossMathCell(row: 1, col: 2, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 1, col: 4, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 1, col: 8, type: CrossMathCellType.operator, label: '÷'),

      // Row 2
      CrossMathCell(row: 2, col: 0, type: CrossMathCellType.blank, targetText: '11'),
      CrossMathCell(row: 2, col: 1, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 2, col: 2, type: CrossMathCellType.blank, targetText: '7'),
      CrossMathCell(row: 2, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 2, col: 4, type: CrossMathCellType.fixedNumber, label: '8'),
      CrossMathCell(row: 2, col: 6, type: CrossMathCellType.blank, targetText: '42'),
      CrossMathCell(row: 2, col: 8, type: CrossMathCellType.blank, targetText: '8'),

      // Row 3
      CrossMathCell(row: 3, col: 0, type: CrossMathCellType.operator, label: 'x'),
      CrossMathCell(row: 3, col: 2, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 4, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 6, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 3, col: 8, type: CrossMathCellType.operator, label: '='),

      // Row 4
      CrossMathCell(row: 4, col: 0, type: CrossMathCellType.fixedNumber, label: '6'),
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
      CrossMathCell(row: 6, col: 0, type: CrossMathCellType.blank, targetText: '66'),
      CrossMathCell(row: 6, col: 2, type: CrossMathCellType.fixedNumber, label: '30'),
      CrossMathCell(row: 6, col: 3, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 6, col: 4, type: CrossMathCellType.blank, targetText: '16'),
      CrossMathCell(row: 6, col: 5, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 6, col: 6, type: CrossMathCellType.fixedNumber, label: '6'),
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
      CrossMathCell(row: 10, col: 4, type: CrossMathCellType.blank, targetText: '21'),
      CrossMathCell(row: 10, col: 5, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 10, col: 6, type: CrossMathCellType.blank, targetText: '15'),
      CrossMathCell(row: 10, col: 7, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 10, col: 8, type: CrossMathCellType.blank, targetText: '36'),
    ];

    final pool = [
      '19', '40', '11', '7', '42', '8',
      '5', '35', '66', '16', '9', '5',
      '39', '21', '15', '36'
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

  /// Level 5: Lưới 11x9
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
      CrossMathCell(row: 2, col: 4, type: CrossMathCellType.blank, targetText: '8'),
      CrossMathCell(row: 2, col: 6, type: CrossMathCellType.blank, targetText: '48'),
      CrossMathCell(row: 2, col: 8, type: CrossMathCellType.fixedNumber, label: '9'),

      // Row 3
      CrossMathCell(row: 3, col: 0, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 2, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 4, type: CrossMathCellType.operator, label: '='),
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
      CrossMathCell(row: 7, col: 4, type: CrossMathCellType.operator, label: 'x'),
      CrossMathCell(row: 7, col: 8, type: CrossMathCellType.operator, label: 'x'),

      // Row 8
      CrossMathCell(row: 8, col: 0, type: CrossMathCellType.fixedNumber, label: '72'),
      CrossMathCell(row: 8, col: 1, type: CrossMathCellType.operator, label: '÷'),
      CrossMathCell(row: 8, col: 2, type: CrossMathCellType.blank, targetText: '8'),
      CrossMathCell(row: 8, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 8, col: 4, type: CrossMathCellType.blank, targetText: '3'),
      CrossMathCell(row: 8, col: 8, type: CrossMathCellType.fixedNumber, label: '12'),

      // Row 9
      CrossMathCell(row: 9, col: 2, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 9, col: 4, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 9, col: 8, type: CrossMathCellType.operator, label: '='),

      // Row 10
      CrossMathCell(row: 10, col: 2, type: CrossMathCellType.blank, targetText: '33'),
      CrossMathCell(row: 10, col: 4, type: CrossMathCellType.blank, targetText: '51'),
      CrossMathCell(row: 10, col: 5, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 10, col: 6, type: CrossMathCellType.blank, targetText: '9'),
      CrossMathCell(row: 10, col: 7, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 10, col: 8, type: CrossMathCellType.blank, targetText: '60'),
    ];

    final pool = [
      '50', '18', '90', '6', '8', '48',
      '42', '10', '17', '8', '8', '3',
      '33', '51', '9', '60'
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

  /// Sinh cấp độ thuật toán từ màn 6 đến 30: Đảm bảo bảng nhiều ô (11x9 hoặc 9x9)
  static CrossMathLevelData _generateProceduralLevel(int level) {
    final rand = Random(level * 7919 + 42);

    // Xây dựng khung 11 hàng x 9 cột đan chéo
    // Các vị trí phép tính:
    // H1: a1 op1 a2 = a3
    // C1: a1 opV1 b1 = c1
    // C2: a2 opV2 b2 = c2
    // C3: a3 opV3 b3 = c3
    // H2: b1 op2 b2 = b3
    // H3: c1 op3 c2 = c3
    // H4: d1 op4 d2 = d3
    // C4: b3 opV4 d3 = e3
    // H5: e1 op5 e2 = e3

    final a1 = rand.nextInt(30) + 10;
    final a2 = rand.nextInt(20) + 5;
    final a3 = a1 + a2; // a1 + a2 = a3

    final b1Mult = rand.nextInt(4) + 2;
    final b1 = b1Mult;
    final c1 = a1 * b1; // a1 x b1 = c1

    final b2 = rand.nextInt(15) + 3;
    final b3 = b1 + b2; // b1 + b2 = b3

    final c2 = a2 + b2; // a2 + b2 = c2
    final c3 = a3 + b3; // a3 + b3 = c3

    // Nhánh dưới
    final d1 = rand.nextInt(20) + 10;
    final d2 = rand.nextInt(15) + 5;
    final d3 = d1 + d2; // d1 + d2 = d3

    final e3Factor = rand.nextInt(3) + 2;
    final e3 = d3 * e3Factor; // d3 x e3Factor = e3

    final e2 = rand.nextInt(25) + 10;
    final e1 = e3 - e2; // e1 + e2 = e3

    // Nhánh phải
    final r1 = rand.nextInt(25) + 10;
    final r2 = rand.nextInt(15) + 5;
    final r3 = r1 + r2;

    final cells = <CrossMathCell>[
      // Hàng 0
      CrossMathCell(row: 0, col: 0, type: CrossMathCellType.blank, targetText: '$a1'),
      CrossMathCell(row: 0, col: 1, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 0, col: 2, type: CrossMathCellType.blank, targetText: '$a2'),
      CrossMathCell(row: 0, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 0, col: 4, type: CrossMathCellType.fixedNumber, label: '$a3'),
      CrossMathCell(row: 0, col: 8, type: CrossMathCellType.blank, targetText: '$r1'),

      // Hàng 1
      CrossMathCell(row: 1, col: 0, type: CrossMathCellType.operator, label: 'x'),
      CrossMathCell(row: 1, col: 2, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 1, col: 4, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 1, col: 8, type: CrossMathCellType.operator, label: '+'),

      // Hàng 2
      CrossMathCell(row: 2, col: 0, type: CrossMathCellType.fixedNumber, label: '$b1'),
      CrossMathCell(row: 2, col: 1, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 2, col: 2, type: CrossMathCellType.blank, targetText: '$b2'),
      CrossMathCell(row: 2, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 2, col: 4, type: CrossMathCellType.blank, targetText: '$b3'),
      CrossMathCell(row: 2, col: 6, type: CrossMathCellType.blank, targetText: '$e3Factor'),
      CrossMathCell(row: 2, col: 8, type: CrossMathCellType.fixedNumber, label: '$r2'),

      // Hàng 3
      CrossMathCell(row: 3, col: 0, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 2, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 4, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 3, col: 6, type: CrossMathCellType.operator, label: 'x'),
      CrossMathCell(row: 3, col: 8, type: CrossMathCellType.operator, label: '='),

      // Hàng 4
      CrossMathCell(row: 4, col: 0, type: CrossMathCellType.blank, targetText: '$c1'),
      CrossMathCell(row: 4, col: 2, type: CrossMathCellType.fixedNumber, label: '$c2'),
      CrossMathCell(row: 4, col: 4, type: CrossMathCellType.blank, targetText: '$c3'),
      CrossMathCell(row: 4, col: 5, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 4, col: 6, type: CrossMathCellType.fixedNumber, label: '$d1'),
      CrossMathCell(row: 4, col: 7, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 4, col: 8, type: CrossMathCellType.blank, targetText: '$r3'),

      // Hàng 5
      CrossMathCell(row: 5, col: 2, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 5, col: 6, type: CrossMathCellType.operator, label: '='),

      // Hàng 6
      CrossMathCell(row: 6, col: 2, type: CrossMathCellType.fixedNumber, label: '$d2'),
      CrossMathCell(row: 6, col: 3, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 6, col: 4, type: CrossMathCellType.blank, targetText: '$d1'),
      CrossMathCell(row: 6, col: 5, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 6, col: 6, type: CrossMathCellType.blank, targetText: '$d3'),
      CrossMathCell(row: 6, col: 8, type: CrossMathCellType.fixedNumber, label: '2'),

      // Hàng 7
      CrossMathCell(row: 7, col: 2, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 7, col: 6, type: CrossMathCellType.operator, label: 'x'),
      CrossMathCell(row: 7, col: 8, type: CrossMathCellType.operator, label: 'x'),

      // Hàng 8
      CrossMathCell(row: 8, col: 0, type: CrossMathCellType.fixedNumber, label: '60'),
      CrossMathCell(row: 8, col: 1, type: CrossMathCellType.operator, label: '-'),
      CrossMathCell(row: 8, col: 2, type: CrossMathCellType.blank, targetText: '${c2 + d2}'),
      CrossMathCell(row: 8, col: 3, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 8, col: 4, type: CrossMathCellType.blank, targetText: '${60 - (c2 + d2)}'),
      CrossMathCell(row: 8, col: 6, type: CrossMathCellType.fixedNumber, label: '$e3Factor'),
      CrossMathCell(row: 8, col: 8, type: CrossMathCellType.fixedNumber, label: '14'),

      // Hàng 9
      CrossMathCell(row: 9, col: 6, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 9, col: 8, type: CrossMathCellType.operator, label: '='),

      // Hàng 10
      CrossMathCell(row: 10, col: 2, type: CrossMathCellType.blank, targetText: '$e1'),
      CrossMathCell(row: 10, col: 3, type: CrossMathCellType.operator, label: '+'),
      CrossMathCell(row: 10, col: 4, type: CrossMathCellType.blank, targetText: '$e2'),
      CrossMathCell(row: 10, col: 5, type: CrossMathCellType.operator, label: '='),
      CrossMathCell(row: 10, col: 6, type: CrossMathCellType.blank, targetText: '$e3'),
      CrossMathCell(row: 10, col: 8, type: CrossMathCellType.blank, targetText: '28'),
    ];

    final pool = cells
        .where((c) => c.isBlank && c.targetText != null)
        .map((c) => c.targetText!)
        .toList();

    // Thêm một số số gây nhiễu
    while (pool.length < 15) {
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
