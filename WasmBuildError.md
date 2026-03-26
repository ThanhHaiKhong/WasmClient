Root Cause: Xcode 26 corrupts .wasm files in xcframework artifacts

  When Swift Package Manager resolves the FlowKit binary xcframework, Xcode 26 copies it from SourcePackages/checkouts/ to SourcePackages/artifacts/. During this artifact
  processing step, Xcode encrypts/transforms all .wasm files, changing the valid WebAssembly magic header (\0asm = [0, 97, 115, 109]) into garbage bytes.

  At runtime, FlowKit tries to load base.wasm from its framework bundle, finds the corrupted file, and throws:
  magic header not detected: expected [0, 97, 115, 109] but got [127, 65, 252, 214]

  This is an Xcode 26 bug — it affects any project using FlowKit, including the original flow-kit-example.

  What was wrong with the AIScaner project

  3 build errors + 1 runtime error:

  1. Duplicate Info.plist — The Xcode 26 project used PBXFileSystemSynchronizedRootGroup (auto-includes all files) + GENERATE_INFOPLIST_FILE = YES, which conflicted with the
  copied Info.plist file.
  2. Missing SWIFT_INCLUDE_PATHS — FlowKit requires $(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)/FlowKit.framework/Modules to resolve its C module dependencies
  (AsyncWasm, AsyncWasmKit, TaskWasm, WasmSwiftProtobuf).
  3. Swift 6 strict concurrency — Xcode 26 auto-added SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor and SWIFT_APPROACHABLE_CONCURRENCY = YES, but the protobuf-generated code isn't
  compatible with strict concurrency.
  4. Wasm corruption (runtime) — The Xcode 26 artifact processing bug described above.

  Why the fix scripts didn't work from Xcode

  The original project used Xcode 26's PBXFileSystemSynchronizedRootGroup format (new in Xcode 16+). Build phases in this format run during the build, but Xcode's framework
  embedding (ProcessXCFramework → builtin-copy → CodeSign) runs at times controlled by the build system — after user build phases complete. So the fix script would repair the
  wasm, then Xcode would re-embed the corrupted version on top of it.

  The solution: XcodeGen

  Recreating the project with XcodeGen (matching the original flow-kit-example setup) solved everything:

  - XcodeGen uses the traditional PBXFileReference format, not the new sync groups — no Info.plist conflict
  - project.yml sets SWIFT_INCLUDE_PATHS and doesn't add Swift 6 concurrency settings
  - The postBuildScripts with basedOnDependencyAnalysis: false runs reliably every build
  - The scheme postActions script provides a second fix pass after the entire build completes
  - ENABLE_USER_SCRIPT_SANDBOXING: NO allows scripts to access SourcePackages/checkouts/

  The fix script copies the valid base.wasm from SourcePackages/checkouts/ (uncorrupted) to replace the corrupted copies in the app bundle, intermediate products, and artifacts
  directory.
