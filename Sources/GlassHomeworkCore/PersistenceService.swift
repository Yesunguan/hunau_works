import Foundation

public enum PersistenceError: Error, LocalizedError, Sendable {
    case invalidData(String)

    public var errorDescription: String? {
        switch self {
        case .invalidData(let reason):
            return "备份文件格式无效：\(reason)"
        }
    }
}

public enum SampleDataFactory {
    public static func makeInitialDatabase(now: Date = Date(), calendar: Calendar = .current) -> HomeworkDatabase {
        let courses = Course.defaultCourses()
        let mathId = courses[0].id
        let csId = courses[1].id
        let englishId = courses[2].id
        let majorId = courses[3].id

        let inFiveHours = now.addingTimeInterval(5 * 3600 + 20 * 60)
        let tomorrowNight = QuickDateOption.tomorrow.resolveDate(from: now, calendar: calendar)
        let inTwoDays = QuickDateOption.inTwoDays.resolveDate(from: now, calendar: calendar)
        let inSixDays = calendar.date(byAdding: .day, value: 6, to: tomorrowNight) ?? now.addingTimeInterval(6 * 86400)

        let items: [HomeworkItem] = [
            HomeworkItem(
                title: "高等数学：第 6 章定积分习题集",
                courseId: mathId,
                dueDate: inFiveHours,
                priority: .high,
                notes: "完成教材 P184 习题 1–12，拍照整理为单个 PDF 上传到学习平台。",
                subtasks: [
                    Subtask(title: "完成基础计算题 1–8", isCompleted: true),
                    Subtask(title: "整理证明题 9–12 步骤", isCompleted: false),
                    Subtask(title: "扫描合并为 PDF 并提交", isCompleted: false)
                ],
                attachments: [],
                isCompleted: false,
                createdAt: now.addingTimeInterval(-3600 * 18),
                isSample: true
            ),
            HomeworkItem(
                title: "数据结构实验报告：红黑树实现与性能对比",
                courseId: csId,
                dueDate: tomorrowNight,
                priority: .high,
                notes: "需附插入/删除基准测试图表，并在 README 说明编译方式。",
                subtasks: [
                    Subtask(title: "完成旋转与重着色单元测试", isCompleted: true),
                    Subtask(title: "跑 10 万次随机操作对比 AVL 树耗时", isCompleted: false),
                    Subtask(title: "导出实验报告 PDF 与源码压缩包", isCompleted: false)
                ],
                attachments: [
                    HomeworkAttachment(title: "GitHub 代码仓库", location: "https://github.com", kind: .url)
                ],
                isCompleted: false,
                createdAt: now.addingTimeInterval(-3600 * 30),
                isSample: true
            ),
            HomeworkItem(
                title: "大学英语：学术写作 Essay Outline 初稿",
                courseId: englishId,
                dueDate: inTwoDays,
                priority: .medium,
                notes: "字数 400 词左右，包含 Thesis Statement 与 3 个分论点及参考文献。",
                subtasks: [
                    Subtask(title: "确定主题与核心论点", isCompleted: true),
                    Subtask(title: "补充 3 篇 APA 格式参考文献", isCompleted: false)
                ],
                isCompleted: false,
                createdAt: now.addingTimeInterval(-3600 * 48),
                isSample: true
            ),
            HomeworkItem(
                title: "专业核心课：期末专题研究选题提案",
                courseId: majorId,
                dueDate: inSixDays,
                priority: .low,
                notes: "准备 5 分钟选题陈述 PPT，说明研究动机、数据来源与时间安排。",
                subtasks: [
                    Subtask(title: "与组员确认分工方案", isCompleted: false),
                    Subtask(title: "制作 6 页提案演示稿", isCompleted: false)
                ],
                isCompleted: false,
                createdAt: now.addingTimeInterval(-3600 * 6),
                isSample: true
            )
        ]

        return HomeworkDatabase(
            schemaVersion: HomeworkDatabase.currentSchemaVersion,
            courses: courses,
            items: items,
            settings: AppSettings()
        )
    }
}

public struct PersistenceService: Sendable {
    public let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
            self.fileURL = appSupport
                .appendingPathComponent("GlassHomework", isDirectory: true)
                .appendingPathComponent("store.json")
        }
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public func loadOrCreateDefault(now: Date = Date()) -> HomeworkDatabase {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                return try decode(data: data)
            } catch {
                // Keep corrupted file as backup before recreating defaults
                let backupURL = fileURL.deletingLastPathComponent()
                    .appendingPathComponent("store.corrupted.\(Int(now.timeIntervalSince1970)).json")
                try? FileManager.default.copyItem(at: fileURL, to: backupURL)
            }
        }
        let initial = SampleDataFactory.makeInitialDatabase(now: now)
        try? save(initial)
        return initial
    }

    public func save(_ database: HomeworkDatabase) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encode(database)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func encode(_ database: HomeworkDatabase) throws -> Data {
        try makeEncoder().encode(database)
    }

    public func decode(data: Data) throws -> HomeworkDatabase {
        let database = try makeDecoder().decode(HomeworkDatabase.self, from: data)
        guard database.schemaVersion >= 1 else {
            throw PersistenceError.invalidData("不支持的 schemaVersion (\(database.schemaVersion))")
        }
        return database
    }

    public func exportDatabase(_ database: HomeworkDatabase, to url: URL) throws {
        let data = try encode(database)
        try data.write(to: url, options: [.atomic])
    }

    public func importDatabase(from url: URL) throws -> HomeworkDatabase {
        let data = try Data(contentsOf: url)
        return try decode(data: data)
    }
}
