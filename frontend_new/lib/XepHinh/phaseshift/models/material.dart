import 'package:flutter/material.dart';

enum ElementType {
  fire,     // 🔥 Lửa
  ice,      // 🧊 Băng
  water,    // 💧 Nước
  electric, // ⚡ Điện
  stone,    // 🪨 Đá
  acid,     // 🧪 Axit
  frost,    // ❄️ Lạnh
}

class ElementBlock {
  final ElementType type;
  final String id;

  const ElementBlock({
    required this.type,
    required this.id,
  });

  String get name {
    switch (type) {
      case ElementType.fire:
        return 'Lửa';
      case ElementType.ice:
        return 'Băng';
      case ElementType.water:
        return 'Nước';
      case ElementType.electric:
        return 'Điện';
      case ElementType.stone:
        return 'Đá';
      case ElementType.acid:
        return 'Axit';
      case ElementType.frost:
        return 'Lạnh';
    }
  }

  String get symbol {
    switch (type) {
      case ElementType.fire:
        return '🔥';
      case ElementType.ice:
        return '🧊';
      case ElementType.water:
        return '💧';
      case ElementType.electric:
        return '⚡';
      case ElementType.stone:
        return '🪨';
      case ElementType.acid:
        return '🧪';
      case ElementType.frost:
        return '❄️';
    }
  }

  Color get color {
    switch (type) {
      case ElementType.fire:
        return Colors.deepOrange;
      case ElementType.ice:
        return Colors.cyan.shade300;
      case ElementType.water:
        return Colors.blue.shade600;
      case ElementType.electric:
        return Colors.amber.shade600;
      case ElementType.stone:
        return Colors.blueGrey.shade700;
      case ElementType.acid:
        return Colors.lime.shade600;
      case ElementType.frost:
        return Colors.indigo.shade200;
    }
  }

  IconData get icon {
    switch (type) {
      case ElementType.fire:
        return Icons.local_fire_department_rounded;
      case ElementType.ice:
        return Icons.ac_unit_rounded;
      case ElementType.water:
        return Icons.water_drop_rounded;
      case ElementType.electric:
        return Icons.bolt_rounded;
      case ElementType.stone:
        return Icons.terrain_rounded;
      case ElementType.acid:
        return Icons.science_rounded;
      case ElementType.frost:
        return Icons.severe_cold_rounded;
    }
  }
}
