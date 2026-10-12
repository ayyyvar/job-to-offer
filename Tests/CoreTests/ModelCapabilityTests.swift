import Core
import Testing

@Suite struct ModelCapabilityTests {
    @Test func availableModelShowsAvailable() {
        let capability = ModelCapability(status: .available, contextSize: 8192, supportedLanguages: ["en"])
        #expect(capability.statusText == "Available")
    }

    @Test func unavailableModelShowsTheReasonText() {
        let capability = ModelCapability(
            status: .unavailable(reason: "Apple Intelligence is off."),
            contextSize: 4096,
            supportedLanguages: []
        )
        #expect(capability.statusText == "Unavailable: Apple Intelligence is off.")
    }
}
