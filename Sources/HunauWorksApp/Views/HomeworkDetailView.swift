import AppKit
import HunauWorksCore
import SwiftUI

struct HomeworkDetailView: View {
    @Bindable var store: HomeworkStore
    let homeworkId: UUID
    var showCloseButton: Bool = false
    var onClose: (() -> Void)? = nil

    @State private var newSubtaskTitle: String = ""
    @State private var showAddURLSheet: Bool = false
    @State private var urlTitle: String = ""
    @State private var urlString: String = ""

    private var item: HomeworkItem? {
        store.item(for: homeworkId)
    }

    var body: some View {
        if let item {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerRow(item: item)
                    titleAndMetaSection(item: item)
                    notesSection(item: item)
                    subtasksSection(item: item)
                    attachmentsSection(item: item)
                    reminderOverrideSection(item: item)
                    footerActions(item: item)
                }
                .padding(14)
            }
            .scrollIndicators(.never)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("选择一条作业查看或编辑详情")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func headerRow(item: HomeworkItem) -> some View {
        let urgency = UrgencyCalculator.urgency(for: item)
        let color = GlassPalette.urgencyColor(urgency)
        return HStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    store.toggleCompletion(id: item.id)
                }
            } label: {
                Label(
                    item.isCompleted ? "已完成（点此撤销）" : "标记完成",
                    systemImage: item.isCompleted ? "checkmark.circle.fill" : "circle"
                )
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .glassEffect(
                    item.isCompleted ? .regular.tint(.green.opacity(0.45)).interactive() : .regular.interactive(),
                    in: .capsule
                )
            }
            .buttonStyle(.plain)

            Text(UrgencyCalculator.countdownText(for: item))
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(color.opacity(0.16)))

            Spacer()

            if showCloseButton {
                Button {
                    onClose?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
            }
        }
    }

    private func titleAndMetaSection(item: HomeworkItem) -> some View {
        let titleBinding = Binding<String>(
            get: { store.item(for: item.id)?.title ?? "" },
            set: { newVal in
                guard var current = store.item(for: item.id) else { return }
                current.title = newVal
                store.updateHomework(current)
            }
        )
        let courseBinding = Binding<UUID?>(
            get: { store.item(for: item.id)?.courseId },
            set: { newVal in
                guard var current = store.item(for: item.id) else { return }
                current.courseId = newVal
                store.updateHomework(current)
            }
        )
        let dueBinding = Binding<Date>(
            get: { store.item(for: item.id)?.dueDate ?? Date() },
            set: { newVal in
                guard var current = store.item(for: item.id) else { return }
                current.dueDate = newVal
                store.updateHomework(current)
            }
        )
        let priorityBinding = Binding<HomeworkPriority>(
            get: { store.item(for: item.id)?.priority ?? .medium },
            set: { newVal in
                guard var current = store.item(for: item.id) else { return }
                current.priority = newVal
                store.updateHomework(current)
            }
        )

        return VStack(alignment: .leading, spacing: 11) {
            TextField("作业标题", text: titleBinding, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .bold))
                .lineLimit(1...3)

            Divider().opacity(0.25)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("课程 / 科目")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Picker("", selection: courseBinding) {
                        Text("未分类").tag(UUID?.none)
                        ForEach(store.courses) { c in
                            Text(c.name).tag(Optional(c.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 140)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("优先级")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Picker("", selection: priorityBinding) {
                        ForEach(HomeworkPriority.allCases, id: \.self) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("截止时间")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    DatePicker("", selection: dueBinding, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                    Button("+1 天") {
                        store.postponeHomework(id: item.id, byDays: 1)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.glass)
                }
            }
        }
        .padding(12)
        .glassContentCard(cornerRadius: 15)
    }

    private func notesSection(item: HomeworkItem) -> some View {
        let notesBinding = Binding<String>(
            get: { store.item(for: item.id)?.notes ?? "" },
            set: { newVal in
                guard var current = store.item(for: item.id) else { return }
                current.notes = newVal
                store.updateHomework(current)
            }
        )

        return VStack(alignment: .leading, spacing: 6) {
            Label("备注与作业要求", systemImage: "note.text")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: notesBinding)
                .font(.system(size: 12.5))
                .scrollContentBackground(.hidden)
                .scrollIndicators(.never)
                .frame(minHeight: 68, maxHeight: 130)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
        }
        .padding(12)
        .glassContentCard(cornerRadius: 15)
    }

    private func subtasksSection(item: HomeworkItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("子任务清单", systemImage: "checklist")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !item.subtasks.isEmpty {
                    Text("\(item.completedSubtasksCount)/\(item.subtasks.count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            if !item.subtasks.isEmpty {
                ProgressView(value: item.subtaskProgress)
                    .tint(Color(hex: "#34D399"))
                    .controlSize(.small)
            }

            ForEach(item.subtasks) { sub in
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            store.toggleSubtask(homeworkId: item.id, subtaskId: sub.id)
                        }
                    } label: {
                        Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(sub.isCompleted ? Color(hex: "#34D399") : .secondary)
                    }
                    .buttonStyle(.plain)

                    Text(sub.title)
                        .font(.system(size: 12.5))
                        .strikethrough(sub.isCompleted)
                        .foregroundStyle(sub.isCompleted ? .secondary : .primary)

                    Spacer()

                    Button {
                        store.deleteSubtask(homeworkId: item.id, subtaskId: sub.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 6) {
                TextField("添加拆分步骤，回车确认...", text: $newSubtaskTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .onSubmit {
                        addSubtask(for: item.id)
                    }

                Button {
                    addSubtask(for: item.id)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.glass)
                .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .glassContentCard(cornerRadius: 15)
    }

    private func attachmentsSection(item: HomeworkItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("提交链接与本地文件", systemImage: "paperclip")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("+ 网址") {
                    urlTitle = ""
                    urlString = "https://"
                    showAddURLSheet = true
                }
                .font(.system(size: 11))
                .buttonStyle(.glass)

                Button("+ 本地文件") {
                    pickLocalFile(for: item.id)
                }
                .font(.system(size: 11))
                .buttonStyle(.glass)
            }

            if item.attachments.isEmpty {
                Text("可绑定提交网页（如学习通/GitHub）或本地文档，点击直达。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(item.attachments) { att in
                    HStack(spacing: 8) {
                        Image(systemName: att.symbolName)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#4DA3FF"))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(att.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Text(att.location)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Button("打开") {
                            openAttachment(att)
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.glass)

                        Button {
                            store.deleteAttachment(homeworkId: item.id, attachmentId: att.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(12)
        .glassContentCard(cornerRadius: 15)
        .popover(isPresented: $showAddURLSheet) {
            VStack(alignment: .leading, spacing: 10) {
                Text("添加提交链接 / 网址")
                    .font(.headline)
                TextField("名称（如：课程平台提交入口）", text: $urlTitle)
                    .textFieldStyle(.roundedBorder)
                TextField("URL（如 https://...）", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("取消") { showAddURLSheet = false }
                    Button("添加") {
                        let cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleaned.isEmpty else { return }
                        let display = urlTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.addAttachment(
                            homeworkId: item.id,
                            attachment: HomeworkAttachment(
                                title: display.isEmpty ? cleaned : display,
                                location: cleaned,
                                kind: .url
                            )
                        )
                        showAddURLSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(14)
            .frame(width: 300)
        }
    }

    private func reminderOverrideSection(item: HomeworkItem) -> some View {
        let isMutedForItem = (item.customReminderMinutes == [])
        return HStack {
            Label("本条提醒", systemImage: isMutedForItem ? "bell.slash" : "bell.badge")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Toggle(
                "静音此作业",
                isOn: Binding(
                    get: { store.item(for: item.id)?.customReminderMinutes == [] },
                    set: { muted in
                        guard var current = store.item(for: item.id) else { return }
                        current.customReminderMinutes = muted ? [] : nil
                        store.updateHomework(current)
                    }
                )
            )
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(12)
        .glassContentCard(cornerRadius: 15)
    }

    private func footerActions(item: HomeworkItem) -> some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                store.deleteHomework(id: item.id)
                onClose?()
            } label: {
                Label("删除该作业", systemImage: "trash")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.glass)
        }
    }

    private func addSubtask(for id: UUID) {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addSubtask(homeworkId: id, title: trimmed)
        newSubtaskTitle = ""
    }

    private func pickLocalFile(for id: UUID) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "绑定附件"
        if panel.runModal() == .OK, let url = panel.url {
            store.addAttachment(
                homeworkId: id,
                attachment: HomeworkAttachment(
                    title: url.lastPathComponent,
                    location: url.path,
                    kind: .localFile
                )
            )
        }
    }

    private func openAttachment(_ att: HomeworkAttachment) {
        switch att.kind {
        case .url:
            var raw = att.location
            if !raw.contains("://") { raw = "https://" + raw }
            if let url = URL(string: raw) {
                NSWorkspace.shared.open(url)
            }
        case .localFile:
            let fileURL = URL(fileURLWithPath: att.location)
            NSWorkspace.shared.open(fileURL)
        }
    }
}
