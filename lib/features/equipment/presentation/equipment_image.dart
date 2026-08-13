import 'package:flutter/material.dart';

class EquipmentImage extends StatelessWidget {
  const EquipmentImage({super.key, required this.equipmentId, this.size = 64});

  final String equipmentId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        'assets/equipment/$equipmentId.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.fitness_center, size: size * 0.55),
      ),
    );
  }
}
