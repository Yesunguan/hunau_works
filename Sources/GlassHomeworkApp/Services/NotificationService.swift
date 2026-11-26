import Foundation
import GlassHomeworkCore
@preconcurrency import UserNotifications

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private(set) var authorizationStatusText: String = "未检测"
    var onOpenHomework: (@MainActor (UUID) -> Void)?

    private var isBundledApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    override init() {
        super.init()
        if isBundledApp {
            UNUserNotificationCenter.current().delegate = self
            refreshAuthorizationStatus()
        } else {
            authorizationStatusText = "需以 .app 运行"
        }
    }

    func requestAuthorizationIfNeeded() {
        guard isBundledApp else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .notDetermined:
                _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
                self.refreshAuthorizationStatus()
            default:
                self.updateStatusLabel(settings.authorizationStatus)
            }
        }
    }

    func refreshAuthorizationStatus() {
        guard isBundledApp else {
            authorizationStatusText = "需以 .app 运行"
            return
        }
        Task { @MainActor [weak self] in
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            self?.updateStatusLabel(settings.authorizationStatus)
        }
    }

    private func updateStatusLabel(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional, .ephemeral:
            authorizationStatusText = "已授权"
        case .denied:
            authorizationStatusText = "已在系统设置中拒绝"
        case .notDetermined:
            authorizationStatusText = "待授权"
        @unknown default:
            authorizationStatusText = "未知"
        }
    }

    func syncReminders(for store: HomeworkStore) {
        guard isBundledApp else { return }
        let planned = ReminderScheduler.plannedReminders(
            items: store.items,
            courses: store.courses,
            settings: store.settings,
            now: Date()
        )
        Task {
            let center = UNUserNotificationCenter.current()
            let existing = await center.pendingNotificationRequests()
            let oldIds = existing
                .map(\.identifier)
                .filter { $0.hasPrefix("glasshomework.") }
            if !oldIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: oldIds)
            }

            for req in planned {
                let content = UNMutableNotificationContent()
                content.title = req.title
                content.body = req.body
                content.sound = .default
                content.userInfo = ["homeworkId": req.homeworkId.uuidString]

                let comps = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: req.fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let unReq = UNNotificationRequest(
                    identifier: req.identifier,
                    content: content,
                    trigger: trigger
                )
                try? await center.add(unReq)
            }
        }
    }

    func sendTestNotification(completion: @escaping @MainActor (String) -> Void) {
        guard isBundledApp else {
            completion("当前非 .app 环境，打包安装后即可测试系统通知")
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                self.refreshAuthorizationStatus()
                guard granted else {
                    completion("通知权限未开启，请在「系统设置 → 通知 → 琉璃作业」中允许")
                    return
                }
                let content = UNMutableNotificationContent()
                content.title = "琉璃作业 · 测试提醒"
                content.body = "系统通知已连通！作业临近截止时我会按你的配置准时提醒你。"
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.5, repeats: false)
                let req = UNNotificationRequest(
                    identifier: "glasshomework.test.\(UUID().uuidString)",
                    content: content,
                    trigger: trigger
                )
                try await center.add(req)
                completion("测试通知已发送，约 1–2 秒后显示")
            } catch {
                completion("通知发送失败：\(error.localizedDescription)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let idStr = response.notification.request.content.userInfo["homeworkId"] as? String
        if let idStr, let uuid = UUID(uuidString: idStr) {
            await MainActor.run { [weak self] in
                self?.onOpenHomework?(uuid)
            }
        }
    }
}
