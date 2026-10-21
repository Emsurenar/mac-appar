import SwiftUI

/// The Stretch Crew. Every member can do every move; how each one is drawn lives in Crew.swift.
enum Buddy: String, CaseIterable, Identifiable {
    case mochi, cat, panda, bunny, frog, semla, chick, crispbread, onigiri, stefan, jesus, gandhi, descartes, bard, kaknas

    var id: String { rawValue }

    /// Their own name. Names aren't translated.
    var name: String {
        switch self {
        case .mochi: return "Momo"
        case .cat: return "Miso"
        case .panda: return "Bao"
        case .bunny: return "Juni"
        case .frog: return "Otto"
        case .semla: return "Selma"
        case .chick: return "Pip"
        case .crispbread: return "Finn"
        case .onigiri: return "Nori"
        case .stefan: return "Stefan"
        case .jesus: return "Jesus"
        case .gandhi: return "Mahatma"
        case .descartes: return "René"
        case .bard: return "Alexander"
        case .kaknas: return "Kaknäs"
        }
    }

    /// What they are, or for the people among them, the rest of their name.
    var kind: String {
        switch self {
        case .mochi: return L("Mochi")
        case .cat: return L("Cat")
        case .panda: return L("Panda")
        case .bunny: return L("Bunny")
        case .frog: return L("Frog")
        case .semla: return L("Semla")
        case .chick: return L("Chick")
        case .crispbread: return L("Crispbread")
        case .onigiri: return L("Onigiri")
        case .stefan: return "Löfven"
        case .jesus: return L("of Nazareth")
        case .gandhi: return "Gandhi"
        case .descartes: return "Descartes"
        case .bard: return "Bard"
        case .kaknas: return L("TV tower")
        }
    }

    /// What a break calls them: the people go by the name people know them by, the rest by their own.
    var callName: String {
        switch self {
        case .stefan: return "Löfven"
        case .gandhi: return "Gandhi"
        case .descartes: return "Descartes"
        case .bard: return "Bard"
        case .kaknas: return L("Kaknäs Tower")
        default: return name
        }
    }

    /// Name and kind together, the way the language puts them: "Otto the frog", "Grodan Otto".
    var introduction: String {
        switch self {
        case .mochi: return L("Momo the mochi")
        case .cat: return L("Miso the cat")
        case .panda: return L("Bao the panda")
        case .bunny: return L("Juni the bunny")
        case .frog: return L("Otto the frog")
        case .semla: return L("Selma the semla")
        case .chick: return L("Pip the chick")
        case .crispbread: return L("Finn the crispbread")
        case .onigiri: return L("Nori the onigiri")
        case .stefan: return "Stefan Löfven"
        case .jesus: return L("Jesus of Nazareth")
        case .gandhi: return "Mahatma Gandhi"
        case .descartes: return "René Descartes"
        case .bard: return "Alexander Bard"
        case .kaknas: return L("Kaknäs Tower")
        }
    }
}
