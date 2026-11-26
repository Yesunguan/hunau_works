import Foundation

public struct Course: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var colorHex: String
    public var iconName: String

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#4DA3FF",
        iconName: String = "book.closed.fill"
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
    }

    public static let paletteHexes: [String] = [
        "#4DA3FF", // 冰川蓝
        "#A78BFA", // 暮光紫
        "#34D399", // 薄荷绿
        "#FB923C", // 暖琥珀
        "#F472B6", // 樱花粉
        "#38BDF8", // 晴空青
        "#FBBF24", // 琉璃黄
        "#F87171"  // 珊瑚红
    ]

    public static let presetIcons: [String] = [
        "function",
        "chevron.left.forwardslash.chevron.right",
        "text.book.closed.fill",
        "graduationcap.fill",
        "flask.fill",
        "sparkles",
        "atom",
        "globe.asia.australia.fill",
        "pencil.and.outline",
        "chart.bar.xaxis"
    ]

    public static func defaultCourses() -> [Course] {
        [
            Course(name: "数学", colorHex: "#4DA3FF", iconName: "function"),
            Course(name: "计算机", colorHex: "#A78BFA", iconName: "chevron.left.forwardslash.chevron.right"),
            Course(name: "英语", colorHex: "#34D399", iconName: "text.book.closed.fill"),
            Course(name: "专业课", colorHex: "#FB923C", iconName: "graduationcap.fill"),
            Course(name: "实验实践", colorHex: "#F472B6", iconName: "flask.fill"),
            Course(name: "通识选修", colorHex: "#38BDF8", iconName: "sparkles")
        ]
    }
}

public struct Subtask: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool

    public init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

public enum HomeworkPriority: Int, Codable, CaseIterable, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2

    public static func < (lhs: HomeworkPriority, rhs: HomeworkPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }

    public var symbolName: String {
        switch self {
        case .low: return "arrow.down.circle"
        case .medium: return "minus.circle"
        case .high: return "exclamationmark.circle.fill"
        }
    }
}

public enum AttachmentKind: String, Codable, Hashable, Sendable {
    case url
    case localFile
}

public struct HomeworkAttachment: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var location: String
    public var kind: AttachmentKind

    public init(
        id: UUID = UUID(),
        title: String,
        location: String,
        kind: AttachmentKind
    ) {
        self.id = id
        self.title = title
        self.location = location
        self.kind = kind
    }

    public var symbolName: String {
        switch kind {
        case .url: return "link"
        case .localFile: return "doc.fill"
        }
    }
}

public struct HomeworkItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var courseId: UUID?
    public var dueDate: Date
    public var priority: HomeworkPriority
    public var notes: String
    public var subtasks: [Subtask]
    public var attachments: [HomeworkAttachment]
    public var isCompleted: Bool
    public var completedAt: Date?
    public var createdAt: Date
    /// `nil` means inherit `AppSettings.defaultReminderMinutes`; empty array means muted for this item.
    public var customReminderMinutes: [Int]?
    public var isSample: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        courseId: UUID? = nil,
        dueDate: Date,
        priority: HomeworkPriority = .medium,
        notes: String = "",
        subtasks: [Subtask] = [],
        attachments: [HomeworkAttachment] = [],
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        customReminderMinutes: [Int]? = nil,
        isSample: Bool = false
    ) {
        self.id = id
        self.title = title
        self.courseId = courseId
        self.dueDate = dueDate
        self.priority = priority
        self.notes = notes
        self.subtasks = subtasks
        self.attachments = attachments
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.customReminderMinutes = customReminderMinutes
        self.isSample = isSample
    }

    public var completedSubtasksCount: Int {
        subtasks.filter(\.isCompleted).count
    }

    public var subtaskProgress: Double {
        guard !subtasks.isEmpty else { return isCompleted ? 1.0 : 0.0 }
        return Double(completedSubtasksCount) / Double(subtasks.count)
    }
}

public enum GlassStylePreference: String, Codable, CaseIterable, Sendable {
    case regular
    case clear

    public var label: String {
        switch self {
        case .regular: return "标准液态"
        case .clear: return "清透折射"
        }
    }

    public var subtitle: String {
        switch self {
        case .regular: return "折射柔和、文字对比度更高"
        case .clear: return "极致通透、最大化透出壁纸"
        }
    }
}

public enum GlassTintPreset: String, Codable, CaseIterable, Sendable {
    case none
    case glacier
    case twilight
    case mint
    case amber
    case rose

    public var label: String {
        switch self {
        case .none: return "原生无染"
        case .glacier: return "冰川蓝"
        case .twilight: return "暮光紫"
        case .mint: return "薄荷青"
        case .amber: return "琥珀金"
        case .rose: return "樱花粉"
        }
    }

    public var previewHex: String {
        switch self {
        case .none: return "#E5E7EB"
        case .glacier: return "#60A5FA"
        case .twilight: return "#A78BFA"
        case .mint: return "#34D399"
        case .amber: return "#FBBF24"
        case .rose: return "#F472B6"
        }
    }
}

public enum AppearanceMode: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark

    public var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

public enum WindowPinMode: String, Codable, CaseIterable, Sendable {
    case desktopSticker
    case floating

    public var label: String {
        switch self {
        case .desktopSticker: return "桌面贴纸"
        case .floating: return "始终置顶"
        }
    }

    public var description: String {
        switch self {
        case .desktopSticker: return "贴在壁纸上方，不遮挡工作窗口"
        case .floating: return "悬浮于所有窗口最前方"
        }
    }
}

public enum WindowSizePreset: String, Codable, CaseIterable, Sendable {
    case compact
    case standard
    case wide

    public var label: String {
        switch self {
        case .compact: return "迷你"
        case .standard: return "标准"
        case .wide: return "宽屏"
        }
    }

    public var width: Double {
        switch self {
        case .compact: return 310
        case .standard: return 440
        case .wide: return 790
        }
    }

    public var height: Double {
        switch self {
        case .compact: return 390
        case .standard: return 580
        case .wide: return 580
        }
    }
}

public enum HomeworkSortOrder: String, Codable, CaseIterable, Sendable {
    case dueDate
    case priority

    public var label: String {
        switch self {
        case .dueDate: return "截止时间优先"
        case .priority: return "优先级优先"
        }
    }
}

public struct WindowFrameRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var windowFrame: WindowFrameRect?
    public var pinMode: WindowPinMode
    public var glassStyle: GlassStylePreference
    public var tintPreset: GlassTintPreset
    public var appearanceMode: AppearanceMode
    public var notificationsEnabled: Bool
    public var notificationsMuted: Bool
    public var defaultReminderMinutes: [Int]
    public var globalHotKeyEnabled: Bool
    public var launchAtLoginEnabled: Bool
    public var sortOrder: HomeworkSortOrder
    public var cornerRadius: Double

    public static let availableReminderOptions: [(minutes: Int, label: String)] = [
        (30, "提前 30 分钟"),
        (120, "提前 2 小时"),
        (360, "提前 6 小时"),
        (1440, "提前 1 天"),
        (4320, "提前 3 天")
    ]

    public init(
        windowFrame: WindowFrameRect? = nil,
        pinMode: WindowPinMode = .desktopSticker,
        glassStyle: GlassStylePreference = .clear,
        tintPreset: GlassTintPreset = .none,
        appearanceMode: AppearanceMode = .system,
        notificationsEnabled: Bool = true,
        notificationsMuted: Bool = false,
        defaultReminderMinutes: [Int] = [1440, 120],
        globalHotKeyEnabled: Bool = true,
        launchAtLoginEnabled: Bool = false,
        sortOrder: HomeworkSortOrder = .dueDate,
        cornerRadius: Double = 26
    ) {
        self.windowFrame = windowFrame
        self.pinMode = pinMode
        self.glassStyle = glassStyle
        self.tintPreset = tintPreset
        self.appearanceMode = appearanceMode
        self.notificationsEnabled = notificationsEnabled
        self.notificationsMuted = notificationsMuted
        self.defaultReminderMinutes = defaultReminderMinutes
        self.globalHotKeyEnabled = globalHotKeyEnabled
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.sortOrder = sortOrder
        self.cornerRadius = cornerRadius
    }
}

public struct HomeworkDatabase: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var courses: [Course]
    public var items: [HomeworkItem]
    public var settings: AppSettings

    public init(
        schemaVersion: Int = HomeworkDatabase.currentSchemaVersion,
        courses: [Course] = Course.defaultCourses(),
        items: [HomeworkItem] = [],
        settings: AppSettings = AppSettings()
    ) {
        self.schemaVersion = schemaVersion
        self.courses = courses
        self.items = items
        self.settings = settings
    }
}
