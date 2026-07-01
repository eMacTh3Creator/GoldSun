import Foundation

public struct AppVersion: Hashable, Comparable, Sendable, CustomStringConvertible {
    public static let zero = AppVersion(rawValue: "0.0.0")!

    public let rawValue: String
    private let numericComponents: [Int]

    public init?(_ value: String) {
        self.init(rawValue: value)
    }

    public init?(rawValue value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix("v") || trimmed.hasPrefix("V") ? String(trimmed.dropFirst()) : trimmed
        let numericPrefix = normalized.split(separator: "-", maxSplits: 1).first.map(String.init) ?? normalized
        let components = numericPrefix.split(separator: ".").map(String.init)

        guard !components.isEmpty else {
            return nil
        }

        let numbers = components.map(Int.init)
        guard numbers.allSatisfy({ $0 != nil }) else {
            return nil
        }

        rawValue = normalized
        numericComponents = numbers.compactMap { $0 }
    }

    public var description: String {
        rawValue
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.canonicalComponents == rhs.canonicalComponents
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(canonicalComponents)
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.numericComponents.count, rhs.numericComponents.count)

        for index in 0..<count {
            let left = index < lhs.numericComponents.count ? lhs.numericComponents[index] : 0
            let right = index < rhs.numericComponents.count ? rhs.numericComponents[index] : 0

            if left != right {
                return left < right
            }
        }

        return false
    }

    private var canonicalComponents: [Int] {
        var components = numericComponents

        while components.last == 0, components.count > 1 {
            components.removeLast()
        }

        return components
    }
}
