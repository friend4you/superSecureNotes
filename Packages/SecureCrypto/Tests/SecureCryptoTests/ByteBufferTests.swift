import XCTest

@testable import SecureCrypto

final class ByteBufferTests: XCTestCase {
  func testRoundtripPrimitives() throws {
    var writer = ByteBuffer()
    writer.appendUInt8(0xAB)
    writer.appendUInt16BE(0x1234)
    writer.appendUInt32BE(0x89ABCDEF)
    writer.appendUInt64BE(0x0123456789ABCDEF)

    var reader = ByteBuffer(data: writer.bytes)
    XCTAssertEqual(try reader.readUInt8(), 0xAB)
    XCTAssertEqual(try reader.readUInt16BE(), 0x1234)
    XCTAssertEqual(try reader.readUInt32BE(), 0x89ABCDEF)
    XCTAssertEqual(try reader.readUInt64BE(), 0x0123456789ABCDEF)
    XCTAssertTrue(reader.isAtEnd)
  }

  func testLengthPrefixedFields() throws {
    var writer = ByteBuffer()
    try writer.appendLengthPrefixedBytes(Data([1, 2, 3]))
    try writer.appendLengthPrefixedString("hello")

    var reader = ByteBuffer(data: writer.bytes)
    XCTAssertEqual(try reader.readLengthPrefixedBytes(), Data([1, 2, 3]))
    XCTAssertEqual(try reader.readLengthPrefixedString(), "hello")
  }

  func testExpectMagicRejectsMismatch() {
    var reader = ByteBuffer(data: Data("ABCD".utf8))
    XCTAssertThrowsError(try reader.expectMagic(Array("SSNV".utf8))) { error in
      XCTAssertEqual(
        error as? SecureCryptoError,
        .invalidMagic(expected: "SSNV", actual: "ABCD")
      )
    }
  }
}
