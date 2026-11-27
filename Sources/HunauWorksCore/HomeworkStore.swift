import Foundation
import Observation

@MainActor
@Observable
public final class HomeworkStore {
    public var courses: [Course]
    public var items: [HomeworkItem]
    public var settings: AppSettings

    // UI transient filter/selection state
    public var selectedCourseId: UUID? = nil
    public var searchText: String = ""
    public var showCompletedArchive: Bool = false
    public var selectedItemId: UUID? = nil
    public var statusBannerMessage: String? = nil

    public let persistence: PersistenceService
    public var onDataChanged: (@MainActor () -> Void)?
    public var onSettingsChanged: (@MainActor () -> Void)?

    public init(persistence: PersistenceService = PersistenceService(), now: Date = Date()) {
        self.persistence = persistence
        let db = persistence.loadOrCreateDefault(now: now)
        self.courses = db.courses
        self.items = db.items
        self.settings = db.settings
        self.selectedItemId = db.items.first(where: { !$0.isCompleted })?.id
    }

    // MARK: - Queries

    public var incompleteCount: Int {
        items.filter { !$0.isCompleted }.count
    }

    public var completedCount: Int {
        items.filter(\.isCompleted).count
    }

    public var hasSampleItems: Bool {
        items.contains(where: \.isSample)
    }

    public func overdueCount(now: Date = Date()) -> Int {
        items.filter { !$0.isCompleted && UrgencyCalculator.urgency(for: $0, now: now) == .overdue }.count
    }

    public func dueSoon24hCount(now: Date = Date()) -> Int {
        items.filter {
            !$0.isCompleted && UrgencyCalculator.urgency(for: $0, now: now) == .critical24h
        }.count
    }

    public func course(for id: UUID?) -> Course? {
        guard let id else { return nil }
        return courses.first { $0.id == id }
    }

    public func item(for id: UUID?) -> HomeworkItem? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }

    public func filteredActiveItems(now: Date = Date()) -> [HomeworkItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = items.filter { item in
            guard !item.isCompleted else { return false }
            if let selectedCourseId, item.courseId != selectedCourseId {
                return false
            }
            if !query.isEmpty {
                let courseName = course(for: item.courseId)?.name.lowercased() ?? ""
                let matchTitle = item.title.lowercased().contains(query)
                let matchNotes = item.notes.lowercased().contains(query)
                let matchCourse = courseName.contains(query)
                if !(matchTitle || matchNotes || matchCourse) {
                    return false
                }
            }
            return true
        }

        return filtered.sorted { lhs, rhs in
            switch settings.sortOrder {
            case .dueDate:
                if lhs.dueDate != rhs.dueDate {
                    return lhs.dueDate < rhs.dueDate
                }
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return lhs.createdAt < rhs.createdAt
            case .priority:
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                if lhs.dueDate != rhs.dueDate {
                    return lhs.dueDate < rhs.dueDate
                }
                return lhs.createdAt < rhs.createdAt
            }
        }
    }

    public func groupedActiveItems(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [(bucket: HomeworkBucket, items: [HomeworkItem])] {
        let active = filteredActiveItems(now: now)
        var groups: [HomeworkBucket: [HomeworkItem]] = [:]
        for item in active {
            let bucket = UrgencyCalculator.bucket(for: item, now: now, calendar: calendar)
            groups[bucket, default: []].append(item)
        }
        return HomeworkBucket.allCases.compactMap { bucket in
            guard let list = groups[bucket], !list.isEmpty else { return nil }
            return (bucket: bucket, items: list)
        }
    }

    public var filteredCompletedItems: [HomeworkItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return items
            .filter { item in
                guard item.isCompleted else { return false }
                if let selectedCourseId, item.courseId != selectedCourseId {
                    return false
                }
                if !query.isEmpty {
                    let courseName = course(for: item.courseId)?.name.lowercased() ?? ""
                    return item.title.lowercased().contains(query)
                        || item.notes.lowercased().contains(query)
                        || courseName.contains(query)
                }
                return true
            }
            .sorted { ($0.completedAt ?? $0.dueDate) > ($1.completedAt ?? $1.dueDate) }
    }

    // MARK: - Homework Mutations

    @discardableResult
    public func addHomework(
        title: String,
        courseId: UUID? = nil,
        dueDate: Date,
        priority: HomeworkPriority = .medium,
        notes: String = "",
        subtasks: [Subtask] = [],
        attachments: [HomeworkAttachment] = [],
        customReminderMinutes: [Int]? = nil,
        now: Date = Date()
    ) -> HomeworkItem? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let newItem = HomeworkItem(
            title: trimmed,
            courseId: courseId,
            dueDate: dueDate,
            priority: priority,
            notes: notes,
            subtasks: subtasks,
            attachments: attachments,
            isCompleted: false,
            completedAt: nil,
            createdAt: now,
            customReminderMinutes: customReminderMinutes,
            isSample: false
        )
        items.append(newItem)
        selectedItemId = newItem.id
        persistAndNotify()
        return newItem
    }

    public func updateHomework(_ updated: HomeworkItem) {
        guard let idx = items.firstIndex(where: { $0.id == updated.id }) else { return }
        var sanitized = updated
        sanitized.isSample = false
        items[idx] = sanitized
        persistAndNotify()
    }

    public func deleteHomework(id: UUID) {
        items.removeAll { $0.id == id }
        if selectedItemId == id {
            selectedItemId = filteredActiveItems().first?.id
        }
        persistAndNotify()
    }

    public func toggleCompletion(id: UUID, now: Date = Date()) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isCompleted.toggle()
        items[idx].completedAt = items[idx].isCompleted ? now : nil
        persistAndNotify()
    }

    public func postponeHomework(id: UUID, byDays days: Int = 1, calendar: Calendar = .current) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        if let newDate = calendar.date(byAdding: .day, value: days, to: items[idx].dueDate) {
            items[idx].dueDate = newDate
            persistAndNotify()
        }
    }

    public func toggleSubtask(homeworkId: UUID, subtaskId: UUID) {
        guard let itemIdx = items.firstIndex(where: { $0.id == homeworkId }),
              let subIdx = items[itemIdx].subtasks.firstIndex(where: { $0.id == subtaskId })
        else { return }
        items[itemIdx].subtasks[subIdx].isCompleted.toggle()
        persistAndNotify()
    }

    public func addSubtask(homeworkId: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let itemIdx = items.firstIndex(where: { $0.id == homeworkId })
        else { return }
        items[itemIdx].subtasks.append(Subtask(title: trimmed))
        items[itemIdx].isSample = false
        persistAndNotify()
    }

    public func deleteSubtask(homeworkId: UUID, subtaskId: UUID) {
        guard let itemIdx = items.firstIndex(where: { $0.id == homeworkId }) else { return }
        items[itemIdx].subtasks.removeAll { $0.id == subtaskId }
        persistAndNotify()
    }

    public func addAttachment(homeworkId: UUID, attachment: HomeworkAttachment) {
        guard let itemIdx = items.firstIndex(where: { $0.id == homeworkId }) else { return }
        items[itemIdx].attachments.append(attachment)
        items[itemIdx].isSample = false
        persistAndNotify()
    }

    public func deleteAttachment(homeworkId: UUID, attachmentId: UUID) {
        guard let itemIdx = items.firstIndex(where: { $0.id == homeworkId }) else { return }
        items[itemIdx].attachments.removeAll { $0.id == attachmentId }
        persistAndNotify()
    }

    public func clearSampleItems() {
        items.removeAll(where: \.isSample)
        if let selectedItemId, !items.contains(where: { $0.id == selectedItemId }) {
            self.selectedItemId = filteredActiveItems().first?.id
        }
        persistAndNotify()
    }

    public func clearCompletedItems() {
        items.removeAll(where: \.isCompleted)
        if let selectedItemId, !items.contains(where: { $0.id == selectedItemId }) {
            self.selectedItemId = filteredActiveItems().first?.id
        }
        persistAndNotify()
    }

    // MARK: - Course Mutations

    @discardableResult
    public func addCourse(name: String, colorHex: String, iconName: String = "book.closed.fill") -> Course? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let course = Course(name: trimmed, colorHex: colorHex, iconName: iconName)
        courses.append(course)
        persistAndNotify()
        return course
    }

    public func updateCourse(_ updated: Course) {
        guard let idx = courses.firstIndex(where: { $0.id == updated.id }) else { return }
        courses[idx] = updated
        persistAndNotify()
    }

    public func deleteCourse(id: UUID) {
        courses.removeAll { $0.id == id }
        for idx in items.indices where items[idx].courseId == id {
            items[idx].courseId = nil
        }
        if selectedCourseId == id {
            selectedCourseId = nil
        }
        persistAndNotify()
    }

    // MARK: - Settings & Backup

    public func updateSettings(_ mutate: (inout AppSettings) -> Void) {
        mutate(&settings)
        saveSilently()
        onSettingsChanged?()
        onDataChanged?()
    }

    public func makeDatabaseSnapshot() -> HomeworkDatabase {
        HomeworkDatabase(
            schemaVersion: HomeworkDatabase.currentSchemaVersion,
            courses: courses,
            items: items,
            settings: settings
        )
    }

    public func exportBackup(to url: URL) throws {
        try persistence.exportDatabase(makeDatabaseSnapshot(), to: url)
    }

    public func importBackup(from url: URL) throws {
        let imported = try persistence.importDatabase(from: url)
        self.courses = imported.courses.isEmpty ? Course.defaultCourses() : imported.courses
        self.items = imported.items
        self.settings = imported.settings
        self.selectedCourseId = nil
        self.selectedItemId = filteredActiveItems().first?.id
        saveSilently()
        onSettingsChanged?()
        onDataChanged?()
    }

    public func saveSilently() {
        do {
            try persistence.save(makeDatabaseSnapshot())
        } catch {
            statusBannerMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func persistAndNotify() {
        saveSilently()
        onDataChanged?()
    }
}
