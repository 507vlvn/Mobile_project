import 'package:flutter/material.dart';

import '../../core/widgets/feedback_states.dart';

/// Sảnh Đối kháng — chỗ giữ chỗ. Phần Q4.1 sẽ thay bằng sảnh thật
/// (chọn game, tìm trận nhanh, lịch sử, rating).
class PvpLobbyScreen extends StatelessWidget {
  const PvpLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đối kháng')),
      body: const EmptyState(
        icon: Icons.sports_mma_rounded,
        title: 'Đối kháng đang được hoàn thiện',
        message: 'Sớm thôi, bạn sẽ đấu trực tiếp 1-1 với người chơi khác.',
      ),
    );
  }
}
