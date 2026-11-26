import GlassHomeworkCore
import SwiftUI

struct QuickAddBarView: View {
    @Bindable var store: HomeworkStore
    var isCompact: Bool = false

    @State private var title: String = ""
    @State private var selectedCourseId: UUID? = nil
    @State private var selectedQuickDate: QuickDateOption = .tomorrow
    @State private var useCustomDate: Bool = false
    @State private var customDate: Date = QuickDateOption.tomorrow.resolveDate()
    @State private var priority: HomeworkPriority = .medium
    @State private var showDatePopover: Bool = false

    private var effectiveCourseId: UUID? {
        selectedCourseId ?? store.selectedCourseId ?? store.courses.first?.id
    }

    private var effectiveDueDate: Date {
        useCustomDate ? customDate : selectedQuickDate.resolveDate()
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)

                TextField("添加新作业，回车立即记录...", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit(submit)

                if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: submit) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.glassProminent)
                    .clipShape(Circle())
                    .help("保存作业 (Return)")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassContentCard(cornerRadius: 13)

            // Quick metadata strip: course picker + quick date capsules + priority
            HStack(spacing: 6) {
                // Course selector menu
                Menu {
                    Button("不指定科目") { selectedCourseId = nil }
                    Divider()
                    ForEach(store.courses) { course in
                        Button {
                            selectedCourseId = course.id
                        } label: {
                            Label(course.name, systemImage: course.iconName)
                        }
                    }
                } label: {
                    let currentCourse = store.course(for: effectiveCourseId)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(currentCourse.map { Color(hex: $0.colorHex) } ?? .secondary)
                            .frame(width: 6, height: 6)
                        Text(currentCourse?.name ?? "科目")
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Quick date chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach([QuickDateOption.tonight, .tomorrow, .inTwoDays, .thisFriday]) { opt in
                            let active = !useCustomDate && selectedQuickDate == opt
                            Button {
                                useCustomDate = false
                                selectedQuickDate = opt
                            } label: {
                                Text(opt.label)
                                    .font(.system(size: 11, weight: active ? .semibold : .regular))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .glassEffect(
                                        active ? .regular.tint(.accentColor.opacity(0.45)).interactive() : .regular.interactive(),
                                        in: .capsule
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            showDatePopover.toggle()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                if useCustomDate {
                                    Text(UrgencyCalculator.dueDateFormatted(customDate))
                                        .font(.system(size: 10.5, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .glassEffect(
                                useCustomDate ? .regular.tint(.accentColor.opacity(0.45)).interactive() : .regular.interactive(),
                                in: .capsule
                            )
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showDatePopover, arrowEdge: .top) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("自定义截止时间")
                                    .font(.headline)
                                DatePicker(
                                    "",
                                    selection: $customDate,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .labelsHidden()
                                .datePickerStyle(.graphical)
                                .onChange(of: customDate) { _, _ in
                                    useCustomDate = true
                                }
                                HStack {
                                    Spacer()
                                    Button("确定") {
                                        useCustomDate = true
                                        showDatePopover = false
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding(14)
                            .frame(width: 280)
                        }
                    }
                }
                .scrollIndicators(.never)

                // Priority cycle pill
                Button {
                    let all = HomeworkPriority.allCases
                    let nextIdx = (all.firstIndex(of: priority)! + 1) % all.count
                    priority = all[nextIdx]
                } label: {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(GlassPalette.priorityColor(priority))
                            .frame(width: 6, height: 6)
                        Text(priority.label)
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                .help("点击切换优先级（低 / 中 / 高）")
            }
        }
    }

    private func submit() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            store.addHomework(
                title: trimmed,
                courseId: effectiveCourseId,
                dueDate: effectiveDueDate,
                priority: priority
            )
            store.showCompletedArchive = false
        }
        title = ""
        useCustomDate = false
    }
}

struct QuickCaptureHUDView: View {
    @Bindable var store: HomeworkStore
    let onDismiss: () -> Void

    @State private var title: String = ""
    @State private var selectedCourseId: UUID? = nil
    @State private var selectedOption: QuickDateOption = .tomorrow
    @State private var priority: HomeworkPriority = .medium
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "#4DA3FF"))

                TextField("快速记录一条作业（回车保存，Esc 取消）...", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
                    .focused($isTitleFocused)
                    .onSubmit(submit)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .keyboardShortcut(.escape, modifiers: [])
            }

            // Course selection row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.courses) { course in
                        let selected = (selectedCourseId ?? store.courses.first?.id) == course.id
                        Button {
                            selectedCourseId = course.id
                        } label: {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: course.colorHex))
                                    .frame(width: 7, height: 7)
                                Text(course.name)
                                    .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .glassEffect(
                                selected ? .regular.tint(Color(hex: course.colorHex).opacity(0.42)).interactive() : .regular.interactive(),
                                in: .capsule
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Quick date + priority + submit
            HStack(spacing: 6) {
                ForEach(QuickDateOption.allCases) { opt in
                    let active = selectedOption == opt
                    Button {
                        selectedOption = opt
                    } label: {
                        Text(opt.label)
                            .font(.system(size: 11.5, weight: active ? .semibold : .regular))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .glassEffect(
                                active ? .regular.tint(.accentColor.opacity(0.45)).interactive() : .regular.interactive(),
                                in: .capsule
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Picker("", selection: $priority) {
                    ForEach(HomeworkPriority.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 98)
                .padding(.trailing, 4)

                Button("保存", action: submit)
                    .buttonStyle(.glassProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            selectedCourseId = store.courses.first?.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isTitleFocused = true
            }
        }
    }

    private func submit() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addHomework(
            title: trimmed,
            courseId: selectedCourseId ?? store.courses.first?.id,
            dueDate: selectedOption.resolveDate(),
            priority: priority
        )
        title = ""
        onDismiss()
    }
}
