import 'package:flutter/material.dart';

import '../models/material.dart';

/// Mở bảng luật chơi PhaseShift (bottom sheet cuộn được).
/// Các con số khớp với engine/reaction_engine.dart và engine/physics_engine.dart.
Future<void> showPhaseShiftRules(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => _RulesContent(controller: controller),
    ),
  );
}

ElementBlock _b(ElementType t) => ElementBlock(type: t, id: t.name);

class _RulesContent extends StatelessWidget {
  final ScrollController controller;
  const _RulesContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Row(
          children: [
            Icon(Icons.science_rounded, color: Colors.teal.shade400),
            const SizedBox(width: 8),
            Expanded(child: Text('Luật chơi PhaseShift', style: text.titleLarge)),
          ],
        ),
        const SizedBox(height: 4),
        Text('Xếp khối nguyên tố và kích hoạt phản ứng dây chuyền để ghi điểm.',
            style: text.bodyMedium?.copyWith(color: muted)),

        const _Section('🎯 Mục tiêu'),
        const _Bullet('Mỗi lượt có một khối nguyên tố rơi từ hàng trên cùng xuống bàn 8 cột. '
            'Khối đầu tiên ra ở cột giữa; các khối sau ra ngay cột bạn vừa đặt khối trước '
            '(cột đó gần đầy thì ra ở cột giữa).'),
        const _Bullet('Đặt khối cạnh khối khác loại để tạo phản ứng: khối biến mất hoặc biến đổi, bạn được điểm.'),
        const _Bullet('Giữ cho bàn không bị đầy càng lâu càng tốt và đạt điểm cao nhất.'),

        const _Section('🎮 Điều khiển'),
        const _Control(Icons.arrow_back_rounded, 'Trái / Phải', 'Dời khối sang một cột.'),
        const _Control(Icons.arrow_downward_rounded, 'Xuống', 'Cho khối rơi nhanh một ô (+1 điểm mỗi ô).'),
        const _Control(Icons.vertical_align_bottom_rounded, 'Thả ngay',
            'Thả thẳng khối xuống đáy (+2 điểm mỗi ô rơi).'),
        const _Control(Icons.pause_circle_outline_rounded, 'Tạm dừng', 'Nút trên thanh tiêu đề.'),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Ô “Tiếp theo” cho biết khối sẽ ra ở lượt sau.',
              style: text.bodySmall?.copyWith(color: muted)),
        ),

        const _Section('🧱 Các khối nguyên tố'),
        _Element(_b(ElementType.fire), 'Bị Nước dập tắt; làm tan Băng thành Nước.'),
        _Element(_b(ElementType.water), 'Dập Lửa; bị Băng / Lạnh đóng băng. Đặt trên mép khối thì chảy xuống chỗ trống thấp hơn bên cạnh.'),
        _Element(_b(ElementType.ice), 'Đóng băng Nước bên cạnh thành Băng; bị Lửa làm tan.'),
        _Element(_b(ElementType.stone), 'Rất cứng, chỉ Axit mới hòa tan được.'),
        _Element(_b(ElementType.acid), 'Hòa tan Đá (cả hai cùng biến mất).'),
        _Element(_b(ElementType.frost), 'Đóng băng Nước bên cạnh rồi tự biến mất. Chỉ có ở Trung bình và Khó.'),
        _Element(_b(ElementType.electric), 'Hiếm (5%). Chạm bất kỳ khối nào là phát nổ, xóa vùng 3×3 quanh nó.'),

        const _Section('⚗️ Phản ứng & điểm'),
        Text('“Bên cạnh” là ô trên, dưới, trái, phải (không tính đường chéo). '
            'Điểm được nhân với hệ số combo hiện tại.',
            style: text.bodySmall?.copyWith(color: muted)),
        const SizedBox(height: 8),
        const _Reaction('⚡ Điện chạm khối bất kỳ', 'Nổ, xóa mọi khối trong ô 3×3 (kể cả chính nó)', '100 / khối'),
        const _Reaction('💧 Nước + 🔥 Lửa', 'Cả hai biến mất', '150'),
        const _Reaction('🧊 Băng + 💧 Nước', 'Nước bên cạnh hóa Băng, Băng gốc vẫn còn', '150 / khối'),
        const _Reaction('🔥 Lửa + 🧊 Băng', 'Lửa biến mất, Băng tan thành Nước', '150'),
        const _Reaction('🧪 Axit + 🪨 Đá', 'Cả hai biến mất', '200'),
        const _Reaction('❄️ Lạnh + 💧 Nước', 'Nước bên cạnh hóa Băng, Lạnh biến mất', '150 / khối'),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Nếu nhiều phản ứng xảy ra cùng lúc, thứ tự ưu tiên như danh sách trên.',
              style: text.bodySmall?.copyWith(color: muted)),
        ),

        const _Section('🔥 Combo & dây chuyền'),
        const _Bullet('Sau mỗi phản ứng, các khối phía trên rơi hẳn xuống lấp chỗ trống (không có khối lơ lửng), Nước chảy xuống chỗ thấp hơn. '
            'Nếu lại có cặp phản ứng, phản ứng tiếp tục ngay (dây chuyền).'),
        const _Bullet('Mỗi phản ứng tăng hệ số combo thêm 1. Combo được giữ suốt ván, nên càng về sau mỗi phản ứng càng nhiều điểm.'),

        const _Section('📊 Độ khó'),
        const _DifficultyTable(),

        const _Section('💀 Thua cuộc'),
        const _Bullet('Khối dừng lại ở hàng trên cùng, hoặc không còn chỗ cho khối mới xuất hiện.'),
        const _Bullet('Nếu bật “Giới hạn thời gian”: hết 3 phút là kết thúc ván.'),

        const _Section('🏆 Kỷ lục'),
        const _Bullet('Điểm cao nhất được lưu riêng cho từng độ khó trên máy.'),

        const _Section('💡 Mẹo'),
        const _Bullet('Đá chỉ mất khi gặp Axit: đừng chất Đá thành cột cao.'),
        const _Bullet('Thả Nước cạnh Lửa, rồi Băng cạnh Nước còn sót để nối nhiều phản ứng.'),
        const _Bullet('Để dành Điện cho chỗ bàn đang chất đống nhiều khối.'),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      );
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
}

class _Control extends StatelessWidget {
  final IconData icon;
  final String name;
  final String effect;
  const _Control(this.icon, this.name, this.effect);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            SizedBox(
              width: 92,
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Text(effect)),
          ],
        ),
      );
}

class _Element extends StatelessWidget {
  final ElementBlock block;
  final String effect;
  const _Element(this.block, this.effect);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: block.color.withAlpha(51),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: block.color),
              ),
              child: Icon(block.icon, color: block.color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(
                    text: '${block.symbol} ${block.name}: ',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: effect),
              ])),
            ),
          ],
        ),
      );
}

class _Reaction extends StatelessWidget {
  final String pair;
  final String result;
  final String points;
  const _Reaction(this.pair, this.result, this.points);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pair, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(result, style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('+$points',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade400)),
        ],
      ),
    );
  }
}

class _DifficultyTable extends StatelessWidget {
  const _DifficultyTable();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    TableRow row(List<String> cells, {bool header = false}) => TableRow(
          decoration: header ? BoxDecoration(color: scheme.surfaceContainerHigh) : null,
          children: [
            for (final c in cells)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(c,
                    style: TextStyle(fontWeight: header ? FontWeight.bold : FontWeight.normal)),
              ),
          ],
        );
    return Table(
      border: TableBorder.all(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(8)),
      columnWidths: const {0: FlexColumnWidth(1.2)},
      children: [
        row(['Độ khó', 'Bàn', 'Rơi 1 ô', 'Loại khối'], header: true),
        row(['Dễ', '10 × 8', '0,7 giây', '6 (không có Lạnh)']),
        row(['Trung bình', '12 × 8', '0,45 giây', '7']),
        row(['Khó', '14 × 8', '0,25 giây', '7']),
      ],
    );
  }
}
