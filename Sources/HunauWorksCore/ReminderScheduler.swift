import Foundation

public struct ReminderRequest: Equatable, Hashable, Sendable {
    public let identifier: String
    public let homeworkId: UUID
    public let title: String
    public let body: String
    public let fireDate: Date
    public let leadMinutes: Int

    public init(
        identifier: String,
        homeworkId: UUID,
        title: String,
        body: String,
        fireDate: Date,
        leadMinutes: Int
    ) {
        self.identifier = identifier
        self.homeworkId = homeworkId
        self.title = title
        self.body = body
        self.fireDate = fireDate
        self.leadMinutes = leadMinutes
    }
}

public enum ReminderScheduler {
    /// macOS/Apple allows up to 64 pending local notifications per app; keep headroom for test notifications.
    public static let maxPendingNotifications = 60

    public static func plannedReminders(
        items: [HomeworkItem],
        courses: [Course],
        settings: AppSettings,
        now: Date = Date()
    ) -> [ReminderRequest] {
        guard settings.notificationsEnabled, !settings.notificationsMuted else {
            return []
        }

        let courseMap = Dictionary(uniqueKeysWithValues: courses.map { ($0.id, $0.name) })
        var requests: [ReminderRequest] = []

        for item in items where !item.isCompleted {
            let leadList = item.customReminderMinutes ?? settings.defaultReminderMinutes
            let uniqueLeads = Array(Set(leadList)).sorted(by: >)
            let courseName = item.courseId.flatMap { courseMap[$0] }

            for lead in uniqueLeads {
                let fireDate = item.dueDate.addingTimeInterval(-Double(lead) * 60)
                guard fireDate > now else { continue }

                let titlePrefix = courseName.map { "[\($0)] " } ?? ""
                let title = "作业提醒 · \(titlePrefix)\(item.title)"
                let leadText = UrgencyCalculator.leadTimeLabel(minutes: lead)
                let dueStr = UrgencyCalculator.dueDateFormatted(item.dueDate, now: fireDate)
                let body = lead > 0
                    ? "距离截止还有 \(leadText)（截止：\(dueStr)）"
                    : "该作业即将截止（\(dueStr)），请检查提交！"

                let id = "hunau_works.\(item.id.uuidString).lead\(lead)"
                requests.append(
                    ReminderRequest(
                        identifier: id,
                        homeworkId: item.id,
                        title: title,
                        body: body,
                        fireDate: fireDate,
                        leadMinutes: lead
                    )
                )
            }
        }

        requests.sort { $0.fireDate < $1.fireDate }
        if requests.count > maxPendingNotifications {
            return Array(requests.prefix(maxPendingNotifications))
        }
        return requests
    }
}
