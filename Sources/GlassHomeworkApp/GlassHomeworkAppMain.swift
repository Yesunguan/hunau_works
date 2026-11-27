import AppKit
import GlassHomeworkCore
import SwiftUI

@MainActor
final class AppCoordinator: NSObject, NSApplicationDelegate {
    private var store: HomeworkStore!
    private var notificationService: NotificationService!
    private var hotKeyService: GlobalHotKeyService!
    private var launchService: LaunchAtLoginService!
    private var windowController: DesktopGlassWindowController!
    private var quickCaptureController: QuickCapturePanelController!
    private var menuBarController: MenuBarController!
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMinimalMainMenu()

        let args = ProcessInfo.processInfo.arguments
        let storePathArg = args.first { $0.hasPrefix("--store-path=") }?.replacingOccurrences(of: "--store-path=", with: "")
        let persistence = storePathArg.map { PersistenceService(fileURL: URL(fileURLWithPath: $0)) } ?? PersistenceService()

        let store = HomeworkStore(persistence: persistence)
        self.store = store
        self.notificationService = NotificationService()
        self.hotKeyService = GlobalHotKeyService()
        self.launchService = LaunchAtLoginService()

        // Sync LaunchAtLogin setting with actual disk state
        let actualLaunchState = launchService.isInstalled
        if actualLaunchState {
            launchService.syncPathIfInstalled()
        }
        if store.settings.launchAtLoginEnabled != actualLaunchState {
            store.settings.launchAtLoginEnabled = actualLaunchState
            store.saveSilently()
        }

        // Optional CLI arguments for automated visual verification
        let forceFloating = args.contains("--preview-floating")
        let forceClear = args.contains("--preview-clear")
        let forceDark = args.contains("--preview-dark")
        let presetArg = args.first { $0.hasPrefix("--preview-size=") }?.replacingOccurrences(of: "--preview-size=", with: "")
        let showQuickCaptureOnStart = args.contains("--preview-quick-capture")

        if forceFloating {
            store.settings.pinMode = .floating
        }
        if forceClear {
            store.settings.glassStyle = .clear
        }
        if forceDark {
            store.settings.appearanceMode = .dark
        }

        let actions = AppActions(
            applySizePreset: { [weak self] preset in
                self?.windowController.applySizePreset(preset, animated: true)
            },
            openQuickCapture: { [weak self] in
                self?.quickCaptureController.present()
            },
            toggleLaunchAtLogin: { [weak self] enabled in
                guard let self else { return }
                do {
                    try self.launchService.setEnabled(enabled)
                    self.store.updateSettings { $0.launchAtLoginEnabled = enabled }
                } catch {
                    self.store.statusBannerMessage = "设置开机自启失败：\(error.localizedDescription)"
                }
            },
            sendTestNotification: { [weak self] completion in
                self?.notificationService.sendTestNotification(completion: completion)
            },
            notificationStatusText: { [weak self] in
                self?.notificationService.authorizationStatusText ?? "未知"
            }
        )

        let rootView = MainGlassRootView(store: store, actions: actions)
        self.windowController = DesktopGlassWindowController(store: store, rootView: rootView)
        self.quickCaptureController = QuickCapturePanelController(store: store)
        self.menuBarController = MenuBarController(store: store)

        if let presetArg, let preset = WindowSizePreset(rawValue: presetArg) {
            windowController.applySizePreset(preset, animated: false)
        }

        // Wire callbacks
        store.onDataChanged = { [weak self] in
            guard let self else { return }
            self.menuBarController.refresh()
            self.notificationService.syncReminders(for: self.store)
        }
        store.onSettingsChanged = { [weak self] in
            guard let self else { return }
            self.windowController.applySettings(self.store.settings)
            self.quickCaptureController.applySettings(self.store.settings)
            self.hotKeyService.setEnabled(self.store.settings.globalHotKeyEnabled) { [weak self] in
                self?.quickCaptureController.toggle()
            }
            self.menuBarController.refresh()
            self.notificationService.syncReminders(for: self.store)
        }

        menuBarController.onToggleMainWindow = { [weak self] in
            self?.windowController.toggleVisibility()
        }
        menuBarController.onOpenQuickCapture = { [weak self] in
            self?.quickCaptureController.toggle()
        }
        menuBarController.onTogglePinMode = { [weak self] in
            guard let self else { return }
            self.store.updateSettings {
                $0.pinMode = ($0.pinMode == .desktopSticker) ? .floating : .desktopSticker
            }
        }
        menuBarController.onApplySizePreset = { [weak self] preset in
            self?.windowController.showWindow(activate: true)
            self?.windowController.applySizePreset(preset, animated: true)
        }
        menuBarController.onToggleMute = { [weak self] in
            self?.store.updateSettings { $0.notificationsMuted.toggle() }
        }
        menuBarController.onQuit = {
            NSApp.terminate(nil)
        }

        notificationService.onOpenHomework = { [weak self] id in
            guard let self else { return }
            self.store.showCompletedArchive = false
            self.store.selectedItemId = id
            self.windowController.showWindow(activate: true)
        }

        // Enable global hotkey & notifications
        hotKeyService.setEnabled(store.settings.globalHotKeyEnabled) { [weak self] in
            self?.quickCaptureController.toggle()
        }
        if store.settings.notificationsEnabled {
            notificationService.requestAuthorizationIfNeeded()
        }
        notificationService.syncReminders(for: store)

        // Periodic menu bar badge refresh (every 60s for overdue transitions)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.menuBarController.refresh()
            }
        }

        windowController.showWindow(activate: forceFloating)
        if showQuickCaptureOnStart {
            quickCaptureController.present()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windowController.showWindow(activate: true)
        return true
    }

    /// Provides standard Cmd+C/V/X/A/Z editing shortcuts for TextField & TextEditor in a nib-less AppKit app.
    private func installMinimalMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出湘农作业", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }
}

@MainActor
struct AppActions {
    let applySizePreset: @MainActor (WindowSizePreset) -> Void
    let openQuickCapture: @MainActor () -> Void
    let toggleLaunchAtLogin: @MainActor (Bool) -> Void
    let sendTestNotification: @MainActor (@escaping @MainActor (String) -> Void) -> Void
    let notificationStatusText: @MainActor () -> String
}

@main
enum GlassHomeworkEntry {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let coordinator = AppCoordinator()
        app.delegate = coordinator
        withExtendedLifetime(coordinator) {
            app.run()
        }
    }
}
