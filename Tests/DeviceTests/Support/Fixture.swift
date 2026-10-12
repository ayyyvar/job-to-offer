import Foundation

/// `Tests/Fixtures/`, copied into the DeviceTests bundle as a folder reference.
enum Fixture {
    private final class Token {}

    static func load(_ name: String) throws -> Data {
        try Data(contentsOf: Bundle(for: Token.self).resourceURL!.appending(path: "Fixtures/\(name)"))
    }

    static func string(_ name: String) throws -> String { String(decoding: try load(name), as: UTF8.self) }
}
