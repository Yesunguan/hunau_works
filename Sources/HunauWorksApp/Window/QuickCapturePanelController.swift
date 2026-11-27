import AppKit
import HunauWorksCore
import SwiftUI

final class QuickCapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
    }
}

@MainActor
final class QuickCapturePanelController: NSObject, NSWindowDelegate {
    private let panel: QuickCapturePanel
    private let glassEffectView: NSGlassEffectView
    private let store: HomeworkStore

    init(store: HomeworkStore) {
        self.store = store
        let rect = NSRect(x: 0, y: 0, width: 552, height: 162)
        self.panel = QuickCapturePanel(contentRect: rect)

        let glassView = NSGlassEffectView(frame: NSRect(origin: .zero, size: rect.size))
        glassView.autoresizingMask = [.width, .height]
        glassView.cornerRadius = 24
        self.glassEffectView = glassView

        super.init()

        let hudView = QuickCaptureHUDView(store: store) { [weak self] in
            self?.dismiss()
        }
        let hostingView = NSHostingView(rootView: hudView)
        hostingView.sizingOptions = []
        hostingView.frame = NSRect(origin: .zero, size: rect.size)
        hostingView.autoresizingMask = [.width, .height]

        let container = NSView(frame: NSRect(origin: .zero, size: rect.size))
        container.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)
        glassView.contentView = container

        panel.contentView = glassView
        panel.delegate = self
        applySettings(store.settings)
    }

    func applySettings(_ settings: AppSettings) {
        glassEffectView.style = (settings.glassStyle == .clear) ? .clear : .regular
        glassEffectView.tintColor = DesktopGlassWindowController.nsTintColor(for: settings.tintPreset)
        switch settings.appearanceMode {
        case .system: panel.appearance = nil
        case .light: panel.appearance = NSAppearance(named: .aqua)
        case .dark: panel.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func toggle() {
        if panel.isVisible {
            dismiss()
        } else {
            present()
        }
    }

    func present() {
        applySettings(store.settings)
        // Center horizontally in the upper third of the screen containing mouse cursor
        let mouseLoc = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) } ?? NSScreen.main
        if let visible = targetScreen?.visibleFrame {
            let x = visible.midX - panel.frame.width / 2
            let y = visible.maxY - panel.frame.height - max(110, visible.height * 0.18)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        NSApp.activate()
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func dismiss() {
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        dismiss()
    }
}
