import CoreGraphics
import Foundation

enum Feature: String, CaseIterable, Codable, Sendable {
    case neckHeight, headScale, shoulderWidth, shoulderTilt, headTilt, headOffset
    case shoulderHeight, headHeight, noseDrop, facePitch, faceYaw

    /// Prior weight in the distance.
    var weight: Double {
        switch self {
        case .neckHeight, .headScale: 1.0
        case .shoulderWidth, .shoulderTilt, .shoulderHeight: 0.8
        case .headOffset, .headHeight, .noseDrop: 0.6
        case .headTilt: 0.5
        case .facePitch: 0.4
        case .faceYaw: 0.2
        }
    }

    /// Floor for the good-class standard deviation.
    var minimumSpread: Double {
        switch self {
        case .neckHeight, .headOffset, .noseDrop: 0.03
        case .headScale: 0.02
        case .shoulderWidth, .shoulderHeight, .headHeight: 0.01
        case .shoulderTilt: 1.5
        case .headTilt: 2
        case .facePitch: 3
        case .faceYaw: 5
        }
    }

    static let gravityWeight = 1.2
    static let gravityMinimumSpread = 3.0
}

/// Posture features from one pose, plus the AirPods gravity direction. Every feature is optional.
struct FeatureVector: Codable, Equatable, Sendable {
    var values: [String: Double]
    var gravity: Vector3?
    /// AirPods pitch in degrees; only for display, not part of the distance.
    var headPitch: Double?

    subscript(_ feature: Feature) -> Double? {
        get { values[feature.rawValue] }
        set { values[feature.rawValue] = newValue }
    }

    init(values: [String: Double] = [:], gravity: Vector3? = nil, headPitch: Double? = nil) {
        self.values = values
        self.gravity = gravity
        self.headPitch = headPitch
    }

    /// Needs both shoulders and a head point (ears, else eyes, else nose).
    init?(pose: BodyPose, head headSample: HeadSample?) {
        guard let left = pose.point(.leftShoulder), let right = pose.point(.rightShoulder) else { return nil }
        let width = hypot(left.x - right.x, left.y - right.y)
        guard width > 0.02 else { return nil }
        let mid = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)

        let earsMid = Self.midpoint(pose.point(.leftEar), pose.point(.rightEar))
        let eyesMid = Self.midpoint(pose.point(.leftEye), pose.point(.rightEye))
        let nose = pose.point(.nose)
        guard let head = earsMid ?? eyesMid ?? nose ?? pose.point(.leftEar) ?? pose.point(.rightEar)
            ?? pose.point(.leftEye) ?? pose.point(.rightEye) else { return nil }

        values = [:]
        gravity = headSample?.gravity
        headPitch = headSample?.pitch
        self[.neckHeight] = Double((head.y - mid.y) / width)
        self[.shoulderWidth] = Double(width)
        self[.shoulderTilt] = Self.tilt(left, right)
        self[.shoulderHeight] = Double(mid.y)
        self[.headHeight] = Double(head.y)
        let mirrored = left.x < right.x
        self[.headOffset] = Double((head.x - mid.x) / width) * (mirrored ? -1 : 1)

        if let leftEye = pose.point(.leftEye), let rightEye = pose.point(.rightEye) {
            self[.headTilt] = Self.tilt(leftEye, rightEye)
        } else if let roll = pose.face?.roll {
            self[.headTilt] = roll
        }
        if let earsMid, let nose {
            self[.noseDrop] = Double((earsMid.y - nose.y) / width)
        }
        if let face = pose.face {
            self[.headScale] = Double(face.box.height / width)
            self[.facePitch] = face.pitch
            self[.faceYaw] = face.yaw
        }
    }

    /// Per-feature median of a burst, so one bad frame does not decide.
    static func median(_ vectors: [FeatureVector]) -> FeatureVector? {
        guard !vectors.isEmpty else { return nil }
        var result = FeatureVector()
        for feature in Feature.allCases {
            let values = vectors.compactMap { $0[feature] }.sorted()
            guard !values.isEmpty else { continue }
            let n = values.count
            result[feature] = n % 2 == 1 ? values[n / 2] : (values[n / 2 - 1] + values[n / 2]) / 2
        }
        result.gravity = Vector3.mean(vectors.compactMap(\.gravity))
        let pitches = vectors.compactMap(\.headPitch)
        result.headPitch = pitches.isEmpty ? nil : pitches.reduce(0, +) / Double(pitches.count)
        return result
    }

    /// Angle of the line between a left and a right point in degrees; robust to mirroring.
    private static func tilt(_ left: CGPoint, _ right: CGPoint) -> Double {
        let dx = max(abs(left.x - right.x), 1e-4)
        return Double(atan((left.y - right.y) / dx)) * 180 / .pi
    }

    private static func midpoint(_ a: CGPoint?, _ b: CGPoint?) -> CGPoint? {
        guard let a, let b else { return nil }
        return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}
