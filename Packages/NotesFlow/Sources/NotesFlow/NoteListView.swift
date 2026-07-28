import SwiftUI
import NavigationProtocol

public struct NoteListView: View {
    @Bindable private var viewModel: DefaultNoteListViewModel

    public init(viewModel: DefaultNoteListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Text("Note list")
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Logout") {
                        Task {
                            await viewModel.logout()
                        }
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button("Share") {
                        viewModel.share(noteID: UUID())
                    }
                }
                
            }
            #endif
    }
}

#Preview {
    NoteListView(
        viewModel: DefaultNoteListViewModel(
            authRepository: PreviewAuthRepository(),
            vaultSession: PreviewVaultSession(),
            noteRepository: PreviewNoteRepository(),
            navigator: PreviewNavigator()
        )
    )
}

#if DEBUG
import AuthRepositoryProtocol
import CryptoKit
import NoteRepositoryProtocol
import VaultSessionProtocol

private actor PreviewAuthRepository: AuthRepository {
    var currentSession: AuthSession? { nil }
    var currentUser: User? { nil }
    func register(_ credentials: RegisterCredentials) async throws -> AuthSession {
        AuthSession(accessToken: "", refreshToken: "", expiresAt: .distantFuture)
    }
    func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        AuthSession(accessToken: "", refreshToken: "", expiresAt: .distantFuture)
    }
    func logout() async throws {}
    func refreshSession() async throws -> AuthSession {
        throw AuthRepositoryError.notAuthenticated
    }
}

private actor PreviewVaultSession: VaultSessionProtocol {
    var isActive: Bool { false }
    nonisolated var changes: AsyncStream<Bool> { AsyncStream { $0.finish() } }
    func establish(_ keys: VaultSessionKeys) {}
    func clear() {}
    func udk() throws -> SymmetricKey { .init(size: .bits256) }
    func identityPrivateKey() throws -> Data { Data() }
}

private actor PreviewNoteRepository: NoteRepository {
    func listNotes() async throws -> [NoteSummary] { [] }
    func readNote(noteID: UUID) async throws -> Data { Data() }
    func writeNote(noteID: UUID, data: Data) async throws {}
    func deleteNote(noteID: UUID) async throws {}
}

@MainActor
private final class PreviewNavigator: Navigating {
    func setRoot<R: Route>(_ route: R) {}
    func push<R: Route>(_ route: R) {}
    func present<R: Route>(_ route: R, style: RoutePresentation) {}
    func pop() {}
    func popToRoot() {}
    func dismissPresentation() {}
}
#endif
