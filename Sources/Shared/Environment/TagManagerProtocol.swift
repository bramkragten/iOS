import Foundation
import PromiseKit

public enum TagManagerHandleResult {
    public enum HandledType {
        case nfc
        case generic
    }

    case unhandled
    case handled(HandledType)
    case open(URL)
}

public enum TagManagerError: LocalizedError {
    case nfcUnavailable
    case notHomeAssistantTag

    public var errorDescription: String? {
        switch self {
        case .nfcUnavailable: return L10n.Nfc.notAvailable
        case .notHomeAssistantTag: return L10n.Nfc.Read.Error.notHomeAssistant
        }
    }
}

public protocol TagManager {
    var isNFCAvailable: Bool { get }
    func readNFC() -> Promise<String>
    func writeNFC(value: String) -> Promise<String>
    func handle(userActivity: NSUserActivity) -> TagManagerHandleResult
    func fireEvent(tag: String) -> Promise<Void>
}

public extension TagManager {
    func writeRandomNFC() -> Promise<String> {
        let value = UUID().uuidString.lowercased()
        return writeNFC(value: value)
    }

    func fireEvent(tag: String) -> Promise<Void> {
        if let version = Current.serverVersion(), version < .tagWebhookAvailable {
            return Current.api.then { api -> Promise<Void> in
                let event = HomeAssistantAPI.tagEvent(tagPath: tag)
                return api.CreateEvent(eventType: event.eventType, eventData: event.eventData)
            }
        } else {
            return Current.webhooks.send(request: .init(type: "scan_tag", data: [
                "tag_id": tag
            ]))
        }
    }
}

class EmptyTagManager: TagManager {
    var isNFCAvailable: Bool {
        false
    }

    func readNFC() -> Promise<String> {
        return .init(error: TagManagerError.nfcUnavailable)
    }

    func writeNFC(value: String) -> Promise<String> {
        return .init(error: TagManagerError.nfcUnavailable)
    }

    func handle(userActivity: NSUserActivity) -> TagManagerHandleResult {
        return .unhandled
    }
}
