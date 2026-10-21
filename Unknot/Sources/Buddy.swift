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
    var handToBrow = 0.0    // 1 when the right hand shades the eyes; in between while it gets there
    var headTilt = 0.0      // degrees; the head leans on its own (people), or the whole figure (everyone else)
    var bend = 0.0          // degrees; the upper body bends sideways at the waist
    var tiptoe = 0.0        // 0–1: up on the toes, heels off the ground, feet staying put
    var lookY = 0.0         // the eyes look up (negative) or down
    var leftTarget: HandTarget?
    var rightTarget: HandTarget?
    var leftReach = 0.0     // how far each hand has gone towards its target, 0–1
    var rightReach = 0.0
    var marks = Marks.none  // cartoon motion lines that show how a move goes
    var markStrength = 0.0
}

/// Little lines drawn beside the figure, the way comics show movement.
enum Marks { case none, shoulderRolls, shoulderLift, wristCircles, shake }

/// Places a hand can go, worked out for each member of the crew from where their head and shoulders are.
enum HandTarget {
    case overhead           // both hands meet above the head, fingers laced
    case farEar             // over the top of the head to the ear on the other side
    case farShoulder        // round to the other shoulder, as in a hug
    case chest              // in front of the chest, on its own side
    case acrossChest        // the arm straight across the chest to the other side
    case elbow              // pressing the other arm, which is across the chest, at the elbow
    case farHip             // across the body to the other hip, as if holding a chair back
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

/// Somewhere between two poses, for the change from one move to the next. Eyes and mouth switch halfway.
func mix(_ a: Pose, _ b: Pose, _ k: Double) -> Pose {
    func m(_ x: Double, _ y: Double) -> Double { x + (y - x) * k }
    var p = b
    p.tilt = m(a.tilt, b.tilt)
    p.lift = m(a.lift, b.lift)
    p.scaleX = m(a.scaleX, b.scaleX)
    p.scaleY = m(a.scaleY, b.scaleY)
    p.leftArm = m(a.leftArm, b.leftArm)
    p.rightArm = m(a.rightArm, b.rightArm)
    p.shoulderLift = m(a.shoulderLift, b.shoulderLift)
    p.faceShiftX = m(a.faceShiftX, b.faceShiftX)
    p.lookX = m(a.lookX, b.lookX)
    p.sproutSway = m(a.sproutSway, b.sproutSway)
    p.handOrbit = m(a.handOrbit, b.handOrbit)
    p.handPhase = m(a.handPhase, b.handPhase)
    p.handToBrow = m(a.handToBrow, b.handToBrow)
    p.headTilt = m(a.headTilt, b.headTilt)
    p.bend = m(a.bend, b.bend)
    p.tiptoe = m(a.tiptoe, b.tiptoe)
    p.lookY = m(a.lookY, b.lookY)
    // A hand moving between two different targets lets go of the first before it reaches for the second
    func hand(_ from: HandTarget?, _ fromReach: Double, _ to: HandTarget?, _ toReach: Double) -> (HandTarget?, Double) {
        if fromReach == 0 || from == to { return (toReach > 0 ? to : from, m(fromReach, toReach)) }
        if toReach == 0 { return (from, m(fromReach, 0)) }
        return k < 0.5 ? (from, fromReach * (1 - k * 2)) : (to, toReach * (k * 2 - 1))
    }
    (p.leftTarget, p.leftReach) = hand(a.leftTarget, a.leftReach, b.leftTarget, b.leftReach)
    (p.rightTarget, p.rightReach) = hand(a.rightTarget, a.rightReach, b.rightTarget, b.rightReach)
    p.marks = k < 0.5 ? a.marks : b.marks
    p.markStrength = k < 0.5 ? a.markStrength * (1 - k * 2) : b.markStrength * (k * 2 - 1)
    if k < 0.5 {
        p.eyes = a.eyes
        p.mouth = a.mouth
    }
    return p
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
        // Arms up, fingers laced above the head, up onto the toes for the stretch, then back down
        let c = phase(t, 4.6)
        let up = hold(c, 0.04, 0.30, 0.68, 0.90)
        let laced = hold(c, 0.16, 0.32, 0.66, 0.80)
        p.leftArm = 25 + up * 145
        p.rightArm = 25 + up * 145
        p.leftTarget = .overhead
        p.rightTarget = .overhead
        p.leftReach = laced
        p.rightReach = laced
        p.tiptoe = hold(c, 0.26, 0.38, 0.62, 0.78)
        p.scaleY += up * 0.06
        p.scaleX -= up * 0.03
        p.lookY = -up * 1.4
        p.eyes = laced > 0.7 ? .happy : .open
        p.mouth = laced > 0.9 ? .open : .smile

    case .sideBend:
        // One arm sweeps up and over the head and the body bends at the waist after it; then the other side
        let c = phase(t, 6.4)
        let right = hold(c, 0.03, 0.18, 0.36, 0.48)
        let left = hold(c, 0.53, 0.68, 0.86, 0.98)
        p.bend = (right - left) * 17
        p.leftArm = 25 + right * 172 - left * 12      // over the top, or sliding down the side
        p.rightArm = 25 + left * 172 - right * 12
        // The arm going over follows the head round, as it does when reaching up
        p.leftTarget = .overhead
        p.rightTarget = .overhead
        p.leftReach = right * 0.8
        p.rightReach = left * 0.8
        p.scaleY += (right + left) * 0.02
        p.faceShiftX = (right - left) * 2
        p.eyes = max(right, left) > 0.6 ? .happy : .open

    case .neckTilt:
        // The head leans towards one shoulder, and the hand on that side rests on the far ear and helps a little
        let c = phase(t, 6.4)
        let right = hold(c, 0.03, 0.2, 0.38, 0.5)
        let left = hold(c, 0.53, 0.7, 0.88, 1.0)
        let lean = right - left
        p.headTilt = lean * 17
        p.rightTarget = .farEar
        p.leftTarget = .farEar
        p.rightReach = hold(c, 0.08, 0.24, 0.36, 0.48)
        p.leftReach = hold(c, 0.58, 0.74, 0.86, 0.98)
        p.rightArm = 22 + right * 120
        p.leftArm = 22 + left * 120
        p.faceShiftX = lean * 2
        p.eyes = max(right, left) > 0.3 ? .closed : .open

    case .shoulderRoll:
        // Shoulders up to the ears, back, and down: big slow circles, the arms hanging loose
        let a = t * 2 * .pi / 2.4
        p.shoulderLift = (1 - cos(a)) * 5
        p.leftArm = 16 + sin(a) * 10
        p.rightArm = 16 + sin(a) * 10
        // Rolling back opens the chest, rolling forward rounds it
        p.scaleX += sin(a) * 0.025
        p.scaleY += (1 - cos(a)) * 0.012
        p.lookY = -sin(a) * 0.6
        p.marks = .shoulderRolls
        p.markStrength = 1

    case .twist:
        // Turn the upper body to one side, one hand across to the chair, the other behind; then the other way
        let c = phase(t, 5.6)
        let right = hold(c, 0.04, 0.2, 0.38, 0.5)
        let left = hold(c, 0.54, 0.7, 0.88, 1.0)
        let turn = right - left
        p.faceShiftX = turn * 10
        p.lookX = turn * 2
        p.scaleX -= abs(turn) * 0.08
        p.leftTarget = .farHip
        p.rightTarget = .farHip
        p.leftReach = right
        p.rightReach = left
        p.leftArm = 25 - right * 40 + left * 50
        p.rightArm = 25 - left * 40 + right * 50
        p.tilt = turn * 2.5

    case .breathe:
        // In for four, out for four: the chest fills, the shoulders rise, the arms float up and out
        let c = phase(t, 8)
        let breath = c < 0.5 ? ease(c / 0.5) : 1 - ease((c - 0.5) / 0.5)
        p.scaleX += breath * 0.07
        p.scaleY += breath * 0.05
        p.lift = breath * 1.5
        p.leftArm = 18 + breath * 40
        p.rightArm = 18 + breath * 40
        p.shoulderLift = breath * 3
        p.lookY = -breath * 0.8
        p.eyes = .closed
        p.mouth = (c > 0.52 && c < 0.92) ? .o : .smile

    case .lookAway:
        // A hand over the brow, a long look into the distance, then the other way; blink in between
        let c = phase(t, 6.4)
        let look = hold(c, 0.06, 0.18, 0.40, 0.50) - hold(c, 0.56, 0.68, 0.90, 1.0)
        p.lookX = look * 3.6
        p.faceShiftX = look * 2.5
        p.rightArm = -152 + sin(t * 1.4) * 2.5
        p.handToBrow = 1
        p.leftArm = 18
        p.tilt = look * 1.5
        p.lookY = -0.6
        if bump(c, at: 0.52, width: 0.025) > 0.3 || bump(c, at: 0.02, width: 0.02) > 0.3 { p.eyes = .closed }

    case .armsWide:
        // Arms out to the sides and pulled back, chest forward and up, chin up; hold, release
        let c = phase(t, 4.8)
        let open = hold(c, 0.05, 0.30, 0.70, 0.92)
        let squeeze = open * (0.5 + 0.5 * sin(t * 4))
        p.leftArm = 25 + open * 72 + squeeze * 6
        p.rightArm = 25 + open * 72 + squeeze * 6
        p.scaleY += open * 0.045
        p.scaleX += open * 0.04
        p.lift = open * 1.5
        p.shoulderLift = -open * 2
        p.lookY = -open * 1.5
        p.eyes = open > 0.8 ? .happy : .open
        p.mouth = open > 0.75 ? .open : .smile

    case .calfRaise:
        // Rise up onto the toes, hold, lower the heels slowly; the feet stay on the ground
        let c = phase(t, 2.6)
        let rise = hold(c, 0.04, 0.34, 0.54, 0.84)
        p.tiptoe = rise
        p.scaleY += rise * 0.03
        p.leftArm = 18 + rise * 10
        p.rightArm = 18 + rise * 10
        p.lookY = -rise * 0.5
        p.mouth = rise > 0.6 ? .open : .smile

    case .wristCircles:
        // Hands in front of the chest, drawing slow circles with the wrists
        let raise = ease(min(t / 0.8, 1))
        p.leftArm = 22 + raise * 40
        p.rightArm = 22 + raise * 40
        p.leftTarget = .chest
        p.rightTarget = .chest
        p.leftReach = raise
        p.rightReach = raise
        p.handOrbit = 3.6 * raise
        p.handPhase = t * 5
        p.marks = .wristCircles
        p.markStrength = raise
        p.lookY = 0.8 * raise
        p.tilt = sin(t * 2.5) * 0.8

    case .wiggle:
        // Shake it all out, in bursts, hands flapping
        let burst = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 1.4))
        p.tilt = sin(t * 9.5) * 5 * burst
        p.leftArm = 50 + sin(t * 11) * 30 * burst
        p.rightArm = 50 + sin(t * 11 + 2.1) * 30 * burst
        p.handOrbit = 2.4 * burst
        p.handPhase = t * 32
        p.marks = .shake
        p.markStrength = burst
        p.lift = abs(sin(t * 9.5)) * 2 * burst
        p.scaleX += sin(t * 19) * 0.015 * burst
        p.eyes = .happy
        p.mouth = .open

    case .hug:
        // Arms round the body, hands on the opposite shoulders, a slow squeeze and a gentle rock
        let reach = ease(min(t / 0.7, 1))
        let squeeze = 0.5 + 0.5 * sin(t * 2.0 - .pi / 2)
        p.leftArm = -50 - squeeze * 10
        p.rightArm = -50 - squeeze * 10
        p.leftTarget = .farShoulder
        p.rightTarget = .farShoulder
        p.leftReach = reach
        p.rightReach = reach
        p.scaleX -= squeeze * 0.045
        p.scaleY += squeeze * 0.015
        p.tilt = sin(t * 1.1) * 4
        p.eyes = .happy

    case .shrug:
        // Shoulders up to the ears, a held squeeze, then let everything drop
        let c = phase(t, 3.6)
        let up = hold(c, 0.05, 0.30, 0.55, 0.72)
        let drop = bump(c, at: 0.78, width: 0.08)
        // The arms ride up with the shoulders and the body squeezes down between them
        p.shoulderLift = up * 13
        p.leftArm = 18 + up * 14
        p.rightArm = 18 + up * 14
        p.scaleY += -up * 0.04 - drop * 0.02
        p.scaleX += up * 0.03 + drop * 0.02
        p.eyes = up > 0.75 ? .closed : .open
        p.mouth = c > 0.72 && c < 0.86 ? .o : .smile
        p.marks = .shoulderLift
        p.markStrength = up

    case .crossArm:
        // One arm straight across the chest, the other hand pressing it in at the elbow; then the other side
        let c = phase(t, 6.4)
        let right = hold(c, 0.04, 0.2, 0.4, 0.5)
        let left = hold(c, 0.54, 0.7, 0.9, 1.0)
        p.rightTarget = right > 0 ? .acrossChest : .elbow
        p.leftTarget = left > 0 ? .acrossChest : .elbow
        p.rightReach = max(right, left)
        p.leftReach = max(right, left)
        p.rightArm = 25 - right * 88 - left * 30
        p.leftArm = 25 - left * 88 - right * 30
        p.tilt = (left - right) * 2.5
        p.faceShiftX = (left - right) * 3
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
