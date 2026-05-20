import SafariServices
import Foundation
import os.log

private let appGroup = "group.com.albassam.mane"
private let log = OSLog(subsystem: "com.albassam.mane.Extension", category: "bridge")

private func containerURL() -> URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
}

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let message: Any?
        if #available(macOS 11.0, *) {
            message = request?.userInfo?[SFExtensionMessageKey]
        } else {
            message = request?.userInfo?["message"]
        }

        var replyPayload: [String: Any] = ["ack": true]

        if let dict = message as? [String: Any],
           let type = dict["type"] as? String {
            switch type {
            case "syncStats":
                if let stats = dict["stats"] {
                    writeStats(stats)
                }
            case "getControl":
                replyPayload = readControl()
            case "setControl":
                if let enabled = dict["enabled"] as? Bool {
                    writeControl(enabled: enabled)
                    replyPayload = ["enabled": enabled]
                }
            default:
                os_log(.debug, log: log, "Unhandled message type: %{public}@", type)
            }
        }

        let response = NSExtensionItem()
        if #available(macOS 11.0, *) {
            response.userInfo = [SFExtensionMessageKey: replyPayload]
        } else {
            response.userInfo = ["message": replyPayload]
        }
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

    private func readControl() -> [String: Any] {
        guard let url = containerURL()?.appendingPathComponent("mane-control.json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ["enabled": true]
        }
        return json
    }

    private func writeControl(enabled: Bool) {
        guard let url = containerURL()?.appendingPathComponent("mane-control.json") else {
            os_log(.error, log: log, "setControl: container unavailable")
            return
        }
        let payload: [String: Any] = ["enabled": enabled]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            os_log(.error, log: log, "Failed to write control: %{public}@", error.localizedDescription)
        }
    }

    private func writeStats(_ stats: Any) {
        guard JSONSerialization.isValidJSONObject(stats),
              let data = try? JSONSerialization.data(withJSONObject: stats),
              let url = containerURL()?.appendingPathComponent("mane-stats.json") else {
            os_log(.error, log: log, "syncStats payload invalid or container unavailable")
            return
        }
        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            os_log(.error, log: log, "Failed to write stats: %{public}@", error.localizedDescription)
        }
    }
}
