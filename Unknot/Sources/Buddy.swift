import SwiftUI

// The choreography: how the crew moves through every exercise. Drawing lives in LineArt.swift and Crew.swift.

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

enum Eyes { case open, happy, closed }
enum Mouth { case smile, open, o }

struct Pose {
    var tilt = 0.0          // degrees; the whole body leans around its feet
    var lift = 0.0          // height off the ground
    var scaleX = 1.0
    var scaleY = 1.0
    var leftArm = 30.0      // degrees: 0 hangs down, positive raises outwards, negative crosses in front
    var rightArm = 30.0
    var shoulderLift = 0.0
    var faceShiftX = 0.0    // the face turns sideways
    var lookX = 0.0         // the eyes look sideways
    var eyes = Eyes.open
    var mouth = Mouth.smile
    var sproutSway = 0.0    // sprouts, tufts and flowers sway with this
    var handOrbit = 0.0     // hands draw small circles (wrist circles)
    var handPhase = 0.0
    var handToBrow = false  // the right hand shades the eyes
}

// MARK: Timing helpers

/// Where in a repeating cycle of `period` seconds we are, from 0 to 1.
func phase(_ t: Double, _ period: Double) -> Double {
    let x = t.truncatingRemainder(dividingBy: period) / period
    return x < 0 ? x + 1 : x
}

/// Smooth start and smooth stop.
func ease(_ x: Double) -> Double {
    let c = min(max(x, 0), 1)
    return c * c * (3 - 2 * c)
}

/// 0 until `a`, rises to 1 at `b`, holds until `c`, falls back to 0 at `d`. Eased at both ends.
func hold(_ x: Double, _ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
    if x <= a || x >= d { return 0 }
    if x < b { return ease((x - a) / (b - a)) }
    if x <= c { return 1 }
    return 1 - ease((x - c) / (d - c))
}

/// A short bump around `center`, for squash on landing and similar accents.
func bump(_ x: Double, at center: Double, width: Double) -> Double {
    let d = abs(x - center) / width
    return d >= 1 ? 0 : 0.5 + 0.5 * cos(d * .pi)
}

// MARK: Moves

/// Every move starts from rest at t = 0, and its end leads straight back into its start.
func pose(for move: Move, at t: Double) -> Pose {
    var p = Pose()
    p.sproutSway = sin(t * 2.1) * 6
    // A quiet breath underneath everything, so nobody ever stands completely still
    let idle = sin(t * 1.6) * 0.012
    p.scaleY = 1 + idle
    p.scaleX = 1 - idle * 0.5

    switch move {
    case .armsUp:
        // Reach up, hold the stretch on tiptoe, come back down
        let c = phase(t, 4.6)
        let up = hold(c, 0.04, 0.30, 0.68, 0.90)
        p.leftArm = 25 + up * 147 + up * sin(t * 2.6) * 2.5
        p.rightArm = 25 + up * 147 + up * sin(t * 2.6 + 1.2) * 2.5
        p.scaleY += up * 0.075
        p.scaleX -= up * 0.035
        p.lift = up * 3.5
        p.eyes = up > 0.65 ? .happy : .open
        p.mouth = up > 0.9 ? .open : .smile

    case .sideBend:
        // Left arm over, lean right; hold; then the other side
        let c = phase(t, 6.4)
        let right = hold(c, 0.03, 0.18, 0.36, 0.48)
        let left = hold(c, 0.53, 0.68, 0.86, 0.98)
        p.tilt = (right - left) * 13
        p.leftArm = 25 + right * 142
        p.rightArm = 25 + left * 142
        p.scaleY += (right + left) * 0.03
        p.faceShiftX = (right - left) * 2
        p.eyes = max(right, left) > 0.6 ? .happy : .open

    case .neckTilt:
        // Ear towards the shoulder, slowly, eyes closed
        let c = phase(t, 6.4)
        let right = hold(c, 0.03, 0.2, 0.38, 0.5)
        let left = hold(c, 0.53, 0.7, 0.88, 1.0)
        let lean = right - left
        p.tilt = lean * 10
        p.faceShiftX = lean * 3.5
        p.leftArm = 22 - lean * 4
        p.rightArm = 22 + lean * 4
        p.eyes = max(right, left) > 0.3 ? .closed : .open

    case .shoulderRoll:
        // Big, slow circles: up, back, down
        let a = t * 2 * .pi / 2.2
        p.shoulderLift = (1 - cos(a)) * 3.4
        p.leftArm = 22 + sin(a) * 9
        p.rightArm = 22 + sin(a) * 9
        p.scaleY += (1 - cos(a)) * 0.012
        p.tilt = sin(a) * 1.2

    case .twist:
        // Turn the upper body to one side, hold, then the other
        let c = phase(t, 5.6)
        let right = hold(c, 0.04, 0.2, 0.38, 0.5)
        let left = hold(c, 0.54, 0.7, 0.88, 1.0)
        let turn = right - left
        p.faceShiftX = turn * 10
        p.lookX = turn * 1.6
        p.scaleX -= abs(turn) * 0.06
        p.leftArm = 30 - turn * 62     // one arm swings across the front, the other back
        p.rightArm = 30 + turn * 62
        p.tilt = turn * 2

    case .breathe:
        // In for four, out for four
        let c = phase(t, 8)
        let breath = c < 0.5 ? ease(c / 0.5) : 1 - ease((c - 0.5) / 0.5)
        p.scaleX += breath * 0.06
        p.scaleY += breath * 0.05
        p.lift = breath * 1.5
        p.leftArm = 20 + breath * 26
        p.rightArm = 20 + breath * 26
        p.shoulderLift = breath * 2
        p.eyes = .closed
        p.mouth = (c > 0.52 && c < 0.92) ? .o : .smile

    case .lookAway:
        // A hand over the brow, a long look into the distance, then the other way; blink in between
        let c = phase(t, 6.4)
        let look = hold(c, 0.06, 0.18, 0.40, 0.50) - hold(c, 0.56, 0.68, 0.90, 1.0)
        p.lookX = look * 3.6
        p.faceShiftX = look * 2.5
        p.rightArm = -152 + sin(t * 1.4) * 2.5
        p.handToBrow = true
        p.leftArm = 18
        p.tilt = look * 1.5
        if bump(c, at: 0.52, width: 0.025) > 0.3 || bump(c, at: 0.02, width: 0.02) > 0.3 { p.eyes = .closed }

    case .armsWide:
        // Arms out and back, chest open, hold, release
        let c = phase(t, 4.8)
        let open = hold(c, 0.05, 0.30, 0.70, 0.92)
        p.leftArm = 25 + open * 88
        p.rightArm = 25 + open * 88
        p.scaleY += open * 0.04
        p.scaleX += open * 0.02
        p.lift = open * 1.5
        p.shoulderLift = -open * 1.5
        p.eyes = open > 0.8 ? .happy : .open
        p.mouth = open > 0.75 ? .open : .smile

    case .calfRaise:
        // Up on the toes, hold, down with a soft landing
        let c = phase(t, 2.4)
        let rise = hold(c, 0.04, 0.32, 0.52, 0.78)
        let land = bump(c, at: 0.84, width: 0.08)
        p.lift = rise * 10
        p.scaleY += rise * 0.045 - land * 0.045
        p.scaleX += land * 0.04
        p.leftArm = 22 + rise * 12
        p.rightArm = 22 + rise * 12
        p.mouth = rise > 0.6 ? .open : .smile

    case .wristCircles:
        // Arms forward, hands drawing small circles
        let raise = ease(min(t / 0.8, 1))
        p.leftArm = 22 + raise * 56
        p.rightArm = 22 + raise * 56
        p.handOrbit = 3 * raise
        p.handPhase = t * 6
        p.tilt = sin(t * 3) * 1

    case .wiggle:
        // Shake it all out, in bursts
        let burst = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 1.4))
        p.tilt = sin(t * 9.5) * 5 * burst
        p.leftArm = 50 + sin(t * 11) * 30 * burst
        p.rightArm = 50 + sin(t * 11 + 2.1) * 30 * burst
        p.lift = abs(sin(t * 9.5)) * 2 * burst
        p.scaleX += sin(t * 19) * 0.015 * burst
        p.eyes = .happy
        p.mouth = .open

    case .hug:
        // Arms around, a slow squeeze, a gentle rock
        let squeeze = 0.5 + 0.5 * sin(t * 2.0 - .pi / 2)
        p.leftArm = -50 - squeeze * 10
        p.rightArm = -50 - squeeze * 10
        p.scaleX -= squeeze * 0.035
        p.scaleY += squeeze * 0.015
        p.tilt = sin(t * 1.1) * 4
        p.eyes = .happy

    case .shrug:
        // Shoulders up to the ears, a held squeeze, then let everything drop
        let c = phase(t, 3.6)
        let up = hold(c, 0.05, 0.30, 0.55, 0.72)
        let drop = bump(c, at: 0.78, width: 0.08)
        // The arms ride up with the shoulders and the body squeezes down between them
        p.shoulderLift = up * 12
        p.leftArm = 20 + up * 16
        p.rightArm = 20 + up * 16
        p.scaleY += -up * 0.035 - drop * 0.02
        p.scaleX += up * 0.025 + drop * 0.02
        p.eyes = up > 0.75 ? .closed : .open
        p.mouth = c > 0.72 && c < 0.86 ? .o : .smile

    case .crossArm:
        // One arm pulled across the chest by the other, held, then the other side
        let c = phase(t, 6.4)
        let right = hold(c, 0.04, 0.2, 0.4, 0.5)
        let left = hold(c, 0.54, 0.7, 0.9, 1.0)
        p.rightArm = 25 - right * 88 - left * 30
        p.leftArm = 25 - left * 88 - right * 30
        p.tilt = (left - right) * 2.5
        p.faceShiftX = (left - right) * 2.5
        p.eyes = max(right, left) > 0.8 ? .happy : .open

    case .celebrate:
        // Little jumps with arms up, squash on every landing
        let c = phase(t, 0.84)
        let air = c < 0.68 ? sin(c / 0.68 * .pi) : 0
        let land = bump(c, at: 0.78, width: 0.12)
        p.lift = air * 14
        p.scaleY += air * 0.04 - land * 0.06
        p.scaleX += land * 0.05
        p.leftArm = 148 + sin(t * 9) * 14
        p.rightArm = 148 - sin(t * 9) * 14
        p.eyes = .happy
        p.mouth = .open

    case .wave:
        // Hello: a raised hand waving, a friendly lean
        p.rightArm = 138 + sin(t * 7) * 22
        p.leftArm = 22
        p.tilt = sin(t * 1.6) * 2.5
        p.mouth = .open
    }
    return p
}

// MARK: Cues

/// A few words to go with the move at time `t`, when timing matters: when to breathe in, when to switch
/// sides. They follow the same timings as the poses above.
func cue(for move: Move, at t: Double) -> String? {
    switch move {
    case .breathe:
        let c = phase(t, 8)
        let count = min(Int(c.truncatingRemainder(dividingBy: 0.5) / 0.125) + 1, 4)
        return c < 0.5 ? L("Breathe in · %ld", count) : L("Breathe out · %ld", count)
    case .sideBend, .neckTilt:
        let c = phase(t, 6.4)
        return c > 0.42 && c < 0.62 ? L("Switch sides") : nil
    case .twist:
        let c = phase(t, 5.6)
        return c > 0.42 && c < 0.62 ? L("Switch sides") : nil
    case .crossArm:
        let c = phase(t, 6.4)
        return c > 0.42 && c < 0.62 ? L("Switch sides") : nil
    case .shrug:
        let c = phase(t, 3.6)
        if c < 0.05 || c > 0.82 { return nil }
        return c < 0.30 ? L("Shoulders up") : (c < 0.55 ? L("Hold") : L("And let go"))
    default:
        return nil
    }
}
