import Foundation
import NavigationProtocol

public enum NotesRoute: Route {
    case list
    case detail(noteID: UUID)
    case create
}
