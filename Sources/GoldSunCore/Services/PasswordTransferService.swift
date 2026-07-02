import Foundation

public enum PasswordTransferError: LocalizedError, Sendable {
    case invalidCSV
    case missingRequiredColumns

    public var errorDescription: String? {
        switch self {
        case .invalidCSV:
            "GoldSun could not read the password CSV."
        case .missingRequiredColumns:
            "The password CSV needs url, username, and password columns."
        }
    }
}

public enum PasswordTransferService {
    public static func importedPasswords(fromCSV data: Data) throws -> [PasswordImportRecord] {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw PasswordTransferError.invalidCSV
        }

        let rows = parseCSV(text)
        guard let header = rows.first, header.count >= 3 else {
            throw PasswordTransferError.invalidCSV
        }

        let normalizedHeader = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard let urlIndex = firstIndex(in: normalizedHeader, matching: ["url", "origin", "website"]),
              let usernameIndex = firstIndex(in: normalizedHeader, matching: ["username", "user", "login username"]),
              let passwordIndex = firstIndex(in: normalizedHeader, matching: ["password"]) else {
            throw PasswordTransferError.missingRequiredColumns
        }

        let titleIndex = firstIndex(in: normalizedHeader, matching: ["name", "title"])

        return rows.dropFirst().compactMap { row in
            guard row.indices.contains(urlIndex),
                  row.indices.contains(usernameIndex),
                  row.indices.contains(passwordIndex) else {
                return nil
            }

            let urlText = row[urlIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let password = row[passwordIndex]

            guard !urlText.isEmpty,
                  !password.isEmpty,
                  let url = URL(string: urlText) ?? URL(string: "https://\(urlText)") else {
                return nil
            }

            let title = titleIndex.flatMap { row.indices.contains($0) ? row[$0] : nil }
                ?? url.host(percentEncoded: false)
                ?? url.absoluteString

            return PasswordImportRecord(
                title: title,
                url: url,
                username: row[usernameIndex],
                password: password
            )
        }
    }

    public static func exportedCSV(from records: [PasswordImportRecord]) -> Data {
        var rows = [["name", "url", "username", "password"]]

        rows.append(
            contentsOf: records.map { record in
                [
                    record.title,
                    record.url.absoluteString,
                    record.username,
                    record.password
                ]
            }
        )

        let text = rows
            .map { row in row.map(escapedCSVField).joined(separator: ",") }
            .joined(separator: "\n") + "\n"

        return Data(text.utf8)
    }

    private static func firstIndex(in header: [String], matching names: Set<String>) -> Int? {
        header.firstIndex { names.contains($0) }
    }

    private static func escapedCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }

        return field
    }

    private static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInsideQuotes = false
        var iterator = text.makeIterator()

        while let character = iterator.next() {
            if isInsideQuotes {
                if character == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            isInsideQuotes = false
                            consumeDelimiter(next, row: &row, field: &field, rows: &rows)
                        }
                    } else {
                        isInsideQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"" {
                isInsideQuotes = true
            } else {
                consumeDelimiter(character, row: &row, field: &field, rows: &rows)
            }
        }

        row.append(field)
        if row.contains(where: { !$0.isEmpty }) {
            rows.append(row)
        }

        return rows
    }

    private static func consumeDelimiter(
        _ character: Character,
        row: inout [String],
        field: inout String,
        rows: inout [[String]]
    ) {
        switch character {
        case ",":
            row.append(field)
            field = ""
        case "\n":
            row.append(field)
            rows.append(row)
            row = []
            field = ""
        case "\r":
            break
        default:
            field.append(character)
        }
    }
}
