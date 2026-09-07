import SwiftUI
import UIKit

/// Centralized haptic helper for tactile feedback across the app.
///
/// Supports pre-warmed `.rigid` mechanical impacts for horizontal page snaps,
/// directional step sensory feedback for time quick adjustments (+/- 15m),
/// and toggle state changes, respecting user haptic settings.
@MainActor
enum AppHaptics {
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)

    /// Pre-warms the rigid generator for horizontal swipe actions to eliminate latency.
    static func preparePageSnap() {
        rigidGenerator.prepare()
    }

    /// Triggers a satisfying mechanical snap when switching alarm modes (Full Alarm <-> Wake Only).
    static func pageSnap(hapticsEnabled: Bool = true) {
        guard hapticsEnabled else { return }
        rigidGenerator.prepare()
        rigidGenerator.impactOccurred(intensity: 1.0)
    }

    /// Directional pitch sensory feedback for quick stepper adjustments (+/- 15m, etc.).
    static func stepAdjustment(direction: StepDirection, hapticsEnabled: Bool = true) {
        guard hapticsEnabled else { return }
        switch direction {
        case .increase:
            mediumGenerator.prepare()
            mediumGenerator.impactOccurred(intensity: 0.85)
        case .decrease:
            lightGenerator.prepare()
            lightGenerator.impactOccurred(intensity: 0.70)
        }
    }

    /// Triggers tactile feedback when a toggle switch changes state.
    static func toggleChanged(isOn: Bool, hapticsEnabled: Bool = true) {
        guard hapticsEnabled else { return }
        let generator = isOn ? mediumGenerator : lightGenerator
        generator.prepare()
        generator.impactOccurred()
    }

    /// Triggers a selection tick.
    static func selectionChanged(hapticsEnabled: Bool = true) {
        guard hapticsEnabled else { return }
        selectionGenerator.selectionChanged()
    }

    enum StepDirection: Sendable {
        case increase
        case decrease
    }
}
