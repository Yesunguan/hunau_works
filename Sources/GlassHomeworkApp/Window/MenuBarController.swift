import AppKit
import GlassHomeworkCore

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let store: HomeworkStore

    var onToggleMainWindow: (@MainActor () -> Void)?
    var onOpenQuickCapture: (@MainActor () -> Void)?
    var onTogglePinMode: (@MainActor () -> Void)?
    var onApplySizePreset: (@MainActor (WindowSizePreset) -> Void)?
    var onToggleMute: (@MainActor () -> Void)?
    var onQuit: (@MainActor () -> Void)?

    init(store: HomeworkStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        refresh()
    }

    func refresh() {
        let now = Date()
        let incomplete = store.incompleteCount
        let overdue = store.overdueCount(now: now)
        let critical = store.dueSoon24hCount(now: now)

        if let button = statusItem.button {
            let symbolName: String
            if overdue > 0 {
                symbolName = "exclamationmark.circle.fill"
            } else if incomplete == 0 {
                symbolName = "checkmark.circle.fill"
            } else {
                symbolName = "checklist"
            }

            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "琉璃作业")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading

            if incomplete > 0 {
                button.title = overdue > 0 ? " \(incomplete) (!)" : " \(incomplete)"
            } else {
                button.title = ""
            }
            button.toolTip = "琉璃作业：\(incomplete) 项待完成（\(overdue) 逾期，\(critical) 项 24h 内到期）"
        }

        buildMenu(incomplete: incomplete, overdue: overdue, critical: critical)
    }

    private func buildMenu(incomplete: Int, overdue: Int, critical: Int) {
        let menu = NSMenu()

        let summaryText = incomplete == 0
            ? "全部作业已完成"
            : "待完成 \(incomplete) 项 · 逾期 \(overdue) · 24h内 \(critical)"
        let summaryItem = NSMenuItem(title: summaryText, action: nil, keyEquivalent: "")
        summaryItem.isEnabled = false
        menu.addItem(summaryItem)

        menu.addItem(.separator())

        let toggleItem = NSMenuItem(
            title: "显示 / 隐藏桌面面板",
            action: #selector(handleToggleMainWindow),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let quickItem = NSMenuItem(
            title: "快速记一条作业（⌥⇧H）",
            action: #selector(handleQuickCapture),
            keyEquivalent: ""
        )
        quickItem.target = self
        menu.addItem(quickItem)

        menu.addItem(.separator())

        let pinLabel = store.settings.pinMode == .floating
            ? "切换为桌面贴纸（不遮挡窗口）"
            : "切换为始终置顶（悬浮前方）"
        let pinItem = NSMenuItem(title: pinLabel, action: #selector(handleTogglePin), keyEquivalent: "")
        pinItem.target = self
        menu.addItem(pinItem)

        // Size presets submenu
        let sizeMenuItem = NSMenuItem(title: "切换窗口尺寸", action: nil, keyEquivalent: "")
        let sizeSubmenu = NSMenu()
        for preset in WindowSizePreset.allCases {
            let item = NSMenuItem(
                title: "\(preset.label)（\(Int(preset.width)) × \(Int(preset.height))）",
                action: #selector(handleSizePreset(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = preset.rawValue
            sizeSubmenu.addItem(item)
        }
        sizeMenuItem.submenu = sizeSubmenu
        menu.addItem(sizeMenuItem)

        let muteTitle = store.settings.notificationsMuted ? "恢复系统通知提醒" : "暂时静音系统通知"
        let muteItem = NSMenuItem(title: muteTitle, action: #selector(handleToggleMute), keyEquivalent: "")
        muteItem.target = self
        menu.addItem(muteItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出琉璃作业", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func handleToggleMainWindow() { onToggleMainWindow?() }
    @objc private func handleQuickCapture() { onOpenQuickCapture?() }
    @objc private func handleTogglePin() { onTogglePinMode?() }
    @objc private func handleToggleMute() { onToggleMute?() }
    @objc private func handleQuit() { onQuit?() }

    @objc private func handleSizePreset(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String,
           let preset = WindowSizePreset(rawValue: raw) {
            onApplySizePreset?(preset)
        }
    }
}
