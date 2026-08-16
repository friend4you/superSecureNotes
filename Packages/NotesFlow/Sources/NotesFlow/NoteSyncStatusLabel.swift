import NoteRepositoryProtocol
import SwiftUI

enum NoteSyncStatusDisplayStyle {
    case standard
    case iconOnly
}

struct NoteSyncStatusLabel: View {
    let syncState: NoteSyncState
    var displayStyle: NoteSyncStatusDisplayStyle = .standard

    var body: some View {
        switch syncState {
        case .pendingSync:
            if displayStyle == .iconOnly {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
                    .accessibilityLabel(NotesFlowUILocalization.localized("notes.sync.pending"))
                    .accessibilityIdentifier("note-sync-status-pending")
            } else {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(NotesFlowUILocalization.localized("notes.sync.pending"))
                }
                .foregroundStyle(.orange)
                .font(.subheadline)
                .accessibilityIdentifier("note-sync-status-pending")
            }
        case .synced:
            if displayStyle == .iconOnly {
                Image(systemName: "checkmark.icloud")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(NotesFlowUILocalization.localized("notes.sync.synced"))
                    .accessibilityIdentifier("note-sync-status-synced")
            } else {
                HStack {
                    Image(systemName: "checkmark.icloud")
                    Text(NotesFlowUILocalization.localized("notes.sync.synced"))
                }
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .accessibilityIdentifier("note-sync-status-synced")
            }
        case .pendingDelete:
            EmptyView()
        }
    }
}
