@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Blobstore

extension WasmActor {

    /// Upload image data to blobstore, returning the hosted URL.
    func uploadImage(imageData: Data) async throws -> String {
        let instance = try await readyEngine()
        let filename = "\(UUID().uuidString).jpg"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try imageData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let action = try delegate.resolveAction(actionID: WasmClient.ActionID.upload.rawValue)
        let args: [String: Google_Protobuf_Value] = [
            "file": Google_Protobuf_Value(stringValue: tempURL.absoluteString),
            "filename": Google_Protobuf_Value(stringValue: filename),
        ]
        let task = try await instance.create(action: action, args: args)
        guard task.status == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        let result = try BlobstoreUploadResult(unpackingAny: task.value)
        guard !result.url.isEmpty else {
            throw WasmClient.Error.uploadFailed("Empty URL returned")
        }
        return result.url
    }

    /// Upload a local file by path to blobstore, returning the hosted URL.
    func uploadFile(filePath: String, filename: String) async throws -> String {
        let instance = try await readyEngine()
        let action = try delegate.resolveAction(actionID: WasmClient.ActionID.upload.rawValue)
        let args: [String: Google_Protobuf_Value] = [
            "file": Google_Protobuf_Value(stringValue: filePath),
            "filename": Google_Protobuf_Value(stringValue: filename),
        ]
        let task = try await instance.create(action: action, args: args)
        guard task.status == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        let result = try BlobstoreUploadResult(unpackingAny: task.value)
        guard !result.url.isEmpty else {
            throw WasmClient.Error.uploadFailed("Empty URL returned")
        }
        return result.url
    }
}
