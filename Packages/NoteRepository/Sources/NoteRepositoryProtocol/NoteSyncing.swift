import Foundation

public protocol NoteSyncing: Actor {
    func flushPending() async
}
