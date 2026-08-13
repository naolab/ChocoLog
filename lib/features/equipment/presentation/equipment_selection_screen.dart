import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/features/equipment/data/equipment_repository.dart';
import 'package:chocolog/features/equipment/presentation/equipment_image.dart';
import 'package:chocolog/features/studios/data/studio_repository.dart';
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
  StudioItem? _studio;
  var _onlyStudioEquipment = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadStudio);
  }

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
            if (_studio != null) ...[
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${_studio!.name}の器具'),
                subtitle: const Text('公式Webの参考情報を使用'),
                value: _onlyStudioEquipment,
                onChanged: (value) {
                  setState(() => _onlyStudioEquipment = value);
                },
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: equipment.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    const Center(child: Text('器具一覧を読み込めませんでした')),
                data: (items) {
                  final filtered = items
                      .where(
                        (item) =>
                            item.name.contains(_query) &&
                            (!_onlyStudioEquipment ||
                                _studio == null ||
                                _studio!.equipmentUnits.isEmpty ||
                                _studio!.equipmentUnits.containsKey(item.id)),
                      )
                      .toList(growable: false);
                  if (filtered.isEmpty) {
                    return const Center(child: Text('該当する器具がありません'));
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _EquipmentTile(
                      equipment: filtered[index],
                      units: _studio?.equipmentUnits[filtered[index].id],
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

  Future<void> _loadStudio() async {
    try {
      final session = await ref
          .read(workoutRepositoryProvider)
          .getActiveSession();
      if (session?.studioId == null) return;
      final studio = await StudioRepository.instance.findById(
        session!.studioId!,
      );
      if (mounted) setState(() => _studio = studio);
    } catch (_) {
      // Studio data is optional; the complete equipment list remains available.
    }
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
  const _EquipmentTile({
    required this.equipment,
    required this.onTap,
    this.units,
  });

  final EquipmentItem equipment;
  final VoidCallback onTap;
  final int? units;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: EquipmentImage(equipmentId: equipment.id, size: 58),
      title: Text(equipment.name),
      subtitle: Text(
        [
          switch (equipment.metricType) {
            'bodyweight' => '自重・回数',
            'cardio' => '時間',
            _ => '重量・回数',
          },
          if (units != null) '$units台',
        ].join('・'),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
