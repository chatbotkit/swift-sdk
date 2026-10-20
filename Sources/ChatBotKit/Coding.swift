import Foundation

/// JSON encoders and decoders configured for the ChatBotKit API.
public enum ChatBotKitCoding {
    /// A decoder that understands the ISO 8601 timestamps used by the API,
    /// with or without fractional seconds.
    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            if let milliseconds = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: milliseconds / 1000)
            }

            let string = try container.decode(String.self)

            if let date = parseDate(string) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }

        return decoder
    }

    /// An encoder that writes dates as ISO 8601 timestamps.
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()

        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()

            let formatter = ISO8601DateFormatter()

            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            try container.encode(formatter.string(from: date))
        }

        return encoder
    }

    static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()

        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: string) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]

        return formatter.date(from: string)
    }
}
