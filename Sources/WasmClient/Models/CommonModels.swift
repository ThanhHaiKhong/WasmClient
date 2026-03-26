import Foundation

// MARK: - Action ID

extension WasmClient {
    /// All known WASM action IDs matching Rust constants.
    public enum ActionID: String, CaseIterable, Sendable {
        // OpenAI
        case chat = "5e1ab91a-ac32-4269-9e20-4d864df4112d"
        case suggest = "b2d4e6f8-1a3c-5e7g-9i0k-2m4o6q8s0u2w"
        // Vision
        case scan = "d4e5f6a7-3b2c-1d0e-9f8a-7b6c5d4e3f2a"
        case visualSearch = "e5f6a7b8-4c3d-2e1f-0a9b-8c7d6e5f4a3b"
        case shopping = "f6a7b8c9-5d4e-3f2a-1b0c-9d8e7f6a5b4c"
        case describe = "a7b8c9d0-6e5f-4a3b-2c1d-0e9f8a7b6c5d"
        // Blobstore
        case upload = "c3f5a7b9-2d4e-6f8a-0c2e-4g6i8k0m2o4q"
        // Inpaint
        case autoSuggestion = "0d6339a1-ea1c-432e-b8d5-9bc0f7d5fe09"
        case enhance = "4425e05a-cf76-4f3f-923e-249494e636bf"
        case removeBg = "1abf881d-23fe-452b-9615-f7c22176e5b3"
        case erase = "c98b41f5-c69b-4dcd-85c0-c01937a56dd9"
        case sky = "30eefa03-bf11-4c33-b397-e5d7015a2bfa"
        case skinBeauty = "64c2e11a-8f23-4c26-8720-e4a065337e2a"
        case tryOn = "75958fa2-978f-41e4-9d4a-a41a645bc59a"
        case clothes = "4b545ec7-c0f2-40d0-a6c1-ff0c39656f62"
        // Music
        case discover = "0e425df1-fcda-4489-969a-d4350392a016"
        case details = "1b1bcaf6-01fc-40b4-83b8-36915d9e505c"
        case tracks = "a9b31651-43b3-415a-b99c-00468be15e28"
        case search = "5d922423-a6fb-4302-b951-ac074c681b7c"
        case lyrics = "47575b25-3d87-4c9d-96d5-a681d064884b"
        case related = "5c770798-6c09-4dd7-8e77-5bab032c269b"
        // Suggestion
        case musicSuggestion = "c5edf8f6-e18d-4a9d-acef-27d19fbb909a"
        // Livescore
        case livescore = "a1c3e5f7-2b4d-4a6c-8e0f-1a2b3c4d5e6f"
        case lsHighlights = "e7a9c1d3-8f0b-4ea2-adf3-7e8f9a0b1c2d"
    }
}

// MARK: - Error

extension WasmClient {
    /// Typed errors for all client operations.
    public enum Error: Swift.Error, Sendable, Equatable, LocalizedError {
        case engineNotReady
        case engineNotStarted
        case engineInitFailed
        case noProviderFound(action: String)
        case taskFailed(status: String)
        case missingValue
        case uploadFailed(String)
        case unexpectedResponseFormat
        case chatActionNotFound
        case decodingFailed(String)

        public var errorDescription: String? {
            switch self {
            case .engineNotReady:
                "The WASM engine is not ready. Please try again."
            case .engineNotStarted:
                "The WASM engine has not been started. Call start() first."
            case .engineInitFailed:
                "The WASM engine failed to initialize."
            case .noProviderFound(let action):
                "No provider found for action: \(action)"
            case .taskFailed(let status):
                "Task did not complete (status: \(status))"
            case .missingValue:
                "Task completed without a value"
            case .uploadFailed(let reason):
                "Upload failed: \(reason)"
            case .unexpectedResponseFormat:
                "Unexpected response data format"
            case .chatActionNotFound:
                "Chat action not found"
            case .decodingFailed(let reason):
                "Decoding failed: \(reason)"
            }
        }
    }
}
