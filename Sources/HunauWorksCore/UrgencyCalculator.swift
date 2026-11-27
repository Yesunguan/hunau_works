import Foundation

public enum UrgencyLevel: Int, Comparable, Sendable {
    case overdue = 0
    case critical24h = 1
    case soon3Days = 2
    case comfortable = 3
    case completed = 4

    public static func < (lhs: UrgencyLevel, rhs: UrgencyLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .overdue: return "已逾期"
        case .critical24h: return "24h 内"
        case .soon3Days: return "3 天内"
        case .comfortable: return "充裕"
        case .completed: return "已完成"
        }
    }
}

public enum HomeworkBucket: Int, CaseIterable, Identifiable, Sendable {
    case overdue = 0
    case today = 1
    case within3Days = 2
    case later = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .overdue: return "已逾期"
        case .today: return "今天到期"
        case .within3Days: return "三天内到期"
        case .later: return "后续待办"
        }
    }

    public var symbolName: String {
        switch self {
        case .overdue: return "exclamationmark.triangle.fill"
        case .today: return "flame.fill"
        case .within3Days: return "clock.badge.exclamationmark"
        case .later: return "calendar"
        }
    }
}

public enum QuickDateOption: String, CaseIterable, Identifiable, Sendable {
    case tonight
    case tomorrow
    case inTwoDays
    case thisFriday
    case nextWeek

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .tonight: return "今晚"
        case .tomorrow: return "明天"
        case .inTwoDays: return "后天"
        case .thisFriday: return "本周五"
        case .nextWeek: return "一周后"
        }
    }

    public func resolveDate(from now: Date = Date(), calendar: Calendar = .current) -> Date {
        func endOfDay(_ date: Date) -> Date {
            var comps = calendar.dateComponents([.year, .month, .day], from: date)
            comps.hour = 23
            comps.minute = 59
            comps.second = 0
            return calendar.date(from: comps) ?? date
        }

        switch self {
        case .tonight:
            let tonight = endOfDay(now)
            if tonight <= now {
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
                return endOfDay(tomorrow)
            }
            return tonight
        case .tomorrow:
            let target = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return endOfDay(target)
        case .inTwoDays:
            let target = calendar.date(byAdding: .day, value: 2, to: now) ?? now
            return endOfDay(target)
        case .thisFriday:
            // In Gregorian calendar: Sunday = 1, ..., Friday = 6, Saturday = 7
            let weekday = calendar.component(.weekday, from: now)
            var daysUntilFriday = (6 - weekday + 7) % 7
            if daysUntilFriday == 0 {
                let todayEnd = endOfDay(now)
                if todayEnd.timeIntervalSince(now) < 3600 {
                    daysUntilFriday = 7
                }
            }
            let target = calendar.date(byAdding: .day, value: daysUntilFriday, to: now) ?? now
            return endOfDay(target)
        case .nextWeek:
            let target = calendar.date(byAdding: .day, value: 7, to: now) ?? now
            return endOfDay(target)
        }
    }
}

public enum UrgencyCalculator {
    public static func urgency(for item: HomeworkItem, now: Date = Date()) -> UrgencyLevel {
        if item.isCompleted { return .completed }
        let remaining = item.dueDate.timeIntervalSince(now)
        if remaining < 0 {
            return .overdue
        } else if remaining <= 24 * 3600 {
            return .critical24h
        } else if remaining <= 72 * 3600 {
            return .soon3Days
        } else {
            return .comfortable
        }
    }

    public static func bucket(
        for item: HomeworkItem,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> HomeworkBucket {
        let remaining = item.dueDate.timeIntervalSince(now)
        if remaining < 0 {
            return .overdue
        }
        if calendar.isDate(item.dueDate, inSameDayAs: now) || remaining <= 12 * 3600 {
            return .today
        }
        if remaining <= 72 * 3600 {
            return .within3Days
        }
        return .later
    }

    public static func countdownText(for item: HomeworkItem, now: Date = Date()) -> String {
        if item.isCompleted {
            return "已完成"
        }
        let delta = item.dueDate.timeIntervalSince(now)
        if delta < 0 {
            let overdueSeconds = Int(abs(delta))
            let days = overdueSeconds / 86400
            let hours = (overdueSeconds % 86400) / 3600
            let minutes = (overdueSeconds % 3600) / 60
            if days > 0 {
                return hours > 0 ? "已逾期 \(days)天\(hours)时" : "已逾期 \(days)天"
            } else if hours > 0 {
                return minutes > 0 ? "已逾期 \(hours)时\(minutes)分" : "已逾期 \(hours)小时"
            } else if minutes > 0 {
                return "已逾期 \(minutes)分钟"
            } else {
                return "刚刚逾期"
            }
        }

        let remainingSeconds = Int(delta)
        let days = remainingSeconds / 86400
        let hours = (remainingSeconds % 86400) / 3600
        let minutes = (remainingSeconds % 3600) / 60

        if days >= 3 {
            return "剩 \(days)天"
        } else if days > 0 {
            return hours > 0 ? "剩 \(days)天\(hours)时" : "剩 \(days)天"
        } else if hours > 0 {
            return minutes > 0 ? "剩 \(hours)时\(minutes)分" : "剩 \(hours)小时"
        } else if minutes > 0 {
            return "剩 \(minutes)分钟"
        } else {
            return "即将截止"
        }
    }

    public static func dueDateFormatted(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "zh_CN")
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "今天 \(timeStr)"
        }
        if calendar.isDateInTomorrow(date) {
            return "明天 \(timeStr)"
        }
        if calendar.isDateInYesterday(date) {
            return "昨天 \(timeStr)"
        }

        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = sameYear ? "M月d日 HH:mm" : "yyyy年M月d日 HH:mm"
        return formatter.string(from: date)
    }

    public static func leadTimeLabel(minutes: Int) -> String {
        if minutes <= 0 { return "截止时刻" }
        if minutes < 60 { return "\(minutes) 分钟" }
        if minutes < 1440 {
            let hours = minutes / 60
            return "\(hours) 小时"
        }
        let days = minutes / 1440
        return "\(days) 天"
    }
}
