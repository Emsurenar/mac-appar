import SwiftUI

/// The Stretch Crew. Every member can do every move; how each one is drawn lives in Crew.swift.
enum Buddy: String, CaseIterable, Identifiable {
    case mochi, cat, panda, bunny, frog, semla, chick, toast, onigiri, stefan, jesus, gandhi, descartes, kaknas

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
        case .toast: return "Toby"
        case .onigiri: return "Nori"
        case .stefan: return "Stefan"
        case .jesus: return "Jesus"
        case .gandhi: return "Mahatma"
        case .descartes: return "René"
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
        case .toast: return L("Toast")
        case .onigiri: return L("Onigiri")
        case .stefan: return "Löfven"
        case .jesus: return L("of Nazareth")
        case .gandhi: return "Gandhi"
        case .descartes: return "Descartes"
        case .kaknas: return L("TV tower")
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
        case .toast: return L("Toby the toast")
        case .onigiri: return L("Nori the onigiri")
        case .stefan: return "Stefan Löfven"
        case .jesus: return L("Jesus of Nazareth")
        case .gandhi: return "Mahatma Gandhi"
        case .descartes: return "René Descartes"
        case .kaknas: return L("Kaknäs Tower")
        }
    }
}
