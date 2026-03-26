import Dependencies
import DependenciesMacros
import Foundation

/// General-purpose TCA dependency client wrapping FlowKit's WASM engine.
///
/// Exposes all WASM domains (chat, inpaint, livescore, blobstore) as
/// `@Sendable` async closures. The interface target has no FlowKit dependency —
/// all FlowKit types are mapped to pure Swift models.
///
/// Usage:
/// ```swift
/// @Dependency(\.wasm) var wasm
/// try await wasm.start()
/// let fixtures = try await wasm.livescores("all")
/// ```
@DependencyClient
public struct WasmClient: Sendable {

    // MARK: - Engine Lifecycle

    /// Start the WASM engine. Boots the engine, waits for actions to register,
    /// and begins emitting state updates. Call on app launch or screen appear.
    /// Safe to call multiple times — no-ops if already started.
    public var start: @Sendable () async throws -> Void

    /// Observe engine state changes as an async stream.
    /// Emits `.stopped`, `.starting`, `.running`, `.failed(String)`.
    /// Use this to drive loading UI (progress → content → error/retry).
    public var observeEngineState: @Sendable () async -> AsyncStream<WasmClient.EngineState> = { AsyncStream { _ in } }

    /// Reset the WASM engine. Clears all cached state and stops the engine.
    /// After calling reset, you must call `start` again.
    public var reset: @Sendable () async throws -> Void

    /// Current WASM binary version ID, or nil if engine hasn't loaded yet.
    public var engineVersion: @Sendable () async -> String? = { nil }

    /// Clear the cached WASM binary, forcing re-download on next start.
    public var resetDownloads: @Sendable () async -> Void = { }

    /// Pre-warm the WASM engine. Convenience wrapper around `start` that
    /// ignores errors. Call early (e.g. on home screen appear) to avoid cold-start delay.
    public var warmUp: @Sendable () async -> Void = { }

    /// List all available actions from the running engine.
    public var availableActions: @Sendable () async throws -> [WasmClient.ActionInfo]

    /// Re-poll the engine for action providers. Use after a network-related
    /// failure during initial startup to retry provider discovery.
    public var refreshActions: @Sendable () async throws -> Void

    // MARK: - Blobstore

    /// Upload image data, returning the hosted URL.
    public var uploadImage: @Sendable (_ imageData: Data) async throws -> String

    /// Upload a local file by path, returning the hosted URL.
    public var uploadFile: @Sendable (_ filePath: String, _ filename: String) async throws -> String

    // MARK: - Chat (OpenAI-compatible)

    /// Send a single chat message and get the full response.
    /// Stateless — does not maintain conversation history.
    public var chatSend: @Sendable (
        _ config: WasmClient.ChatConfig,
        _ messages: [WasmClient.ChatMessage]
    ) async throws -> WasmClient.ChatMessage

    /// Stream a chat response, yielding content deltas as they arrive via SSE.
    /// Stateless — caller manages conversation history.
    public var chatStream: @Sendable (
        _ config: WasmClient.ChatConfig,
        _ messages: [WasmClient.ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Swift.Error>

    // MARK: - Inpaint

    /// Auto-detect objects in an image for removal suggestions.
    public var autoSuggestion: @Sendable (
        _ image: String, _ cacheDir: String
    ) async throws -> WasmClient.ObjectSegments

    /// Enhance (upscale) an image.
    public var enhance: @Sendable (
        _ image: String, _ cacheDir: String, _ zoomFactor: Int
    ) async throws -> WasmClient.ObjectSegments

    /// Remove background from an image.
    public var removeBackground: @Sendable (
        _ image: String, _ cacheDir: String
    ) async throws -> WasmClient.Segment

    /// Erase selected objects from an image.
    public var erase: @Sendable (
        _ cacheDir: String,
        _ image: String?,
        _ sessionId: String?,
        _ maskBrush: String?,
        _ maskObjects: String?
    ) async throws -> WasmClient.EraseResult

    /// Skin beauty filter.
    public var skinBeauty: @Sendable (
        _ image: String, _ cacheDir: String
    ) async throws -> WasmClient.ObjectSegments

    /// Sky segmentation.
    public var sky: @Sendable (
        _ image: String, _ cacheDir: String
    ) async throws -> WasmClient.Segment

    /// Virtual try-on. Returns initial result (may be `.processing` — poll via `tryOnStatus`).
    public var tryOn: @Sendable (
        _ cacheDir: String,
        _ image: String?,
        _ modelId: String?,
        _ clothType: String,
        _ clothId: String
    ) async throws -> WasmClient.TryOnResult

    /// Poll try-on task status.
    public var tryOnStatus: @Sendable (_ taskID: String) async throws -> WasmClient.TryOnResult

    // MARK: - Livescore

    /// Fetch live scores.
    public var livescores: @Sendable (_ type: String) async throws -> [WasmClient.Fixture]

    /// Fetch fixtures for a date.
    public var fixtures: @Sendable (_ date: String) async throws -> [WasmClient.Fixture]

    /// Fetch a single fixture by ID.
    public var fixture: @Sendable (_ id: String) async throws -> [WasmClient.Fixture]

    /// Head-to-head between two teams.
    public var headToHead: @Sendable (_ team1: String, _ team2: String) async throws -> [WasmClient.Fixture]

    /// List all leagues.
    public var leagues: @Sendable () async throws -> [WasmClient.League]

    /// Search leagues by query.
    public var searchLeagues: @Sendable (_ query: String) async throws -> [WasmClient.League]

    /// Standings for a season.
    public var standings: @Sendable (_ seasonID: String) async throws -> [WasmClient.Standing]

    /// Search teams by query.
    public var searchTeams: @Sendable (_ query: String) async throws -> [WasmClient.Team]

    /// Fetch team by ID.
    public var team: @Sendable (_ id: String) async throws -> [WasmClient.Team]

    /// Search players.
    public var searchPlayers: @Sendable (_ query: String) async throws -> [WasmClient.Player]

    /// Fetch player by ID.
    public var player: @Sendable (_ id: String) async throws -> [WasmClient.Player]

    /// Fetch league by ID.
    public var league: @Sendable (_ id: String) async throws -> [WasmClient.League]

    /// Topscorers for a season.
    public var topscorers: @Sendable (_ seasonID: String) async throws -> [WasmClient.Player]

    /// Predictions for a fixture.
    public var predictions: @Sendable (_ fixtureID: String) async throws -> Data

    /// Odds for a fixture.
    public var odds: @Sendable (_ fixtureID: String, _ type: String) async throws -> Data

    /// Expected goals (xG) for a fixture.
    public var expectedGoals: @Sendable (_ fixtureID: String, _ type: String) async throws -> Data

    /// News for a season.
    public var news: @Sendable (_ seasonID: String, _ type: String) async throws -> Data

    /// Fetch highlights.
    public var highlights: @Sendable (
        _ competition: String?, _ team: String?
    ) async throws -> [WasmClient.Highlight]
}
