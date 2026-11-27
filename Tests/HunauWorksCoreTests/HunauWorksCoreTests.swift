import Foundation
import HunauWorksCore

struct TestFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String = "", line: Int = #line) throws {
    if actual != expected {
        throw TestFailure(message: "Line \(line) \(label): expected \(expected), got \(actual)")
    }
}

func assertTrue(_ condition: Bool, _ message: String, line: Int = #line) throws {
    if !condition {
        throw TestFailure(message: "Line \(line): \(message)")
    }
}

func unwrap<T>(_ value: T?, _ message: String = "unexpected nil", line: Int = #line) throws -> T {
    guard let value else {
        throw TestFailure(message: "Line \(line): \(message)")
    }
    return value
}

func makeTempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("HunauWorksTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

@MainActor
@main
enum HunauWorksTestRunner {
    static func main() {
        var passed = 0
        var failed = 0

        func run(_ name: String, _ body: () throws -> Void) {
            do {
                try body()
                passed += 1
                print("  [PASS] \(name)")
            } catch {
                failed += 1
                print("  [FAIL] \(name) -> \(error)")
            }
        }

        print("Running HunauWorksCore automated test suite...")

        run("紧急度分级与中文倒计时格式") {
            let now = Date(timeIntervalSince1970: 1_800_000_000)

            let overdue = HomeworkItem(title: "已逾期作业", dueDate: now.addingTimeInterval(-3 * 3600 - 15 * 60))
            try assertEqual(UrgencyCalculator.urgency(for: overdue, now: now), .overdue)
            try assertEqual(UrgencyCalculator.countdownText(for: overdue, now: now), "已逾期 3时15分")

            let critical = HomeworkItem(title: "临期作业", dueDate: now.addingTimeInterval(5 * 3600 + 25 * 60))
            try assertEqual(UrgencyCalculator.urgency(for: critical, now: now), .critical24h)
            try assertEqual(UrgencyCalculator.countdownText(for: critical, now: now), "剩 5时25分")

            let soon = HomeworkItem(title: "两天后作业", dueDate: now.addingTimeInterval(50 * 3600))
            try assertEqual(UrgencyCalculator.urgency(for: soon, now: now), .soon3Days)
            try assertEqual(UrgencyCalculator.countdownText(for: soon, now: now), "剩 2天2时")

            let comfortable = HomeworkItem(title: "下周作业", dueDate: now.addingTimeInterval(5 * 86400))
            try assertEqual(UrgencyCalculator.urgency(for: comfortable, now: now), .comfortable)
            try assertEqual(UrgencyCalculator.countdownText(for: comfortable, now: now), "剩 5天")

            let done = HomeworkItem(title: "已完成", dueDate: now.addingTimeInterval(-1000), isCompleted: true)
            try assertEqual(UrgencyCalculator.urgency(for: done, now: now), .completed)
            try assertEqual(UrgencyCalculator.countdownText(for: done, now: now), "已完成")
        }

        run("快捷截止日期计算（今晚/明天/后天/本周五/一周后）") {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try unwrap(TimeZone(secondsFromGMT: 8 * 3600))
            let wednesday = try unwrap(
                calendar.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 14, minute: 0))
            )

            let tonight = QuickDateOption.tonight.resolveDate(from: wednesday, calendar: calendar)
            try assertEqual(calendar.component(.day, from: tonight), 25)
            try assertEqual(calendar.component(.hour, from: tonight), 23)
            try assertEqual(calendar.component(.minute, from: tonight), 59)

            let tomorrow = QuickDateOption.tomorrow.resolveDate(from: wednesday, calendar: calendar)
            try assertEqual(calendar.component(.day, from: tomorrow), 26)

            let inTwo = QuickDateOption.inTwoDays.resolveDate(from: wednesday, calendar: calendar)
            try assertEqual(calendar.component(.day, from: inTwo), 27)

            let friday = QuickDateOption.thisFriday.resolveDate(from: wednesday, calendar: calendar)
            try assertEqual(calendar.component(.day, from: friday), 27)
            try assertEqual(calendar.component(.weekday, from: friday), 6)

            let nextWeek = QuickDateOption.nextWeek.resolveDate(from: wednesday, calendar: calendar)
            try assertEqual(calendar.component(.month, from: nextWeek), 12)
            try assertEqual(calendar.component(.day, from: nextWeek), 2)
        }

        run("作业 CRUD、子任务进度、附件、完成撤销、删课解绑与磁盘持久化") {
            let tempDir = try makeTempDir()
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let storeURL = tempDir.appendingPathComponent("store.json")
            let persistence = PersistenceService(fileURL: storeURL)
            let now = Date(timeIntervalSince1970: 1_800_000_000)

            let store = HomeworkStore(persistence: persistence, now: now)
            try assertTrue(store.hasSampleItems, "initial DB should have sample items")
            try assertEqual(store.incompleteCount, 4)

            store.clearSampleItems()
            try assertTrue(!store.hasSampleItems, "samples should be cleared")
            try assertEqual(store.incompleteCount, 0)

            let course = try unwrap(store.courses.first)
            let added = try unwrap(
                store.addHomework(
                    title: "编译原理词法分析器",
                    courseId: course.id,
                    dueDate: now.addingTimeInterval(10 * 3600),
                    priority: .high,
                    notes: "支持注释与字符串转义",
                    now: now
                )
            )
            store.addSubtask(homeworkId: added.id, title: "实现状态机")
            store.addSubtask(homeworkId: added.id, title: "补充测试用例")
            let fetched1 = try unwrap(store.item(for: added.id))
            try assertEqual(fetched1.subtasks.count, 2)
            try assertTrue(abs(fetched1.subtaskProgress - 0.0) < 0.001, "expected 0% progress")

            store.toggleSubtask(homeworkId: added.id, subtaskId: fetched1.subtasks[0].id)
            let fetched2 = try unwrap(store.item(for: added.id))
            try assertTrue(abs(fetched2.subtaskProgress - 0.5) < 0.001, "expected 50% progress")

            store.addAttachment(
                homeworkId: added.id,
                attachment: HomeworkAttachment(title: "提交入口", location: "https://example.edu/submit", kind: .url)
            )
            try assertEqual(store.item(for: added.id)?.attachments.count, 1)

            // Postpone by 1 day
            let beforeDue = try unwrap(store.item(for: added.id)).dueDate
            store.postponeHomework(id: added.id, byDays: 1)
            let afterDue = try unwrap(store.item(for: added.id)).dueDate
            try assertTrue(afterDue > beforeDue, "postponed dueDate should advance")

            // Complete & undo
            store.toggleCompletion(id: added.id, now: now)
            try assertEqual(store.incompleteCount, 0)
            try assertEqual(store.completedCount, 1)

            store.toggleCompletion(id: added.id, now: now)
            try assertEqual(store.incompleteCount, 1)
            try assertEqual(store.completedCount, 0)

            // Delete course safely detaches courseId
            store.deleteCourse(id: course.id)
            try assertEqual(store.item(for: added.id)?.courseId, nil)

            // Reload verifies atomic disk persistence
            let reloaded = HomeworkStore(persistence: persistence, now: now)
            try assertEqual(reloaded.items.count, 1)
            try assertEqual(reloaded.items.first?.title, "编译原理词法分析器")
            try assertEqual(reloaded.items.first?.subtasks.count, 2)
        }

        run("JSON 备份导出与导入恢复往返一致性") {
            let tempDir = try makeTempDir()
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let storeURL = tempDir.appendingPathComponent("store.json")
            let backupURL = tempDir.appendingPathComponent("backup.json")
            let persistence = PersistenceService(fileURL: storeURL)
            let now = Date(timeIntervalSince1970: 1_800_000_000)

            let store = HomeworkStore(persistence: persistence, now: now)
            store.updateSettings {
                $0.glassStyle = .clear
                $0.tintPreset = .glacier
                $0.pinMode = .floating
            }
            try store.exportBackup(to: backupURL)

            store.clearSampleItems()
            store.updateSettings { $0.glassStyle = .regular }
            try assertTrue(store.items.isEmpty, "items should be empty before import")

            try store.importBackup(from: backupURL)
            try assertEqual(store.items.count, 4)
            try assertEqual(store.settings.glassStyle, .clear)
            try assertEqual(store.settings.tintPreset, .glacier)
            try assertEqual(store.settings.pinMode, .floating)
        }

        run("提醒计划器：静音、单条免打扰、已完成过滤与上限控制") {
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let courses = [Course(name: "数学")]
            let item1 = HomeworkItem(
                title: "高数作业",
                courseId: courses[0].id,
                dueDate: now.addingTimeInterval(48 * 3600)
            )
            let itemMuted = HomeworkItem(
                title: "免打扰作业",
                courseId: courses[0].id,
                dueDate: now.addingTimeInterval(48 * 3600),
                customReminderMinutes: []
            )
            let itemCompleted = HomeworkItem(
                title: "已交作业",
                dueDate: now.addingTimeInterval(48 * 3600),
                isCompleted: true
            )

            let settings = AppSettings(
                notificationsEnabled: true,
                notificationsMuted: false,
                defaultReminderMinutes: [1440, 120]
            )

            let planned = ReminderScheduler.plannedReminders(
                items: [item1, itemMuted, itemCompleted],
                courses: courses,
                settings: settings,
                now: now
            )
            try assertEqual(planned.count, 2)
            try assertEqual(planned[0].leadMinutes, 1440)
            try assertEqual(planned[1].leadMinutes, 120)
            try assertTrue(planned[0].title.contains("[数学]"), "title should include course name")

            var mutedSettings = settings
            mutedSettings.notificationsMuted = true
            let mutedPlanned = ReminderScheduler.plannedReminders(
                items: [item1],
                courses: courses,
                settings: mutedSettings,
                now: now
            )
            try assertTrue(mutedPlanned.isEmpty, "muted settings should schedule no reminders")
        }

        run("排序与筛选（按科目、关键词、优先级排序）") {
            let tempDir = try makeTempDir()
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let store = HomeworkStore(persistence: PersistenceService(fileURL: tempDir.appendingPathComponent("s.json")))
            store.clearSampleItems()
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let c1 = store.courses[0]
            let c2 = store.courses[1]

            store.addHomework(title: "低优近截止", courseId: c1.id, dueDate: now.addingTimeInterval(3600), priority: .low, now: now)
            store.addHomework(title: "高优远截止", courseId: c2.id, dueDate: now.addingTimeInterval(86400 * 5), priority: .high, now: now)

            // Default dueDate sort
            try assertEqual(store.filteredActiveItems(now: now).first?.title, "低优近截止")

            // Priority sort
            store.updateSettings { $0.sortOrder = .priority }
            try assertEqual(store.filteredActiveItems(now: now).first?.title, "高优远截止")

            // Course filter
            store.selectedCourseId = c1.id
            try assertEqual(store.filteredActiveItems(now: now).count, 1)
            try assertEqual(store.filteredActiveItems(now: now).first?.title, "低优近截止")

            // Search filter
            store.selectedCourseId = nil
            store.searchText = "高优"
            try assertEqual(store.filteredActiveItems(now: now).count, 1)
            try assertEqual(store.filteredActiveItems(now: now).first?.title, "高优远截止")
        }

        print("Test Summary: \(passed) passed, \(failed) failed.")
        if failed > 0 {
            exit(1)
        }
    }
}
