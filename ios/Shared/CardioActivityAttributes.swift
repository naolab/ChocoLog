import ActivityKit
import Foundation

struct CardioActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let adjustedStartedAt: Date?
    let elapsedSeconds: Int
    let isPaused: Bool
  }

  let recordId: String
  let equipmentId: String
  let equipmentName: String
}
