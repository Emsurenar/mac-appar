import Foundation

/// Learns the user's own good and bad postures. Features are standardised by the good
/// class, then a kernel-weighted kNN votes. Far-away samples are flagged as uncertain.
struct PostureClassifier: Sendable {
    struct Result: Equatable, Sendable {
        var badProbability: Double
        var isUncertain: Bool
        var issue: PostureIssue?
        var nearestDistance: Double
    }

    struct Evaluation: Equatable, Sendable {
        var correct: Int
        var total: Int
        /// Samples that were classified wrongly when left out.
        var misses: [UUID]
    }

    private struct Point: Sendable {
        let vector: FeatureVector
        let sample: Int
        let label: PostureLabel
        let issue: PostureIssue?
    }

    static let k = 7
    static let minimumSharedWeight = 2.5
    static let clamp = 8.0

    private let points: [Point]
    private var mean: [Feature: Double] = [:]
    private var spread: [Feature: Double] = [:]
    private var gravitySpread = Feature.gravityMinimumSpread
    private var goodPitch: Double?
    private var lowerPitchIsDown = true
    private(set) var sigma = 0.5

    let sampleCount: Int

    /// Nil unless there is at least one good and one bad sample.
    init?(samples: [CalibrationSample]) {
        let points = samples.enumerated().flatMap { index, sample in
            sample.vectors.map { Point(vector: $0, sample: index, label: sample.label, issue: sample.issue) }
        }
        guard points.contains(where: { $0.label == .good }), points.contains(where: { $0.label == .bad }) else { return nil }
        self.points = points
        self.sampleCount = samples.count
        fitStandardisation()
        fitSigma()
        fitPitch()
    }

    // MARK: Training

    private mutating func fitStandardisation() {
        let good = points.filter { $0.label == .good }.map(\.vector)
        for feature in Feature.allCases {
            let values = good.compactMap { $0[feature] }
            guard !values.isEmpty else {
                spread[feature] = feature.minimumSpread
                continue
            }
            let m = values.reduce(0, +) / Double(values.count)
            let variance = values.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(values.count)
            mean[feature] = m
            spread[feature] = max(variance.squareRoot(), feature.minimumSpread)
        }
        let gravities = good.compactMap(\.gravity)
        if let center = Vector3.mean(gravities) {
            let squares = gravities.map { pow(center.angle(to: $0), 2) }
            let rms = (squares.reduce(0, +) / Double(squares.count)).squareRoot()
            gravitySpread = max(rms, Feature.gravityMinimumSpread)
        }
    }

    /// σ is the median distance from each vector to its nearest neighbour in another pose.
    private mutating func fitSigma() {
        var nearest: [Double] = []
        for (i, a) in points.enumerated() {
            var best = Double.infinity
            for (j, b) in points.enumerated() where j != i && b.sample != a.sample {
                if let d = distance(a.vector, b.vector), d < best { best = d }
            }
            if best.isFinite { nearest.append(best) }
        }
        nearest.sort()
        let median = nearest.isEmpty ? 0 : nearest[nearest.count / 2]
        sigma = max(median, 0.5)
    }

    /// Which way the AirPods pitch moves when the user bends the neck.
    private mutating func fitPitch() {
        let good = points.filter { $0.label == .good }.compactMap(\.vector.headPitch)
        guard !good.isEmpty else { return }
        let goodMean = good.reduce(0, +) / Double(good.count)
        goodPitch = goodMean
        let bent = points.filter { $0.label == .bad && $0.issue?.bendsNeck == true }.compactMap(\.vector.headPitch)
        if !bent.isEmpty {
            lowerPitchIsDown = bent.reduce(0, +) / Double(bent.count) < goodMean
        }
    }

    // MARK: Distance

    private func distance(_ a: FeatureVector, _ b: FeatureVector) -> Double? {
        var sum = 0.0
        var weights = 0.0
        for feature in Feature.allCases {
            guard let x = a[feature], let y = b[feature], let s = spread[feature] else { continue }
            let z = min(max((x - y) / s, -Self.clamp), Self.clamp)
            sum += feature.weight * z * z
            weights += feature.weight
        }
        if let ga = a.gravity, let gb = b.gravity {
            let z = min(ga.angle(to: gb) / gravitySpread, Self.clamp)
            sum += Feature.gravityWeight * z * z
            weights += Feature.gravityWeight
        }
        guard weights >= Self.minimumSharedWeight else { return nil }
        return (sum / weights).squareRoot()
    }

    // MARK: Classification

    /// - Parameter threshold: P(bad) at or above which the posture counts as bad.
    func classify(_ vector: FeatureVector, threshold: Double = 0.5) -> Result? {
        var neighbours: [(distance: Double, point: Point)] = []
        neighbours.reserveCapacity(points.count)
        for point in points {
            if let d = distance(vector, point.vector) { neighbours.append((d, point)) }
        }
        guard !neighbours.isEmpty else { return nil }
        neighbours.sort { $0.distance < $1.distance }
        let nearest = Array(neighbours.prefix(Self.k))
        let dMin = nearest[0].distance

        // Relative to the nearest, so the weights never all underflow to zero.
        var total = 0.0
        var bad = 0.0
        var issueVotes: [PostureIssue: Double] = [:]
        for (d, point) in nearest {
            let w = exp(-(d * d - dMin * dMin) / (2 * sigma * sigma))
            total += w
            if point.label == .bad {
                bad += w
                if let issue = point.issue { issueVotes[issue, default: 0] += w }
            }
        }
        let probability = total > 0 ? bad / total : 0
        var issue: PostureIssue?
        if probability >= threshold {
            issue = issueVotes.max { $0.value < $1.value }?.key ?? inferIssue(vector)
        }
        return Result(badProbability: probability,
                      isUncertain: dMin > max(3 * sigma, 2.5),
                      issue: issue,
                      nearestDistance: dMin)
    }

    /// Falls back on how the features deviate from the good mean.
    func inferIssue(_ v: FeatureVector) -> PostureIssue {
        func z(_ f: Feature) -> Double {
            guard let x = v[f], let m = mean[f], let s = spread[f] else { return 0 }
            return (x - m) / s
        }
        var scores: [PostureIssue: Double] = [:]
        let tilt = z(.shoulderTilt)
        scores[tilt < 0 ? .leaningLeft : .leaningRight] = abs(tilt)
        var down = max(z(.noseDrop), abs(z(.facePitch)) * 0.6)
        if let g = v.gravity, let center = Vector3.mean(points.filter { $0.label == .good }.compactMap(\.vector.gravity)) {
            down = max(down, center.angle(to: g) / gravitySpread)
        }
        scores[.lookingDown] = down
        let neck = -z(.neckHeight)
        let shoulders = z(.shoulderHeight)
        if shoulders < 0 { scores[.slouching] = min(neck, -shoulders) + neck * 0.5 }
        if shoulders > 0 { scores[.shrugging] = min(neck, shoulders) + neck * 0.5 }
        scores[.forwardHead] = z(.headScale)
        scores[.tooClose] = z(.shoulderWidth)
        scores[.headTilt] = abs(z(.headTilt)) * 0.8
        guard let best = scores.max(by: { $0.value < $1.value }), best.value > 1.5 else { return .slouching }
        return best.key
    }

    /// How far the neck is bent compared with the good calibration, in degrees (positive is down).
    func neckAngle(pitch: Double) -> Double {
        let delta = pitch - (goodPitch ?? 0)
        return lowerPitchIsDown ? -delta : delta
    }

    // MARK: Evaluation

    /// Leave-one-pose-out cross-validation over the given samples.
    static func crossValidate(_ samples: [CalibrationSample], threshold: Double) -> Evaluation {
        var correct = 0
        var total = 0
        var misses: [UUID] = []
        for (index, sample) in samples.enumerated() {
            var rest = samples
            rest.remove(at: index)
            guard let classifier = PostureClassifier(samples: rest),
                  let vector = FeatureVector.median(sample.vectors),
                  let result = classifier.classify(vector, threshold: threshold) else { continue }
            total += 1
            if (result.badProbability >= threshold) == (sample.label == .bad) {
                correct += 1
            } else {
                misses.append(sample.id)
            }
        }
        return Evaluation(correct: correct, total: total, misses: misses)
    }
}
