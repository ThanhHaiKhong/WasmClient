import Dependencies
import Foundation

// MARK: - Dependency Registration

extension DependencyValues {
    public var wasm: WasmClient {
        get { self[WasmClient.self] }
        set { self[WasmClient.self] = newValue }
    }
}

// MARK: - Test Dependency Key

extension WasmClient: TestDependencyKey {
    public static let previewValue = Self.happy
    public static let testValue = Self()
}

// MARK: - Mock Constants

private enum MockConstants {
    static let warmUpDelay: UInt64 = 200_000_000
    static let shortDelay: UInt64 = 300_000_000
    static let mediumDelay: UInt64 = 500_000_000
    static let longDelay: UInt64 = 1_500_000_000
}

// MARK: - Mock Implementations

extension WasmClient {
    public static let happy = Self(
        start: {
            try? await Task.sleep(nanoseconds: MockConstants.warmUpDelay)
        },
        observeEngineState: {
            AsyncStream { continuation in
                continuation.yield(.starting)
                Task {
                    try? await Task.sleep(nanoseconds: MockConstants.warmUpDelay)
                    continuation.yield(.running)
                }
            }
        },
        reset: { },
        engineVersion: { "mock-1.2.3" },
        resetDownloads: { },
        warmUp: {
            try? await Task.sleep(nanoseconds: MockConstants.warmUpDelay)
        },
        availableActions: {
            [
                ActionInfo(id: ActionID.chat.rawValue, provider: "openai", name: "Chat"),
                ActionInfo(id: ActionID.scan.rawValue, provider: "vision", name: "Scan"),
                ActionInfo(id: ActionID.livescore.rawValue, provider: "football", name: "Livescore"),
            ]
        },
        uploadImage: { _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return "https://example.com/mock-image.jpg"
        },
        uploadFile: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return "https://example.com/mock-file.jpg"
        },
        chatSend: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.longDelay)
            return ChatMessage(role: .assistant, content: "Hello! How can I help you today?")
        },
        chatStream: { _, _ in
            AsyncThrowingStream { continuation in
                Task {
                    for word in ["Hello", "!", " How", " can", " I", " help", "?"] {
                        try await Task.sleep(nanoseconds: 50_000_000)
                        continuation.yield(word)
                    }
                    continuation.finish()
                }
            }
        },
        autoSuggestion: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return ObjectSegments(sessionID: "mock-session")
        },
        enhance: { _, _, _ in
            try await Task.sleep(nanoseconds: MockConstants.longDelay)
            return ObjectSegments(sessionID: "mock-session")
        },
        removeBackground: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return Segment(maskURL: "https://example.com/mask.png")
        },
        erase: { _, _, _, _, _ in
            try await Task.sleep(nanoseconds: MockConstants.longDelay)
            return EraseResult(sessionID: "mock-session", imageURL: "https://example.com/erased.jpg")
        },
        skinBeauty: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return ObjectSegments(sessionID: "mock-session")
        },
        sky: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return Segment(maskURL: "https://example.com/sky-mask.png")
        },
        tryOn: { _, _, _, _, _ in
            try await Task.sleep(nanoseconds: MockConstants.longDelay)
            return TryOnResult(status: .completed, imageURL: "https://example.com/tryon.jpg")
        },
        tryOnStatus: { _ in
            TryOnResult(status: .completed, imageURL: "https://example.com/tryon.jpg")
        },
        livescores: { _ in
            try await Task.sleep(nanoseconds: MockConstants.shortDelay)
            return [
                Fixture(id: "1", homeTeam: "Arsenal", awayTeam: "Chelsea", homeScore: 2, awayScore: 1, status: "FT"),
                Fixture(id: "2", homeTeam: "Liverpool", awayTeam: "Man City", homeScore: 0, awayScore: 0, status: "LIVE"),
            ]
        },
        fixtures: { _ in
            [Fixture(id: "1", homeTeam: "Arsenal", awayTeam: "Chelsea", status: "NS", date: "2026-03-25")]
        },
        fixture: { _ in
            [Fixture(id: "1", homeTeam: "Arsenal", awayTeam: "Chelsea", homeScore: 2, awayScore: 1, status: "FT")]
        },
        headToHead: { _, _ in
            [Fixture(id: "h2h-1", homeTeam: "Arsenal", awayTeam: "Chelsea", homeScore: 1, awayScore: 0, status: "FT")]
        },
        leagues: {
            [
                League(id: "39", name: "Premier League", country: "England", type: "League"),
                League(id: "140", name: "La Liga", country: "Spain", type: "League"),
            ]
        },
        searchLeagues: { _ in
            [League(id: "39", name: "Premier League", country: "England")]
        },
        standings: { _ in
            [Standing(rank: 1, teamID: "42", teamName: "Arsenal", points: 75, played: 30)]
        },
        searchTeams: { _ in
            [Team(id: "42", name: "Arsenal", logo: "https://example.com/arsenal.png", country: "England")]
        },
        team: { _ in
            [Team(id: "42", name: "Arsenal", logo: "https://example.com/arsenal.png", country: "England")]
        },
        searchPlayers: { _ in
            [Player(id: "1", name: "Bukayo Saka", position: "Attacker", nationality: "England")]
        },
        player: { _ in
            [Player(id: "1", name: "Bukayo Saka", position: "Attacker", nationality: "England")]
        },
        league: { _ in
            [League(id: "39", name: "Premier League", country: "England")]
        },
        topscorers: { _ in
            [Player(id: "1", name: "Erling Haaland", position: "Attacker", nationality: "Norway")]
        },
        predictions: { _ in Data() },
        odds: { _, _ in Data() },
        expectedGoals: { _, _ in Data() },
        news: { _, _ in Data() },
        highlights: { _, _ in
            [Highlight(title: "Arsenal vs Chelsea Highlights", videoURL: "https://example.com/video.mp4")]
        }
    )
}
