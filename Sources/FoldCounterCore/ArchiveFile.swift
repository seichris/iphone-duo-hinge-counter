import Foundation

/// Call from a single serial owner. The app is the only writer; widgets read snapshots.
/// A failed decode is NEVER replaced by a fresh zero counter.
public struct ArchiveFile: Sendable {
    public let url: URL
    public static let maximumBytes = 8 * 1024 * 1024

    public init(url: URL) { self.url = url }

    public static func encode(_ archive: CounterArchive) throws -> Data {
        try archive.validated()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(archive)
        guard data.count <= maximumBytes else {
            throw CounterDataError.invalid("Backup is larger than 8 MB.")
        }
        return data
    }

    public static func decode(_ data: Data) throws -> CounterArchive {
        guard data.count <= maximumBytes else {
            throw CounterDataError.invalid("Backup is larger than 8 MB.")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CounterArchive.self, from: data).validated()
    }

    public func load(orCreate initial: CounterArchive) throws -> CounterArchive {
        if FileManager.default.fileExists(atPath: url.path) {
            return try Self.decode(Data(contentsOf: url))
        }
        try save(initial)
        return initial
    }

    public func save(_ archive: CounterArchive) throws {
        let data = try Self.encode(archive)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}
