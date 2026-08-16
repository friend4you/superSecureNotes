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
                Label {
                    Text(NotesFlowUILocalization.localized("notes.sync.pending"))
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .foregroundStyle(.orange)
                .accessibilityIdentifier("note-sync-status-pending")
            }
        case .synced:
            if displayStyle == .iconOnly {
                Image(systemName: "checkmark.icloud")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(NotesFlowUILocalization.localized("notes.sync.synced"))
                    .accessibilityIdentifier("note-sync-status-synced")
            } else {
                Label {
                    Text(NotesFlowUILocalization.localized("notes.sync.synced"))
                } icon: {
                    Image(systemName: "checkmark.icloud")
                }
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("note-sync-status-synced")
            }
        case .pendingDelete:
            EmptyView()
        }
    }
}
