/// Trạng thái hiện diện của một người chơi.
enum PresenceStatus {
  online('online', 'Đang online'),
  inMatch('in_match', 'Đang trong trận'),
  offline('offline', 'Ngoại tuyến');

  const PresenceStatus(this.code, this.label);
  final String code;
  final String label;

  /// Chấp nhận nhiều cách viết: "online", "in_match", "InMatch", "in-match"...
  static PresenceStatus parse(Object? v) {
    final s = (v is String ? v : '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]'), '');
    return switch (s) {
      'online' || 'available' || 'active' => online,
      'inmatch' || 'playing' || 'ingame' || 'busy' => inMatch,
      _ => offline,
    };
  }

  bool get isOnline => this != offline;
}
