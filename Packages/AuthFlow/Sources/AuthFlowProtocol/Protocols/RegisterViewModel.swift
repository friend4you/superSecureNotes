import Foundation
import Observation

@MainActor
public protocol RegisterViewModel: AnyObject, Observable {
    var email: String { get set }
    var password: String { get set }
    var state: AuthFormState { get }

    func register() async
}
