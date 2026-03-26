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

    /// Build, start the engine, discover action providers.
    ///
    /// After start(), polls actions() until providers register (up to 30s).
    /// Simple polling — no task group deadlock risk.
    func ensureStarted(logger: @escaping @Sendable (String) -> Void) async throws -> TaskWasmProtocol {
        if let engine, isStarted { return engine }
        self.logger = logger

        Self.installWasmBinaryIfNeeded(logger: logger)

        // If no downloaded version exists, clear any bad cache state so
        // WasmUpdateManager inside TaskWasm.default() triggers a fresh download.
        if AsyncifyWasm.currentVersionID == nil {
            logger("No cached wasm version — resetting downloads to force fresh download")
            AsyncifyWasm.resetDownloads()
        } else {
            logger("Using cached wasm version: \(AsyncifyWasm.currentVersionID!)")
        }

        logger("Building engine via TaskWasm.default()...")
        var instance = try await TaskWasm.default()
        instance.premium = true
        instance.delegate = self

        logger("Starting engine (delegate set)...")
        stateContinuation?.yield(.starting)
        try await instance.start()
        logger("Engine start() returned, discovering providers...")

        // Store engine immediately — it IS running once start() returns.
        engine = instance
        isStarted = true

        // Poll actions() until providers register. The WASM pool may throw
        // during .reload state; empty results and errors are both retried.
        var cache: [String: [WaTAction]] = [:]
        for attempt in 1...60 { // 60 × 500ms = 30s
            try Task.checkCancellation()
            do {
                let all = try await instance.actions()
                if !all.actions.isEmpty {
                    for action in all.actions {
                        cache[action.id, default: []].append(action)
                    }
                    logger("Actions available after \(attempt) poll(s)")
                    break
                }
            } catch is CancellationError { throw CancellationError() }
            catch { logger("Poll \(attempt)/60: \(error)") }
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        if !cache.isEmpty {
            actionCache = cache
            for (id, actions) in cache {
                logger("  \(id): \(actions.map(\.provider).joined(separator: ", "))")
            }
            logger("Cached \(cache.count) action types")
        } else {
            logger("warning: no action providers registered")
        }
        stateContinuation?.yield(.running)
        return instance
    }

    /// Re-poll the engine for available actions. Call this to retry action
    /// discovery after a network-related failure during initial startup.
    func refreshActions(logger: @escaping @Sendable (String) -> Void) async throws {
        guard let engine else { throw WasmClient.Error.engineNotStarted }
        let allActions = try await engine.actions()
        var cache: [String: [WaTAction]] = [:]
        for action in allActions.actions {
            cache[action.id, default: []].append(action)
        }
        if !cache.isEmpty {
            actionCache = cache
            logger("Refreshed \(cache.count) action types (\(allActions.actions.count) total providers)")
        }
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
    let logger: @Sendable (String) -> Void

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

    func refreshActions() async throws {
        try await delegate.refreshActions(logger: logger)
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
