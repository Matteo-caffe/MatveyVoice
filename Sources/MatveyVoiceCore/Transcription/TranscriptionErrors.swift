import Foundation

/// Turns download/load failures into short human-readable messages (no dictated text involved).
public enum TranscriptionErrorDescriber {
    public static func reason(for error: Error) -> String {
        let ns = error as NSError
        if error is CancellationError { return string("error.cancelled") }
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorDataNotAllowed, NSURLErrorInternationalRoamingOff:
                return string("error.noNetwork")
            case NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut, NSURLErrorCannotConnectToHost,
                 NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed, NSURLErrorSecureConnectionFailed:
                return string("error.connectionLost")
            case NSURLErrorCancelled:
                return string("error.cancelled")
            default:
                return string("error.connectionLost")
            }
        }
        if ns.domain == NSCocoaErrorDomain && ns.code == NSFileWriteOutOfSpaceError { return string("error.noSpace") }
        if ns.domain == NSPOSIXErrorDomain && ns.code == Int(ENOSPC) { return string("error.noSpace") }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error, (underlying as NSError) != ns {
            return reason(for: underlying)
        }
        return string("error.generic")
    }

    static func string(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: fallback[key], table: "Transcription")
    }

    private static let fallback: [String: String] = [
        "error.noNetwork": "No internet connection. Connect and try again.",
        "error.connectionLost": "The download was interrupted. Check your connection and try again.",
        "error.noSpace": "Not enough free disk space for the model.",
        "error.cancelled": "The download was cancelled.",
        "error.generic": "Could not prepare the speech model. Try again.",
        "error.unknownModel": "Unknown speech model.",
        "error.notReady": "The speech model is not ready yet.",
    ]
}

public enum TranscriberError: LocalizedError, Equatable {
    case notReady

    public var errorDescription: String? {
        TranscriptionErrorDescriber.string("error.notReady")
    }
}
