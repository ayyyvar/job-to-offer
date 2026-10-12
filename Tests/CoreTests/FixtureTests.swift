import Testing

@Suite struct FixtureTests {
    @Test func loadReturnsTheFileContents() throws {
        #expect(try Fixture.string("smoke_2026-09-27.txt") == "fixture loader ok\n")
    }

    @Test func loadThrowsForAMissingFile() {
        #expect(throws: Fixture.Error.missing("no_such_file.txt")) {
            try Fixture.load("no_such_file.txt")
        }
    }
}
