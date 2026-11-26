import GlassHomeworkCore
import SwiftUI

enum ResponsiveLayoutTier {
    case compact   // < 350pt
    case standard  // 350pt..<660pt
    case wide      // >= 660pt

    init(width: CGFloat) {
        if width < 350 {
            self = .compact
        } else if width < 660 {
            self = .standard
        } else {
            self = .wide
        }
    }
}

struct MainGlassRootView: View {
    @Bindable var store: HomeworkStore
    let actions: AppActions

    @Namespace private var glassNamespace
    @State private var showSettingsPopover: Bool = false
    @State private var sheetDetailItemId: UUID? = nil
    @State private var showSearchBar: Bool = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let now = timeline.date
            GeometryReader { geo in
                let tier = ResponsiveLayoutTier(width: geo.size.width)
                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 0) {
                        headerBar(tier: tier, now: now)
                            .padding(.horizontal, tier == .compact ? 11 : 15)
                            .padding(.top, tier == .compact ? 11 : 14)
                            .padding(.bottom, tier == .compact ? 7 : 9)

                        if tier != .compact {
                            courseFilterStrip(now: now)
                                .padding(.horizontal, 15)
                                .padding(.bottom, 8)
                        }

                        if showSearchBar && tier != .compact {
                            searchBarView
                                .padding(.horizontal, 15)
                                .padding(.bottom, 8)
                        }

                        if store.hasSampleItems && !store.showCompletedArchive && tier != .compact {
                            sampleNoticeBanner
                                .padding(.horizontal, 15)
                                .padding(.bottom, 8)
                        }

                        // Body switches smoothly across Compact / Standard / Wide
                        switch tier {
                        case .compact:
                            compactBody(now: now)
                        case .standard:
                            standardBody(now: now)
                        case .wide:
                            wideSplitBody(now: now, totalWidth: geo.size.width)
                        }
                    }

                    // Subtle visual resize grip hint in bottom-right corner
                    SubtleResizeGrip()
                        .padding(6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .sheet(
                    isPresented: Binding(
                        get: { sheetDetailItemId != nil && tier != .wide },
                        set: { presented in
                            if !presented { sheetDetailItemId = nil }
                        }
                    )
                ) {
                    if let id = sheetDetailItemId {
                        HomeworkDetailView(
                            store: store,
                            homeworkId: id,
                            showCloseButton: true
                        ) {
                            sheetDetailItemId = nil
                        }
                        .frame(minWidth: 360, idealWidth: 420, minHeight: 460, idealHeight: 540)
                    }
                }
            }
        }
    }

    // MARK: - Top Liquid Glass Header Bar

    private func headerBar(tier: ResponsiveLayoutTier, now: Date) -> some View {
        let overdue = store.overdueCount(now: now)
        let soon24h = store.dueSoon24hCount(now: now)
        let incomplete = store.incompleteCount

        return HStack(spacing: 8) {
            // App identity & live count
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#60A5FA"), Color(hex: "#A78BFA")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: tier == .compact ? 22 : 26, height: tier == .compact ? 22 : 26)
                    Image(systemName: "checklist")
                        .font(.system(size: tier == .compact ? 11 : 12.5, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text("琉璃作业")
                            .font(.system(size: tier == .compact ? 13 : 14.5, weight: .bold))
                        Text("\(incomplete)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(overdue > 0 ? Color(hex: "#FF4D5E") : .primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule().fill(
                                    (overdue > 0 ? Color(hex: "#FF4D5E") : Color.primary).opacity(0.14)
                                )
                            )
                    }

                    if tier != .compact {
                        HStack(spacing: 6) {
                            if overdue > 0 {
                                Text("逾期 \(overdue)")
                                    .foregroundStyle(Color(hex: "#FF4D5E"))
                                    .fontWeight(.semibold)
                            }
                            if soon24h > 0 {
                                Text("24h内 \(soon24h)")
                                    .foregroundStyle(Color(hex: "#FF9438"))
                                    .fontWeight(.semibold)
                            }
                            if overdue == 0 && soon24h == 0 {
                                Text(incomplete == 0 ? "全部搞定，轻松一刻" : "节奏良好，稳步推进")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.system(size: 10.5))
                    }
                }
            }

            Spacer(minLength: 4)

            // Native macOS 26 GlassEffectContainer toolbar cluster
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 5) {
                    if tier != .compact {
                        // Active vs Completed archive toggle
                        Button {
                            withAnimation(.bouncy(duration: 0.3)) {
                                store.showCompletedArchive.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: store.showCompletedArchive ? "tray.full.fill" : "checkmark.circle")
                                    .font(.system(size: 11))
                                Text(store.showCompletedArchive ? "归档" : "已交 \(store.completedCount)")
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .fixedSize()
                            .glassEffect(
                                store.showCompletedArchive
                                    ? .regular.tint(Color(hex: "#34D399").opacity(0.45)).interactive()
                                    : .regular.interactive(),
                                in: .capsule
                            )
                        }
                        .buttonStyle(.plain)
                        .glassEffectID("archiveToggle", in: glassNamespace)
                        .help("切换查看未完成待办 / 已完成归档")

                        // Search toggle
                        Button {
                            withAnimation(.bouncy(duration: 0.28)) {
                                showSearchBar.toggle()
                                if !showSearchBar { store.searchText = "" }
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11.5, weight: .semibold))
                                .frame(width: 26, height: 26)
                                .glassEffect(
                                    showSearchBar ? .regular.tint(.accentColor.opacity(0.45)).interactive() : .regular.interactive(),
                                    in: .circle
                                )
                        }
                        .buttonStyle(.plain)
                        .glassEffectID("searchBtn", in: glassNamespace)
                        .help("搜索作业")
                    }

                    // Pin mode toggle: Desktop Sticker <-> Always On Top
                    let isFloating = store.settings.pinMode == .floating
                    Button {
                        withAnimation(.bouncy(duration: 0.3)) {
                            store.updateSettings {
                                $0.pinMode = isFloating ? .desktopSticker : .floating
                            }
                        }
                    } label: {
                        Image(systemName: isFloating ? "pin.fill" : "pin")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(isFloating ? Color(hex: "#FF9438") : .primary)
                            .frame(width: 26, height: 26)
                            .glassEffect(
                                isFloating ? .regular.tint(Color(hex: "#FF9438").opacity(0.42)).interactive() : .regular.interactive(),
                                in: .circle
                            )
                    }
                    .buttonStyle(.plain)
                    .glassEffectID("pinBtn", in: glassNamespace)
                    .help(isFloating ? "当前：始终置顶（点击切回桌面贴纸）" : "当前：桌面贴纸（点击切换始终置顶）")

                    // Quick size preset menu
                    if tier != .compact {
                        Menu {
                            ForEach(WindowSizePreset.allCases, id: \.self) { preset in
                                Button("\(preset.label)尺寸（\(Int(preset.width))×\(Int(preset.height))）") {
                                    actions.applySizePreset(preset)
                                }
                            }
                            Divider()
                            ForEach(HomeworkSortOrder.allCases, id: \.self) { order in
                                Button {
                                    store.updateSettings { $0.sortOrder = order }
                                } label: {
                                    if store.settings.sortOrder == order {
                                        Label(order.label, systemImage: "checkmark")
                                    } else {
                                        Text(order.label)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10.5, weight: .semibold))
                                .frame(width: 26, height: 26)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .frame(width: 26, height: 26)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .glassEffectID("sizeBtn", in: glassNamespace)
                        .help("快速切换尺寸预设与排序方式")
                    } else {
                        // Compact quick capture shortcut
                        Button {
                            actions.openQuickCapture()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 11.5, weight: .bold))
                                .frame(width: 26, height: 26)
                                .glassEffect(.regular.tint(.accentColor.opacity(0.45)).interactive(), in: .circle)
                        }
                        .buttonStyle(.plain)
                        .glassEffectID("quickPlusBtn", in: glassNamespace)
                        .help("快速新增作业 (⌥⇧H)")
                    }

                    // Settings popover button
                    Button {
                        showSettingsPopover.toggle()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11.5, weight: .semibold))
                            .frame(width: 26, height: 26)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .glassEffectID("settingsBtn", in: glassNamespace)
                    .help("外观材质、提醒与科目设置")
                    .popover(isPresented: $showSettingsPopover, arrowEdge: .bottom) {
                        SettingsPopoverView(store: store, actions: actions)
                    }
                }
            }
        }
    }

    // MARK: - Course Filter Strip

    private func courseFilterStrip(now: Date) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 6) {
                    filterPill(
                        title: "全部",
                        color: .accentColor,
                        count: store.showCompletedArchive ? store.completedCount : store.incompleteCount,
                        isSelected: store.selectedCourseId == nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.selectedCourseId = nil
                        }
                    }

                    ForEach(store.courses) { course in
                        let count = store.items.filter {
                            $0.courseId == course.id && $0.isCompleted == store.showCompletedArchive
                        }.count
                        filterPill(
                            title: course.name,
                            color: Color(hex: course.colorHex),
                            count: count,
                            isSelected: store.selectedCourseId == course.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.selectedCourseId = (store.selectedCourseId == course.id) ? nil : course.id
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 18)
            }
        }
        .scrollIndicators(.never)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: .black, location: 0.90),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private func filterPill(
        title: String,
        color: Color,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 6.5, height: 6.5)
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .glassEffect(
                isSelected ? .regular.tint(color.opacity(0.40)).interactive() : .regular.interactive(),
                in: .capsule
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search & Sample Banner

    private var searchBarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("搜索作业标题、备注或科目...", text: $store.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassContentCard(cornerRadius: 11)
    }

    private var sampleNoticeBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: "#60A5FA"))
            Text("示例作业预览 · 点击可编辑或一键清空")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button("清空示例") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    store.clearSampleItems()
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .fixedSize()
            .buttonStyle(.glass)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassContentCard(cornerRadius: 11)
    }

    // MARK: - 3 Responsive Layout Bodies

    private func compactBody(now: Date) -> some View {
        VStack(spacing: 0) {
            homeworkScrollList(now: now, isCompact: true, opensSheetOnTap: true)
                .padding(.horizontal, 10)

            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.showCompletedArchive.toggle()
                    }
                } label: {
                    Text(store.showCompletedArchive ? "返回待办 (\(store.incompleteCount))" : "已完成 (\(store.completedCount))")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    actions.applySizePreset(.standard)
                } label: {
                    Label("展开标准视图", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private func standardBody(now: Date) -> some View {
        VStack(spacing: 0) {
            homeworkScrollList(now: now, isCompact: false, opensSheetOnTap: true)
                .padding(.horizontal, 14)

            if !store.showCompletedArchive {
                QuickAddBarView(store: store, isCompact: false)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 13)
            } else {
                completedArchiveFooter
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
    }

    private func wideSplitBody(now: Date, totalWidth: CGFloat) -> some View {
        let leftWidth = min(max(345, totalWidth * 0.45), 440)
        let activeDetailId = store.selectedItemId
            ?? (store.showCompletedArchive ? store.filteredCompletedItems.first?.id : store.filteredActiveItems(now: now).first?.id)

        return HStack(spacing: 0) {
            // Left list column
            VStack(spacing: 0) {
                homeworkScrollList(now: now, isCompact: false, opensSheetOnTap: false)
                    .padding(.horizontal, 14)

                if !store.showCompletedArchive {
                    QuickAddBarView(store: store, isCompact: false)
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .padding(.bottom, 13)
                } else {
                    completedArchiveFooter
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
            }
            .frame(width: leftWidth)

            // Specular translucent divider
            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 0.8)
                .padding(.vertical, 8)

            // Right detail inspector pane
            if let detailId = activeDetailId {
                HomeworkDetailView(store: store, homeworkId: detailId, showCloseButton: false)
                    .id(detailId)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text("在左侧选择或添加作业，这里将展开完整详情")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Homework Scroll List

    private func homeworkScrollList(now: Date, isCompact: Bool, opensSheetOnTap: Bool) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
                if store.showCompletedArchive {
                    let completed = store.filteredCompletedItems
                    if completed.isEmpty {
                        emptyStateView(
                            icon: "tray",
                            title: "暂无已完成归档",
                            subtitle: "完成作业勾选后会自动收录到这里，随时可撤销。"
                        )
                    } else {
                        ForEach(completed) { item in
                            row(for: item, now: now, isCompact: isCompact, opensSheetOnTap: opensSheetOnTap)
                        }
                    }
                } else {
                    let grouped = store.groupedActiveItems(now: now)
                    if grouped.isEmpty {
                        emptyStateView(
                            icon: "checkmark.seal.fill",
                            title: "所有作业已完成！",
                            subtitle: isCompact ? "点右上角 + 记一条新作业" : "在下方输入框添加新作业，或按 ⌥⇧H 随时快记。"
                        )
                    } else {
                        ForEach(grouped, id: \.bucket) { group in
                            HStack(spacing: 5) {
                                Image(systemName: group.bucket.symbolName)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(GlassPalette.bucketColor(group.bucket))
                                Text(group.bucket.title)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                Text("\(group.items.count)")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.tertiary)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, group.bucket == grouped.first?.bucket ? 2 : 6)

                            ForEach(group.items) { item in
                                row(for: item, now: now, isCompact: isCompact, opensSheetOnTap: opensSheetOnTap)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 10)
        }
        .scrollIndicators(.never)
    }

    private func row(
        for item: HomeworkItem,
        now: Date,
        isCompact: Bool,
        opensSheetOnTap: Bool
    ) -> some View {
        HomeworkRowView(
            item: item,
            course: store.course(for: item.courseId),
            now: now,
            isCompact: isCompact,
            isSelected: store.selectedItemId == item.id,
            onToggleComplete: {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                    store.toggleCompletion(id: item.id, now: now)
                }
            },
            onSelect: {
                store.selectedItemId = item.id
                if opensSheetOnTap {
                    sheetDetailItemId = item.id
                }
            },
            onPostponeOneDay: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.postponeHomework(id: item.id, byDays: 1)
                }
            },
            onDelete: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.deleteHomework(id: item.id)
                }
            }
        )
    }

    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Color(hex: "#34D399").opacity(0.9))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 16)
    }

    private var completedArchiveFooter: some View {
        HStack {
            Text("共 \(store.completedCount) 条已完成归档")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            Spacer()
            if store.completedCount > 0 {
                Button("清空归档", role: .destructive) {
                    withAnimation { store.clearCompletedItems() }
                }
                .font(.system(size: 11.5))
                .buttonStyle(.glass)
            }
            Button("返回待办") {
                withAnimation { store.showCompletedArchive = false }
            }
            .font(.system(size: 11.5, weight: .semibold))
            .buttonStyle(.glassProminent)
        }
    }
}
