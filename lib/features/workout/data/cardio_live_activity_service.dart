import 'dart:io';

import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:flutter/services.dart';

class CardioLiveActivityService {
  CardioLiveActivityService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.naolab.chocolog/cardio_live_activity';

  final MethodChannel _channel;

  Future<void> sync({
    required CardioRecordSnapshot record,
    required String equipmentName,
  }) async {
    if (!Platform.isIOS) return;

    try {
      if (record.timerStatus == 'completed') {
        await _channel.invokeMethod<void>('end', {
          'recordId': record.id,
          'elapsedSeconds': record.durationSeconds ?? 0,
        });
        return;
      }

      final now = DateTime.now().toUtc();
      await _channel.invokeMethod<void>('sync', {
        'recordId': record.id,
        'equipmentId': record.equipmentId,
        'equipmentName': equipmentName,
        'elapsedSeconds': record.elapsedSecondsAt(now),
        'isPaused': record.timerStatus == 'paused',
      });
    } on MissingPluginException {
      // Live Activity is an optional iOS enhancement. Recording continues.
    } on PlatformException {
      // The user may disable Live Activities or the system may reach its limit.
    }
  }
}
