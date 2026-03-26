import Foundation
import PackagePlugin

@main
struct MergeFlowKitModulesPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let packageDir = context.package.directory
        let mergedDir = packageDir.appending(subpath: ".build/flowkit-merged-modules")
        let script = packageDir.appending(subpath: "scripts/merge-flowkit-modules.sh")

        return [
            .prebuildCommand(
                displayName: "Merge FlowKit Sub-Module Interfaces",
                executable: Path("/bin/bash"),
                arguments: [script.string, packageDir.string, mergedDir.string],
                outputFilesDirectory: mergedDir
            ),
        ]
    }
}
