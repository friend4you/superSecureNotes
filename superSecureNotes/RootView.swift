import AuthFlowUI
import AuthRepository
import Foundation
import Navigation
import NotesFlow
import SecureCrypto
import SwiftUI
import VaultRepository
import VaultSession

@MainActor
final class AppDependencies {
    static let apiBaseURL = URL(string: "https://api.example.com/v1")!

    let authRepository: NetworkAuthRepository
    let vaultRepository: NetworkVaultRepository
    let vaultSession: VaultSession
    let vaultAuthenticator: SecureCryptoVaultAuthenticator

    init() {
        authRepository = NetworkAuthRepository(baseURL: Self.apiBaseURL)
        let tokenProvider = AuthRepositoryAccessTokenProvider(repository: authRepository)
        vaultRepository = NetworkVaultRepository(
            baseURL: Self.apiBaseURL,
            tokenProvider: tokenProvider
        )
        vaultSession = VaultSession()
        vaultAuthenticator = SecureCryptoVaultAuthenticator()
    }

    func makeLoginViewModel(navigator: any LoginNavigating) -> DefaultLoginViewModel {
        DefaultLoginViewModel(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            navigator: navigator
        )
    }

    func makeRegisterViewModel() -> DefaultRegisterViewModel {
        DefaultRegisterViewModel(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession
        )
    }
}

struct RootView: View {
    @State private var dependencies = AppDependencies()
    @State private var router = NavigationRouter()
    @State private var isVaultActive = false

    var body: some View {
        Group {
            if isVaultActive {
                NoteListView()
            } else {
                NavigationStack(path: router.pathBinding) {
                    LoginView(
                        viewModel: dependencies.makeLoginViewModel(
                            navigator: AuthLoginNavigator(router: router)
                        )
                    )
                }
            }
        }
        .task {
            isVaultActive = await dependencies.vaultSession.isActive
            for await active in dependencies.vaultSession.changes {
                isVaultActive = active
            }
        }
    }
}

#Preview {
    RootView()
}
