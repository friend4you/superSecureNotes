import Foundation

/// Maximum wire blob size for single-request `PUT /notes/{noteId}` upload per the backend API.
public let NoteUploadSizeThreshold = 10_000_000
