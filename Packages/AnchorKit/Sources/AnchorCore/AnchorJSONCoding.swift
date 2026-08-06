import Foundation

/// The canonical wire/storage coding strategy shared by Core and Transport.
/// Keeping it in Core prevents the persistence layer from depending on the
/// transport module while ensuring dates round-trip bit-for-bit on both peers.
public extension JSONEncoder {
    static var anchor: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.timeIntervalSinceReferenceDate.bitPattern)
        }
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

public extension JSONDecoder {
    static var anchor: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let bitPattern = try container.decode(UInt64.self)
            return Date(timeIntervalSinceReferenceDate: Double(bitPattern: bitPattern))
        }
        return decoder
    }

    /// Human-readable, stable coding for the supported CLI/source contract.
    /// Internal event envelopes continue to use `anchor` so their timestamps
    /// round-trip bit-for-bit across encrypted local transport.
    static var anchorExternal: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public extension JSONEncoder {
    /// Human-readable, stable coding for external source adapters and the CLI.
    static var anchorExternal: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
