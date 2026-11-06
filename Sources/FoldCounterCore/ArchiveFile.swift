import Foundation

/// Call from a single serial owner. The app is the only writer; widgets read snapshots.
/// A failed decode is NEVER replaced by a fresh zero counter.
public struct ArchiveFile: Sendable {
    public let url: URL
    public static let maximumBytes = 8 * 1024 * 1024
    private static let oversized = CounterDataError.invalid("Backup is larger than 8 MB.")

    public init(url: URL) { self.url = url }

    public static func encode(_ archive: CounterArchive) throws -> Data {
        try archive.validated()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(archive)
        guard data.count <= maximumBytes else {
            throw oversized
        }
        return data
    }

    public static func decode(_ data: Data) throws -> CounterArchive {
        guard data.count <= maximumBytes else {
            throw oversized
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CounterArchive.self, from: data).validated()
    }

    /// Applies the backup limit while reading, including files supplied by a document provider.
    public func load() throws -> CounterArchive {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while let chunk = try handle.read(upToCount: min(64 * 1024, Self.maximumBytes - data.count + 1)),
              !chunk.isEmpty {
            guard data.count + chunk.count <= Self.maximumBytes else { throw Self.oversized }
            data.append(chunk)
        }
        return try Self.decode(data)
    }

    public func load(orCreate initial: CounterArchive) throws -> CounterArchive {
        do {
            return try load()
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            try save(initial)
            return initial
        }
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
