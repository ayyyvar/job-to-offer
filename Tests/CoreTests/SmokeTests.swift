import Testing

@Suite struct SmokeTests {
    @Test func swiftTestingRunsFromTheCLI() {
        #expect(1 + 1 == 2)
    }
}
