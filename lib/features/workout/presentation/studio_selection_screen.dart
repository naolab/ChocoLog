import 'package:chocolog/features/workout/presentation/workout_flow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StudioSelectionScreen extends ConsumerWidget {
  const StudioSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutFlowControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('今回の店舗')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.location_on_outlined, size: 36),
                    SizedBox(height: 12),
                    Text('よく行く店舗の登録は準備中です。今回はすべての器具から選べます。'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: session.isLoading
                  ? null
                  : () async {
                      try {
                        await ref
                            .read(workoutFlowControllerProvider.notifier)
                            .ensureSession();
                        if (context.mounted) {
                          await context.push('/workout/equipment');
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('トレーニングを開始できませんでした')),
                          );
                        }
                      }
                    },
              child: Text(session.isLoading ? '開始中…' : '店舗を選ばずに続ける'),
            ),
          ],
        ),
      ),
    );
  }
}
