import Foundation
import Observation

@MainActor
public protocol LoginViewModel: AnyObject, Observable {
    var email: String { get set }
    var password: String { get set }
    var state: AuthFormState { get }

    func login() async
    func registerTapped()
}
