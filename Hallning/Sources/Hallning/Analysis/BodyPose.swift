import CoreGraphics
import Foundation

enum JointName: String, Codable, CaseIterable {
    case leftEar, leftEye, rightEar, rightEye, neck, nose
    case leftShoulder, leftElbow, leftWrist, rightShoulder, rightElbow, rightWrist
    case root, leftHip, leftKnee, leftAnkle, rightHip, rightKnee, rightAnkle
}

/// One detected person. Points are normalised to the image (0…1, lower-left origin).
/// No image data is ever kept, only these coordinates.
struct BodyPose: Codable, Equatable {
    struct Face: Codable, Equatable {
        var box: CGRect
        var pitch: Double?
        var yaw: Double?
        var roll: Double?
    }

    var joints: [String: CGPoint]
    /// Image width / height.
    var aspect: Double
    var face: Face?
    /// Mean joint confidence, used to pick the best frame of a burst.
    var confidence: Double

    func normalized(_ joint: JointName) -> CGPoint? { joints[joint.rawValue] }

    /// The joint in a space where one unit is the image height.
    func point(_ joint: JointName) -> CGPoint? {
        guard let p = joints[joint.rawValue] else { return nil }
        return CGPoint(x: p.x * aspect, y: p.y)
    }

    var hasShoulders: Bool { joints[JointName.leftShoulder.rawValue] != nil && joints[JointName.rightShoulder.rawValue] != nil }

    var hasHead: Bool {
        [JointName.leftEar, .rightEar, .leftEye, .rightEye, .nose].contains { joints[$0.rawValue] != nil }
    }

    var isUsable: Bool { hasShoulders && hasHead }

    static let bones: [(JointName, JointName)] = [
        (.leftShoulder, .rightShoulder), (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist), (.neck, .nose),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip), (.leftHip, .rightHip),
        (.leftEye, .rightEye), (.leftEar, .leftEye), (.rightEar, .rightEye), (.nose, .leftEye), (.nose, .rightEye),
    ]
}
