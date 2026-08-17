import Foundation

nonisolated struct PartnerContact: Equatable, Sendable {
    let name: String?
    let phoneNumber: String

    init?(name: String?, phoneNumber: String) {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmedName.count <= 80,
              let normalizedPhoneNumber = Self.normalizePhoneNumber(phoneNumber)
        else {
            return nil
        }
        self.name = trimmedName.isEmpty ? nil : trimmedName
        self.phoneNumber = normalizedPhoneNumber
    }

    var phoneURL: URL? {
        URL(string: "tel:\(phoneNumber)")
    }

    private static func normalizePhoneNumber(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }

        var normalized = ""
        for character in trimmedValue {
            if character.isWholeNumber {
                normalized.append(character)
            } else if character == "+", normalized.isEmpty {
                normalized.append(character)
            } else if " -().".contains(character) {
                continue
            } else {
                return nil
            }
        }

        let digitCount = normalized.reduce(into: 0) { count, character in
            if character.isWholeNumber {
                count += 1
            }
        }
        guard (7 ... 15).contains(digitCount) else { return nil }
        return normalized
    }
}
