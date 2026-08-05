import Foundation

/// Maximum wire blob size for single-request `PUT /notes/{noteId}` upload per the backend API (10 MiB).
public let NoteUploadSizeThreshold = 10_485_760
