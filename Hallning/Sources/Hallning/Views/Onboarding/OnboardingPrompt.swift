import Foundation

/// One guided posture in the calibration.
struct OnboardingPrompt: Identifiable {
    let id: Int
    let label: PostureLabel
    let issue: PostureIssue?
    let title: String
    let instruction: String
    let symbol: String

    /// How slouched the illustration should be.
    var slouch: Double {
        guard let issue else { return 0 }
        switch issue {
        case .slouching: return 1
        case .lookingDown: return 0.75
        case .forwardHead, .chinOnHand, .neckBent: return 0.6
        case .roundedShoulders: return 0.5
        case .tooClose: return 0.4
        case .leaningLeft, .leaningRight, .shrugging, .headTilt: return 0.2
        }
    }

    static let good: [OnboardingPrompt] = [
        .init(id: 0, label: .good, issue: nil, title: "Sit up straight and comfortably",
              instruction: "Feet on the floor, back against the backrest and shoulders relaxed.", symbol: "figure.stand"),
        .init(id: 1, label: .good, issue: nil, title: "Look at the left edge of the screen",
              instruction: "Stay just as upright and only turn your eyes and head slightly to the left.", symbol: "arrow.left"),
        .init(id: 2, label: .good, issue: nil, title: "Look at the right edge",
              instruction: "The same to the right. Keep your shoulders where they are.", symbol: "arrow.right"),
        .init(id: 3, label: .good, issue: nil, title: "Look at the top edge",
              instruction: "Raise your eyes to the top of the screen without leaning back.", symbol: "arrow.up"),
        .init(id: 4, label: .good, issue: nil, title: "Lower your eyes to the keyboard",
              instruction: "Look down with your eyes, without bending your neck.", symbol: "keyboard"),
        .init(id: 5, label: .good, issue: nil, title: "Hands on the keyboard",
              instruction: "Place your hands as if typing and sit up straight.", symbol: "hand.raised.fingers.spread"),
        .init(id: 6, label: .good, issue: nil, title: "Lean back slightly",
              instruction: "Rest against the backrest with a straight back, as when reading.", symbol: "chair.lounge"),
        .init(id: 7, label: .good, issue: nil, title: "Hands in your lap",
              instruction: "Drop your hands into your lap and keep your posture.", symbol: "hands.clap"),
        .init(id: 8, label: .good, issue: nil, title: "Sit up straight and breathe calmly",
              instruction: "Take a deep breath and let your shoulders sink as you breathe out.", symbol: "wind"),
        .init(id: 9, label: .good, issue: nil, title: "Your own best posture",
              instruction: "Sit the way you would like to sit when you work well.", symbol: "star.fill"),
    ]

    static let bad: [OnboardingPrompt] = [
        .init(id: 10, label: .bad, issue: .slouching, title: "Slump",
              instruction: "Let your back round and your chest sink, as at the end of a long day.", symbol: "arrow.down"),
        .init(id: 11, label: .bad, issue: .forwardHead, title: "Push your head forward",
              instruction: "Move your head towards the screen so your chin juts out.", symbol: "arrow.forward"),
        .init(id: 12, label: .bad, issue: .roundedShoulders, title: "Round your shoulders",
              instruction: "Let your shoulders roll forward and in towards your chest.", symbol: "arrow.turn.down.right"),
        .init(id: 13, label: .bad, issue: .lookingDown, title: "Look down into your lap",
              instruction: "Bend your neck and look down as when reading on your phone.", symbol: "iphone"),
        .init(id: 14, label: .bad, issue: .tooClose, title: "Lean close to the screen",
              instruction: "Lean your whole upper body towards the screen.", symbol: "arrow.up.left.and.arrow.down.right"),
        .init(id: 15, label: .bad, issue: .leaningLeft, title: "Lean to the left",
              instruction: "Lean your upper body to the left, as when resting on the armrest.", symbol: "arrow.down.left"),
        .init(id: 16, label: .bad, issue: .leaningRight, title: "Lean to the right",
              instruction: "The same to the right.", symbol: "arrow.down.right"),
        .init(id: 17, label: .bad, issue: .shrugging, title: "Raise your shoulders",
              instruction: "Pull your shoulders up towards your ears, as when cold or stressed.", symbol: "arrow.up.and.down"),
        .init(id: 18, label: .bad, issue: .chinOnHand, title: "Rest your chin on your hand",
              instruction: "Put your elbow on the desk and rest your chin on your hand.", symbol: "hand.raised.fill"),
        .init(id: 19, label: .bad, issue: .slouching, title: "Sink down in the chair",
              instruction: "Slide forward on the seat and sink down until you are almost lying.", symbol: "arrow.down.to.line"),
    ]

    static let all = good + bad
}
