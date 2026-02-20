import Foundation
import UserNotifications

final class NotificationService: NSObject {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let categoryId = "agentdock.agent.response"
    private var isAuthorized = false

    private override init() {
        super.init()
        center.delegate = self
        setupCategory()
    }

    // MARK: - Setup

    private func setupCategory() {
        let category = UNNotificationCategory(
            identifier: categoryId,
            actions: [],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            self?.isAuthorized = granted
        }
    }

    // MARK: - Notifications

    func notifyTaskComplete(agentName: String, preview: String) {
        guard isAuthorized else {
            // Try requesting permission on first use
            center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                self?.isAuthorized = granted
                if granted {
                    self?.sendNotification(
                        title: "\(agentName) finished",
                        body: preview
                    )
                }
            }
            return
        }

        sendNotification(
            title: "\(agentName) finished",
            body: preview
        )
    }

    func notifyCollaborationComplete(agentNames: [String]) {
        let names = agentNames.joined(separator: ", ")
        sendNotification(
            title: "Collaboration complete",
            body: "\(names) finished the collaborative task."
        )
    }

    // MARK: - Internal

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = categoryId

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )

        center.add(request)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
