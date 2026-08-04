import NoteRepositoryProtocol
import SwiftUI

struct NoteSyncStatusLabel: View {
    let syncState: NoteSyncState

    var body: some View {
        switch syncState {
        case .pendingSync:
            Label {
                Text(NotesFlowUILocalization.localized("notes.sync.pending"))
            } icon: {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .foregroundStyle(.orange)
            .accessibilityIdentifier("note-sync-status-pending")
        case .synced:
            Label {
                Text(NotesFlowUILocalization.localized("notes.sync.synced"))
            } icon: {
                Image(systemName: "checkmark.icloud")
            }
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("note-sync-status-synced")
        case .pendingDelete:
            EmptyView()
        }
    }
}
