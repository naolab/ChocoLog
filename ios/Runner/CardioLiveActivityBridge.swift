import ActivityKit
import Flutter
import Foundation

enum CardioLiveActivityBridge {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.naolab.chocolog/cardio_live_activity",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard #available(iOS 16.2, *) else {
        result(nil)
        return
      }

      guard let arguments = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
        return
      }

      Task { @MainActor in
        do {
          switch call.method {
          case "sync":
            try await sync(arguments)
          case "end":
            await end(arguments)
          default:
            result(FlutterMethodNotImplemented)
            return
          }
          result(nil)
        } catch {
          result(
            FlutterError(
              code: "live_activity_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }

  @available(iOS 16.2, *)
  @MainActor
  private static func sync(_ arguments: [String: Any]) async throws {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    guard
      let recordId = arguments["recordId"] as? String,
      let equipmentId = arguments["equipmentId"] as? String,
      let equipmentName = arguments["equipmentName"] as? String,
      let elapsedSeconds = arguments["elapsedSeconds"] as? Int,
      let isPaused = arguments["isPaused"] as? Bool
    else {
      throw BridgeError.invalidArguments
    }

    let state = CardioActivityAttributes.ContentState(
      adjustedStartedAt: isPaused
        ? nil
        : Date().addingTimeInterval(TimeInterval(-elapsedSeconds)),
      elapsedSeconds: elapsedSeconds,
      isPaused: isPaused
    )
    let content = ActivityContent(state: state, staleDate: nil)

    if let activity = Activity<CardioActivityAttributes>.activities.first(
      where: { $0.attributes.recordId == recordId }
    ) {
      await activity.update(content)
      return
    }

    for activity in Activity<CardioActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }

    let attributes = CardioActivityAttributes(
      recordId: recordId,
      equipmentId: equipmentId,
      equipmentName: equipmentName
    )
    _ = try Activity.request(
      attributes: attributes,
      content: content,
      pushType: nil
    )
  }

  @available(iOS 16.2, *)
  @MainActor
  private static func end(_ arguments: [String: Any]) async {
    guard let recordId = arguments["recordId"] as? String else { return }
    let elapsedSeconds = arguments["elapsedSeconds"] as? Int ?? 0
    let finalState = CardioActivityAttributes.ContentState(
      adjustedStartedAt: nil,
      elapsedSeconds: elapsedSeconds,
      isPaused: true
    )
    let content = ActivityContent(state: finalState, staleDate: nil)

    for activity in Activity<CardioActivityAttributes>.activities
    where activity.attributes.recordId == recordId {
      await activity.end(content, dismissalPolicy: .immediate)
    }
  }
}

private enum BridgeError: LocalizedError {
  case invalidArguments

  var errorDescription: String? {
    "Live Activityの引数が不正です"
  }
}
