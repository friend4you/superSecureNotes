import PhotosUI
import SecureCrypto
import SwiftUI
import UniformTypeIdentifiers

enum NoteAttachmentImportSupport {
    static let fileImporterAllowedTypes: [UTType] = [.item]

    static func attachment(from item: PhotosPickerItem) async -> NotePayload.Attachment? {
        if let video = try? await item.loadTransferable(type: MoviePickerData.self) {
            return NotePayload.Attachment(
                id: UUID().uuidString,
                filename: video.filename,
                mime: video.mimeType,
                data: video.data
            )
        }
        if let photo = try? await item.loadTransferable(type: PhotoPickerData.self) {
            return NotePayload.Attachment(
                id: UUID().uuidString,
                filename: photo.filename,
                mime: photo.mimeType,
                data: photo.data
            )
        }
        return nil
    }

    static func attachment(from url: URL) throws -> NotePayload.Attachment {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let contentType = UTType(filenameExtension: url.pathExtension) ?? .data
        return NotePayload.Attachment(
            id: UUID().uuidString,
            filename: url.lastPathComponent,
            mime: contentType.preferredMIMEType ?? "application/octet-stream",
            data: data
        )
    }
}

struct PhotoPickerData: Transferable {
    let data: Data
    let filename: String
    let mimeType: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            PhotoPickerData(
                data: data,
                filename: "photo.jpg",
                mimeType: UTType.image.preferredMIMEType ?? "image/jpeg"
            )
        }
    }
}

struct MoviePickerData: Transferable {
    let data: Data
    let filename: String
    let mimeType: String
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .movie) { data in
            MoviePickerData(
                data: data,
                filename: "video.mov",
                mimeType: UTType.movie.preferredMIMEType ?? "video/quicktime"
            )
        }
    }
}
