import Foundation
import NetworkProtocol
import NoteRepositoryProtocol

public enum NoteSyncRetryObserver {
    public static func start(
        reachability: any NetworkReachability,
        noteSync: any NoteSyncing
    ) -> Task<Void, Never> {
        Task {
            var wasOnline = reachability.isOnline
            for await isOnline in reachability.changes {
                if isOnline, !wasOnline {
                    await noteSync.flushPending()
                }
                wasOnline = isOnline
            }
        }
    }
}
