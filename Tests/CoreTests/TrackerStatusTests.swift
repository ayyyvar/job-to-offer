import Core
import Testing

@Suite struct TrackerStatusTests {
    static let canonical = [
        "drafted", "applied", "interview", "offer", "hired",
        "rejected", "no_response", "offer_declined", "withdrawn",
    ]

    @Test(arguments: canonical)
    func canonicalValueRoundTrips(_ raw: String) throws {
        #expect(try #require(TrackerStatus(rawValue: raw)).rawValue == raw)
    }

    @Test func thereAreExactlyNineStatuses() {
        #expect(TrackerStatus.allCases.map(\.rawValue) == Self.canonical)
    }

    @Test(arguments: [("no response", TrackerStatus.noResponse), ("offer declined", .offerDeclined)])
    func legacySpaceSpellingReadsAsTheCanonicalValue(legacy: String, expected: TrackerStatus) throws {
        let status = try #require(TrackerStatus(rawValue: legacy))
        #expect(status == expected)
        #expect(!status.rawValue.contains(" "))
    }

    @Test(arguments: ["hired", "rejected", "no_response", "offer_declined", "withdrawn", "no response", "offer declined"])
    func finalValuesAreFinal(_ raw: String) throws {
        #expect(try #require(TrackerStatus(rawValue: raw)).isFinal)
    }

    @Test(arguments: ["drafted", "applied", "interview", "offer"])
    func openValuesAreNotFinal(_ raw: String) throws {
        #expect(try !#require(TrackerStatus(rawValue: raw)).isFinal)
    }

    @Test(arguments: ["", "Applied", "no-response", "pending", "ranked"])
    func unknownValueIsRejected(_ raw: String) {
        #expect(TrackerStatus(rawValue: raw) == nil)
    }
}
