import Foundation
import NoteRepositoryProtocol
import SQLCipher

public actor NotesIndexStore: NotesIndexStoreProtocol {
    public private(set) var isOpen = false

    private var database: OpaquePointer?
    private let notesDirectoryURL: URL
    private let fileManager: FileManager

    public init(
        notesDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        if let notesDirectoryURL {
            self.notesDirectoryURL = notesDirectoryURL
        } else {
            let appSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.temporaryDirectory
            self.notesDirectoryURL = appSupport
                .appendingPathComponent("superSecureNotes", isDirectory: true)
                .appendingPathComponent("notes", isDirectory: true)
        }
    }

    private var databaseURL: URL {
        notesDirectoryURL.appendingPathComponent("notes.db", isDirectory: false)
    }

    public func open(passphrase: Data) async throws {
        if isOpen {
            await close()
        }

        try fileManager.createDirectory(
            at: notesDirectoryURL,
            withIntermediateDirectories: true
        )

        var connection: OpaquePointer?
        let openResult = sqlite3_open(databaseURL.path, &connection)
        guard openResult == SQLITE_OK, let connection else {
            throw NotesIndexStoreError.openFailed(code: openResult)
        }

        do {
            try execute(
                "PRAGMA key = \"x'\(passphrase.hexEncodedString())'\"",
                on: connection
            )
            try execute(Self.createTableSQL, on: connection)
            try execute("SELECT count(*) FROM notes", on: connection)
        } catch {
            sqlite3_close(connection)
            throw error
        }

        database = connection
        isOpen = true
    }

    public func close() async {
        if let database {
            sqlite3_close(database)
            self.database = nil
        }
        isOpen = false
    }

    func requireOpen() throws {
        guard isOpen, database != nil else {
            throw NotesIndexStoreError.notOpen
        }
    }

    func withDatabase<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        try requireOpen()
        guard let database else {
            throw NotesIndexStoreError.notOpen
        }
        return try body(database)
    }

    func execute(_ sql: String, on database: OpaquePointer, bindings: [SQLiteBinding] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw NotesIndexStoreError.sqliteError(message: lastErrorMessage(database))
        }
        defer { sqlite3_finalize(statement) }

        for (index, binding) in bindings.enumerated() {
            let position = Int32(index + 1)
            let result: Int32
            switch binding {
            case let .text(value):
                result = sqlite3_bind_text(statement, position, value, -1, SQLITE_TRANSIENT)
            case let .int64(value):
                result = sqlite3_bind_int64(statement, position, value)
            case let .int32(value):
                result = sqlite3_bind_int(statement, position, value)
            case let .blob(value):
                result = value.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(
                        statement,
                        position,
                        buffer.baseAddress,
                        Int32(buffer.count),
                        SQLITE_TRANSIENT
                    )
                }
            }
            guard result == SQLITE_OK else {
                throw NotesIndexStoreError.sqliteError(message: lastErrorMessage(database))
            }
        }

        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_DONE || stepResult == SQLITE_ROW else {
            throw NotesIndexStoreError.sqliteError(message: lastErrorMessage(database))
        }
    }

    func queryRows(
        _ sql: String,
        bindings: [SQLiteBinding] = [],
        on database: OpaquePointer
    ) throws -> [[String: SQLiteValue]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw NotesIndexStoreError.sqliteError(message: lastErrorMessage(database))
        }
        defer { sqlite3_finalize(statement) }

        for (index, binding) in bindings.enumerated() {
            let position = Int32(index + 1)
            let result: Int32
            switch binding {
            case let .text(value):
                result = sqlite3_bind_text(statement, position, value, -1, SQLITE_TRANSIENT)
            case let .int64(value):
                result = sqlite3_bind_int64(statement, position, value)
            case let .int32(value):
                result = sqlite3_bind_int(statement, position, value)
            case let .blob(value):
                result = value.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(
                        statement,
                        position,
                        buffer.baseAddress,
                        Int32(buffer.count),
                        SQLITE_TRANSIENT
                    )
                }
            }
            guard result == SQLITE_OK else {
                throw NotesIndexStoreError.sqliteError(message: lastErrorMessage(database))
            }
        }

        var rows: [[String: SQLiteValue]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: SQLiteValue] = [:]
            let columnCount = sqlite3_column_count(statement)
            for columnIndex in 0 ..< columnCount {
                let name = String(cString: sqlite3_column_name(statement, columnIndex))
                switch sqlite3_column_type(statement, columnIndex) {
                case SQLITE_TEXT:
                    row[name] = .text(String(cString: sqlite3_column_text(statement, columnIndex)))
                case SQLITE_INTEGER:
                    row[name] = .int64(sqlite3_column_int64(statement, columnIndex))
                case SQLITE_BLOB:
                    let bytes = sqlite3_column_blob(statement, columnIndex)
                    let length = Int(sqlite3_column_bytes(statement, columnIndex))
                    row[name] = .blob(Data(bytes: bytes!, count: length))
                default:
                    break
                }
            }
            rows.append(row)
        }
        return rows
    }

    private func lastErrorMessage(_ database: OpaquePointer) -> String {
        String(cString: sqlite3_errmsg(database))
    }

    private static let createTableSQL = """
        CREATE TABLE IF NOT EXISTS notes (
            note_id TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            attachment_count INTEGER NOT NULL,
            attachments_total_size INTEGER NOT NULL,
            wrapped_fek BLOB NOT NULL,
            sync_state TEXT NOT NULL CHECK (sync_state IN ('pendingSync', 'synced'))
        )
        """
}

extension NotesIndexStore {
    static func textValue(_ value: SQLiteValue?) -> String {
        guard case let .text(text) = value else { return "" }
        return text
    }

    static func int64Value(_ value: SQLiteValue?) -> Int64 {
        guard case let .int64(number) = value else { return 0 }
        return number
    }

    static func blobValue(_ value: SQLiteValue?) -> Data {
        guard case let .blob(data) = value else { return Data() }
        return data
    }
}

enum SQLiteBinding {
    case text(String)
    case int64(Int64)
    case int32(Int32)
    case blob(Data)
}

enum SQLiteValue {
    case text(String)
    case int64(Int64)
    case blob(Data)
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private extension Data {
    func hexEncodedString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
