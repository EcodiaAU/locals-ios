import UIKit

/// Tight wrapper over UIFeedbackGenerator. SwiftUI 17's .sensoryFeedback
/// covers most cases inline, but the code-issued flow wants two beats
/// (light prepare + success) and the consume-code flow wants notification
/// success - both easier as one-liners here.
enum Haptics {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let g = UIImpactFeedbackGenerator(style: style)
        g.impactOccurred()
    }

    static func success() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.success)
    }

    static func warn() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.warning)
    }

    static func error() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.error)
    }
}
