@MainActor
public protocol AuthFlowDependencyProviding: AnyObject {
    func makeLoginViewModel() -> DefaultLoginViewModel
    func makeRegisterViewModel() -> DefaultRegisterViewModel
}
