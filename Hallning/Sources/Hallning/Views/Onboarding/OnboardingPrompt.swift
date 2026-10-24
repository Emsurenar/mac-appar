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
        case .forwardHead, .chinOnHand: return 0.6
        case .roundedShoulders: return 0.5
        case .tooClose: return 0.4
        case .leaningLeft, .leaningRight, .shrugging, .headTilt: return 0.2
        }
    }

    static let good: [OnboardingPrompt] = [
        .init(id: 0, label: .good, issue: nil, title: "Sitt rakt och bekvämt",
              instruction: "Fötterna i golvet, ryggen mot ryggstödet och axlarna avslappnade.", symbol: "figure.stand"),
        .init(id: 1, label: .good, issue: nil, title: "Titta mot skärmens vänstra kant",
              instruction: "Sitt kvar lika rakt och vrid bara blicken och huvudet lätt åt vänster.", symbol: "arrow.left"),
        .init(id: 2, label: .good, issue: nil, title: "Titta mot högra kanten",
              instruction: "Samma sak åt höger. Behåll axlarna där de är.", symbol: "arrow.right"),
        .init(id: 3, label: .good, issue: nil, title: "Titta mot överkanten",
              instruction: "Höj blicken mot skärmens överkant utan att luta dig bakåt.", symbol: "arrow.up"),
        .init(id: 4, label: .good, issue: nil, title: "Sänk blicken mot tangentbordet",
              instruction: "Titta ner med ögonen, utan att böja nacken.", symbol: "keyboard"),
        .init(id: 5, label: .good, issue: nil, title: "Händerna på tangentbordet",
              instruction: "Lägg händerna som när du skriver och sitt rakt.", symbol: "hand.raised.fingers.spread"),
        .init(id: 6, label: .good, issue: nil, title: "Luta dig lätt bakåt",
              instruction: "Vila mot ryggstödet med rak rygg, som när du läser.", symbol: "chair.lounge"),
        .init(id: 7, label: .good, issue: nil, title: "Händerna i knät",
              instruction: "Släpp händerna i knät och behåll hållningen.", symbol: "hands.clap"),
        .init(id: 8, label: .good, issue: nil, title: "Sitt rakt och andas lugnt",
              instruction: "Ta ett djupt andetag och låt axlarna sjunka på utandningen.", symbol: "wind"),
        .init(id: 9, label: .good, issue: nil, title: "Din egen bästa hållning",
              instruction: "Sitt som du helst vill sitta när du jobbar bra.", symbol: "star.fill"),
    ]

    static let bad: [OnboardingPrompt] = [
        .init(id: 10, label: .bad, issue: .slouching, title: "Sjunk ihop",
              instruction: "Låt ryggen runda sig och bröstet sjunka, som i slutet av en lång dag.", symbol: "arrow.down"),
        .init(id: 11, label: .bad, issue: .forwardHead, title: "Skjut fram huvudet",
              instruction: "För huvudet fram mot skärmen så att hakan sticker ut.", symbol: "arrow.forward"),
        .init(id: 12, label: .bad, issue: .roundedShoulders, title: "Runda axlarna",
              instruction: "Låt axlarna rulla fram och in mot bröstet.", symbol: "arrow.turn.down.right"),
        .init(id: 13, label: .bad, issue: .lookingDown, title: "Titta ner i knät",
              instruction: "Böj nacken och titta ner som när du läser på mobilen.", symbol: "iphone"),
        .init(id: 14, label: .bad, issue: .tooClose, title: "Luta dig nära skärmen",
              instruction: "Luta hela överkroppen fram mot skärmen.", symbol: "arrow.up.left.and.arrow.down.right"),
        .init(id: 15, label: .bad, issue: .leaningLeft, title: "Luta åt vänster",
              instruction: "Luta överkroppen åt vänster, som när du stöder dig på armstödet.", symbol: "arrow.down.left"),
        .init(id: 16, label: .bad, issue: .leaningRight, title: "Luta åt höger",
              instruction: "Samma sak åt höger.", symbol: "arrow.down.right"),
        .init(id: 17, label: .bad, issue: .shrugging, title: "Dra upp axlarna",
              instruction: "Dra upp axlarna mot öronen, som när du fryser eller är stressad.", symbol: "arrow.up.and.down"),
        .init(id: 18, label: .bad, issue: .chinOnHand, title: "Vila hakan i handen",
              instruction: "Stöd armbågen mot bordet och vila hakan i handen.", symbol: "hand.raised.fill"),
        .init(id: 19, label: .bad, issue: .slouching, title: "Sjunk ner i stolen",
              instruction: "Glid fram på sitsen och sjunk ner så att du nästan ligger.", symbol: "arrow.down.to.line"),
    ]

    static let all = good + bad
}
