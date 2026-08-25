import AnchorCore
import Darwin
import Foundation

private func runAnchorWebBridge() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments == ["--print-manifest"] {
        let binaryPath = URL(filePath: CommandLine.arguments[0])
            .standardizedFileURL.path
        FileHandle.standardOutput.write(
            try BrowserNativeMessagingHost.manifestData(binaryPath: binaryPath)
        )
        FileHandle.standardOutput.write(Data("\n".utf8))
        return
    }

    guard let origin = arguments.first else {
        throw AnchorWebBridgeError.missingOrigin
    }
    try BrowserNativeMessagingHost.validate(origin: origin)
    try BrowserNativeMessagingHost.run()
}

private enum AnchorWebBridgeError: LocalizedError {
    case missingOrigin

    var errorDescription: String? {
        "The browser did not provide an extension origin."
    }
}

do {
    try runAnchorWebBridge()
} catch {
    let message = "AnchorWebBridge: \(error.localizedDescription)\n"
    FileHandle.standardError.write(Data(message.utf8))
    exit(EXIT_FAILURE)
}
