import Foundation

/// Loads files from `Tests/Fixtures/`. `name` is a path relative to that folder,
/// for example `"ATS/greenhouse_2026-09-27.json"`.
enum Fixture {
    enum Error: Swift.Error, Equatable {
        case missing(String)
    }

    static func url(_ name: String) throws -> URL {
        let url = Bundle.module.resourceURL!.appending(path: "Fixtures/\(name)")
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            throw Error.missing(name)
        }
        return url
    }

    static func load(_ name: String) throws -> Data {
        try Data(contentsOf: url(name))
    }

    static func string(_ name: String) throws -> String {
        String(decoding: try load(name), as: UTF8.self)
    }
}
