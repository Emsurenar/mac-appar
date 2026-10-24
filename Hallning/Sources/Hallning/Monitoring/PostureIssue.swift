import Foundation

/// What is wrong with a bad posture, and what to do about it.
enum PostureIssue: String, Codable, CaseIterable, Identifiable, Sendable {
    case slouching, forwardHead, roundedShoulders, lookingDown, tooClose
    case leaningLeft, leaningRight, shrugging, headTilt, chinOnHand
    /// From the AirPods: the neck bent further down than the limit.
    case neckBent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slouching: "Sit up straight"
        case .forwardHead: "Draw your head back"
        case .roundedShoulders: "Pull your shoulders back"
        case .lookingDown: "Raise your gaze"
        case .tooClose: "Lean back"
        case .leaningLeft, .leaningRight: "Straighten up"
        case .shrugging: "Drop your shoulders"
        case .headTilt: "Straighten your head"
        case .chinOnHand: "Let go of your chin"
        case .neckBent: "Lift your head"
        }
    }

    var advice: String {
        switch self {
        case .slouching: "You have slumped. Rise from your hips and let your spine grow towards the ceiling."
        case .forwardHead: "Your head has drifted forward. Tuck your chin slightly so your ears line up over your shoulders."
        case .roundedShoulders: "Your shoulders are rolling forward. Draw your shoulder blades back and down and open your chest."
        case .lookingDown: "You have been looking down for a while. Raise the screen so its top edge is at eye level."
        case .tooClose: "You are sitting close to the screen. Sit back in the chair with support for your lower back."
        case .leaningLeft: "You are leaning to the left. Spread your weight evenly over both sit bones."
        case .leaningRight: "You are leaning to the right. Spread your weight evenly over both sit bones."
        case .shrugging: "Your shoulders are pulled up towards your ears. Breathe out and let them sink."
        case .headTilt: "Your head is tilted to the side. Let it rest straight on top of your neck."
        case .chinOnHand: "You are resting your head on your hand. Put your hands on the desk and let your neck carry your head."
        case .neckBent: "Your neck is bent forward. Raise your eyes to the screen and tuck your chin slightly."
        }
    }

    /// Short name for charts and lists.
    var label: String {
        switch self {
        case .slouching: "Slumped"
        case .forwardHead: "Head forward"
        case .roundedShoulders: "Rounded shoulders"
        case .lookingDown: "Looking down"
        case .tooClose: "Too close to the screen"
        case .leaningLeft: "Leaning left"
        case .leaningRight: "Leaning right"
        case .shrugging: "Raised shoulders"
        case .headTilt: "Head tilted"
        case .chinOnHand: "Chin on hand"
        case .neckBent: "Bent neck"
        }
    }

    /// Whether this issue mostly shows as the head bending forward or down.
    var bendsNeck: Bool { self == .forwardHead || self == .lookingDown || self == .neckBent }

    /// The reminder text: how long it lasted, then the advice.
    func reminderBody(minutes: Int, neckLimit: Double) -> String {
        let duration = "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
        if self == .neckBent {
            return "Your neck has been bent more than \(Int(neckLimit.rounded()))° for \(duration). Raise your eyes to the screen and tuck your chin slightly."
        }
        return "You have had poor posture for \(duration). " + advice
    }
}

enum PostureLabel: String, Codable, Sendable {
    case good, bad
}
