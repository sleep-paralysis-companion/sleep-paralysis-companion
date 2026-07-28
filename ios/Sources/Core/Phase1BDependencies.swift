import Foundation

nonisolated protocol Phase1BClock: Sendable {
    func now() -> Date
}

nonisolated struct SystemPhase1BClock: Phase1BClock {
    func now() -> Date {
        Date()
    }
}

nonisolated protocol IdentifierGenerating: Sendable {
    func next() -> UUID
}

nonisolated struct SystemIdentifierGenerator: IdentifierGenerating {
    func next() -> UUID {
        UUID()
    }
}

nonisolated protocol UnitIntervalRandom: Sendable {
    func next() -> Double
}

nonisolated struct SystemUnitIntervalRandom: UnitIntervalRandom {
    func next() -> Double {
        Double.random(in: 0 ... 1)
    }
}
