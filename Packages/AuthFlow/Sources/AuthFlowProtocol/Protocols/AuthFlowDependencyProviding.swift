@MainActor
public protocol AuthFlowDependencyProviding: AnyObject {
    func makeLoginViewModel(navigator: any LoginNavigating) -> DefaultLoginViewModel
    func makeRegisterViewModel() -> DefaultRegisterViewModel
}
