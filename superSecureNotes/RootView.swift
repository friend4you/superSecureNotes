import CredentialStore
import Navigation
import SwiftUI
import VaultSession

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var composition = AppComposition()

    var body: some View {
        NavigationHost(model: composition.navigation.hostModel)
            .task {
                composition.syncRootRoute(
                    hasLocalSetup: composition.appDependencies.credentialStore.hasLocalSetup,
                    isVaultActive: await composition.appDependencies.vaultSession.isActive
                )
                for await isVaultActive in composition.appDependencies.vaultSession.changes {
                    composition.syncRootRoute(
                        hasLocalSetup: composition.appDependencies.credentialStore.hasLocalSetup,
                        isVaultActive: isVaultActive
                    )
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                composition.handleScenePhase(newPhase)
            }
    }
}

#Preview {
    RootView()
}
