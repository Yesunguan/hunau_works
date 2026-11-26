import AppKit
import GlassHomeworkCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsPopoverView: View {
    @Bindable var store: HomeworkStore
    let actions: AppActions

    enum Tab: String, CaseIterable {
        case appearance = "外观"
        case reminders = "提醒"
        case manage = "科目与备份"
    }

    @State private var activeTab: Tab = .appearance
    @State private var feedbackMessage: String? = nil
    @State private var newCourseName: String = ""
    @State private var newCourseHex: String = Course.paletteHexes[0]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("琉璃作业设置")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Picker("", selection: $activeTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
            }

            Divider().opacity(0.25)

            ScrollView {
                switch activeTab {
                case .appearance:
                    appearanceTab
                case .reminders:
                    remindersTab
                case .manage:
                    manageTab
                }
            }
            .scrollIndicators(.never)

            if let feedbackMessage {
                Text(feedbackMessage)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color(hex: "#34D399"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(hex: "#34D399").opacity(0.12))
                    )
            }
        }
        .padding(14)
        .frame(width: 365, height: 430)
    }

    // MARK: - Appearance Tab

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionBlock("窗口驻留层级") {
                Picker(
                    "",
                    selection: Binding(
                        get: { store.settings.pinMode },
                        set: { mode in store.updateSettings { $0.pinMode = mode } }
                    )
                ) {
                    ForEach(WindowPinMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(store.settings.pinMode.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            sectionBlock("液态玻璃通透风格") {
                Picker(
                    "",
                    selection: Binding(
                        get: { store.settings.glassStyle },
                        set: { style in store.updateSettings { $0.glassStyle = style } }
                    )
                ) {
                    ForEach(GlassStylePreference.allCases, id: \.self) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Text(store.settings.glassStyle.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            sectionBlock("色相微染") {
                HStack(spacing: 10) {
                    ForEach(GlassTintPreset.allCases, id: \.self) { preset in
                        let selected = store.settings.tintPreset == preset
                        Button {
                            store.updateSettings { $0.tintPreset = preset }
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: preset.previewHex).opacity(preset == .none ? 0.35 : 0.85))
                                        .frame(width: 24, height: 24)
                                    if preset == .none {
                                        Image(systemName: "slash.circle")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                    if selected {
                                        Circle()
                                            .strokeBorder(.primary, lineWidth: 2)
                                            .frame(width: 30, height: 30)
                                    }
                                }
                                Text(preset.label)
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(selected ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            sectionBlock("色彩外观与圆角") {
                Picker(
                    "",
                    selection: Binding(
                        get: { store.settings.appearanceMode },
                        set: { mode in store.updateSettings { $0.appearanceMode = mode } }
                    )
                ) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("窗口圆角：\(Int(store.settings.cornerRadius)) pt")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { store.settings.cornerRadius },
                            set: { radius in store.updateSettings { $0.cornerRadius = radius } }
                        ),
                        in: 14...34,
                        step: 2
                    )
                }
            }

            sectionBlock("一键切换预设尺寸（也可直接拖动窗口四角）") {
                HStack(spacing: 8) {
                    ForEach(WindowSizePreset.allCases, id: \.self) { preset in
                        Button("\(preset.label) (\(Int(preset.width))×\(Int(preset.height)))") {
                            actions.applySizePreset(preset)
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    // MARK: - Reminders Tab

    private var remindersTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionBlock("系统通知提醒") {
                Toggle(
                    "启用 macOS 截止前系统通知",
                    isOn: Binding(
                        get: { store.settings.notificationsEnabled },
                        set: { val in store.updateSettings { $0.notificationsEnabled = val } }
                    )
                )
                .font(.system(size: 12.5))

                Toggle(
                    "暂时静音全部提醒（免打扰）",
                    isOn: Binding(
                        get: { store.settings.notificationsMuted },
                        set: { val in store.updateSettings { $0.notificationsMuted = val } }
                    )
                )
                .font(.system(size: 12.5))
                .disabled(!store.settings.notificationsEnabled)

                HStack {
                    Text("系统权限状态：\(actions.notificationStatusText())")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("发送测试通知") {
                        actions.sendTestNotification { msg in
                            feedbackMessage = msg
                        }
                    }
                    .font(.system(size: 11.5))
                    .buttonStyle(.bordered)
                }
            }

            sectionBlock("默认提前提醒节点（可多选）") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 102), spacing: 6)], spacing: 6) {
                    ForEach(AppSettings.availableReminderOptions, id: \.minutes) { option in
                        let active = store.settings.defaultReminderMinutes.contains(option.minutes)
                        Button {
                            store.updateSettings { s in
                                if let idx = s.defaultReminderMinutes.firstIndex(of: option.minutes) {
                                    s.defaultReminderMinutes.remove(at: idx)
                                } else {
                                    s.defaultReminderMinutes.append(option.minutes)
                                    s.defaultReminderMinutes.sort(by: >)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: active ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 11))
                                Text(option.label)
                                    .font(.system(size: 11.5, weight: active ? .semibold : .regular))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(active ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            sectionBlock("快捷键与开机启动") {
                Toggle(
                    "全局快记快捷键（⌥ + Shift + H）",
                    isOn: Binding(
                        get: { store.settings.globalHotKeyEnabled },
                        set: { val in store.updateSettings { $0.globalHotKeyEnabled = val } }
                    )
                )
                .font(.system(size: 12.5))

                Toggle(
                    "开机自动启动琉璃作业",
                    isOn: Binding(
                        get: { store.settings.launchAtLoginEnabled },
                        set: { enabled in actions.toggleLaunchAtLogin(enabled) }
                    )
                )
                .font(.system(size: 12.5))
            }
        }
    }

    // MARK: - Manage Tab

    private var manageTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionBlock("自定义课程 / 科目标签") {
                VStack(spacing: 6) {
                    ForEach(store.courses) { course in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: course.colorHex))
                                .frame(width: 10, height: 10)
                            Text(course.name)
                                .font(.system(size: 12.5))
                            Spacer()
                            Button {
                                store.deleteCourse(id: course.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(store.courses.count <= 1)
                        }
                    }
                }

                Divider().opacity(0.2)

                HStack(spacing: 6) {
                    TextField("新科目名称...", text: $newCourseName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    Button("添加") {
                        let name = newCourseName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        store.addCourse(name: name, colorHex: newCourseHex)
                        newCourseName = ""
                        feedbackMessage = "已添加科目「\(name)」"
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                HStack(spacing: 6) {
                    ForEach(Course.paletteHexes, id: \.self) { hex in
                        Button {
                            newCourseHex = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 18, height: 18)
                                .overlay {
                                    if newCourseHex == hex {
                                        Circle().strokeBorder(.primary, lineWidth: 1.8)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            sectionBlock("数据备份与清理") {
                HStack(spacing: 8) {
                    Button("导出 JSON 备份") { exportBackup() }
                        .buttonStyle(.bordered)
                    Button("导入 JSON 恢复") { importBackup() }
                        .buttonStyle(.bordered)
                }
                .font(.system(size: 12))

                HStack(spacing: 8) {
                    if store.hasSampleItems {
                        Button("清空示例作业") {
                            store.clearSampleItems()
                            feedbackMessage = "已清空示例作业"
                        }
                        .buttonStyle(.bordered)
                    }
                    if store.completedCount > 0 {
                        Button("清空已完成归档", role: .destructive) {
                            store.clearCompletedItems()
                            feedbackMessage = "已清空已完成归档"
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .font(.system(size: 12))

                Text("数据路径：~/Library/Application Support/GlassHomework/store.json")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
    }

    private func sectionBlock<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "GlassHomework-Backup.json"
        panel.prompt = "导出备份"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try store.exportBackup(to: url)
                feedbackMessage = "备份已导出至 \(url.lastPathComponent)"
            } catch {
                feedbackMessage = "导出失败：\(error.localizedDescription)"
            }
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.prompt = "导入恢复"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try store.importBackup(from: url)
                feedbackMessage = "已成功从 \(url.lastPathComponent) 恢复数据"
            } catch {
                feedbackMessage = "导入失败：\(error.localizedDescription)"
            }
        }
    }
}
