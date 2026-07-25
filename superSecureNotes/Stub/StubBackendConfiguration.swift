import Foundation

#if DEBUG

enum StubBackendConfiguration {
    static var testLaunchArguments: [String]?

    static var isEnabled: Bool {
        let arguments = testLaunchArguments ?? ProcessInfo.processInfo.arguments
        return arguments.contains("-UseStubBackend")
    }
}

#endif
