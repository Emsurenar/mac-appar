import CoreGraphics
import Foundation
import Vision

/// Runs Vision's body pose and face rectangle models on a frame.
struct PoseAnalyzer: Sendable {
    static let minimumConfidence: Float = 0.3

    func analyze(_ image: CGImage) async -> BodyPose? {
        let bodies = (try? await DetectHumanBodyPoseRequest().perform(on: image)) ?? []
        let faces = (try? await DetectFaceRectanglesRequest().perform(on: image)) ?? []
        let aspect = Double(image.width) / Double(max(image.height, 1))

        var best: BodyPose?
        var bestWidth = 0.0
        for body in bodies {
            var pose = Self.pose(from: body, aspect: aspect)
            guard pose.hasShoulders || pose.hasHead else { continue }
            let width = Self.shoulderWidth(pose) ?? 0
            if best == nil || width > bestWidth {
                pose.face = Self.matchFace(faces, to: pose)
                best = pose
                bestWidth = width
            }
        }
        return best
    }

    private static func pose(from body: HumanBodyPoseObservation, aspect: Double) -> BodyPose {
        let candidates: [(JointName, Joint?)] = [
            (.leftEar,body.joint(for: .leftEar)), (.rightEar, body.joint(for: .rightEar)),
            (.leftEye, body.joint(for: .leftEye)), (.rightEye, body.joint(for: .rightEye)),
            (.neck, body.joint(for: .neck)), (.nose, body.joint(for: .nose)),
            (.leftShoulder, body.joint(for: .leftShoulder)), (.rightShoulder, body.joint(for: .rightShoulder)),
            (.leftElbow, body.joint(for: .leftElbow)), (.rightElbow, body.joint(for: .rightElbow)),
            (.leftWrist, body.joint(for: .leftWrist)), (.rightWrist, body.joint(for: .rightWrist)),
            (.root, body.joint(for: .root)), (.leftHip, body.joint(for: .leftHip)), (.rightHip, body.joint(for: .rightHip)),
        ]
        var joints: [String: CGPoint] = [:]
        var confidence = 0.0
        for (name, joint) in candidates {
            guard let joint, joint.confidence >= minimumConfidence else { continue }
            joints[name.rawValue] = CGPoint(x: Double(joint.location.x), y: Double(joint.location.y))
            confidence += Double(joint.confidence)
        }
        return BodyPose(joints: joints, aspect: aspect, face: nil,
                        confidence: joints.isEmpty ? 0 : confidence / Double(joints.count))
    }

    private static func shoulderWidth(_ pose: BodyPose) -> Double? {
        guard let l = pose.point(.leftShoulder), let r = pose.point(.rightShoulder) else { return nil }
        return hypot(l.x - r.x, l.y - r.y)
    }

    /// The face whose box contains (or lies closest to) this person's head.
    private static func matchFace(_ faces: [FaceObservation], to pose: BodyPose) -> BodyPose.Face? {
        let head = [JointName.nose, .leftEye, .rightEye, .leftEar, .rightEar].lazy.compactMap { pose.normalized($0) }.first
        var best: (face: BodyPose.Face, distance: Double)?
        for observation in faces {
            let box = observation.boundingBox.cgRect
            let distance: Double
            if let head {
                distance = box.contains(head) ? 0 : hypot(box.midX - head.x, box.midY - head.y)
            } else {
                distance = 1
            }
            guard distance < 0.25, best == nil || distance < best!.distance else { continue }
            let pitch: Measurement<UnitAngle>? = observation.pitch
            let yaw: Measurement<UnitAngle>? = observation.yaw
            let roll: Measurement<UnitAngle>? = observation.roll
            let face = BodyPose.Face(box: box,
                                     pitch: pitch?.converted(to: .degrees).value,
                                     yaw: yaw?.converted(to: .degrees).value,
                                     roll: roll?.converted(to: .degrees).value)
            best = (face, distance)
        }
        return best?.face
    }
}
