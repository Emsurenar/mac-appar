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
        case .slouching: "Sträck på dig"
        case .forwardHead: "Dra bakhuvudet bakåt"
        case .roundedShoulders: "Dra bak axlarna"
        case .lookingDown: "Lyft blicken"
        case .tooClose: "Luta dig tillbaka"
        case .leaningLeft, .leaningRight: "Räta upp dig"
        case .shrugging: "Släpp ner axlarna"
        case .headTilt: "Räta upp huvudet"
        case .chinOnHand: "Släpp hakan"
        case .neckBent: "Lyft huvudet"
        }
    }

    var advice: String {
        switch self {
        case .slouching: "Du har sjunkit ihop. Res dig från höfterna och låt ryggen växa mot taket."
        case .forwardHead: "Huvudet har glidit fram. Dra in hakan lätt så att öronen hamnar rakt ovanför axlarna."
        case .roundedShoulders: "Axlarna rullar framåt. För skulderbladen bakåt och nedåt och öppna bröstet."
        case .lookingDown: "Du tittar ner länge. Höj skärmen så att överkanten hamnar i ögonhöjd."
        case .tooClose: "Du sitter nära skärmen. Sätt dig långt bak i stolen med stöd för ländryggen."
        case .leaningLeft: "Du lutar åt vänster. Fördela vikten jämnt på båda sittbenen."
        case .leaningRight: "Du lutar åt höger. Fördela vikten jämnt på båda sittbenen."
        case .shrugging: "Axlarna är uppdragna mot öronen. Andas ut och låt dem sjunka."
        case .headTilt: "Huvudet lutar åt sidan. Låt det vila rakt ovanpå halsen."
        case .chinOnHand: "Du stöder huvudet i handen. Lägg händerna på bordet och låt nacken bära huvudet."
        case .neckBent: "Nacken är böjd framåt. Lyft blicken mot skärmen och dra in hakan lätt."
        }
    }

    /// Short name for charts and lists.
    var label: String {
        switch self {
        case .slouching: "Hopsjunken"
        case .forwardHead: "Huvudet framåt"
        case .roundedShoulders: "Rundade axlar"
        case .lookingDown: "Tittar ner"
        case .tooClose: "För nära skärmen"
        case .leaningLeft: "Lutar åt vänster"
        case .leaningRight: "Lutar åt höger"
        case .shrugging: "Uppdragna axlar"
        case .headTilt: "Lutar huvudet"
        case .chinOnHand: "Hakan i handen"
        case .neckBent: "Böjd nacke"
        }
    }

    /// Whether this issue mostly shows as the head bending forward or down.
    var bendsNeck: Bool { self == .forwardHead || self == .lookingDown || self == .neckBent }

    /// The reminder text: how long it lasted, then the advice.
    func reminderBody(minutes: Int, neckLimit: Double) -> String {
        let duration = "\(minutes) \(minutes == 1 ? "minut" : "minuter")"
        if self == .neckBent {
            return "Nacken har varit böjd mer än \(Int(neckLimit.rounded()))° i \(duration). Lyft blicken mot skärmen och dra in hakan lätt."
        }
        return "Du har suttit med dålig hållning i \(duration). " + advice
    }
}

enum PostureLabel: String, Codable, Sendable {
    case good, bad
}
