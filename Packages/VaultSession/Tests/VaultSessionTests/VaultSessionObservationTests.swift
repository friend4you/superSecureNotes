import CryptoKit
import XCTest

@testable import VaultSession

final class VaultSessionObservationTests: XCTestCase {
    func testEstablishEmitsActive() async {
        let session = VaultSession()
        let collector = ChangeCollector(stream: session.changes)
        await waitForValues(collector, count: 1)
        XCTAssertEqual(collector.values, [false])

        await session.establish(sampleKeys())
        await waitForValues(collector, count: 2)

        XCTAssertEqual(collector.values, [false, true])
    }

    func testClearEmitsInactive() async {
        let session = VaultSession()
        await session.establish(sampleKeys())

        let collector = ChangeCollector(stream: session.changes)
        await waitForValues(collector, count: 1)
        XCTAssertEqual(collector.values, [true])

        await session.clear()
        await waitForValues(collector, count: 2)

        XCTAssertEqual(collector.values, [true, false])
    }

    func testNewSubscriberReceivesCurrentState() async {
        let session = VaultSession()
        await session.establish(sampleKeys())

        let stream = session.changes
        let collector = ChangeCollector(stream: stream)
        await waitForValues(collector, count: 1)

        XCTAssertEqual(collector.values, [true])
    }

    func testIdempotentClearDoesNotEmit() async {
        let session = VaultSession()
        let stream = session.changes
        let collector = ChangeCollector(stream: stream)

        await session.clear()
        await waitForValues(collector, count: 1)

        XCTAssertEqual(collector.values, [false])
    }

    private func sampleKeys() -> VaultSessionKeys {
        VaultSessionKeys(
            udk: SymmetricKey(size: .bits256),
            identityPrivateKey: Data(repeating: 0x01, count: 32)
        )
    }

    private func waitForValues(_ collector: ChangeCollector, count: Int) async {
        for _ in 0 ..< 50 {
            if collector.values.count >= count {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Expected at least \(count) values, got \(collector.values)")
    }
}

private final class ChangeCollector: @unchecked Sendable {
    private let queue = DispatchQueue(label: "ChangeCollector")
    private(set) var values: [Bool] = []
    private var task: Task<Void, Never>?

    init(stream: AsyncStream<Bool>) {
        task = Task {
            for await value in stream {
                self.queue.sync {
                    self.values.append(value)
                }
            }
        }
    }

    deinit {
        task?.cancel()
    }
}
