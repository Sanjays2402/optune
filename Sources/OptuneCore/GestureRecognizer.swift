import Foundation

/// Swipe direction of a gesture-button drag.
public enum GestureDirection: String, Codable, CaseIterable, Sendable, Hashable {
    case up, down, left, right

    public var label: String { rawValue.capitalized }
}

/// Turns the raw XY deltas a diverted gesture button streams while held into a
/// tap or a four-way swipe, decided when the button is released.
public struct GestureRecognizer: Sendable {
    public enum Result: Equatable, Sendable {
        case tap
        case swipe(GestureDirection)
    }

    /// Minimum accumulated travel (device units) before a drag counts as a swipe.
    public let threshold: Int
    private var dx = 0
    private var dy = 0
    public private(set) var isTracking = false

    public init(threshold: Int = 50) {
        self.threshold = threshold
    }

    public mutating func begin() {
        dx = 0
        dy = 0
        isTracking = true
    }

    public mutating func move(dx: Int, dy: Int) {
        guard isTracking else { return }
        self.dx += dx
        self.dy += dy
    }

    /// Finish the gesture. Returns nil when no gesture was in progress.
    public mutating func end() -> Result? {
        guard isTracking else { return nil }
        isTracking = false
        let ax = abs(dx), ay = abs(dy)
        guard max(ax, ay) >= threshold else { return .tap }
        if ax >= ay { return .swipe(dx > 0 ? .right : .left) }
        return .swipe(dy > 0 ? .down : .up)   // HID++ Y grows downward, like screen space
    }
}
