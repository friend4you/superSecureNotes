import Foundation

@MainActor
public protocol SessionPasswordCaching: AnyObject {
    func store(_ password: String)
    func password() -> String?
    func clear()
}
