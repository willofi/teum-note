import Foundation

/// A single, versioned JSON document. Failed reads never fall back to overwriting user data.
public struct NotebookRepository: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public func load() throws -> Notebook? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let notebook = try JSONDecoder().decode(Notebook.self, from: Data(contentsOf: fileURL))
        guard notebook.schemaVersion == 1 else { throw RepositoryError.unsupportedVersion }
        guard Set(notebook.notes.map(\.id)).count == notebook.notes.count else {
            throw RepositoryError.duplicateIdentifiers
        }
        return notebook
    }

    public func save(_ notebook: Notebook) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(notebook)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    public enum RepositoryError: LocalizedError {
        case unsupportedVersion, duplicateIdentifiers

        public var errorDescription: String? {
            switch self {
            case .unsupportedVersion: "이 버전의 틈에서 읽을 수 없는 메모 파일입니다."
            case .duplicateIdentifiers: "메모 파일에 중복된 식별자가 있습니다."
            }
        }
    }
}
