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
        String(localized: String.LocalizationValue(key), table: "Transcription", bundle: .main)
    }
}

public enum TranscriberError: LocalizedError, Equatable {
    case notReady

    public var errorDescription: String? {
        TranscriptionErrorDescriber.string("error.notReady")
    }
}
