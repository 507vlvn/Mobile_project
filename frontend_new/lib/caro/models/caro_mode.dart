import 'package:flutter/material.dart';

/// Chế độ chơi Caro
enum CaroGameMode {
  /// Đấu với trí tuệ nhân tạo (PvE)
  pve('Đấu với Máy', 'Luyện tập trí tuệ với AI từ Dễ đến Khó', Icons.smart_toy_rounded),

  /// 2 Người chơi chung một thiết bị (Pass & Play)
  pvpLocal('2 Người (Cùng máy)', 'Chuyền tay hoặc ngồi đối diện chơi cùng bạn bè', Icons.people_rounded),

  /// Cờ sinh tồn: Mỗi bên tối đa 6 quân, quân thứ 7 làm quân đầu tiên biến mất (FIFO)
  fading('Cờ sinh tồn', 'Tối đa 6 quân mỗi bên — quân cũ sẽ tự tan biến', Icons.hourglass_top_rounded);

  const CaroGameMode(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;

  static CaroGameMode fromName(String? name) {
    return CaroGameMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => CaroGameMode.pve,
    );
  }
}
