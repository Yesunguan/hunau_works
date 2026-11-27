import AppKit
import HunauWorksCore
import SwiftUI

final class GlassDesktopWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.minSize = NSSize(width: 275, height: 270)
        self.maxSize = NSSize(width: 1400, height: 1100)
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
    }
}

@MainActor
final class DesktopGlassWindowController: NSObject, NSWindowDelegate {
    let window: GlassDesktopWindow
    private let glassEffectView: NSGlassEffectView
    private let store: HomeworkStore
    private var saveFrameTask: Task<Void, Never>?

    var isVisible: Bool { window.isVisible }

    init<Content: View>(store: HomeworkStore, rootView: Content) {
        self.store = store

        let initialRect = Self.resolveInitialFrame(from: store.settings.windowFrame)
        self.window = GlassDesktopWindow(contentRect: initialRect)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        hostingView.frame = NSRect(origin: .zero, size: initialRect.size)
        hostingView.autoresizingMask = [.width, .height]

        let containerView = NSView(frame: NSRect(origin: .zero, size: initialRect.size))
        containerView.autoresizingMask = [.width, .height]
        containerView.addSubview(hostingView)

        let glassView = NSGlassEffectView(frame: NSRect(origin: .zero, size: initialRect.size))
        glassView.autoresizingMask = [.width, .height]
        glassView.cornerRadius = CGFloat(store.settings.cornerRadius)
        glassView.contentView = containerView
        self.glassEffectView = glassView

        super.init()

        window.contentView = glassView
        window.delegate = self
        applySettings(store.settings)
    }

    func showWindow(activate: Bool = false) {
        if activate {
            NSApp.activate()
            window.orderFrontRegardless()
            window.makeKey()
        } else {
            window.orderFrontRegardless()
        }
    }

    func hideWindow() {
        window.orderOut(nil)
    }

    func toggleVisibility() {
        if window.isVisible {
            hideWindow()
        } else {
            showWindow(activate: true)
        }
    }

    func applySettings(_ settings: AppSettings) {
        // Glass style & corner radius
        glassEffectView.cornerRadius = CGFloat(settings.cornerRadius)
        glassEffectView.style = (settings.glassStyle == .clear) ? .clear : .regular
        glassEffectView.tintColor = Self.nsTintColor(for: settings.tintPreset)

        // Appearance override
        switch settings.appearanceMode {
        case .system:
            window.appearance = nil
        case .light:
            window.appearance = NSAppearance(named: .aqua)
        case .dark:
            window.appearance = NSAppearance(named: .darkAqua)
        }

        // Window pin level
        switch settings.pinMode {
        case .desktopSticker:
            let desktopIconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
            window.level = NSWindow.Level(rawValue: desktopIconLevel + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        case .floating:
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
    }

    func applySizePreset(_ preset: WindowSizePreset, animated: Bool = true) {
        let current = window.frame
        let newSize = NSSize(width: preset.width, height: preset.height)
        // Anchor top-left corner so resizing expands rightward & downward naturally
        let newOriginY = current.maxY - newSize.height
        var targetRect = NSRect(x: current.minX, y: newOriginY, width: newSize.width, height: newSize.height)

        if let screen = window.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            if targetRect.maxX > visible.maxX - 12 {
                targetRect.origin.x = max(visible.minX + 12, visible.maxX - newSize.width - 12)
            }
            if targetRect.minY < visible.minY + 12 {
                targetRect.origin.y = visible.minY + 12
            }
            if targetRect.maxY > visible.maxY - 12 {
                targetRect.origin.y = visible.maxY - newSize.height - 12
            }
        }

        window.setFrame(targetRect, display: true, animate: animated)
        schedulePersistFrame()
    }

    // MARK: - NSWindowDelegate

    func windowDidResize(_ notification: Notification) {
        schedulePersistFrame()
    }

    func windowDidMove(_ notification: Notification) {
        schedulePersistFrame()
    }

    private func schedulePersistFrame() {
        saveFrameTask?.cancel()
        let frame = window.frame
        saveFrameTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self else { return }
            self.store.settings.windowFrame = WindowFrameRect(
                x: frame.origin.x,
                y: frame.origin.y,
                width: frame.size.width,
                height: frame.size.height
            )
            self.store.saveSilently()
        }
    }

    // MARK: - Helpers

    private static func resolveInitialFrame(from saved: WindowFrameRect?) -> NSRect {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        if let saved, saved.width >= 275, saved.height >= 270 {
            let rect = NSRect(x: saved.x, y: saved.y, width: saved.width, height: saved.height)
            let onSomeScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(rect) }
            if onSomeScreen {
                return rect
            }
        }
        // Default position: right side of desktop, spacious margin from edges
        let defaultWidth = WindowSizePreset.standard.width
        let defaultHeight = WindowSizePreset.standard.height
        let x = visible.maxX - defaultWidth - 36
        let y = visible.maxY - defaultHeight - 48
        return NSRect(x: max(visible.minX + 24, x), y: max(visible.minY + 24, y), width: defaultWidth, height: defaultHeight)
    }

    static func nsTintColor(for preset: GlassTintPreset) -> NSColor? {
        switch preset {
        case .none:
            return nil
        case .glacier:
            return NSColor(calibratedRed: 0.28, green: 0.62, blue: 0.98, alpha: 0.16)
        case .twilight:
            return NSColor(calibratedRed: 0.56, green: 0.42, blue: 0.96, alpha: 0.16)
        case .mint:
            return NSColor(calibratedRed: 0.18, green: 0.80, blue: 0.60, alpha: 0.15)
        case .amber:
            return NSColor(calibratedRed: 0.96, green: 0.68, blue: 0.22, alpha: 0.15)
        case .rose:
            return NSColor(calibratedRed: 0.95, green: 0.42, blue: 0.68, alpha: 0.15)
        }
    }
}
