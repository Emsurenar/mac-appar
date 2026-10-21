import SwiftUI

/// The Stretch Crew. Every member can do every move; how each one is drawn lives in Crew.swift.
enum Buddy: String, CaseIterable, Identifiable {
    case mochi, cat, panda, bunny, frog, semla, chick, toast, onigiri, cactus

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
        case .cactus: return "Sol"
        }
    }

    /// What they are.
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
        case .cactus: return L("Cactus")
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
        case .cactus: return L("Sol the cactus")
        }
    }
}
