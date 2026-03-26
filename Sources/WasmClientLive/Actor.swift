@preconcurrency import FlowKit
import Foundation
import WasmClient

// MARK: - Delegate

/// Bridges FlowKit's TaskWasmEngine lifecycle to the actor.
/// Implements WasmInstanceDelegate to receive engine state changes —
/// the engine requires a delegate to be set BEFORE start() to fully initialize.
internal final class WasmDelegate: NSObject, WasmInstanceDelegate, @unchecked Sendable {
    private(set) var engine: TaskWasmProtocol?
    private(set) var isStarted = false
    /// Cached actions keyed by action ID — populated after engine stabilizes.
    private var actionCache: [String: [WaTAction]] = [:]
    private var logger: (@Sendable (String) -> Void)?
    /// Continuation for engine state stream.
    var stateContinuation: AsyncStream<WasmClient.EngineState>.Continuation?

    // MARK: - WasmInstanceDelegate

    func stateChanged(state: AsyncWasm.EngineState) {
        logger?("Engine state: \(state)")
        let mapped: WasmClient.EngineState
        switch state {
        case .running:
            mapped = .running
        case .reload:
            mapped = .starting
        default:
            mapped = .stopped
        }
        stateContinuation?.yield(mapped)
    }

    // MARK: - Engine Lifecycle

    /// Build, start the engine, wait for it to stabilize, then cache actions.
    ///
    /// Engine lifecycle observed in production:
    ///   `start()` → `.reload(version)` → (WASM pool stabilizes) → `actions()` works
    ///   `.running` does NOT fire for this FlowKit version.
    ///
    /// The WASM pool throws AsyncifyWasmPoolError if queried during `.reload`.
    /// Strategy: after `start()`, poll `actions()` with error catching until the
    /// pool stabilizes and providers register. Simple, no race conditions.
    func ensureStarted(logger: @escaping @Sendable (String) -> Void) async throws -> TaskWasmProtocol {
        if let engine, isStarted { return engine }
        self.logger = logger

        Self.installWasmBinaryIfNeeded(logger: logger)

        logger("Building engine via TaskWasm.default()...")
        var instance = try await TaskWasm.default()
        instance.premium = true

        instance.delegate = self

        // Start on the main actor — flow-kit-example always starts from SwiftUI views
        // (main thread). FlowKit's WASM engine may require main thread for full init.
        logger("Starting engine (delegate set, main actor)...")
        stateContinuation?.yield(.starting)
        try await Self.startOnMain(instance)
        logger("Engine start() returned, waiting for actions to become available...")

        // Poll for actions. The WASM pool throws during .reload state and actions()
        // returns empty until providers register. Both are caught and retried.
        var cache: [String: [WaTAction]] = [:]
        for attempt in 1...60 { // 60 × 500ms = 30s max
            try Task.checkCancellation()
            do {
                let allActions = try await instance.actions()
                if !allActions.actions.isEmpty {
                    for action in allActions.actions {
                        cache[action.id, default: []].append(action)
                        logger("  Cached action: id=\(action.id) name=\(action.name) provider=\(action.provider)")
                    }
                    logger("Cached \(cache.count) action types (\(allActions.actions.count) total providers) after \(attempt) attempt(s)")
                    break
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                logger("Poll \(attempt)/60: \(error)")
            }
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        }

        guard !cache.isEmpty else {
            stateContinuation?.yield(.failed("Engine init failed — no actions registered"))
            throw WasmClient.Error.engineInitFailed
        }

        actionCache = cache
        engine = instance
        isStarted = true
        stateContinuation?.yield(.running)
        return instance
    }

    /// Copy the bundled raw `base.wasm` from WasmClientLive's SPM resource bundle
    /// into the app's Documents directory. FlowKit's `TaskWasm.default()` checks
    /// `Bundle.main` for the wasm binary; consumers that don't manually place it
    /// there can rely on this copy as a fallback if FlowKit also checks Documents.
    ///
    /// This is a best-effort operation — if it fails, the consumer must include
    /// `base.wasm` in their app target's Copy Bundle Resources phase.
    private static func installWasmBinaryIfNeeded(logger: @escaping @Sendable (String) -> Void) {
        // Already in Bundle.main — nothing to do.
        if Bundle.main.url(forResource: "base", withExtension: "wasm") != nil {
            logger("base.wasm found in Bundle.main")
            return
        }

        // Locate bundled copy inside WasmClientLive's SPM resource bundle.
        guard let sourceURL = Bundle.module.url(forResource: "base", withExtension: "wasm") else {
            logger("warning: base.wasm not found in WasmClientLive resources")
            return
        }

        // Copy to Documents — FlowKit may check here for cached/downloaded binaries.
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destURL = docs.appending(path: "base.wasm")

        if fm.fileExists(atPath: destURL.path()) { return }

        do {
            try fm.copyItem(at: sourceURL, to: destURL)
            logger("Installed base.wasm to Documents/")
        } catch {
            logger("warning: failed to install base.wasm — \(error.localizedDescription)")
        }
    }

    /// Start the engine on the main actor — FlowKit requires main thread.
    @MainActor
    private static func startOnMain(_ instance: TaskWasmProtocol) async throws {
        try await instance.start()
    }

    /// Resolve an action from the pre-loaded cache.
    func resolveAction(actionID: String) throws -> WaTAction {
        guard let actions = actionCache[actionID], let action = actions.first else {
            throw WasmClient.Error.noProviderFound(action: actionID)
        }
        return action
    }

    /// Reset the engine — clear all cached state.
    func resetEngine() {
        engine = nil
        isStarted = false
        actionCache = [:]
        stateContinuation?.yield(.stopped)
    }

    /// All cached actions flattened.
    func allActions() -> [WaTAction] {
        actionCache.values.flatMap { $0 }
    }
}

// MARK: - Actor

/// Plain actor that manages WASM engine lifecycle and business logic via the delegate.
/// All methods are serialized by the actor — no concurrent WASM engine access.
actor WasmActor {
    let delegate = WasmDelegate()
    private let logger: @Sendable (String) -> Void

    // MARK: - Init

    init(
        logger: @escaping @Sendable (String) -> Void = { message in
            #if DEBUG
            print("[WasmClient]: \(message)")
            #endif
        }
    ) {
        self.logger = logger
    }

    // MARK: - Engine Lifecycle

    func readyEngine() async throws -> TaskWasmProtocol {
        let engine = try await delegate.ensureStarted(logger: logger)
        logger("Engine ready")
        return engine
    }

    func start() async throws {
        delegate.stateContinuation?.yield(.starting)
        _ = try await readyEngine()
    }

    func observeEngineState() -> AsyncStream<WasmClient.EngineState> {
        AsyncStream { continuation in
            delegate.stateContinuation = continuation
            continuation.onTermination = { [weak delegate] _ in
                delegate?.stateContinuation = nil
            }
        }
    }

    func reset() async throws {
        delegate.resetEngine()
    }

    func engineVersion() -> String? {
        AsyncifyWasm.currentVersionID
    }

    func resetDownloads() {
        AsyncifyWasm.resetDownloads()
    }

    func warmUp() async {
        do {
            _ = try await readyEngine()
        } catch {
            logger("Warm-up failed (non-fatal): \(error.localizedDescription)")
        }
    }

    func availableActions() throws -> [WasmClient.ActionInfo] {
        delegate.allActions().map { action in
            WasmClient.ActionInfo(
                id: action.id,
                provider: action.provider,
                name: action.name
            )
        }
    }
}
