import SwiftUI

/// The Stretch Crew. Every member can do every move; how each one is drawn lives in Crew.swift.
enum Buddy: String, CaseIterable, Identifiable {
    case mochi, cat, panda, bunny, frog, semla, chick, toast, onigiri, cactus

    var id: String { rawValue }

    var name: String {
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
}
