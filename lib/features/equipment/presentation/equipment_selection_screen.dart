import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/features/equipment/data/equipment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EquipmentSelectionScreen extends ConsumerStatefulWidget {
  const EquipmentSelectionScreen({super.key});

  @override
  ConsumerState<EquipmentSelectionScreen> createState() =>
      _EquipmentSelectionScreenState();
}

class _EquipmentSelectionScreenState
    extends ConsumerState<EquipmentSelectionScreen> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final equipment = ref.watch(activeEquipmentProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('器具を選ぶ')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          children: [
            TextField(
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: const InputDecoration(
                hintText: '器具名で検索',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: equipment.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    const Center(child: Text('器具一覧を読み込めませんでした')),
                data: (items) {
                  final filtered = items
                      .where((item) => item.name.contains(_query))
                      .toList(growable: false);
                  if (filtered.isEmpty) {
                    return const Center(child: Text('該当する器具がありません'));
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _EquipmentTile(
                      equipment: filtered[index],
                      onTap: () => _openEquipment(filtered[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEquipment(EquipmentItem equipment) {
    final route = switch (equipment.metricType) {
      'cardio' => 'cardio',
      'bodyweight' => 'bodyweight',
      _ => 'strength',
    };
    context.push('/workout/$route/${equipment.id}');
  }
}

class _EquipmentTile extends StatelessWidget {
  const _EquipmentTile({required this.equipment, required this.onTap});

  final EquipmentItem equipment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        child: Icon(
          equipment.metricType == 'cardio'
              ? Icons.directions_run
              : Icons.fitness_center,
        ),
      ),
      title: Text(equipment.name),
      subtitle: Text(switch (equipment.metricType) {
        'bodyweight' => '自重・回数',
        'cardio' => '時間',
        _ => '重量・回数',
      }),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
