@preconcurrency import FlowKit
import CoreGraphics
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Inpaint

extension WasmActor {

    /// Auto-detect objects in an image for removal suggestions.
    func autoSuggestion(image: String, cacheDir: String) async throws -> WasmClient.ObjectSegments {
        let args: [String: Google_Protobuf_Value] = [
            "image": Google_Protobuf_Value(stringValue: image),
            "cache_dir": Google_Protobuf_Value(stringValue: cacheDir),
        ]
        let result: InpaintObjectSegments = try await runInpaint(
            actionID: WasmClient.ActionID.autoSuggestion, args: args
        )
        return mapObjectSegments(result)
    }

    /// Enhance (upscale) an image.
    func enhance(image: String, cacheDir: String, zoomFactor: Int) async throws -> WasmClient.ObjectSegments {
        var args: [String: Google_Protobuf_Value] = [
            "image": Google_Protobuf_Value(stringValue: image),
            "cache_dir": Google_Protobuf_Value(stringValue: cacheDir),
        ]
        if zoomFactor != 2 {
            args["zoom_factor"] = Google_Protobuf_Value(stringValue: "\(zoomFactor)")
        }
        let result: InpaintObjectSegments = try await runInpaint(
            actionID: WasmClient.ActionID.enhance, args: args
        )
        return mapObjectSegments(result)
    }

    /// Remove background from an image.
    func removeBackground(image: String, cacheDir: String) async throws -> WasmClient.Segment {
        let args: [String: Google_Protobuf_Value] = [
            "image": Google_Protobuf_Value(stringValue: image),
            "cache_dir": Google_Protobuf_Value(stringValue: cacheDir),
        ]
        let result: InpaintSegment = try await runInpaint(
            actionID: WasmClient.ActionID.removeBg, args: args
        )
        return mapSegment(result)
    }

    /// Erase selected objects from an image.
    func erase(
        cacheDir: String,
        image: String?,
        sessionId: String?,
        maskBrush: String?,
        maskObjects: String?
    ) async throws -> WasmClient.EraseResult {
        var args: [String: Google_Protobuf_Value] = [
            "cache_dir": Google_Protobuf_Value(stringValue: cacheDir),
        ]
        if let image {
            args["image"] = Google_Protobuf_Value(stringValue: image)
        }
        if let sessionId {
            args["session_id"] = Google_Protobuf_Value(stringValue: sessionId)
        }
        if let maskBrush {
            args["mask_brush"] = Google_Protobuf_Value(stringValue: maskBrush)
        }
        if let maskObjects {
            args["mask_objects"] = Google_Protobuf_Value(stringValue: maskObjects)
        }
        let result: InpaintErase = try await runInpaint(
            actionID: WasmClient.ActionID.erase, args: args
        )
        return WasmClient.EraseResult(
            sessionID: result.sessionID,
            imageURL: result.hasImage ? result.image.url : "",
            maskURL: result.hasMask ? result.mask.url : "",
            metadata: mapMetadata(result.metadata)
        )
    }

    /// Skin beauty filter.
    func skinBeauty(image: String, cacheDir: String) async throws -> WasmClient.ObjectSegments {
        let args: [String: Google_Protobuf_Value] = [
            "image": Google_Protobuf_Value(stringValue: image),
            "cache_dir": Google_Protobuf_Value(stringValue: cacheDir),
        ]
        let result: InpaintObjectSegments = try await runInpaint(
            actionID: WasmClient.ActionID.skinBeauty, args: args
        )
        return mapObjectSegments(result)
    }

    /// Sky segmentation.
    func sky(image: String, cacheDir: String) async throws -> WasmClient.Segment {
        let args: [String: Google_Protobuf_Value] = [
            "image": Google_Protobuf_Value(stringValue: image),
            "cache_dir": Google_Protobuf_Value(stringValue: cacheDir),
        ]
        let result: InpaintSegment = try await runInpaint(
            actionID: WasmClient.ActionID.sky, args: args
        )
        return mapSegment(result)
    }

    /// Virtual try-on.
    func tryOn(
        cacheDir: String,
        image: String?,
        modelId: String?,
        clothType: String,
        clothId: String
    ) async throws -> WasmClient.TryOnResult {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [
            "cache_dir": Google_Protobuf_Value(stringValue: cacheDir),
            "cloth_type": Google_Protobuf_Value(stringValue: clothType),
            "cloth_id": Google_Protobuf_Value(stringValue: clothId),
        ]
        if let image {
            args["image"] = Google_Protobuf_Value(stringValue: image)
        }
        if let modelId {
            args["model_id"] = Google_Protobuf_Value(stringValue: modelId)
        }
        let action = try await delegate.resolveAction(actionID: WasmClient.ActionID.tryOn.rawValue, logger: logger)
        let task = try await instance.create(action: action, args: args)
        return mapTryOnResult(task)
    }

    /// Poll try-on task status.
    func tryOnStatus(taskID: String) async throws -> WasmClient.TryOnResult {
        let instance = try await readyEngine()
        // Build a WaTTask with the task ID to query status
        var taskRef = WaTTask()
        taskRef.id = taskID
        guard let engine = instance as? TaskWasmEngine else {
            throw WasmClient.Error.engineNotReady
        }
        let updated = try await engine.status(task: taskRef)
        return mapTryOnResult(updated)
    }

    // MARK: - Inpaint Helpers

    /// Generic helper to run an inpaint action and decode the proto result.
    private func runInpaint<T: SwiftProtobuf.Message>(
        actionID: WasmClient.ActionID,
        args: [String: Google_Protobuf_Value]
    ) async throws -> T {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: actionID.rawValue, logger: logger)
        return try await instance.run(action: action, args: args)
    }

    // MARK: - Inpaint Mapping

    private func mapObjectSegments(_ proto: InpaintObjectSegments) -> WasmClient.ObjectSegments {
        WasmClient.ObjectSegments(
            sessionID: proto.sessionID,
            segments: proto.segments.map(mapSegment),
            suggestMask: proto.suggestMask,
            suggestObjectIds: proto.suggestObjectIds.joined(separator: ","),
            metadata: mapMetadata(proto.metadata)
        )
    }

    private func mapSegment(_ proto: InpaintSegment) -> WasmClient.Segment {
        let bbox: CGRect
        if proto.hasBbox {
            let r = proto.bbox
            bbox = CGRect(x: r.origin.x, y: r.origin.y, width: r.size.width, height: r.size.height)
        } else {
            bbox = .zero
        }
        return WasmClient.Segment(
            bbox: bbox,
            maskURL: proto.hasMask ? proto.mask.url : "",
            metadata: mapMetadata(proto.metadata)
        )
    }

    private func mapMetadata(_ proto: Google_Protobuf_Struct) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in proto.fields {
            switch value.kind {
            case .stringValue(let s):
                result[key] = s
            case .numberValue(let n):
                result[key] = "\(n)"
            case .boolValue(let b):
                result[key] = "\(b)"
            default:
                break
            }
        }
        return result
    }

    private func mapTryOnResult(_ task: WaTTask) -> WasmClient.TryOnResult {
        let status: WasmClient.TaskStatus
        var imageURL = ""
        let progress = task.progress ?? 0

        switch task.status {
        case .completed:
            status = .completed
            if task.hasValue, let img = try? TypesImage(unpackingAny: task.value) {
                imageURL = img.url
            }
        case .processing:
            status = .processing
        default:
            status = .failed("\(task.status)")
        }

        return WasmClient.TryOnResult(
            status: status,
            imageURL: imageURL,
            progress: progress
        )
    }
}
