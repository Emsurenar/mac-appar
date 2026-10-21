import Foundation

/// The animations the buddy can perform.
enum Move: String, CaseIterable {
    case armsUp, sideBend, neckTilt, shoulderRoll, twist, breathe, lookAway
    case armsWide, calfRaise, wristCircles, wiggle, hug
    case celebrate, wave
}

struct Exercise: Identifiable {
    let move: Move
    let titleKey: String
    let textKey: String

    init(_ move: Move, _ title: String, _ text: String) {
        self.move = move
        self.titleKey = title
        self.textKey = text
    }

    var id: String { move.rawValue }
    var title: String { L(titleKey) }
    var text: String { L(textKey) }
}

let allExercises: [Exercise] = [
    Exercise(.armsUp, "Reach for the sky", "Interlace your fingers and stretch your arms straight up."),
    Exercise(.sideBend, "Side bend", "One arm overhead, lean to the side. Switch halfway."),
    Exercise(.neckTilt, "Neck stretch", "Slowly tilt your ear toward your shoulder. Right, then left."),
    Exercise(.shoulderRoll, "Shoulder rolls", "Roll your shoulders backwards in big, slow circles."),
    Exercise(.twist, "Seated twist", "Twist your upper body with one hand on the chair back. Switch sides."),
    Exercise(.breathe, "Deep breaths", "Breathe in for four seconds and out for four. Drop your shoulders."),
    Exercise(.lookAway, "Rest your eyes", "Look at something at least 6 meters away and blink a few times."),
    Exercise(.armsWide, "Open your chest", "Bring your arms out and back and squeeze your shoulder blades."),
    Exercise(.calfRaise, "Calf raises", "Stand up, rise slowly onto your toes and back down again."),
    Exercise(.wristCircles, "Wrist circles", "Slowly roll your wrists in both directions."),
    Exercise(.wiggle, "Shake it out", "Shake out your arms and hands for a few seconds."),
    Exercise(.hug, "Back hug", "Give yourself a hug and breathe deeply into your back."),
]

/// Shown when a break is finished.
let cheers = ["Knots undone", "That's better", "Loose again", "Nicely stretched", "Lighter already"]
