import UIKit
import UserNotifications
import Observation

@MainActor
@Observable
final class OpenLineLink {
    static let shared = OpenLineLink()
    struct Destination: Equatable {
        let story: String
        let session: String
    }
    var pending: Destination?
    var foregroundStory: String?

    func receive(_ url: URL) {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard url.scheme == "openline", url.host == "story", parts.count == 2 else { return }
        pending = Destination(story: parts[0], session: parts[1])
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let story = notification.request.content.userInfo["storyID"] as? String
        Task { @MainActor in
            completionHandler(story == OpenLineLink.shared.foregroundStory ? [] : [.banner, .sound])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        guard let story = info["storyID"] as? String, let session = info["sessionID"] as? String else {
            completionHandler()
            return
        }
        Task { @MainActor in
            OpenLineLink.shared.pending = .init(story: story, session: session)
            completionHandler()
        }
    }
}
