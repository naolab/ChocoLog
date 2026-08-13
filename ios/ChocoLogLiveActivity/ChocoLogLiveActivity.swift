import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ChocoLogLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    CardioLiveActivityWidget()
  }
}

struct CardioLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: CardioActivityAttributes.self) { context in
      HStack(spacing: 14) {
        Image(systemName: "figure.run")
          .font(.title2)
          .foregroundStyle(.black)
          .frame(width: 42, height: 42)
          .background(Color.chocoYellow, in: Circle())

        VStack(alignment: .leading, spacing: 3) {
          Text(context.attributes.equipmentName)
            .font(.headline)
            .lineLimit(1)
          Text(context.state.isPaused ? "一時停止中" : "計測中")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()
        elapsedTime(context.state)
          .font(.title3.monospacedDigit().bold())
      }
      .padding()
      .activityBackgroundTint(.white)
      .activitySystemActionForegroundColor(.black)
      .widgetURL(deepLink(context.attributes.equipmentId))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label("chocoLOG", systemImage: "figure.run")
            .font(.caption.bold())
        }
        DynamicIslandExpandedRegion(.trailing) {
          elapsedTime(context.state)
            .font(.headline.monospacedDigit())
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            Text(context.attributes.equipmentName)
              .lineLimit(1)
            Spacer()
            Text(context.state.isPaused ? "一時停止中" : "計測中")
              .foregroundStyle(.secondary)
          }
          .font(.caption)
        }
      } compactLeading: {
        Image(systemName: "figure.run")
          .foregroundStyle(Color.chocoYellow)
      } compactTrailing: {
        elapsedTime(context.state)
          .font(.caption2.monospacedDigit())
      } minimal: {
        Image(systemName: "figure.run")
          .foregroundStyle(Color.chocoYellow)
      }
      .widgetURL(deepLink(context.attributes.equipmentId))
      .keylineTint(Color.chocoYellow)
    }
  }

  @ViewBuilder
  private func elapsedTime(
    _ state: CardioActivityAttributes.ContentState
  ) -> some View {
    if let startedAt = state.adjustedStartedAt, !state.isPaused {
      Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
    } else {
      Text(formatDuration(state.elapsedSeconds))
    }
  }

  private func formatDuration(_ seconds: Int) -> String {
    String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
  }

  private func deepLink(_ equipmentId: String) -> URL? {
    URL(string: "chocolog:///workout/cardio/\(equipmentId)")
  }
}

private extension Color {
  static let chocoYellow = Color(red: 1.0, green: 0.84, blue: 0.0)
}
